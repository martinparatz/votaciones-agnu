# 05_argentina_por_gobierno.R — Cómo votó Argentina en cada gobierno (incluidos los de facto), 1946-2026
#
# Entrada : data/governments_argentina.csv, resolutions/votes_1946_2026 (script 04), argentina_ideal_points.csv (02)
# Salida  : data/processed/argentina_by_government_votes.csv           (reparto de votos por gobierno y tema)
#           data/processed/argentina_by_government_agreement.csv       (coincidencia con referentes por gobierno)
#           data/processed/argentina_by_government_agreement_topic.csv (lo mismo, por tema)
#           data/processed/argentina_by_government_ideal_points.csv    (ideal point medio por gobierno, hasta 2025)
# Cada votación va al gobierno vigente en su fecha. Cada año de ideal points va al gobierno vigente el 1 de octubre.
# Coincidencia = % de votaciones en que ambos países emitieron voto y votaron igual (mínimo 10 en común).
# Equivale a scripts/04_argentina_by_government.py.

source("R/pipeline/00_config.R")

gov <- leer_gobiernos()

res <- read_csv(file.path(PROC, "resolutions_1946_2026.csv"), show_col_types = FALSE,
                col_types = cols(date = col_date(), topics = col_character(), .default = col_guess())) |>
  mutate(topics = coalesce(topics, ""), gov_id = gobierno_de(date, gov))
# Una columna lógica por tema (TRUE si la votación trata ese tema)
for (t in TOPICS) res[[t]] <- tiene_tema(res$topics, t)

v <- read_csv(file.path(PROC, "votes_1946_2026.csv.gz"), show_col_types = FALSE,
              col_select = c(rcid, ccode, vote_label)) |>
  filter(vote_label %in% CAST) |>
  inner_join(select(res, rcid, gov_id, all_of(TOPICS)), by = "rcid")

# ---- 1. Reparto de votos de Argentina por gobierno y tema ----
reparto <- function(x) {
  x |> summarise(n_votes = n(),
                 pct_yes = 100 * mean(vote_label == "yes"),
                 pct_abstain = 100 * mean(vote_label == "abstain"),
                 pct_no = 100 * mean(vote_label == "no"), .by = gov_id)
}
a <- filter(v, ccode == ARG)
votos_g <- bind_rows(
  reparto(a) |> mutate(topic = "Todos"),
  map(TOPICS, \(t) reparto(filter(a, .data[[t]])) |> mutate(topic = t)) |> list_rbind()
) |>
  mutate(across(starts_with("pct_"), \(x) round(x, 1))) |>
  arrange(gov_id, match(topic, c("Todos", TOPICS))) |>
  select(gov_id, topic, n_votes, pct_yes, pct_abstain, pct_no) |>
  left_join(select(gov, gov_id, government, type), by = "gov_id")
write_csv(votos_g, file.path(PROC, "argentina_by_government_votes.csv"), na = "")

# ---- 2. Coincidencia con los países de referencia ----
# Se pone el voto de Argentina al lado del voto de cada referente en la misma votación
# y se cuenta en qué porcentaje coinciden.
coincidencia <- function(x, gobiernos = unique(na.omit(v$gov_id))) {
  arg_v <- x |> filter(ccode == ARG) |> select(rcid, arg = vote_label)
  x |>
    filter(ccode %in% REFS) |>
    inner_join(arg_v, by = "rcid") |>
    summarise(n_common_votes = n(), pct = 100 * mean(vote_label == arg), .by = c(gov_id, ccode)) |>
    right_join(expand_grid(gov_id = gobiernos, ccode = unname(REFS)), by = c("gov_id", "ccode")) |>
    mutate(n_common_votes = coalesce(n_common_votes, 0L),  # gobiernos sin votos en común: 0
           pct_agreement = if_else(n_common_votes >= 10, round(pct, 1), NA_real_),
           reference = names(REFS)[match(ccode, REFS)]) |>
    arrange(gov_id, match(ccode, REFS))
}

coin <- coincidencia(v) |>
  select(gov_id, reference, n_common_votes, pct_agreement) |>
  left_join(select(gov, gov_id, government, type), by = "gov_id")
write_csv(coin, file.path(PROC, "argentina_by_government_agreement.csv"), na = "")

coin_t <- map(TOPICS, \(t) coincidencia(filter(v, .data[[t]])) |> mutate(topic = t)) |>
  list_rbind() |>
  arrange(gov_id, match(topic, TOPICS), match(ccode, REFS)) |>
  select(gov_id, topic, reference, n_common_votes, pct_agreement) |>
  left_join(select(gov, gov_id, government, type), by = "gov_id")
write_csv(coin_t, file.path(PROC, "argentina_by_government_agreement_topic.csv"), na = "")

# ---- 3. Ideal points promedio por gobierno ----
ipa <- read_csv(file.path(PROC, "argentina_ideal_points.csv"), show_col_types = FALSE) |>
  mutate(gov_id = gobierno_de(as.Date(paste0(year, "-10-01")), gov))
ip_g <- ipa |>
  filter(!is.na(gov_id)) |>
  summarise(year_from = min(year), year_to = max(year), n_years = n(),
            ideal_point_mean = mean(ARG), dist_USA_mean = mean(dist_USA, na.rm = TRUE),
            dist_CHN_mean = mean(dist_CHN, na.rm = TRUE), dist_RUS_mean = mean(dist_RUS, na.rm = TRUE),
            rank_mean = mean(rank_from_us_side), .by = gov_id) |>
  mutate(across(where(is.double), \(x) round(if_else(is.nan(x), NA_real_, x), 2))) |>
  arrange(gov_id) |>
  left_join(select(gov, gov_id, government, type), by = "gov_id")
write_csv(ip_g, file.path(PROC, "argentina_by_government_ideal_points.csv"), na = "")

# ---- 4. Para mirar en la consola ----
print(filter(votos_g, topic == "Todos") |> select(government, type, n_votes, pct_yes, pct_abstain, pct_no), n = 30)
print(coin |> select(gov_id, reference, pct_agreement) |>
        pivot_wider(names_from = reference, values_from = pct_agreement), n = 30)
