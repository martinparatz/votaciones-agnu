"""Convierte registros de votación de la UN Digital Library (MARCXML) al formato del CSV oficial de votos.

Sirve para sumar votaciones posteriores a la última versión del dataset oficial (record 4060887) mientras la
Biblioteca Dag Hammarskjöld no publique una nueva.  No descarga nada: los MARCXML se exportan a mano desde la
Biblioteca Digital (búsqueda `989__a:"Voting Data" 791__a:A/RES/81*`, Exportar > MARCXML) y se guardan en
data/raw/undl_registros/*.xml (no versionado).

Salida: data/undl_registros/votes_ga_registros.csv (versionado; mismas columnas que 2026_10_15_votes_ga.csv),
        data/undl_registros/titles_es_registros.json (título oficial en español de cada registro, campo MARC 767 spa).
Solo se conservan los registros con voto por país (campo 967).  Correspondencia de campos MARC:
001 id, 992 fecha, 791 símbolo y sesión, 993 proyecto, 952 acta, 245 título, 991 tema de agenda y materia,
996 totales (b sí, c no, d abstenciones, e no votantes, f miembros), 967 voto por país (c ISO, e nombre, d voto;
sin d = no votó = X).
"""
import csv, json, re, sys
import xml.etree.ElementTree as ET
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / "data/raw/undl_registros"
OUT = ROOT / "data/undl_registros"
NS = {"m": "http://www.loc.gov/MARC21/slim"}
COLS = ["undl_id", "ms_code", "ms_name", "ms_vote", "date", "session", "resolution", "draft", "committee_report",
        "meeting", "title", "agenda_title", "subjects", "vote_note", "total_yes", "total_no", "total_abstentions",
        "total_non_voting", "total_ms", "undl_link"]


def fields(rec, tag):
    return rec.findall(f"m:datafield[@tag='{tag}']", NS)


def sub(df, code):
    return [s.text or "" for s in df.findall(f"m:subfield[@code='{code}']", NS)]


def first(rec, tag, code, default=""):
    for df in fields(rec, tag):
        v = sub(df, code)
        if v: return v[0].strip()
    return default


rows, titles_es, seen = [], {}, set()
for f in sorted(SRC.glob("*.xml")):
    for rec in ET.parse(f).getroot().findall("m:record", NS):
        rid = rec.find("m:controlfield[@tag='001']", NS).text.strip()
        votes = fields(rec, "967")
        if rid in seen or not votes: continue
        seen.add(rid)
        t = fields(rec, "245")[0]
        title = " ".join(x.strip() for c in "abc" for x in sub(t, c)).strip()
        agenda = fields(rec, "991")
        tot = fields(rec, "996")[0]
        drafts = [sub(df, "a")[0] for df in fields(rec, "993") if df.get("ind1") == "2" and sub(df, "a")]
        reports = [sub(df, "a")[0] for df in fields(rec, "993") if df.get("ind1") != "2" and sub(df, "a")]
        base = {"undl_id": rid, "date": first(rec, "992", "a"), "session": first(rec, "791", "c"),
                "resolution": first(rec, "791", "a"), "draft": "|".join(drafts), "committee_report": "|".join(reports),
                "meeting": first(rec, "952", "a"), "title": title,
                "agenda_title": "|".join(x for df in agenda for x in sub(df, "c")),
                "subjects": "|".join(x for df in agenda for x in sub(df, "d")), "vote_note": first(rec, "996", "a"),
                "total_yes": first(rec, "996", "b"), "total_no": first(rec, "996", "c"),
                "total_abstentions": first(rec, "996", "d"), "total_non_voting": first(rec, "996", "e"),
                "total_ms": first(rec, "996", "f"), "undl_link": f"https://digitallibrary.un.org/record/{rid}"}
        for df in votes:
            rows.append({**base, "ms_code": (sub(df, "c") or [""])[0],
                         "ms_name": (sub(df, "e") or [""])[0], "ms_vote": (sub(df, "d") or ["X"])[0] or "X"})
        for df in fields(rec, "767"):
            if sub(df, "9") == ["spa"] and sub(df, "t"):
                titles_es[base["resolution"]] = sub(df, "t")[0].strip()

if not rows:
    sys.exit(f"No hay registros con voto por país en {SRC}")
OUT.mkdir(exist_ok=True)
with open(OUT / "votes_ga_registros.csv", "w", newline="", encoding="utf-8") as fh:
    w = csv.DictWriter(fh, fieldnames=COLS)
    w.writeheader()
    w.writerows(sorted(rows, key=lambda r: (r["date"], r["undl_id"], r["ms_code"])))
(OUT / "titles_es_registros.json").write_text(json.dumps(titles_es, ensure_ascii=False, indent=1), encoding="utf-8")
by_res = {}
for r in rows: by_res.setdefault((r["date"], r["resolution"]), set()).add(r["ms_code"])
for k in sorted(by_res): print(*k, len(by_res[k]), "países")
