"""Votación de Argentina en la AGNU por gobierno (incluidos los de facto).

Entrada : data/governments_argentina.csv (fechas de cada gobierno), votes/resolutions 1946-2012, ideal points 1946-2025
Salida  : data/processed/argentina_by_government_votes.csv      (reparto de votos por gobierno, todos los temas y por tema)
          data/processed/argentina_by_government_agreement.csv  (coincidencia con referentes por gobierno)
          data/processed/argentina_by_government_ideal_points.csv (ideal point anual y medio por gobierno, hasta 2025)
Asignación: cada votación va al gobierno vigente en su fecha. Para los ideal points (anuales), cada año va al gobierno
vigente el 1 de octubre, cuando transcurre la mayor parte del período ordinario de sesiones.
"""
import pandas as pd
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
P = ROOT / "data/processed"
ARG = 160
REFS = {"EE. UU.": 2, "URSS/Rusia": 365, "China": 710, "Reino Unido": 200, "Francia": 220,
        "Brasil": 140, "Chile": 155, "México": 70, "Cuba": 40, "Uruguay": 165}
TOPICS = ["Medio Oriente", "Armas nucleares", "Desarme", "Derechos humanos", "Colonialismo", "Desarrollo económico"]
CAST = {"yes", "abstain", "no"}

gov = pd.read_csv(ROOT / "data/governments_argentina.csv", parse_dates=["start", "end"])

def gov_of(d):
    m = gov[(gov.start <= d) & (d <= gov.end)]
    return m.gov_id.iloc[0] if len(m) else None

res = pd.read_csv(P / "resolutions_1946_2012.csv", parse_dates=["date"])
res["topics"] = res["topics"].fillna("")
res["gov_id"] = res["date"].map(gov_of)
for t in TOPICS: res[t] = res["topics"].str.contains(t, regex=False)

v = pd.read_csv(P / "votes_1946_2012.csv.gz")
v = v[v["vote_label"].isin(CAST)].merge(res[["rcid", "gov_id"] + TOPICS], on="rcid")
a = v[v.ccode == ARG][["rcid", "vote_label", "gov_id"] + TOPICS].rename(columns={"vote_label": "arg"})

rows = []
for g, h0 in a.groupby("gov_id"):
    for t in ["Todos"] + TOPICS:
        h = h0 if t == "Todos" else h0[h0[t]]
        n = len(h)
        if n == 0: continue
        c = h["arg"].value_counts()
        rows.append({"gov_id": g, "topic": t, "n_votes": n, "pct_yes": 100 * c.get("yes", 0) / n,
                     "pct_abstain": 100 * c.get("abstain", 0) / n, "pct_no": 100 * c.get("no", 0) / n})
votes_g = pd.DataFrame(rows).round(1).merge(gov[["gov_id", "government", "type"]], on="gov_id")
votes_g.to_csv(P / "argentina_by_government_votes.csv", index=False)

ag = []
for g, sub in v.groupby("gov_id"):
    s = sub[sub.ccode == ARG][["rcid", "vote_label"]].rename(columns={"vote_label": "arg"})
    for name, cc in REFS.items():
        o = sub[sub.ccode == cc][["rcid", "vote_label"]].merge(s, on="rcid")
        ag.append({"gov_id": g, "reference": name, "n_common_votes": len(o),
                   "pct_agreement": round(100 * (o.vote_label == o.arg).mean(), 1) if len(o) >= 10 else None})
agree_g = pd.DataFrame(ag).merge(gov[["gov_id", "government", "type"]], on="gov_id")
agree_g.to_csv(P / "argentina_by_government_agreement.csv", index=False)

ipa = pd.read_csv(P / "argentina_ideal_points.csv")
ipa["gov_id"] = [gov_of(pd.Timestamp(int(y), 10, 1)) for y in ipa.year]
ipg = (ipa.groupby("gov_id").agg(year_from=("year", "min"), year_to=("year", "max"), n_years=("year", "count"),
                                 ideal_point_mean=("ARG", "mean"), dist_USA_mean=("dist_USA", "mean"),
                                 dist_CHN_mean=("dist_CHN", "mean"), dist_RUS_mean=("dist_RUS", "mean"),
                                 rank_mean=("rank_from_us_side", "mean")).round(2).reset_index()
       .merge(gov[["gov_id", "government", "type"]], on="gov_id"))
ipg.to_csv(P / "argentina_by_government_ideal_points.csv", index=False)

pd.set_option("display.width", 220); pd.set_option("display.max_colwidth", 42)
t = votes_g[votes_g.topic == "Todos"][["government", "type", "n_votes", "pct_yes", "pct_abstain", "pct_no"]]
print(t.to_string(index=False))
print()
print(agree_g.pivot(index="gov_id", columns="reference", values="pct_agreement")[["EE. UU.", "URSS/Rusia", "China", "Brasil", "Chile", "México", "Cuba"]].to_string())
print()
print(ipg[["gov_id", "government", "year_from", "year_to", "ideal_point_mean", "dist_USA_mean", "rank_mean"]].to_string(index=False))
