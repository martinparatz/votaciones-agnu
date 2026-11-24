# 06_exportar_web.R — Exporta los datos de Argentina y los ideal points a JSON para el sitio (docs/data/)
#
# Salida: docs/data/ideal_points.json, governments.json, votes_by_government.json,
#         agreement_by_government.json, government_ideal_points.json, argentina_votes.json
# El sitio (docs/index.html) lee estos archivos con fetch() y dibuja los gráficos con Plotly.js.
# Equivale a scripts/05_export_web_data.py.

source("R/pipeline/00_config.R")

# ---- 1. Ideal points de todos los países ----
# Estructura: {"countries": {"160": {"name": ..., "iso3": ..., "years": [...], "ip": [...]}, ...},
#              "world": {"years": [...], "ip": [...]}}
ip <- read_csv(file.path(PROC, "ideal_points_1946_2025.csv"), show_col_types = FALSE) |>
  filter(!is.na(ideal_point)) |>
  arrange(ccode, country, year)

por_pais <- ip |>
  left_join(NAMES_ES, by = "ccode") |>
  summarise(name = coalesce(first(name_es), first(country)),
            iso3 = coalesce(first(iso3c), ""),
            years = list(year), ip = list(round(ideal_point, 3)),
            .by = c(ccode, country))
# Si un código tiene dos nombres en inglés, queda el último (igual que en Python)
por_pais <- por_pais |> slice_tail(n = 1, by = ccode)

countries <- setNames(
  pmap(por_pais, \(ccode, country, name, iso3, years, ip) {
    list(name = name, iso3 = iso3, years = I(years), ip = I(ip))   # I() = mantener como lista aunque tenga 1 valor
  }),
  as.character(por_pais$ccode))
mundo <- ip |> summarise(ip = round(mean(ideal_point), 3), .by = year) |> arrange(year)
escribir_json(list(countries = countries, world = list(years = I(mundo$year), ip = I(mundo$ip))),
              "ideal_points.json")

# ---- 2. Tablas que van tal cual (una fila = un objeto JSON) ----
gov <- read_csv("data/governments_argentina.csv", col_types = cols(.default = col_character()))
escribir_json(gov, "governments.json")

votos <- read_csv(file.path(PROC, "argentina_by_government_votes.csv"), show_col_types = FALSE)
escribir_json(votos, "votes_by_government.json")

ag  <- read_csv(file.path(PROC, "argentina_by_government_agreement.csv"), show_col_types = FALSE) |>
  mutate(topic = "Todos")
agt <- read_csv(file.path(PROC, "argentina_by_government_agreement_topic.csv"), show_col_types = FALSE)
escribir_json(bind_rows(ag, agt), "agreement_by_government.json")

ipg <- read_csv(file.path(PROC, "argentina_by_government_ideal_points.csv"), show_col_types = FALSE)
escribir_json(ipg, "government_ideal_points.json")

# ---- 3. Tabla de votaciones de Argentina (una fila por votación, con el resultado global) ----
V <- read_csv(file.path(PROC, "votes_1946_2026.csv.gz"), show_col_types = FALSE,
              col_select = c(rcid, ccode, vote_label))
R <- read_csv(file.path(PROC, "resolutions_1946_2026.csv"), show_col_types = FALSE,
              col_types = cols(date = col_date(), title_short = col_character(), topics = col_character(),
                               .default = col_guess()))

# Resultado global: cuántos países votaron sí, no y abstención en cada votación
conteo <- V |>
  filter(vote_label %in% CAST) |>
  count(rcid, vote_label) |>
  pivot_wider(names_from = vote_label, values_from = n, values_fill = 0)

# Títulos en español: diccionario título en inglés (en minúsculas) -> traducción
TES <- fromJSON("data/i18n/titles_es.json")
traducir <- function(t) {
  t <- str_trim(coalesce(t, ""))
  k <- str_to_lower(t)
  hay <- k %in% names(TES)
  out <- t
  out[hay] <- unlist(TES[k[hay]], use.names = FALSE)
  # sin traducción: si está todo en mayúsculas, se pasa a "Tipo oración"
  mayus <- !hay & t == str_to_upper(t) & t != str_to_lower(t)
  out[mayus] <- paste0(substr(t[mayus], 1, 1), str_to_lower(substring(t[mayus], 2)))
  out
}

# Símbolo oficial de la resolución, para enlazar con la Biblioteca Digital
simbolo <- function(u) {
  case_when(is.na(u) ~ "",
            str_starts(u, fixed("R/"))   ~ str_replace(u, "^R/", "A/RES/"),
            str_starts(u, fixed("ESS/")) ~ str_replace(u, "^ESS/", "A/RES/ES-"),
            str_starts(u, fixed("SS/"))  ~ str_replace(u, "^SS/", "A/RES/S-"),
            .default = u)
}

registros <- read_csv(file.path(PROC, "resolutions_2013_2026.csv"), show_col_types = FALSE,
                      col_select = c(rcid, undl_record))
gov_d <- leer_gobiernos()

A <- V |>
  filter(ccode == ARG) |>
  select(rcid, arg = vote_label) |>
  inner_join(R, by = "rcid") |>
  left_join(conteo, by = "rcid") |>
  left_join(registros, by = "rcid") |>
  arrange(date, rcid) |>
  mutate(g = gobierno_de(date, gov_d), topics = coalesce(topics, ""))

cat("títulos sin traducir:", sum(!str_to_lower(str_trim(coalesce(A$title_short, ""))) %in% names(TES)), "\n")

tabla <- tibble(d = format(A$date, "%Y-%m-%d"), s = simbolo(A$unres),
                k = as.integer(coalesce(A$undl_record, 0)), t = traducir(A$title_short), tp = A$topics,
                v = A$arg, y = as.integer(A$yes), n = as.integer(A$no), a = as.integer(A$abstain), g = A$g)
escribir_json(tabla, "argentina_votes.json")

print(file.info(list.files(WEB, full.names = TRUE))["size"])
