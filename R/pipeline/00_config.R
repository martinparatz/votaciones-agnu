# 00_config.R — Configuración común del pipeline en R
#
# Todos los scripts de R/pipeline/ empiezan con source("R/pipeline/00_config.R").
# Acá se cargan los paquetes y se definen las rutas y las constantes que se repiten
# (temas, países de referencia, códigos de voto). Si algo cambia, se cambia una sola vez acá.
#
# Requiere abrir votaciones-agnu.Rproj en RStudio: así el directorio de trabajo es la raíz del repo.

suppressPackageStartupMessages({
  library(readr)     # leer y escribir CSV
  library(dplyr)     # transformar tablas
  library(tidyr)     # pivotear (ancho <-> largo)
  library(stringr)   # texto y expresiones regulares
  library(purrr)     # iterar sobre listas
  library(jsonlite)  # escribir JSON para la web
})

# ---- Rutas ----
RAW  <- "data/raw"          # descargas originales (no se suben a GitHub, ver .gitignore)
PROC <- "data/processed"    # bases limpias
WEB  <- "docs/data"         # JSON que lee el sitio
dir.create(PROC, recursive = TRUE, showWarnings = FALSE)
dir.create(WEB,  recursive = TRUE, showWarnings = FALSE)

# ---- Constantes ----
ARG <- 160  # código Correlates of War (COW) de Argentina

# Países de referencia para las coincidencias (nombre en español = código COW)
REFS <- c("EE. UU." = 2, "URSS/Rusia" = 365, "China" = 710, "Reino Unido" = 200, "Francia" = 220,
          "Brasil" = 140, "Chile" = 155, "México" = 70, "Cuba" = 40, "Uruguay" = 165)

# Los seis temas de Voeten, con su código en la base original
TOPICS_VOETEN <- c(me = "Medio Oriente", nu = "Armas nucleares", di = "Desarme",
                   hr = "Derechos humanos", co = "Colonialismo", ec = "Desarrollo económico")
TOPICS <- unname(TOPICS_VOETEN)

# Votos "emitidos": los únicos que cuentan para porcentajes y coincidencias
CAST <- c("yes", "abstain", "no")

# Nombres de países en español, por código COW
NAMES_ES <- read_csv("data/i18n/country_names_es.csv", show_col_types = FALSE)

# ---- Funciones auxiliares ----

# ¿El texto de temas ("Desarme;Medio Oriente") incluye este tema?
tiene_tema <- function(topics, tema) str_detect(coalesce(topics, ""), fixed(tema))

# Asigna a cada fecha el gobierno argentino vigente (gov_id), según data/governments_argentina.csv
leer_gobiernos <- function() {
  read_csv("data/governments_argentina.csv", show_col_types = FALSE,
           col_types = cols(start = col_date(), end = col_date(), .default = col_character()))
}
gobierno_de <- function(fechas, gov) {
  i <- vapply(fechas, function(d) {
    m <- which(gov$start <= d & d <= gov$end)
    if (length(m) == 0 || is.na(d)) NA_integer_ else m[1]
  }, integer(1))
  gov$gov_id[i]
}

# Escribe un objeto de R como JSON compacto para la web.
# digits = NA conserva todos los decimales; na = "null" escribe los faltantes como null.
escribir_json <- function(x, archivo) {
  write(toJSON(x, auto_unbox = TRUE, digits = NA, na = "null", null = "null"), file.path(WEB, archivo))
}
