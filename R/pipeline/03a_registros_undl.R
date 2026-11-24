# 03a_registros_undl.R — (Opcional) Votaciones posteriores al dataset oficial, desde registros MARCXML
#
# Sirve para sumar votaciones que la Biblioteca Digital ya publicó como registros sueltos pero que todavía no
# están en el CSV oficial (record 4060887). No descarga nada: los MARCXML se exportan a mano desde
# https://digitallibrary.un.org (búsqueda  989__a:"Voting Data" 791__a:A/RES/81*  -> Exportar -> MARCXML)
# y se guardan en data/raw/undl_registros/*.xml.
#
# Salida: data/undl_registros/votes_ga_registros.csv  (mismas columnas que el CSV oficial; 03 lo suma solo
#         si las votaciones son posteriores a la última fecha del oficial)
#         data/undl_registros/titles_es_registros.json (título oficial en español, campo MARC 767 spa)
# Campos MARC: 001 id, 992 fecha, 791 símbolo y sesión, 993 proyecto, 952 acta, 245 título,
# 991 tema de agenda y materia, 996 totales (b sí, c no, d abst., e no votantes, f miembros),
# 967 voto por país (c ISO, e nombre, d voto; sin d = no votó = X).
# Equivale a scripts/06a_registros_undl_a_csv.py.
# Requiere el paquete xml2: install.packages("xml2")

source("R/pipeline/00_config.R")
library(xml2)

SRC <- file.path(RAW, "undl_registros")
OUT <- "data/undl_registros"
archivos <- list.files(SRC, pattern = "\\.xml$", full.names = TRUE)
if (length(archivos) == 0) stop("No hay archivos MARCXML en ", SRC)

# Funciones cortas para leer subcampos MARC (el XML usa el espacio de nombres "d1" que asigna xml2)
campos  <- function(rec, tag) xml_find_all(rec, sprintf("d1:datafield[@tag='%s']", tag))
sub     <- function(df, code) xml_text(xml_find_all(df, sprintf("d1:subfield[@code='%s']", code)))
primero <- function(rec, tag, code) {
  for (df in campos(rec, tag)) { x <- sub(df, code); if (length(x)) return(str_trim(x[1])) }
  ""
}

filas <- list(); titulos_es <- list(); vistos <- character()
for (f in sort(archivos)) {
  for (rec in xml_find_all(read_xml(f), "//d1:record")) {
    rid <- str_trim(xml_text(xml_find_first(rec, "d1:controlfield[@tag='001']")))
    votos <- campos(rec, "967")
    if (rid %in% vistos || length(votos) == 0) next
    vistos <- c(vistos, rid)
    t245 <- campos(rec, "245")[[1]]
    titulo <- str_trim(paste(str_trim(c(sub(t245, "a"), sub(t245, "b"), sub(t245, "c"))), collapse = " "))
    agenda <- campos(rec, "991")
    d993 <- campos(rec, "993")
    es_proyecto <- xml_attr(d993, "ind1") == "2"
    base <- tibble(
      undl_id = rid, date = primero(rec, "992", "a"), session = primero(rec, "791", "c"),
      resolution = primero(rec, "791", "a"),
      draft = paste(unlist(map(d993[es_proyecto], \(x) head(sub(x, "a"), 1))), collapse = "|"),
      committee_report = paste(unlist(map(d993[!es_proyecto], \(x) head(sub(x, "a"), 1))), collapse = "|"),
      meeting = primero(rec, "952", "a"), title = titulo,
      agenda_title = paste(unlist(map(agenda, \(x) sub(x, "c"))), collapse = "|"),
      subjects = paste(unlist(map(agenda, \(x) sub(x, "d"))), collapse = "|"),
      vote_note = primero(rec, "996", "a"), total_yes = primero(rec, "996", "b"),
      total_no = primero(rec, "996", "c"), total_abstentions = primero(rec, "996", "d"),
      total_non_voting = primero(rec, "996", "e"), total_ms = primero(rec, "996", "f"),
      undl_link = paste0("https://digitallibrary.un.org/record/", rid))
    pv <- tibble(ms_code = map_chr(votos, \(x) c(sub(x, "c"), "")[1]),
                 ms_name = map_chr(votos, \(x) c(sub(x, "e"), "")[1]),
                 ms_vote = map_chr(votos, \(x) { d <- sub(x, "d"); if (length(d) && d[1] != "") d[1] else "X" }))
    filas[[rid]] <- bind_cols(base[rep(1, nrow(pv)), ], pv)
    for (df in campos(rec, "767")) {
      if (identical(sub(df, "9"), "spa") && length(sub(df, "t"))) titulos_es[[base$resolution]] <- str_trim(sub(df, "t")[1])
    }
  }
}

if (length(filas) == 0) stop("No hay registros con voto por país en ", SRC)
COLS <- c("undl_id", "ms_code", "ms_name", "ms_vote", "date", "session", "resolution", "draft", "committee_report",
          "meeting", "title", "agenda_title", "subjects", "vote_note", "total_yes", "total_no", "total_abstentions",
          "total_non_voting", "total_ms", "undl_link")
salida <- list_rbind(filas) |> select(all_of(COLS)) |> arrange(date, undl_id, ms_code)
dir.create(OUT, showWarnings = FALSE)
write_csv(salida, file.path(OUT, "votes_ga_registros.csv"), na = "")
write(toJSON(titulos_es, auto_unbox = TRUE, pretty = TRUE), file.path(OUT, "titles_es_registros.json"))
print(count(salida, date, resolution, name = "países"))
