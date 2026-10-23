#!/usr/bin/env bash
# B-M4 video 06-report: report_ttl writes the ads:Artifact, identical to the R artifact except the generator
# shellcheck source=../lib.sh
source "$(dirname "$0")/../lib.sh"
julia --project="$PKG" -e '
using AgenticDS
r = pipeline_wine("datasets/wine-quality/winequality-red.csv", "datasets/wine-quality/winequality-white.csv")
mktempdir() do dir
    p = report_ttl(r, joinpath(dir, "wine-report.ttl"))
    txt = read(p, String); print(txt)
    got = filter(!contains("generatedBy"), split(txt, "\n"))
    want = filter(!contains("generatedBy"), split(read("datasets/golden/p4-artifact.ttl", String), "\n"))
    @assert got == want
    @assert occursin("a ads:Artifact", txt) && occursin("ads:generatedBy \"AgenticDS.pipeline_wine\"", txt)
end
println("contract: b-m4 report_ttl matches the R artifact except the generator OK")'
