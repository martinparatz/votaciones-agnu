"""Construye la base de votos AGNU 1946-2012 (Voeten, versión 2013) en formato largo.

Entrada : data/raw/undata-213.tab, data/raw/descriptions-213.tab
Salida  : data/processed/resolutions_1946_2012.csv
          data/processed/votes_1946_2012.csv.gz   (país x resolución)
Códigos de voto originales: 1 = sí, 2 = abstención, 3 = no, 8 = ausente, 9 = no miembro.
"""
import io
import pandas as pd
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
raw, out = ROOT / "data/raw", ROOT / "data/processed"
out.mkdir(parents=True, exist_ok=True)

LABELS = {1: "yes", 2: "abstain", 3: "no", 8: "absent", 9: "non_member"}
TOPICS = {"me": "Medio Oriente", "nu": "Armas nucleares", "di": "Desarme",
          "hr": "Derechos humanos", "co": "Colonialismo", "ec": "Desarrollo económico"}

# una fila trae campos sobrantes al final (comilla suelta y tabs): se recorta a 18 columnas
lines = (raw / "descriptions-213.tab").read_text(encoding="latin-1").splitlines()
lines = ["\t".join(l.split("\t")[:18]) for l in lines]
res = pd.read_csv(io.StringIO("\n".join(lines)), sep="\t", quoting=3, dtype=str)
# el archivo trae comillas escapadas con barra; se leen sin comillado y se limpian a mano
for c in res.columns:
    res[c] = res[c].str.strip().str.strip('"')
for c in ["session","rcid","abstain","yes","no","amend","para","me","nu","di","hr","co","ec"]:
    res[c] = pd.to_numeric(res[c], errors="coerce")
res = res.rename(columns={"short": "title_short", "descr": "description",
                          "para": "is_paragraph", "amend": "is_amendment",
                          "importantvote": "important_vote"})
for k, v in TOPICS.items():
    res[v] = res[k]
res["topics"] = res[list(TOPICS)].apply(
    lambda r: ";".join(TOPICS[k] for k in TOPICS if r[k] == 1), axis=1)
res["year"] = pd.to_datetime(res["date"], errors="coerce").dt.year
res = res.drop(columns=list(TOPICS))
res.to_csv(out / "resolutions_1946_2012.csv", index=False)

cols = ["rcid", "session", "date", "unres", "vote", "ccode", "voetenname", "voetenshortcode", "uncode"]
v = pd.read_csv(raw / "undata-213.tab", sep="\t", quotechar='"', usecols=cols, encoding="latin-1")
v["vote_label"] = v["vote"].map(LABELS)
v = v.rename(columns={"voetenname": "country", "voetenshortcode": "iso3_voeten", "uncode": "un_m49"})
v.to_csv(out / "votes_1946_2012.csv.gz", index=False, compression="gzip")

print("resoluciones:", len(res), "| votos:", len(v), "| países:", v["ccode"].nunique())
print(v["vote_label"].value_counts(dropna=False).to_string())
arg = v[v["iso3_voeten"] == "ARG"]
print("\nArgentina:", len(arg), "filas; sesiones", arg["session"].min(), "-", arg["session"].max())
print(arg["vote_label"].value_counts().to_string())
