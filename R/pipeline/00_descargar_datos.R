# 00_descargar_datos.R — Baja los archivos de Voeten desde Harvard Dataverse a data/raw/
#
# Usa la API pública de Dataverse: primero pide la lista de archivos de una versión del dataset
# y después baja cada archivo por su número (id). No hace falta registrarse.
#
#   Versión 7 (2015)  -> undata-213.tab y descriptions-213.tab  (votos por resolución, 1946-2012)
#   Versión 39 (2026) -> IdealpointestimatesFP_2026FP.csv       (ideal points anuales, 1946-2025)
#
# El dataset oficial de la ONU (2013 en adelante) NO se baja con este script: se descarga a mano
# desde https://digitallibrary.un.org/record/4060887 y se guarda en data/raw/undl_oficial/ (ver la guía, cap. 2).

library(jsonlite)

DOI <- "doi:10.7910/DVN/LEJUQZ"
dir.create("data/raw/undl_oficial", recursive = TRUE, showWarnings = FALSE)
options(timeout = 1200)   # los archivos grandes pueden tardar más que los 60 s que R espera por defecto

bajar_de_dataverse <- function(version, archivos, destino = "data/raw") {
  url_lista <- sprintf("https://dataverse.harvard.edu/api/datasets/:persistentId/versions/%s/files?persistentId=%s",
                       version, DOI)
  lista <- fromJSON(url_lista)$data$dataFile        # tabla con id, filename, filesize...
  for (a in archivos) {
    fila <- lista[lista$filename == a, ]
    if (nrow(fila) == 0) stop("No encontré ", a, " en la versión ", version)
    dest <- file.path(destino, a)
    if (file.exists(dest)) { message("ya existe: ", dest); next }
    message("bajando ", a, " (", round(fila$filesize / 1e6, 1), " MB)...")
    download.file(sprintf("https://dataverse.harvard.edu/api/access/datafile/%s", fila$id),
                  dest, mode = "wb", quiet = TRUE)
  }
}

bajar_de_dataverse("7.0",  c("undata-213.tab", "descriptions-213.tab"))
bajar_de_dataverse("39.0", "IdealpointestimatesFP_2026FP.csv")

print(file.info(list.files("data/raw", recursive = TRUE, full.names = TRUE))["size"])
if (!file.exists("data/raw/undl_oficial/2026_10_15_votes_ga.csv"))
  message("Falta el CSV oficial de la ONU: bajalo de https://digitallibrary.un.org/record/4060887 a data/raw/undl_oficial/")
