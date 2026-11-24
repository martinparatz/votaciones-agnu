# 01_votos_1946_2012.R — Base de votos de la AGNU 1946-2012 (Voeten, versión 7 del dataverse)
#
# Entrada : data/raw/undata-213.tab        (un voto por país y votación: ~1,2 millones de filas)
#           data/raw/descriptions-213.tab  (una fila por votación: fecha, título, temas)
# Salida  : data/processed/resolutions_1946_2012.csv
#           data/processed/votes_1946_2012.csv.gz
# Códigos de voto de Voeten: 1 = sí, 2 = abstención, 3 = no, 8 = ausente, 9 = no miembro.
# Equivale a scripts/01_build_votes_1946_2012.py.

source("R/pipeline/00_config.R")

# ---- 1. Descripciones de las votaciones ----
# El archivo viene en latin-1, separado por tabulaciones, y una fila trae campos sobrantes al final.
# Por eso se lee línea por línea, se recorta cada línea a 18 campos y recién ahí se arma la tabla.
lineas <- readLines(file.path(RAW, "descriptions-213.tab"), encoding = "latin1")
lineas <- iconv(lineas, from = "latin1", to = "UTF-8")
campos <- str_split(lineas, "\t")
campos <- map(campos, \(x) x[1:18])                 # recorta (o completa con NA) a 18 campos
tabla  <- do.call(rbind, campos)
res <- as_tibble(tabla[-1, ], .name_repair = "minimal")
names(res) <- tabla[1, ]

# Las comillas vienen escapadas de forma irregular: se leen como texto y se limpian a mano
res <- res |>
  mutate(across(everything(), \(x) str_remove_all(str_trim(x), '^"+|"+$'))) |>
  mutate(across(c(session, rcid, abstain, yes, no, amend, para, me, nu, di, hr, co, ec),
                \(x) suppressWarnings(as.numeric(x)))) |>
  rename(title_short = short, description = descr, is_paragraph = para,
         is_amendment = amend, important_vote = importantvote)

# Columnas de tema: de los códigos (me, nu...) a nombres en español, y una columna "topics"
# que junta los temas de cada votación separados por ";"
for (cod in names(TOPICS_VOETEN)) res[[TOPICS_VOETEN[[cod]]]] <- res[[cod]]
res$topics <- apply(res[names(TOPICS_VOETEN)], 1, \(fila) {
  paste(TOPICS_VOETEN[names(TOPICS_VOETEN)][which(fila == 1)], collapse = ";")
})
res <- res |>
  mutate(year = as.integer(substr(date, 1, 4))) |>
  select(-all_of(names(TOPICS_VOETEN)))

write_csv(res, file.path(PROC, "resolutions_1946_2012.csv"), na = "")

# ---- 2. Votos por país ----
etiquetas <- c("1" = "yes", "2" = "abstain", "3" = "no", "8" = "absent", "9" = "non_member")

v <- read_tsv(file.path(RAW, "undata-213.tab"),
              col_select = c(rcid, session, date, unres, vote, ccode, voetenname, voetenshortcode, uncode),
              locale = locale(encoding = "latin1"), show_col_types = FALSE) |>
  mutate(vote_label = unname(etiquetas[as.character(vote)])) |>
  rename(country = voetenname, iso3_voeten = voetenshortcode, un_m49 = uncode)

write_csv(v, file.path(PROC, "votes_1946_2012.csv.gz"), na = "")

# ---- 3. Control ----
cat("resoluciones:", nrow(res), "| votos:", nrow(v), "| países:", n_distinct(v$ccode), "\n")
print(count(v, vote_label))
arg <- filter(v, iso3_voeten == "ARG")
cat("Argentina:", nrow(arg), "filas; sesiones", min(arg$session), "-", max(arg$session), "\n")
