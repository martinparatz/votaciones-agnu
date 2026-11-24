# 02_ideal_points.R — Ideal points anuales 1946-2025 (Bailey, Strezhnev y Voeten)
#
# Entrada : data/raw/IdealpointestimatesFP_2026FP.csv  (del zip de Voeten en Harvard Dataverse, versión 39)
# Salida  : data/processed/ideal_points_1946_2025.csv   (todos los países, formato largo)
#           data/processed/argentina_ideal_points.csv   (Argentina + referentes, distancias y ranking)
# Escala: valores altos = más cerca de EE. UU. y Occidente; bajos = más cerca del mundo en desarrollo.
# Equivale a la primera parte de scripts/02_build_ideal_points.py (la segmentación automática en
# "épocas" del script de Python era un borrador y no la usa la web, así que no se repite acá).

source("R/pipeline/00_config.R")

ip <- read_csv(file.path(RAW, "IdealpointestimatesFP_2026FP.csv"), show_col_types = FALSE) |>
  transmute(ccode, iso3c, country = Countryname, year = as.integer(year),
            ideal_point = IdealPointFP, nvotesfp = NVotesFP, q5fp = `Q5%FP`, q95fp = `Q95%FP`)
write_csv(ip, file.path(PROC, "ideal_points_1946_2025.csv"), na = "")

# Se trabaja con el código COW (ccode) y no con iso3c porque la fuente le da el mismo iso3c (YAR)
# a los dos Yemen.
refs <- c(USA = 2, CHN = 710, RUS = 365, BRA = 140, CHL = 155, MEX = 70, GBR = 200, FRA = 220)

# Estadísticas del mundo por año: promedio, cantidad de países y ranking de Argentina
# (1 = el país más cercano a EE. UU.; empates promediados, como en pandas)
mundo <- ip |>
  filter(!is.na(ideal_point)) |>
  group_by(year) |>
  mutate(rank = rank(-ideal_point, ties.method = "average")) |>
  summarise(mean_world = mean(ideal_point),
            rank_from_us_side = rank[ccode == ARG][1],
            n_countries = n())

# Tabla ancha: una fila por año, una columna por país de referencia
ancha <- ip |>
  filter(ccode %in% c(ARG, refs)) |>
  mutate(pais = names(c(ARG = ARG, refs))[match(ccode, c(ARG, refs))]) |>
  select(year, pais, ideal_point) |>
  pivot_wider(names_from = pais, values_from = ideal_point)

arg <- tibble(year = sort(unique(ip$year))) |>
  left_join(ancha, by = "year")
for (r in names(refs)) arg[[paste0("dist_", r)]] <- abs(arg$ARG - arg[[r]])

# Mismo orden de columnas que la versión de Python: ARG, USA, dist_USA, CHN, dist_CHN...
orden <- c("year", "ARG", as.vector(rbind(names(refs), paste0("dist_", names(refs)))))
arg <- arg |>
  select(all_of(orden)) |>
  left_join(mundo, by = "year") |>
  filter(!is.na(ARG))

write_csv(arg, file.path(PROC, "argentina_ideal_points.csv"), na = "")

print(arg |> filter(year %% 5 == 0) |>
        select(year, ARG, USA, CHN, mean_world, rank_from_us_side, n_countries) |>
        mutate(across(where(is.double), \(x) round(x, 2))), n = 20)
