"""Datos de todos los países para la web: coincidencias entre pares por período y reparto de votos por país, período y tema.

Entrada : data/processed/votes_1946_2026.csv.gz, resolutions_1946_2026.csv, ideal_points_1946_2025.csv
Salida  : docs/data/world.json
Coincidencia entre dos países = % de votaciones en que ambos emitieron voto (sí/abstención/no) y votaron igual; se exige >= 10 votaciones en común.
"""
import json, sys
import numpy as np
import pandas as pd
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "scripts"))
from country_names_es import NAMES_ES

P, D = ROOT / "data/processed", ROOT / "docs/data"
PERIODS = [
    ("all", "Todo el período (1946–2026)", 1946, 2026),
    ("p1", "Guerra Fría temprana (1946–1962)", 1946, 1962),
    ("p2", "Descolonización y distensión (1963–1979)", 1963, 1979),
    ("p3", "Guerra Fría tardía (1980–1991)", 1980, 1991),
    ("p4", "Posguerra fría (1992–2000)", 1992, 2000),
    ("p5", "Siglo XXI hasta 2011", 2001, 2011),
    ("p6", "Desde 2012 (2012–2026)", 2012, 2026),
]
TOPICS = ["Medio Oriente", "Armas nucleares", "Desarme", "Derechos humanos", "Colonialismo", "Desarrollo económico"]

ip = pd.read_csv(P / "ideal_points_1946_2025.csv")
meta = ip.drop_duplicates("ccode").set_index("ccode")
ccodes = sorted(c for c in meta.index if c in NAMES_ES)
idx = {c: i for i, c in enumerate(ccodes)}

res = pd.read_csv(P / "resolutions_1946_2026.csv")
res["topics"] = res["topics"].fillna("")
res["year"] = pd.to_datetime(res["date"], errors="coerce").dt.year
v = pd.read_csv(P / "votes_1946_2026.csv.gz", usecols=["rcid", "ccode", "vote_label"])
v = v[v.ccode.isin(ccodes)]
CODE = {"yes": 1, "abstain": 2, "no": 3, "absent": 4}
v["c"] = v["vote_label"].map(CODE)
v = v[v["rcid"].isin(set(res["rcid"])) & v["c"].notna()]
rids = sorted(res["rcid"])
ridx = {r: i for i, r in enumerate(rids)}
M = np.zeros((len(rids), len(ccodes)), dtype=np.int8)
M[v["rcid"].map(ridx).to_numpy(), v["ccode"].map(idx).to_numpy()] = v["c"].to_numpy()
year = res.set_index("rcid").loc[rids, "year"].to_numpy()
topic_mask = {t: res.set_index("rcid").loc[rids, "topics"].str.contains(t, regex=False).to_numpy() for t in TOPICS}

agree, counts = {}, {}
for pid, label, y0, y1 in PERIODS:
    rows = (year >= y0) & (year <= y1)
    X = M[rows]
    Y, A, N = [(X == k).astype(np.float32) for k in (1, 2, 3)]
    C = Y + A + N
    same = Y.T @ Y + A.T @ A + N.T @ N
    both = C.T @ C
    pct = np.where(both >= 10, np.rint(100 * same / np.maximum(both, 1)), -1).astype(int)
    agree[pid] = pct.tolist()
    cc = {}
    for t in ["Todos"] + TOPICS:
        sub = X if t == "Todos" else X[topic_mask[t][rows]]
        cc[t] = [[int((sub[:, j] == k).sum()) for k in (1, 2, 3, 4)] for j in range(len(ccodes))]
    counts[pid] = cc

countries = []
for c in ccodes:
    r = meta.loc[c]
    yrs = ip[ip.ccode == c]["year"]
    countries.append({"c": int(c), "es": NAMES_ES[c], "en": r["country"], "iso": r["iso3c"] if isinstance(r["iso3c"], str) else "",
                      "y0": int(yrs.min()), "y1": int(yrs.max())})
out = {"countries": countries, "periods": [{"id": p, "label": l, "y0": a, "y1": b} for p, l, a, b in PERIODS],
       "topics": ["Todos"] + TOPICS, "agree": agree, "counts": counts}
(D / "world.json").write_text(json.dumps(out, ensure_ascii=False, separators=(",", ":")), encoding="utf-8")
print("países:", len(ccodes), "| votaciones:", len(rids), "| world.json:", round((D / "world.json").stat().st_size / 1e6, 2), "MB")
a = agree["all"]; i160 = idx[160]
for c in (2, 365, 710, 140, 666):
    print(NAMES_ES[c], "con Argentina (todo el período):", a[i160][idx[c]])
