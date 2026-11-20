# Figuras sobre la posición de Argentina en la AGNU, por gobierno.
# Abrir votaciones-agnu.Rproj en RStudio (el directorio de trabajo queda en la raíz del proyecto) y ejecutar.
# Requiere: readr, dplyr, tidyr, ggplot2, scales (todos incluidos en tidyverse).

library(readr); library(dplyr); library(tidyr); library(ggplot2); library(scales)

dir.create("figures", showWarnings = FALSE)
P <- "data/processed/"

gov <- read_csv("data/governments_argentina.csv", show_col_types = FALSE) |>
  mutate(start = as.Date(start), end = as.Date(end),
         de_facto = type == "de facto",
         etiqueta = government)

# Dispositivo gráfico: ragg si está instalado; si no, cairo (renderiza bien tildes y ñ)
guardar <- function(nombre, g, ancho = 11, alto = 6.5) {
  if (requireNamespace("ragg", quietly = TRUE)) {
    ggsave(nombre, g, width = ancho, height = alto, dpi = 150, bg = "white", device = ragg::agg_png)
  } else {
    ggsave(nombre, g, width = ancho, height = alto, dpi = 150, bg = "white", type = "cairo")
  }
}

tema_base <- theme_minimal(base_size = 12) +
  theme(plot.title.position = "plot", panel.grid.minor = element_blank(),
        legend.position = "bottom")

# ---- 1. Ideal point de Argentina vs. referentes, con gobiernos sombreados ----
ip <- read_csv(paste0(P, "argentina_ideal_points.csv"), show_col_types = FALSE)
bandas <- gov |>
  transmute(gov_id, de_facto, etiqueta,
            xmin = pmax(as.integer(format(start, "%Y")), min(ip$year)),
            xmax = pmin(as.integer(format(end, "%Y")) + 1, max(ip$year) + 1)) |>
  filter(xmax > xmin)

serie <- ip |>
  select(year, Argentina = ARG, `EE. UU.` = USA, China = CHN, `Promedio mundial` = mean_world) |>
  pivot_longer(-year, names_to = "pais", values_to = "ideal_point")

g1 <- ggplot() +
  geom_rect(data = bandas, aes(xmin = xmin, xmax = xmax, ymin = -Inf, ymax = Inf, fill = de_facto), alpha = 0.18) +
  geom_line(data = serie, aes(year, ideal_point, colour = pais, linewidth = pais == "Argentina"), na.rm = TRUE) +
  scale_linewidth_manual(values = c(`TRUE` = 1.3, `FALSE` = 0.6), guide = "none") +
  scale_fill_manual(values = c(`TRUE` = "#9a9a9a", `FALSE` = "#ffffff"), labels = c("Gobierno constitucional", "Gobierno de facto"), name = NULL) +
  scale_colour_manual(values = c(Argentina = "#1f77b4", `EE. UU.` = "#d62728", China = "#e6a100", `Promedio mundial` = "#555555"), name = NULL) +
  labs(title = "Argentina en la Asamblea General de la ONU, 1946-2025",
       subtitle = "Ideal point anual (alto = más cerca de EE. UU. y Occidente; bajo = más cerca del mundo en desarrollo).\nSombreado gris: gobiernos de facto",
       x = NULL, y = "Ideal point", caption = "Fuente: Bailey, Strezhnev y Voeten, ideal points de la AGNU") +
  tema_base
guardar("figures/01_ideal_point_argentina.png", g1, 11, 6)

# ---- 2. Reparto de votos por gobierno ----
vg <- read_csv(paste0(P, "argentina_by_government_votes.csv"), show_col_types = FALSE)
orden <- gov$government[gov$government %in% vg$government]
todos <- vg |>
  filter(topic == "Todos") |>
  pivot_longer(starts_with("pct_"), names_to = "voto", values_to = "pct") |>
  mutate(voto = factor(voto, levels = c("pct_no", "pct_abstain", "pct_yes"), labels = c("En contra", "Abstención", "A favor")),
         government = factor(government, levels = rev(orden)),
         marca = ifelse(type == "de facto", " (de facto)", ""))

g2 <- ggplot(todos, aes(pct, government, fill = voto)) +
  geom_col(width = 0.75) +
  geom_text(data = distinct(todos, government, n_votes, marca), aes(x = 101, y = government, label = paste0("n=", n_votes, marca)),
            inherit.aes = FALSE, hjust = 0, size = 3.2) +
  scale_fill_manual(values = c(`A favor` = "#2a9d8f", `Abstención` = "#e9c46a", `En contra` = "#e76f51"), name = NULL) +
  scale_x_continuous(labels = label_percent(scale = 1), breaks = seq(0, 100, 25), expand = expansion(mult = c(0, 0.22))) +
  labs(title = "Cómo vota Argentina, por gobierno (1946-2025)", x = NULL, y = NULL,
       caption = "Votaciones nominales con voto emitido (sí, abstención o no). Fuentes: Voeten (hasta 2012) y UN Digital Library (desde 2013)") +
  tema_base
guardar("figures/02_votos_por_gobierno.png", g2, 11, 6.5)

# ---- 3. Coincidencia con referentes ----
ag <- read_csv(paste0(P, "argentina_by_government_agreement.csv"), show_col_types = FALSE) |>
  mutate(government = factor(government, levels = rev(orden)),
         reference = factor(reference, levels = c("EE. UU.", "Reino Unido", "Francia", "URSS/Rusia", "China", "Cuba", "Brasil", "Chile", "México", "Uruguay")))

g3 <- ggplot(ag, aes(reference, government, fill = pct_agreement)) +
  geom_tile(colour = "white") +
  geom_text(aes(label = ifelse(is.na(pct_agreement), "s/d", round(pct_agreement))), size = 3) +
  scale_fill_gradient2(low = "#b2182b", mid = "#f7f7f7", high = "#2166ac", midpoint = 55, na.value = "grey90",
                       limits = c(0, 100), name = "% de coincidencia") +
  labs(title = "Con quién coincide Argentina en sus votos, por gobierno (1946-2025)", x = NULL, y = NULL,
       caption = "Porcentaje de votaciones en que ambos países votaron igual, sobre las votaciones en que los dos emitieron voto") +
  tema_base + theme(axis.text.x = element_text(angle = 30, hjust = 1))
guardar("figures/03_coincidencia_por_gobierno.png", g3, 11, 6.5)

# ---- 4. Votos a favor por gobierno y tema ----
tm <- vg |>
  filter(topic != "Todos") |>
  mutate(government = factor(government, levels = rev(orden)))

g4 <- ggplot(tm, aes(topic, government, fill = pct_yes)) +
  geom_tile(colour = "white") +
  geom_text(aes(label = round(pct_yes)), size = 3) +
  scale_fill_gradient(low = "#fde0dd", high = "#1a9850", limits = c(0, 100), name = "% a favor") +
  labs(title = "Votos a favor de Argentina por tema y gobierno (1946-2025)", x = NULL, y = NULL,
       caption = "Temas: codificación de Voeten hasta 2012 y palabras clave sobre el título desde 2013; una resolución puede tener más de un tema") +
  tema_base + theme(axis.text.x = element_text(angle = 30, hjust = 1))
guardar("figures/04_votos_por_tema_y_gobierno.png", g4, 11, 6.5)

message("Figuras guardadas en figures/")
