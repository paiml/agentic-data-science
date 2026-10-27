test_that("verdict prints the plain line when colour is off", {
  expect_output(
    verdict("contract: ads-r-p1 x OK", color = FALSE),
    "^contract: ads-r-p1 x OK$"
  )
})

test_that("verdict wraps the line in green when colour is on", {
  expect_output(
    verdict("contract: ads-r-p1 x OK", color = TRUE),
    "\033\\[38;5;83mcontract: ads-r-p1 x OK\033\\[0m",
    fixed = FALSE
  )
})

test_that("verdict returns its text", {
  out <- utils::capture.output(r <- verdict("t", color = FALSE))
  expect_identical(r, "t")
})

test_that("verdict default is plain when output is captured", {
  out <- utils::capture.output(verdict("contract: ads-r-p1 x OK"))
  expect_identical(out, "contract: ads-r-p1 x OK")
})
