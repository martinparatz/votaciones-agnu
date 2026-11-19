# Votaciones en la Asamblea General de la ONU

Análisis temático, cronológico y político de las votaciones nominales de la AGNU,
con foco en la posición de la República Argentina (1946 en adelante) y un pipeline
replicable para el resto de los miembros.

## Estructura
- `scripts/` — recolección y limpieza (Python); análisis y gráficos (R, próximamente).
- `data/raw/` — descargas originales (no versionadas, ver `.gitignore`).
- `data/processed/` — bases limpias que consumen R y la web.

## Fuentes
- Voeten, E. *United Nations General Assembly Voting Data* (Harvard Dataverse, doi:10.7910/DVN/LEJUQZ, versión 7, 2015): votos por país y resolución, sesiones 1–67 (1946–2012).
- Voeten, E. *United Nations General Assembly Ideal Points* (misma doi, versión vigente): ideal points anuales 1946–2025.
- UN Digital Library (voting data): sesiones posteriores a 2012.

## Estado
- [x] Votos 1946–2012 (`scripts/01_build_votes_1946_2012.py`)
- [ ] Votos 2013–2025
- [ ] Épocas y análisis de Argentina
- [ ] Visualizaciones en R y sitio web (GitHub Pages)
