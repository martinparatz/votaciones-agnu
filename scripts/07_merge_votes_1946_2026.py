"""Une la base Voeten (1946-2012) con la de la UN Digital Library (2013-2026) en un formato común.

Salida : data/processed/resolutions_1946_2026.csv, data/processed/votes_1946_2026.csv.gz
Columnas de votos: rcid, ccode (COW), country, iso3, session, date, unres, vote_label (yes/abstain/no/absent)
topic_source: 'voeten' (codificación manual de Voeten, hasta 2012) o 'keywords' (palabras clave sobre el título, desde 2013).
Los rcid de la base 2013+ empiezan en 100001 para no pisar los de Voeten.
"""
import pandas as pd
from pathlib import Path

P = Path(__file__).resolve().parents[1] / "data/processed"
r1 = pd.read_csv(P / "resolutions_1946_2012.csv")
r1["topic_source"] = "voeten"; r1["source"] = "Voeten (Harvard Dataverse)"
r2 = pd.read_csv(P / "resolutions_2013_2026.csv")
r2["source"] = "UN Digital Library"
cols = ["rcid", "session", "date", "year", "unres", "title_short", "description", "topics", "topic_source", "source"]
res = pd.concat([r1.reindex(columns=cols), r2.reindex(columns=cols)], ignore_index=True)
res["topics"] = res["topics"].fillna("")
res.to_csv(P / "resolutions_1946_2026.csv", index=False)

v1 = pd.read_csv(P / "votes_1946_2012.csv.gz").rename(columns={"iso3_voeten": "iso3"})
v2 = pd.read_csv(P / "votes_2013_2026.csv.gz")
vc = ["rcid", "ccode", "country", "iso3", "session", "date", "unres", "vote_label"]
v = pd.concat([v1[vc], v2[vc]], ignore_index=True)
v.to_csv(P / "votes_1946_2026.csv.gz", index=False, compression="gzip")
print("resoluciones:", len(res), "| votos:", len(v), "| rango:", res["date"].min(), res["date"].max())
print(v[v.ccode == 160]["vote_label"].value_counts().to_dict())
