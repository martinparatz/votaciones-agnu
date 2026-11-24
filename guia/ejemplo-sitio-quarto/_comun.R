# Código común a todas las páginas del sitio de ejemplo: paquetes y lectura de datos.
# Cada página lo carga con source("_comun.R").
library(tidyverse)
library(jsonlite)
library(plotly)
library(DT)

raiz <- here::here()   # la raíz del repositorio (donde está votaciones-agnu.Rproj)
leer <- function(...) file.path(raiz, ...)

gov   <- read_csv(leer("data/governments_argentina.csv"), show_col_types = FALSE)
W     <- fromJSON(leer("docs/data/world.json"))
ipj   <- fromJSON(leer("docs/data/ideal_points.json"), simplifyVector = FALSE)
votos_gov <- read_csv(leer("data/processed/argentina_by_government_votes.csv"), show_col_types = FALSE)
coin_gov  <- read_csv(leer("data/processed/argentina_by_government_agreement.csv"), show_col_types = FALSE)
av    <- fromJSON(leer("docs/data/argentina_votes.json"))

orden_gob <- gov$government[gov$government %in% votos_gov$government]
COLORES_VOTO <- c(`A favor` = "#2a9d8f", `Abstención` = "#d9a82b", `En contra` = "#e0573a")
