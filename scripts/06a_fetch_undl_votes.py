"""Descarga de la UN Digital Library los registros de votación nominal (colección Voting Data, voto registrado)
por año, en MARCXML, a data/raw/undl/.  Uso: python3 scripts/06a_fetch_undl_votes.py 2013 2026

El buscador limita cada consulta a unos 700 registros, por eso se parte por año (cada año tiene < 200).
"""
import re, subprocess, sys, time
from pathlib import Path
ROOT = Path(__file__).resolve().parents[1]
out = ROOT / "data/raw/undl"; out.mkdir(exist_ok=True)
rg = 200
def fetch(year, jrec):
    f = out / f"{year}_{jrec:05d}.xml"
    if not f.exists():
        for attempt in range(4):
            r = subprocess.run(["curl","-sS","-m","180","-L","-G","https://digitallibrary.un.org/search",
                "-d","ln=en","--data-urlencode",f'p=989__a:"Voting Data" 591__a:RECORDED 269__a:{year}*',"-d","of=xm","-d",f"rg={rg}","-d",f"jrec={jrec}","-o",str(f)],capture_output=True,text=True)
            if r.returncode==0 and f.exists() and f.stat().st_size>200: break
            time.sleep(5)
    return f.read_text(errors="replace")
for year in range(int(sys.argv[1]), int(sys.argv[2])+1):
    seen=set(); jrec=1
    while True:
        x = fetch(year, jrec)
        ids = set(re.findall(r'tag="001">(\d+)', x))
        new = ids - seen
        seen |= ids
        print(year, jrec, len(ids), "new", len(new), flush=True)
        if len(ids) < rg or not new: break
        jrec += rg
    print("YEAR", year, "records", len(seen), flush=True)
