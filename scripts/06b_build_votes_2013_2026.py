"""Construye la base de votos AGNU 2013-2026 desde el dataset oficial de la Biblioteca Dag Hammarskjöld.

Entrada : data/raw/undl_oficial/2026_10_15_votes_ga.csv  (versión 6, 15/10/2026; se descarga a mano de
          https://digitallibrary.un.org/record/4060887), data/processed/ideal_points_1946_2025.csv (códigos COW) y,
          si existe, data/undl_registros/votes_ga_registros.csv (votaciones posteriores al dataset oficial, ver 06a)
Salida  : data/processed/resolutions_2013_2026.csv, data/processed/votes_2013_2026.csv.gz
Mismo formato que la base 1946-2012 (vote_label: yes/abstain/no/absent; X = no votó -> absent).  Los temas NO vienen
codificados por Voeten en este tramo: se asignan por palabras clave sobre el título y las materias (topic_source=keywords).
Atribución obligatoria: United Nations Dag Hammarskjöld Library, United Nations General Assembly Voting Data, 2026,
https://digitallibrary.un.org/record/4060887. Uso no comercial con atribución.
"""
import re
import pandas as pd
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
P = ROOT / "data/processed"
VOTE = {"Y": "yes", "N": "no", "A": "abstain", "X": "absent"}

TOPIC_RULES = {
    "Medio Oriente": r"palestin|israel|middle east|jerusalem|golan|unrwa|occupied (arab|syrian)|arab-israeli",
    "Armas nucleares": r"nuclear|atomic|non-proliferation|test-ban|radiolog",
    "Desarme": r"disarm|arms\b|weapon|missile|landmine|anti-personnel|cluster munition|small arms|conventional arms",
    "Derechos humanos": r"human rights|racism|racial|torture|death penalty|rights of (the child|indigenous|persons|women)|discriminat|enforced disappearance|freedom of (religion|expression)",
    "Colonialismo": r"self-determination|colonial|non-self-governing|decoloni|western sahara|apartheid|falkland|malvinas|mayotte",
    "Desarrollo económico": r"economic|development|trade\b|financing for development|financial (system|crisis|institutions)|debt|poverty|sustainable|globali[sz]ation|commodit|food|energy|industrial",
}

ip = pd.read_csv(P / "ideal_points_1946_2025.csv")
iso2cow = ip.dropna(subset=["iso3c"]).drop_duplicates("iso3c").set_index("iso3c")["ccode"].to_dict()
name2cow = ip.drop_duplicates("ccode").set_index("ccode")["country"].to_dict()
# códigos ISO de la ONU que difieren de los de la fuente de ideal points (o faltan en ella)
MANUAL = {"SRB": 345, "MNE": 341, "SSD": 626, "TLS": 860, "CZE": 316, "MKD": 343, "SWZ": 572, "CIV": 437,
          "DEU": 255, "ROU": 360, "ZWE": 552, "KIR": 970, "NRU": 971, "TUV": 973, "PLW": 986, "MHL": 983, "FSM": 987,
          "AND": 232, "MCO": 221, "LIE": 223, "SMR": 331, "VUT": 935, "WSM": 990, "TON": 972, "KNA": 60, "LCA": 56,
          "VCT": 57, "ATG": 58, "GRD": 55, "DMA": 54, "BRB": 53, "BHS": 31, "BLZ": 80, "SYC": 591, "MDV": 781, "CPV": 402,
          "STP": 403, "COM": 581, "BRN": 835, "BTN": 760, "ERI": 531, "PRK": 731, "COD": 490, "MMR": 775}


d = pd.read_csv(ROOT / "data/raw/undl_oficial/2026_10_15_votes_ga.csv", low_memory=False)
# votaciones posteriores al dataset oficial, tomadas de los registros de la Biblioteca Digital (scripts/06a)
SUP = ROOT / "data/undl_registros/votes_ga_registros.csv"
if SUP.exists():
    s = pd.read_csv(SUP, low_memory=False)
    s = s[~s["undl_id"].isin(d["undl_id"]) & (s["date"] > d["date"].max())]
    print("registros agregados desde la Biblioteca Digital:", sorted(s["resolution"].unique()))
    d = pd.concat([d, s], ignore_index=True)
d = d[d["date"] >= "2013-01-01"].copy()
d["date"] = d["date"].astype(str)
d = d.rename(columns={"undl_id": "undl_record", "resolution": "unres"})
def clean_title(t):
    t = re.sub(r"\s*:?\s*(reso\w+|decision)\s*/\s*adopted by the General Assembly\s*$", "", str(t).strip(), flags=re.I)
    return re.sub(r"\s*:?\s*(resolution|decision)\s*/?\s*$", "", t, flags=re.I).strip(" :/")
d["title_short"] = d["title"].map(clean_title)

r = d.drop_duplicates("undl_record").copy()
def session_of(row):
    m = re.search(r"A/RES/(\d+)/", str(row["unres"])) or re.search(r"A/(\d+)/PV", str(row["meeting"]))
    return int(m.group(1)) if m else None
r["session"] = r.apply(session_of, axis=1)
def topics_of(row):
    text = " ".join(str(row[c]) for c in ("title_short", "agenda_title", "subjects") if pd.notna(row[c])).lower()
    return ";".join(t for t, rx in TOPIC_RULES.items() if re.search(rx, text))
r["topics"] = r.apply(topics_of, axis=1)
res = pd.DataFrame({"undl_record": r["undl_record"], "session": r["session"], "date": r["date"], "unres": r["unres"],
                    "meeting": r["meeting"], "title_short": r["title_short"], "description": r["agenda_title"].fillna(""),
                    "topics": r["topics"], "topic_source": "keywords", "n_yes": r["total_yes"], "n_no": r["total_no"],
                    "n_abstain": r["total_abstentions"], "n_nonvoting": r["total_non_voting"], "n_total": r["total_ms"]})
res = res.sort_values(["date", "undl_record"]).reset_index(drop=True)
res["rcid"] = 100001 + res.index
res["year"] = pd.to_datetime(res["date"], errors="coerce").dt.year

unknown = {}
def cow_of(iso, name):
    c = iso2cow.get(iso, MANUAL.get(iso))
    if c is None: unknown[iso] = name
    return c
v = d[["undl_record", "ms_code", "ms_name", "ms_vote"]].rename(columns={"ms_code": "iso3", "ms_vote": "vote_code"})
v["ccode"] = [cow_of(i, n) for i, n in zip(v["iso3"], v["ms_name"])]
v["vote_label"] = v["vote_code"].map(VOTE).fillna("other")
v = v.merge(res[["undl_record", "rcid", "session", "date", "unres"]], on="undl_record")
v["country"] = v["ccode"].map(name2cow).fillna(v["ms_name"].str.title())
v = v.drop(columns=["ms_name"])
v = v[["undl_record", "iso3", "ccode", "vote_code", "vote_label", "rcid", "session", "date", "unres", "country"]]

res.to_csv(P / "resolutions_2013_2026.csv", index=False)
v.to_csv(P / "votes_2013_2026.csv.gz", index=False, compression="gzip")

print("resoluciones:", len(res), "| votos:", len(v), "| países:", v["iso3"].nunique(), "| última fecha:", res["date"].max())
print("sin código COW:", unknown)
print(v["vote_label"].value_counts().to_string())
print("temas:", res["topics"].replace("", "(ninguno)").str.split(";").explode().value_counts().to_dict())
# control cruzado: conteo de votos por país vs. totales del propio dataset
chk = v.groupby("rcid")["vote_label"].value_counts().unstack(fill_value=0).join(res.set_index("rcid")[["n_yes", "n_no", "n_abstain"]].astype(float).fillna(0))
bad = chk[(chk["yes"] != chk["n_yes"]) | (chk["no"] != chk["n_no"]) | (chk["abstain"] != chk["n_abstain"])]
print("registros cuyo conteo no coincide con los totales:", len(bad), "de", len(chk))
print(res.groupby("year").size().to_dict())
print(v[v.iso3 == "ARG"]["vote_label"].value_counts().to_dict())
