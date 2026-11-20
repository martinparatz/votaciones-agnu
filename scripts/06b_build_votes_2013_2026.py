"""Construye la base de votos AGNU 2013-2026 desde los registros de la UN Digital Library (MARCXML).

Entrada : data/raw/undl/*.xml (scripts/06a_fetch_undl_votes.py), data/processed/ideal_points_1946_2025.csv (códigos COW)
Salida  : data/processed/resolutions_2013_2026.csv, data/processed/votes_2013_2026.csv.gz
Mismo formato que la base 1946-2012 (vote_label: yes/abstain/no/absent).  Los temas NO vienen codificados por Voeten
en este tramo: se asignan por palabras clave sobre el título y las materias de la resolución (columna topic_source=keywords).
"""
import glob, re
import xml.etree.ElementTree as ET
import pandas as pd
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
P = ROOT / "data/processed"
NS = {"m": "http://www.loc.gov/MARC21/slim"}
VOTE = {"Y": "yes", "N": "no", "A": "abstain", "": "absent"}

TOPIC_RULES = {
    "Medio Oriente": r"palestin|israel|middle east|jerusalem|golan|unrwa|occupied (arab|syrian)|arab-israeli",
    "Armas nucleares": r"nuclear|atomic|non-proliferation|test-ban|radiolog",
    "Desarme": r"disarm|arms\b|weapon|missile|landmine|anti-personnel|cluster munition|small arms|conventional arms",
    "Derechos humanos": r"human rights|racism|racial|torture|death penalty|rights of (the child|indigenous|persons|women)|discriminat|enforced disappearance|freedom of (religion|expression)",
    "Colonialismo": r"self-determination|colonial|non-self-governing|decoloni|western sahara|apartheid|falkland|malvinas|mayotte",
    "Desarrollo económico": r"economic|development|trade\b|financing for development|financial (system|crisis|institutions)|debt|poverty|sustainable|globali[sz]ation|commodit|food|energy|industrial",
}

def subs(rec, tag):
    return [{s.get("code"): (s.text or "") for s in d.findall("m:subfield", NS)} for d in rec.findall(f"m:datafield[@tag='{tag}']", NS)]

def first(rec, tag, code, default=""):
    v = subs(rec, tag)
    return v[0].get(code, default) if v else default

ip = pd.read_csv(P / "ideal_points_1946_2025.csv")
iso2cow = ip.dropna(subset=["iso3c"]).drop_duplicates("iso3c").set_index("iso3c")["ccode"].to_dict()
name2cow = ip.drop_duplicates("ccode").set_index("ccode")["country"].to_dict()
# códigos ISO de la ONU que difieren de los de la fuente de ideal points (o faltan en ella)
MANUAL = {"SRB": 345, "MNE": 341, "SSD": 626, "TLS": 860, "CZE": 316, "MKD": 343, "SWZ": 572, "CIV": 437,
          "DEU": 255, "ROU": 360, "ZWE": 552, "KIR": 970, "NRU": 971, "TUV": 973, "PLW": 986, "MHL": 983, "FSM": 987,
          "AND": 232, "MCO": 221, "LIE": 223, "SMR": 331, "VUT": 935, "WSM": 990, "TON": 972, "KNA": 60, "LCA": 56,
          "VCT": 57, "ATG": 58, "GRD": 55, "DMA": 54, "BRB": 53, "BHS": 31, "BLZ": 80, "SYC": 591, "MDV": 781, "CPV": 402,
          "STP": 403, "COM": 581, "BRN": 835, "BTN": 760, "ERI": 531, "PRK": 731, "COD": 490, "MMR": 775}

rows_res, rows_votes, unknown = [], [], {}
for f in sorted(glob.glob(str(ROOT / "data/raw/undl/*.xml"))):
    for rec in ET.parse(f).getroot().findall("m:record", NS):
        rid = int(rec.find("m:controlfield[@tag='001']", NS).text)
        date = first(rec, "269", "a") or first(rec, "992", "a")
        sym = first(rec, "791", "a") or first(rec, "993", "a")
        pv = first(rec, "952", "a")
        m = re.search(r"A/(\d+)/PV", pv) or re.search(r"A/RES/(\d+)/", sym)
        session = int(m.group(1)) if m else None
        title = re.sub(r"\s*:?\s*(resolution|decision)\s*/?\s*$", "", first(rec, "245", "a").strip(), flags=re.I).strip(" :/")
        agenda = first(rec, "991", "c"); subj = " ".join(first(rec, "991", "d") for _ in [0])
        text = " ".join([title, agenda, subj]).lower()
        topics = [t for t, rx in TOPIC_RULES.items() if re.search(rx, text)]
        tl = subs(rec, "996")
        tally = tl[0] if tl else {}
        rows_res.append({"undl_record": rid, "session": session, "date": date, "unres": sym, "meeting": pv,
                         "title_short": title, "description": agenda, "topics": ";".join(topics),
                         "topic_source": "keywords", "n_yes": tally.get("b"), "n_no": tally.get("c"),
                         "n_abstain": tally.get("d"), "n_nonvoting": tally.get("e"), "n_total": tally.get("f")})
        for v in subs(rec, "967"):
            iso = v.get("c", "")
            cow = iso2cow.get(iso, MANUAL.get(iso))
            if cow is None: unknown[iso] = v.get("e")
            rows_votes.append({"undl_record": rid, "iso3": iso, "country_un": v.get("e", ""), "ccode": cow,
                               "vote_code": v.get("d", ""), "vote_label": VOTE.get(v.get("d", ""), "other")})

res = pd.DataFrame(rows_res).drop_duplicates("undl_record").sort_values(["date", "undl_record"]).reset_index(drop=True)
res["rcid"] = 100001 + res.index
res["year"] = pd.to_datetime(res["date"], errors="coerce").dt.year
v = pd.DataFrame(rows_votes).merge(res[["undl_record", "rcid", "session", "date", "unres"]], on="undl_record")
v["country"] = v["ccode"].map(name2cow).fillna(v["country_un"].str.title())
v = v.drop(columns=["country_un"])

res = res[res["date"] >= "2013-01-01"]
v = v[v["rcid"].isin(res["rcid"])]
res.to_csv(P / "resolutions_2013_2026.csv", index=False)
v.to_csv(P / "votes_2013_2026.csv.gz", index=False, compression="gzip")

print("resoluciones:", len(res), "| votos:", len(v), "| países:", v["iso3"].nunique())
print("sin código COW:", unknown)
print(v["vote_label"].value_counts().to_string())
print("temas:", res["topics"].replace("", "(ninguno)").str.split(";").explode().value_counts().to_dict())
# control cruzado: conteo del registro vs. votos 967
chk = v.groupby("rcid")["vote_label"].value_counts().unstack(fill_value=0).join(res.set_index("rcid")[["n_yes", "n_no", "n_abstain"]].astype(float).fillna(0))
bad = chk[(chk["yes"] != chk["n_yes"]) | (chk["no"] != chk["n_no"]) | (chk["abstain"] != chk["n_abstain"])]
print("registros cuyo conteo no coincide con el resumen 996:", len(bad), "de", len(chk))
print(res.groupby("year").size().to_dict())
print(v[v.iso3 == "ARG"]["vote_label"].value_counts().to_dict())
