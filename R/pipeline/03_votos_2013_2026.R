# 03_votos_2013_2026.R — Base de votos 2013-2026 desde el dataset oficial de la Biblioteca Dag Hammarskjöld
#
# Entrada : data/raw/undl_oficial/2026_10_15_votes_ga.csv  (versión 6, 15/10/2026; ~370 MB; se baja a mano de
#           https://digitallibrary.un.org/record/4060887)
#           data/processed/ideal_points_1946_2025.csv       (para pasar los códigos ISO a códigos COW)
#           data/undl_registros/votes_ga_registros.csv      (opcional: votaciones posteriores al dataset oficial,
#                                                            ver 03a_registros_undl.R)
# Salida  : data/processed/resolutions_2013_2026.csv, data/processed/votes_2013_2026.csv.gz
# Mismo formato que la base 1946-2012. Códigos de voto: Y sí, N no, A abstención, X no votó (-> absent).
# Los temas no vienen codificados en este tramo: se asignan por palabras clave sobre el título y las materias.
# Atribución obligatoria: United Nations Dag Hammarskjöld Library, United Nations General Assembly Voting Data,
# 2026, https://digitallibrary.un.org/record/4060887. Uso no comercial con atribución.
# Equivale a scripts/06b_build_votes_2013_2026.py.

source("R/pipeline/00_config.R")

ARCHIVO_OFICIAL <- file.path(RAW, "undl_oficial", "2026_10_15_votes_ga.csv")  # cambiar si sale una versión nueva
VOTO <- c(Y = "yes", N = "no", A = "abstain", X = "absent")

# Reglas de palabras clave (expresiones regulares sobre el texto en minúsculas)
TOPIC_RULES <- c(
  "Medio Oriente"        = "palestin|israel|middle east|jerusalem|golan|unrwa|occupied (arab|syrian)|arab-israeli",
  "Armas nucleares"      = "nuclear|atomic|non-proliferation|test-ban|radiolog",
  "Desarme"              = "disarm|arms\\b|weapon|missile|landmine|anti-personnel|cluster munition|small arms|conventional arms",
  "Derechos humanos"     = "human rights|racism|racial|torture|death penalty|rights of (the child|indigenous|persons|women)|discriminat|enforced disappearance|freedom of (religion|expression)",
  "Colonialismo"         = "self-determination|colonial|non-self-governing|decoloni|western sahara|apartheid|falkland|malvinas|mayotte",
  "Desarrollo económico" = "economic|development|trade\\b|financing for development|financial (system|crisis|institutions)|debt|poverty|sustainable|globali[sz]ation|commodit|food|energy|industrial"
)

# ---- 1. Correspondencia ISO -> COW ----
ip <- read_csv(file.path(PROC, "ideal_points_1946_2025.csv"), show_col_types = FALSE)
iso2cow  <- ip |> filter(!is.na(iso3c)) |> distinct(iso3c, .keep_all = TRUE) |> select(iso3c, ccode)
name2cow <- ip |> distinct(ccode, .keep_all = TRUE) |> select(ccode, country)
# Códigos ISO de la ONU que difieren de los de la fuente de ideal points (o faltan en ella)
MANUAL <- c(SRB = 345, MNE = 341, SSD = 626, TLS = 860, CZE = 316, MKD = 343, SWZ = 572, CIV = 437,
            DEU = 255, ROU = 360, ZWE = 552, KIR = 970, NRU = 971, TUV = 973, PLW = 986, MHL = 983, FSM = 987,
            AND = 232, MCO = 221, LIE = 223, SMR = 331, VUT = 935, WSM = 990, TON = 972, KNA = 60, LCA = 56,
            VCT = 57, ATG = 58, GRD = 55, DMA = 54, BRB = 53, BHS = 31, BLZ = 80, SYC = 591, MDV = 781, CPV = 402,
            STP = 403, COM = 581, BRN = 835, BTN = 760, ERI = 531, PRK = 731, COD = 490, MMR = 775)

# ---- 2. Leer el dataset oficial (y los registros posteriores, si existen) ----
d <- read_csv(ARCHIVO_OFICIAL, col_types = cols(.default = col_character()))
sup_path <- "data/undl_registros/votes_ga_registros.csv"
if (file.exists(sup_path)) {
  s <- read_csv(sup_path, col_types = cols(.default = col_character())) |>
    filter(!undl_id %in% d$undl_id, date > max(d$date))
  message("registros agregados desde la Biblioteca Digital: ", paste(sort(unique(s$resolution)), collapse = ", "))
  d <- bind_rows(d, s)
}
d <- d |>
  filter(date >= "2013-01-01") |>
  rename(undl_record = undl_id, unres = resolution)

# ---- 3. Una fila por votación ----
limpiar_titulo <- function(t) {
  t <- str_remove(str_trim(t), regex("\\s*:?\\s*(reso\\w+|decision)\\s*/\\s*adopted by the General Assembly\\s*$", ignore_case = TRUE))
  t <- str_remove(t, regex("\\s*:?\\s*(resolution|decision)\\s*/?\\s*$", ignore_case = TRUE))
  str_remove_all(t, "^[ :/]+|[ :/]+$")
}
sesion_de <- function(unres, meeting) {
  s <- str_match(unres, "A/RES/(\\d+)/")[, 2]
  s2 <- str_match(meeting, "A/(\\d+)/PV")[, 2]
  as.integer(coalesce(s, s2))
}
temas_de <- function(texto) {
  texto <- str_to_lower(texto)
  map_chr(texto, \(x) paste(names(TOPIC_RULES)[str_detect(x, TOPIC_RULES)], collapse = ";"))
}

r <- d |>
  distinct(undl_record, .keep_all = TRUE) |>
  mutate(title_short = limpiar_titulo(title),
         session = sesion_de(unres, meeting),
         texto = paste(title_short, coalesce(agenda_title, ""), coalesce(subjects, "")),
         topics = temas_de(texto))

res <- r |>
  transmute(undl_record = as.integer(undl_record), session, date, unres, meeting, title_short,
            description = coalesce(agenda_title, ""), topics, topic_source = "keywords",
            n_yes = as.numeric(total_yes), n_no = as.numeric(total_no), n_abstain = as.numeric(total_abstentions),
            n_nonvoting = as.numeric(total_non_voting), n_total = as.numeric(total_ms)) |>
  arrange(date, undl_record) |>
  mutate(rcid = 100001L + row_number() - 1L,   # los rcid nuevos empiezan en 100001 para no pisar los de Voeten
         year = as.integer(substr(date, 1, 4)))

# ---- 4. Votos por país ----
v <- d |>
  transmute(undl_record = as.integer(undl_record), iso3 = ms_code, ms_name, vote_code = ms_vote) |>
  left_join(iso2cow, by = c("iso3" = "iso3c")) |>
  mutate(ccode = coalesce(ccode, unname(MANUAL[iso3])),
         vote_label = coalesce(unname(VOTO[vote_code]), "other")) |>
  inner_join(select(res, undl_record, rcid, session, date, unres), by = "undl_record") |>
  left_join(name2cow, by = "ccode") |>
  mutate(country = coalesce(country, str_to_title(ms_name))) |>
  select(undl_record, iso3, ccode, vote_code, vote_label, rcid, session, date, unres, country)

write_csv(res, file.path(PROC, "resolutions_2013_2026.csv"), na = "")
write_csv(v, file.path(PROC, "votes_2013_2026.csv.gz"), na = "")

# ---- 5. Controles ----
cat("resoluciones:", nrow(res), "| votos:", nrow(v), "| países:", n_distinct(v$iso3),
    "| última fecha:", max(res$date), "\n")
sin_cow <- v |> filter(is.na(ccode)) |> distinct(iso3)
cat("sin código COW:", paste(sin_cow$iso3, collapse = ", "), "\n")
print(count(v, vote_label))
# Control cruzado: el conteo de votos país por país tiene que dar los totales que informa la ONU
chk <- v |>
  count(rcid, vote_label) |>
  pivot_wider(names_from = vote_label, values_from = n, values_fill = 0) |>
  left_join(select(res, rcid, n_yes, n_no, n_abstain), by = "rcid") |>
  mutate(across(c(n_yes, n_no, n_abstain), \(x) coalesce(x, 0)))
mal <- filter(chk, yes != n_yes | no != n_no | abstain != n_abstain)
cat("votaciones cuyo conteo no coincide con los totales:", nrow(mal), "de", nrow(chk), "\n")
print(count(filter(v, iso3 == "ARG"), vote_label))
