# Votaciones en la Asamblea General de la ONU

Análisis temático, cronológico y político de las votaciones nominales de la AGNU,
con foco en la posición de la República Argentina (1946 en adelante) y un pipeline
replicable para el resto de los miembros.

## Cómo usarlo
- **RStudio:** abrir `votaciones-agnu.Rproj` y ejecutar `R/01_figuras_argentina.R` (paquetes: readr, dplyr, tidyr, ggplot2, scales; todos vienen con tidyverse). Genera las figuras en `figures/`.
- **Web:** el sitio interactivo está en `docs/` (HTML + Plotly). Para publicarlo: *Settings → Pages → Deploy from a branch → `main` / `/docs`*. Para verlo en local: `python3 -m http.server -d docs`.
- **Regenerar datos:** `python3 scripts/01…05` en orden (los scripts 01 y 02 necesitan los archivos de `data/raw/`, ver Fuentes).

## Estructura
- `scripts/` — recolección, limpieza y análisis (Python).
- `R/` — figuras y análisis en R/RStudio.
- `figures/` — gráficos estáticos generados con R.
- `docs/` — sitio web interactivo (GitHub Pages).
- `data/raw/` — descargas originales (no versionadas, ver `.gitignore`).
- `data/processed/` — bases limpias que consumen R y la web.

## Fuentes
- Voeten, E. *United Nations General Assembly Voting Data* (Harvard Dataverse, doi:10.7910/DVN/LEJUQZ, versión 7, 2015): votos por país y resolución, sesiones 1–67 (1946–2012).
- Voeten, E. *United Nations General Assembly Ideal Points* (misma doi, versión vigente): ideal points anuales 1946–2025.
- UN Digital Library (voting data): sesiones posteriores a 2012.

## Estado
- [x] Votos 1946–2012 (`scripts/01_build_votes_1946_2012.py`)
- [x] Épocas por gobierno (`data/governments_argentina.csv`, `scripts/04_argentina_by_government.py`)
- [ ] Votos 2013–2025
- [x] Ideal points 1946–2025 y borrador de épocas de Argentina (`scripts/02_build_ideal_points.py`)
- [x] Análisis temático y coincidencias de Argentina 1946–2012 (`scripts/03_argentina_thematic.py`)
- [x] Figuras en R (`R/01_figuras_argentina.R`) y prototipo web (`docs/`)
- [ ] Pulir la web, versión para todos los países y datos 2013–2025
