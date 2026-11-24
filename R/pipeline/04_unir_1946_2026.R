# 04_unir_1946_2026.R — Une Voeten (1946-2012) y la Biblioteca Digital de la ONU (2013-2026)
#
# Salida : data/processed/resolutions_1946_2026.csv, data/processed/votes_1946_2026.csv.gz
# Columnas de votos: rcid, ccode (COW), country, iso3, session, date, unres, vote_label (yes/abstain/no/absent...)
# topic_source: "voeten" (codificación manual, hasta 2012) o "keywords" (palabras clave, desde 2013).
# Equivale a scripts/07_merge_votes_1946_2026.py.

source("R/pipeline/00_config.R")

cols_res <- c("rcid", "session", "date", "year", "unres", "title_short", "description", "topics", "topic_source", "source")

r1 <- read_csv(file.path(PROC, "resolutions_1946_2012.csv"), col_types = cols(.default = col_character()), trim_ws = FALSE) |>
  mutate(topic_source = "voeten", source = "Voeten (Harvard Dataverse)")
r2 <- read_csv(file.path(PROC, "resolutions_2013_2026.csv"), col_types = cols(.default = col_character()), trim_ws = FALSE) |>
  mutate(source = "UN Digital Library")

res <- bind_rows(select(r1, any_of(cols_res)), select(r2, any_of(cols_res))) |>
  mutate(topics = coalesce(topics, ""))
write_csv(res, file.path(PROC, "resolutions_1946_2026.csv"), na = "")

cols_v <- c("rcid", "ccode", "country", "iso3", "session", "date", "unres", "vote_label")
v1 <- read_csv(file.path(PROC, "votes_1946_2012.csv.gz"), col_types = cols(.default = col_character())) |>
  rename(iso3 = iso3_voeten)
v2 <- read_csv(file.path(PROC, "votes_2013_2026.csv.gz"), col_types = cols(.default = col_character()))
v <- bind_rows(select(v1, all_of(cols_v)), select(v2, all_of(cols_v)))
write_csv(v, file.path(PROC, "votes_1946_2026.csv.gz"), na = "")

cat("resoluciones:", nrow(res), "| votos:", nrow(v), "| rango:", min(res$date), max(res$date), "\n")
print(count(filter(v, ccode == "160"), vote_label))
