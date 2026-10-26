# penguins: parsnip OLS vs the normal-equation oracle
library(parsnip)
library(ggplot2)
h <- new.env()
sys.source("R/helpers.R", envir = h)

run_scene <- function() {
  d <- h$load_clean("data/penguins.csv")
  m <- linear_reg() |>
    fit(body_mass_g ~ flipper_length_mm, data = d)
  b <- coef(m$fit)
  cat(sprintf("%d rows, slope %.2f\n", nrow(d), b[[2]]))
  p <- ggplot(d, aes(
    .data$flipper_length_mm,
    .data$body_mass_g
  )) +
    geom_point(aes(color = .data$species), size = 3) +
    geom_smooth(method = "lm", formula = y ~ x) +
    h$theme_scene()
  h$save_png(p, "plot.png")
  ok <- nrow(d) == 342 && abs(b[[2]] - 49.69) < 0.005 &&
    isTRUE(all.equal(b, h$oracle(d), tolerance = 1e-8))
  h$verdict("check 342 rows, slope 49.69", ok)
}
if (sys.nframe() == 0 && !run_scene()) quit(status = 1)
