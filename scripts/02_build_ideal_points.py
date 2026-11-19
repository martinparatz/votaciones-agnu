"""Ideal points anuales (Voeten/Bailey/Strezhnev, 1946-2025) y primer esbozo de épocas de Argentina.

Entrada : data/raw/IdealpointsJuly2025.tab
Salida  : data/processed/ideal_points_1946_2025.csv
          data/processed/argentina_ideal_points.csv   (serie de Argentina + referentes y distancias)
          data/processed/argentina_epochs_draft.csv   (corte automático por segmentación binaria, solo borrador)
Escala: valores altos = más cercano a EE. UU. y Occidente; bajos = más cercano al consenso del mundo en desarrollo.
"""
import numpy as np
import pandas as pd
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
raw, out = ROOT / "data/raw", ROOT / "data/processed"

ip = pd.read_csv(raw / "IdealpointsJuly2025.tab", sep="\t", quotechar='"')
ip["year"] = ip["year"].astype(int)
ip = ip.rename(columns={"countryname": "country", "idealpointfp": "ideal_point"})
keep = ["ccode", "iso3c", "country", "year", "ideal_point", "idealpointall", "idealpointlegacy",
        "nvotesfp", "q5fp", "q95fp"]
ip = ip[keep]
ip.to_csv(out / "ideal_points_1946_2025.csv", index=False)

# se pivotea por código COW porque la fuente asigna el mismo iso3c (YAR) a los dos Yemen
ISO = {"ARG": 160, "USA": 2, "CHN": 710, "RUS": 365, "BRA": 140, "CHL": 155, "MEX": 70, "GBR": 200, "FRA": 220}
wide = ip.pivot(index="year", columns="ccode", values="ideal_point")
wide = wide.rename(columns={v: k for k, v in ISO.items()})
arg = pd.DataFrame({"year": wide.index, "ARG": wide["ARG"].values})
for ref in ["USA", "CHN", "RUS", "BRA", "CHL", "MEX", "GBR", "FRA"]:
    if ref in wide:
        arg[ref] = wide[ref].values
        arg[f"dist_{ref}"] = (arg["ARG"] - arg[ref]).abs()
arg["mean_world"] = wide.mean(axis=1).values
arg["rank_from_us_side"] = wide.rank(axis=1, ascending=False)["ARG"].values
arg["n_countries"] = wide.notna().sum(axis=1).values
arg = arg.dropna(subset=["ARG"])
arg.to_csv(out / "argentina_ideal_points.csv", index=False)

def sse(x): return float(((x - x.mean()) ** 2).sum()) if len(x) else 0.0

def segment(y, min_len=5, n_breaks=5):
    breaks = []
    segs = [(0, len(y))]
    for _ in range(n_breaks):
        best = None
        for a, b in segs:
            base = sse(y[a:b])
            for k in range(a + min_len, b - min_len + 1):
                gain = base - sse(y[a:k]) - sse(y[k:b])
                if best is None or gain > best[0]:
                    best = (gain, a, b, k)
        if best is None: break
        _, a, b, k = best
        segs.remove((a, b)); segs += [(a, k), (k, b)]
    return sorted(segs)

y = arg["ARG"].to_numpy(); yrs = arg["year"].to_numpy()
rows = []
for a, b in segment(y):
    rows.append({"start": int(yrs[a]), "end": int(yrs[b - 1]), "mean_ideal_point": round(y[a:b].mean(), 3),
                 "dist_USA_mean": round(arg["dist_USA"].iloc[a:b].mean(), 3)})
ep = pd.DataFrame(rows); ep.to_csv(out / "argentina_epochs_draft.csv", index=False)
print(ep.to_string(index=False))
print("\nArgentina (cada 5 años):")
print(arg.loc[arg["year"] % 5 == 0, ["year", "ARG", "USA", "CHN", "mean_world", "rank_from_us_side", "n_countries"]].round(2).to_string(index=False))
