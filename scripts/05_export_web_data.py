"""Exporta los datos procesados a JSON para el sitio web (docs/data/)."""
import json
import pandas as pd
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
P, D = ROOT / "data/processed", ROOT / "docs/data"
D.mkdir(parents=True, exist_ok=True)

def dump(name, obj):
    (D / name).write_text(json.dumps(obj, ensure_ascii=False, separators=(",", ":")), encoding="utf-8")

# Ideal points de todos los países (serie anual)
ip = pd.read_csv(P / "ideal_points_1946_2025.csv").dropna(subset=["ideal_point"])
ip["label"] = ip["country"] + " (" + ip["iso3c"].fillna("") + ")"
countries = {}
for (cc, name), g in ip.groupby(["ccode", "country"]):
    countries[str(cc)] = {"name": name, "iso3": g["iso3c"].iloc[0] if pd.notna(g["iso3c"].iloc[0]) else "",
                          "years": g["year"].astype(int).tolist(), "ip": g["ideal_point"].round(3).tolist()}
world = ip.groupby("year")["ideal_point"].mean().round(3)
dump("ideal_points.json", {"countries": countries, "world": {"years": world.index.astype(int).tolist(), "ip": world.tolist()}})

gov = pd.read_csv(ROOT / "data/governments_argentina.csv")
dump("governments.json", json.loads(gov.to_json(orient="records", force_ascii=False)))

votes = pd.read_csv(P / "argentina_by_government_votes.csv")
dump("votes_by_government.json", json.loads(votes.to_json(orient="records", force_ascii=False)))

ag = pd.read_csv(P / "argentina_by_government_agreement.csv"); ag["topic"] = "Todos"
agt = pd.read_csv(P / "argentina_by_government_agreement_topic.csv")
allag = pd.concat([ag, agt], ignore_index=True)
dump("agreement_by_government.json", json.loads(allag.to_json(orient="records", force_ascii=False)))
print("ok", {p.name: p.stat().st_size for p in D.iterdir()})
