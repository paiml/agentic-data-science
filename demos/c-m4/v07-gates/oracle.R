# gates: each one is a command that either passes or blocks
gate <- function(cmd) system(cmd, ignore.stdout = TRUE) == 0L
gates <- c(
  datasets = gate("cd datasets/wine-quality && sha256sum -c SHA256SUMS"),
  golden = gate("test -s datasets/golden/p4.json"),
  turtle = gate("grep -q 'a ads:Artifact' datasets/golden/p4-artifact.ttl"))
gates
ok <- all(gates)
cat(cli::col_green(cli::style_bold(ok)), "\n")
