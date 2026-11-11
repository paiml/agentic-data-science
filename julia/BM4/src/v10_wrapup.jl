const TEXT = [
    "ticket: 6497 rows split 5198 and 1299",
    "validate first: quality 11 is refused",
    "held-out RMSE equals the golden",
    "held-out R2 equals the golden",
]
const NOTE = "green gates prove no model is good"
sizes(x) = (x.rows, x.train, x.test)
bad(d) = with(d, :quality, 11)
refused(d) = refusal(validate_wine, bad(d))
function main()
    df, g = read_wine(RED, WHITE), golden()
    r = pipeline_wine(RED, WHITE)
    held = [
        sizes(r) == sizes(g),
        refused(df) == BAD[2][4],
        near(r.rmse, g.rmse),
        near(r.r2, g.r2),
    ]
    foreach(claim, held, TEXT)
    n = sum(held)
    println("Gate Report: $n of 4 claims hold;")
    println(NOTE)
    verdict(all(held), "all Gate Report claims hold")
end
