# correr_todo.R — Corre el pipeline completo en orden, de los datos crudos al sitio
#
# Antes: tener en data/raw/ los archivos de origen (ver guia/02-recoleccion.qmd). Los de Voeten se bajan
# con source("R/pipeline/00_descargar_datos.R"); el CSV oficial de la ONU, a mano.
# Tarda alrededor de un minuto; los pasos más lentos son 01 y 03, que leen los archivos grandes.

pasos <- c(
  "R/pipeline/01_votos_1946_2012.R",
  "R/pipeline/02_ideal_points.R",
  # "R/pipeline/03a_registros_undl.R",   # opcional: solo si bajaste registros MARCXML nuevos
  "R/pipeline/03_votos_2013_2026.R",
  "R/pipeline/04_unir_1946_2026.R",
  "R/pipeline/05_argentina_por_gobierno.R",
  "R/pipeline/06_exportar_web.R",
  "R/pipeline/07_exportar_mundo.R",
  "R/01_figuras_argentina.R"
)

for (p in pasos) {
  message("\n==== ", p, " ====")
  t0 <- Sys.time()
  source(p, local = new.env(), encoding = "UTF-8")   # cada script corre en su propio entorno
  message("listo en ", round(difftime(Sys.time(), t0, units = "secs")), " s")
}
message("\nPipeline completo. Revisá los cambios en la pestaña Git de RStudio antes de hacer commit.")
