# 07_exportar_mundo.R — Datos de todos los países para la sección Mundo del sitio
#
# Entrada : data/processed/votes_1946_2026.csv.gz, resolutions_1946_2026.csv, ideal_points_1946_2025.csv
# Salida  : docs/data/world.json con
#   countries: lista de países (código COW, nombre en español e inglés, ISO, primer y último año)
#   periods:   los seis períodos históricos (más "todo el período")
#   agree:     para cada período, matriz país x país con el % de coincidencia (-1 = menos de 10 votos en común)
#   counts:    para cada período y tema, cuántos sí / abstenciones / no / ausencias tiene cada país
# Equivale a scripts/08_export_world_data.py.
#
# La idea clave: se arma una matriz M (votaciones x países) con el voto codificado como número.
# Con álgebra de matrices se calculan de una sola vez las coincidencias de todos los pares de países.

source("R/pipeline/00_config.R")

PERIODS <- tribble(
  ~id,  ~label,                                      ~y0,  ~y1,
  "all", "Todo el período (1946–2026)",               1946, 2026,
  "p1",  "Guerra Fría temprana (1946–1962)",          1946, 1962,
  "p2",  "Descolonización y distensión (1963–1979)",  1963, 1979,
  "p3",  "Guerra Fría tardía (1980–1991)",            1980, 1991,
  "p4",  "Posguerra fría (1992–2000)",                1992, 2000,
  "p5",  "Siglo XXI hasta 2011",                      2001, 2011,
  "p6",  "Desde 2012 (2012–2026)",                    2012, 2026
)

ip <- read_csv(file.path(PROC, "ideal_points_1946_2025.csv"), show_col_types = FALSE)
meta <- ip |> distinct(ccode, .keep_all = TRUE)
ccodes <- sort(intersect(meta$ccode, NAMES_ES$ccode))   # países con nombre en español

res <- read_csv(file.path(PROC, "resolutions_1946_2026.csv"), show_col_types = FALSE,
                col_types = cols(topics = col_character(), .default = col_guess())) |>
  mutate(topics = coalesce(topics, ""), year = as.integer(substr(date, 1, 4))) |>
  arrange(rcid)

CODIGO <- c(yes = 1L, abstain = 2L, no = 3L, absent = 4L)
v <- read_csv(file.path(PROC, "votes_1946_2026.csv.gz"), show_col_types = FALSE,
              col_select = c(rcid, ccode, vote_label)) |>
  filter(ccode %in% ccodes, rcid %in% res$rcid, vote_label %in% names(CODIGO)) |>
  mutate(c = CODIGO[vote_label])

# ---- Matriz votaciones x países (0 = sin dato) ----
M <- matrix(0L, nrow = nrow(res), ncol = length(ccodes))
M[cbind(match(v$rcid, res$rcid), match(v$ccode, ccodes))] <- v$c

agree <- list(); counts <- list()
for (i in seq_len(nrow(PERIODS))) {
  p <- PERIODS[i, ]
  filas <- res$year >= p$y0 & res$year <= p$y1
  X <- M[filas, , drop = FALSE]
  Y <- (X == 1) * 1; A <- (X == 2) * 1; N <- (X == 3) * 1
  C <- Y + A + N                                   # 1 si el país emitió voto
  iguales <- crossprod(Y) + crossprod(A) + crossprod(N)   # votaciones en que i y j votaron igual
  ambos   <- crossprod(C)                                 # votaciones en que i y j emitieron voto
  pct <- ifelse(ambos >= 10, round(100 * iguales / pmax(ambos, 1)), -1)
  agree[[p$id]] <- matrix(as.integer(pct), nrow = nrow(pct))

  cc <- list()
  for (t in c("Todos", TOPICS)) {
    sub <- if (t == "Todos") X else X[tiene_tema(res$topics[filas], t), , drop = FALSE]
    # una fila por país: [sí, abstención, no, ausente]
    cc[[t]] <- t(apply(sub, 2, \(col) c(sum(col == 1), sum(col == 2), sum(col == 3), sum(col == 4))))
  }
  counts[[p$id]] <- cc
}

anios <- ip |> group_by(ccode) |> summarise(y0 = min(year), y1 = max(year))
paises <- tibble(c = ccodes) |>
  left_join(NAMES_ES, by = c("c" = "ccode")) |>
  left_join(select(meta, ccode, country, iso3c), by = c("c" = "ccode")) |>
  left_join(anios, by = c("c" = "ccode")) |>
  transmute(c, es = name_es, en = country, iso = coalesce(iso3c, ""), y0, y1)

out <- list(countries = paises,
            periods = select(PERIODS, id, label, y0, y1),
            topics = c("Todos", TOPICS),
            agree = agree, counts = counts)
escribir_json(out, "world.json")

cat("países:", length(ccodes), "| votaciones:", nrow(res), "| world.json:",
    round(file.size(file.path(WEB, "world.json")) / 1e6, 2), "MB\n")
i_arg <- match(ARG, ccodes)
for (c in c(2, 365, 710, 140, 666)) {
  cat(NAMES_ES$name_es[NAMES_ES$ccode == c], "con Argentina (todo el período):", agree$all[i_arg, match(c, ccodes)], "\n")
}
