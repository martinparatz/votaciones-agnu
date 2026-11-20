# Votaciones en la Asamblea General de la ONU

Análisis temático, cronológico y político de las votaciones nominales de la AGNU,
con foco en la posición de la República Argentina (1946 en adelante) y un pipeline
replicable para el resto de los miembros.

## Cómo usarlo
- **RStudio:** abrir `votaciones-agnu.Rproj` y ejecutar `R/01_figuras_argentina.R` (paquetes: readr, dplyr, tidyr, ggplot2, scales; todos vienen con tidyverse). Genera las figuras en `figures/`.
- **Web:** el sitio interactivo está en `docs/` (HTML + Plotly). Para publicarlo: *Settings → Pages → Deploy from a branch → `main` / `/docs`*. Para verlo en local: `python3 -m http.server -d docs`.
- **Regenerar datos:** `python3 scripts/01…08` en orden (06a/06b/07 para 2013–2025; 08 genera `docs/data/world.json`) (los scripts 01 y 02 necesitan los archivos de `data/raw/`, ver Fuentes).

## Licencias
Código: MIT (`LICENSE`). Análisis, textos y figuras propios: CC BY 4.0. Los datos de origen conservan las condiciones de sus fuentes (ver `LICENSE-CONTENT.md` y la pestaña *Metodología y fuentes* de la web). Proyecto independiente, no avalado por la ONU.

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
- UN Digital Library (colección *Voting Data*, votos registrados 2013–2025): votos por país y resolución, descargados por año (`scripts/06a`). Los temas de este tramo se asignan por palabras clave sobre el título, no por la codificación de Voeten.

## Estado
- [x] Votos 1946–2012 (`scripts/01_build_votes_1946_2012.py`)
- [x] Épocas por gobierno (`data/governments_argentina.csv`, `scripts/04_argentina_by_government.py`)
- [x] Votos 2013–2025 desde la UN Digital Library (`scripts/06a`, `06b`, `07`)
- [x] Ideal points 1946–2025 y borrador de épocas de Argentina (`scripts/02_build_ideal_points.py`)
- [x] Análisis temático y coincidencias de Argentina por época (borrador, 1946–2012: `scripts/03_argentina_thematic.py`) y por gobierno hasta 2025 (`scripts/04_argentina_by_government.py`)
- [x] Figuras en R (`R/01_figuras_argentina.R`) y prototipo web (`docs/`)
- [x] Web con sección **Mundo** (mapa planisferio de alineamientos por país de referencia y período, o de ideal points por año; explorador de países; línea de tiempo comparable) y sección **Argentina** (por gobierno, votos, coincidencias, tabla de votaciones). Datos de todos los países en `docs/data/world.json` (`scripts/08_export_world_data.py`).
- [x] Títulos de resoluciones en español: 160 oficiales de la ONU y el resto traducidos (`data/i18n/`); nombres de países en `scripts/country_names_es.py`.
- Limitaciones: la geometría del mapa (110m) omite los Estados pequeños; los Estados desaparecidos figuran con su nombre histórico; los temas desde 2013 son aproximados.
- [ ] Textos contextuales por gobierno (para revisión)
