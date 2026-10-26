# helpers: plumbing only, nothing here is shown on camera
feats <- c(
  "bill_length_mm", "bill_depth_mm",
  "flipper_length_mm", "body_mass_g"
)

verdict <- function(msg, ok) {
  paint <- if (ok) cli::col_green else cli::col_red
  cat(paint(cli::style_bold(paste0(msg, ok))), "\n")
  invisible(ok)
}

load_clean <- function(path) {
  d <- readr::read_csv(path, show_col_types = FALSE)
  tidyr::drop_na(d, tidyr::all_of(feats))
}

read_centroids <- function(path) {
  df <- readr::read_csv(path, show_col_types = FALSE)
  as.matrix(df[, feats])
}

kmeans_fixed <- function(df, centroids, max_iter = 100L) {
  z <- scale(as.matrix(df[, feats]))
  centre <- attr(z, "scaled:center")
  spread <- attr(z, "scaled:scale")
  cen <- scale(centroids, center = centre, scale = spread)
  cluster <- rep(0L, nrow(z))
  for (iter in seq_len(max_iter)) {
    dist <- vapply(seq_len(nrow(cen)), function(k) {
      rowSums((z - rep(cen[k, ], each = nrow(z)))^2)
    }, numeric(nrow(z)))
    new_cluster <- max.col(-dist, ties.method = "first")
    if (all(new_cluster == cluster)) break
    cluster <- new_cluster
    for (k in seq_len(nrow(cen))) {
      members <- cluster == k
      if (any(members)) {
        cen[k, ] <- colMeans(z[members, , drop = FALSE])
      }
    }
  }
  objective <- sum((z - cen[cluster, , drop = FALSE])^2)
  list(
    cluster = as.integer(cluster),
    centers = sweep(sweep(cen, 2, spread, `*`), 2, centre, `+`),
    objective = objective
  )
}

list(
  feats = feats,
  verdict = verdict,
  load_clean = load_clean,
  read_centroids = read_centroids,
  kmeans_fixed = kmeans_fixed
)
