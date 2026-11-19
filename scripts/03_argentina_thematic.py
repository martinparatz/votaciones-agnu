"""Análisis temático y por época de la votación de Argentina, 1946-2012.

Entrada : data/processed/votes_1946_2012.csv.gz, resolutions_1946_2012.csv, argentina_epochs_draft.csv
Salida  : data/processed/argentina_votes_by_epoch_topic.csv   (reparto de votos por época y tema)
          data/processed/argentina_agreement_by_epoch.csv     (coincidencia con referentes por época)
          data/processed/argentina_agreement_by_epoch_topic.csv
          data/processed/argentina_votes_by_year.csv
Coincidencia: sobre resoluciones en que ambos países votaron (sí/abstención/no), % con el mismo voto.
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

v = pd.read_csv(P / "votes_1946_2012.csv.gz")
res = pd.read_csv(P / "resolutions_1946_2012.csv")
res["topics"] = res["topics"].fillna("")
res["year"] = pd.to_datetime(res["date"], errors="coerce").dt.year
ep = pd.read_csv(P / "argentina_epochs_draft.csv")
ep.loc[ep["end"] > 2012, "end"] = 2012
ep = ep[ep["start"] <= 2012]

def epoch_of(y):
    for _, r in ep.iterrows():
        if r.start <= y <= r.end: return f"{int(r.start)}-{int(r.end)}"
    return None

res["epoch"] = res["year"].map(epoch_of)
res["n_topics"] = res["topics"].apply(lambda s: 0 if s == "" else len(s.split(";")))
for t in TOPICS: res[t] = res["topics"].str.contains(t, regex=False)
res["Sin tema"] = res["n_topics"] == 0

meta = res[["rcid", "year", "epoch", "important_vote", "is_paragraph", "is_amendment", "Sin tema"] + TOPICS]
v = v[v["vote_label"].isin(CAST)].merge(meta, on="rcid", how="inner")
a = v[v["ccode"] == ARG][["rcid", "vote_label"]].rename(columns={"vote_label": "arg"})

# 1) Reparto de votos de Argentina por época y tema
rows = []
av = a.merge(meta, on="rcid")
for e, g in av.groupby("epoch"):
    for t in ["Todos"] + TOPICS + ["Sin tema"]:
        h = g if t == "Todos" else g[g[t]]
        n = len(h)
        if n == 0: continue
        c = h["arg"].value_counts()
        rows.append({"epoch": e, "topic": t, "n_votes": n,
                     "pct_yes": 100 * c.get("yes", 0) / n, "pct_abstain": 100 * c.get("abstain", 0) / n,
                     "pct_no": 100 * c.get("no", 0) / n})
pd.DataFrame(rows).round(1).to_csv(P / "argentina_votes_by_epoch_topic.csv", index=False)

# 2) Coincidencia con referentes
def agreement(sub):
    out = {}
    s = sub[sub["ccode"] == ARG][["rcid", "vote_label"]].rename(columns={"vote_label": "arg"})
    for name, cc in REFS.items():
        o = sub[sub["ccode"] == cc][["rcid", "vote_label"]].merge(s, on="rcid")
        out[name] = (round(100 * (o["vote_label"] == o["arg"]).mean(), 1), len(o)) if len(o) >= 10 else (None, len(o))
    return out

ag, agt = [], []
for e, g in v.groupby("epoch"):
    for name, (pct, n) in agreement(g).items():
        ag.append({"epoch": e, "reference": name, "pct_agreement": pct, "n_common_votes": n})
    for t in TOPICS:
        for name, (pct, n) in agreement(g[g[t]]).items():
            agt.append({"epoch": e, "topic": t, "reference": name, "pct_agreement": pct, "n_common_votes": n})
pd.DataFrame(ag).to_csv(P / "argentina_agreement_by_epoch.csv", index=False)
pd.DataFrame(agt).to_csv(P / "argentina_agreement_by_epoch_topic.csv", index=False)

# 3) Serie anual
y = av.groupby(["year", "arg"]).size().unstack(fill_value=0)
y["n"] = y.sum(axis=1)
for c in ["yes", "abstain", "no"]: y[f"pct_{c}"] = (100 * y[c] / y["n"]).round(1)
y.reset_index().to_csv(P / "argentina_votes_by_year.csv", index=False)

pd.set_option("display.width", 200)
t = pd.DataFrame(rows).round(0)
print(t[t.topic == "Todos"].to_string(index=False))
print()
print(t[t.topic != "Todos"].pivot(index="topic", columns="epoch", values="pct_yes").to_string())
print("\n%no/abst por tema:")
print(t[t.topic != "Todos"].assign(x=lambda d: d.pct_abstain + d.pct_no).pivot(index="topic", columns="epoch", values="x").to_string())
print()
print(pd.DataFrame(ag).pivot(index="reference", columns="epoch", values="pct_agreement").to_string())
