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
# Ficha por gobierno: ideal points + notas
ipg = pd.read_csv(P / "argentina_by_government_ideal_points.csv")
dump("government_ideal_points.json", json.loads(ipg.to_json(orient="records", force_ascii=False)))

# Votaciones de Argentina, una fila por resolución, con el resultado global
V = pd.read_csv(P / "votes_1946_2026.csv.gz", usecols=["rcid", "ccode", "vote_label"])
R = pd.read_csv(P / "resolutions_1946_2026.csv")
tally = V[V.vote_label.isin(["yes", "no", "abstain"])].groupby(["rcid", "vote_label"]).size().unstack(fill_value=0)
arg = V[V.ccode == 160][["rcid", "vote_label"]].rename(columns={"vote_label": "arg"})
A = arg.merge(R, on="rcid").merge(tally, left_on="rcid", right_index=True, how="left")
gov["start"] = pd.to_datetime(gov["start"]); gov["end"] = pd.to_datetime(gov["end"])
def gid(d):
    m = gov[(gov.start <= d) & (d <= gov.end)]
    return m.gov_id.iloc[0] if len(m) else None
A["date"] = pd.to_datetime(A["date"]); A["topics"] = A["topics"].fillna("")
A["g"] = A["date"].map(gid)
def tidy(t):
    t = str(t).strip()
    return t[:1] + t[1:].lower() if t.isupper() else t
A["t"] = A["title_short"].fillna("").map(tidy)
A = A.sort_values(["date", "rcid"])
out = [{"d": r.date.strftime("%Y-%m-%d"), "s": r.unres if isinstance(r.unres, str) else "", "t": r.t, "tp": r.topics or "",
        "v": r.arg, "y": int(r.yes), "n": int(r.no), "a": int(r.abstain), "g": r.g} for r in A.itertuples()]
dump("argentina_votes.json", out)
print("ok", {p.name: p.stat().st_size for p in D.iterdir()})
