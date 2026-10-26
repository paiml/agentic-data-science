# penguins: flipper length vs body mass, parsnip + ggplot2
library(parsnip)
library(ggplot2)

model_cols <- c("flipper_length_mm", "body_mass_g")

load_penguins <- function(path) {
  d <- readr::read_csv(path, show_col_types = FALSE)
  d <- tidyr::drop_na(d, tidyr::all_of(model_cols))
  dplyr::select(d, dplyr::all_of(c("species", model_cols)))
}

fit_line <- function(d) {
  fit <- linear_reg() |>
    fit(body_mass_g ~ flipper_length_mm, data = d)
  coef(fit$fit)
}

save_plot <- function(d, file) {
  p <- ggplot(d, aes(.data$flipper_length_mm, .data$body_mass_g)) +
    geom_point(aes(color = .data$species), size = 3) +
    geom_smooth(
      method = "lm", formula = y ~ x, color = "black"
    ) +
    theme_bw(base_size = 18)
  ggsave(file, p, width = 8, height = 6, dpi = 200)
  invisible(p)
}

run_scene <- function() {
  d <- load_penguins("data/penguins.csv")
  b <- fit_line(d)
  cat("rows used:", nrow(d), "\n")
  print(dplyr::tibble(intercept = b[[1]], slope = b[[2]]))
  save_plot(d, "plot.png")
  cli::cli_alert_success("Saved {.file plot.png}")
  ok <- nrow(d) == 342 &&
    abs(b[[1]] + 5780.83) <= 1e-3 * 5780.83 &&
    abs(b[[2]] - 49.69) <= 1e-3 * 49.69
  msg <- paste0("check 342 rows, slope 49.69: ", ok)
  cat(cli::col_green(cli::style_bold(msg)), "\n")
  invisible(ok)
}

if (sys.nframe() == 0 && !run_scene()) {
  quit(status = 1)
}
