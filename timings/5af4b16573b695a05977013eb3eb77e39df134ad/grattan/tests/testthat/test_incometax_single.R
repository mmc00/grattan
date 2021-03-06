
context("Individual income tax")

test_that("income tax checks", {
  # no fy.year
  expect_error(income_tax(1), regexp = "fy.year is missing")
  
  # not fy
  expect_error(income_tax(1, "2015-17"), regexp = "not in correct form")
  
  # not implemented
  expect_error(income_tax(1, "2013-14", allow.forecasts = TRUE))
  
  # NA
  expect_warning(income_tax(-1, "2013-14"), regexp = "Negative")
  
  # not a data frame
  expect_error(income_tax(1, "2013-14", .dots.ATO = "foo"))
  
  # not implemented
  expect_error(income_tax(1, "2013-14", return.mode = "integer"))
})

test_that("income_tax returns known results",{
  
  # All numbers are from the ATO comprehensive tax calculator. 
  expect_equal(income_tax(50e3, fy.year = "2012-13"), 8297)
  expect_equal(income_tax(60e3, fy.year = "2012-13"), 11847)
  expect_equal(income_tax(70e3, fy.year = "2012-13"), 15347)
  expect_equal(income_tax(200e3, fy.year = "2012-13"), 66547)
  
  expect_equal(income_tax(30e3, fy.year = "2013-14"), 2247)
  expect_equal(income_tax(40e3, fy.year = "2013-14"), 4747)
  expect_equal(income_tax(40e3, "2013-14", family_status = "family", n_dependants = 1L), 4394.70)
  # different rounding treatment.
  expect_equal(round(income_tax(40e3, "2013-14", family_status = "family", n_dependants = 0L, age = 66)), 2882)
  expect_equal(income_tax(40e3, "2013-14", family_status = "family", n_dependants = 2L, .dots.ATO = data.frame(Spouse_adjusted_taxable_inc = 30e3)), 4747)
  
  expect_equal(income_tax(31993, fy.year = "2014-15"), 2815.53)
  expect_equal(income_tax(31993, fy.year = "2014-15", age = 70), 0)
  expect_equal(income_tax(135288, fy.year = "2014-15"), 40709, tolerance = 1)
  expect_equal(income_tax(41636, fy.year = "2014-15"), 5535.95, tolerance = 1)
  expect_equal(income_tax(26010, fy.year = "2014-15"), 1550.30, tolerance = 1)
  
  
})

test_that("income_tax is not NA for any years)", {
  expect_false(any(is.na(income_tax(50e3, fy.year = yr2fy(2004:2015)))))
})

test_that("income_tax always returns the length of its arguments", {
  LEN <- ceiling(abs(rcauchy(1)))
  expect_equal(length(income_tax(runif(LEN, 0, 2e6), fy.year = sample(yr2fy(2004:2014), size = LEN, replace = TRUE))), LEN)
})

