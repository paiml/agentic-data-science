#!/usr/bin/env bash
# Generate assets/hero.svg from datasets/penguins/penguins.csv (flipper length vs body mass,
# coloured by species). No hand-drawn art: every dot is a data row. Render to PNG with
#   rmedia svg2png assets/hero.svg assets/hero.png --width 1280 --height 640
set -euo pipefail
out="${1:-assets/hero.svg}"
awk -F, '
BEGIN {
  W = 1280; H = 640; px0 = 640; px1 = 1220; py0 = 110; py1 = 560
  fmin = 170; fmax = 235; mmin = 2600; mmax = 6400
  col["Adelie"] = "#ff8c42"; col["Chinstrap"] = "#b86bff"; col["Gentoo"] = "#2fd1c5"
  printf "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"%d\" height=\"%d\" viewBox=\"0 0 %d %d\">\n", W, H, W, H
  printf "<rect width=\"%d\" height=\"%d\" fill=\"#0e1424\"/>\n", W, H
  printf "<rect x=\"%d\" y=\"%d\" width=\"%d\" height=\"%d\" fill=\"none\" stroke=\"#2a3556\"/>\n", px0, py0, px1 - px0, py1 - py0
}
NR > 1 && $5 != "NA" && $6 != "NA" {
  x = px0 + ($5 - fmin) / (fmax - fmin) * (px1 - px0)
  y = py1 - ($6 - mmin) / (mmax - mmin) * (py1 - py0)
  printf "<circle cx=\"%.1f\" cy=\"%.1f\" r=\"5\" fill=\"%s\" fill-opacity=\"0.8\"/>\n", x, y, col[$1]
  n++
}
END {
  printf "<text x=\"60\" y=\"250\" font-family=\"DejaVu Sans, sans-serif\" font-size=\"64\" font-weight=\"700\" fill=\"#ffffff\">Agentic</text>\n"
  printf "<text x=\"60\" y=\"322\" font-family=\"DejaVu Sans, sans-serif\" font-size=\"64\" font-weight=\"700\" fill=\"#ffffff\">Data Science</text>\n"
  printf "<text x=\"60\" y=\"380\" font-family=\"DejaVu Sans, sans-serif\" font-size=\"26\" fill=\"#9fb0d8\">R · Julia · Kotlin · Rust · Lean 4</text>\n"
  printf "<text x=\"60\" y=\"420\" font-family=\"DejaVu Sans, sans-serif\" font-size=\"22\" fill=\"#9fb0d8\">Same problems. Same golden numbers.</text>\n"
  printf "<text x=\"%d\" y=\"%d\" font-family=\"DejaVu Sans, sans-serif\" font-size=\"16\" fill=\"#9fb0d8\">flipper length (mm) vs body mass (g), %d Palmer penguins</text>\n", px0, py1 + 30, n
  printf "<text x=\"60\" y=\"590\" font-family=\"DejaVu Sans, sans-serif\" font-size=\"18\" fill=\"#6f7fa8\">Pragmatic AI Labs</text>\n"
  printf "</svg>\n"
}' datasets/penguins/penguins.csv > "$out"
