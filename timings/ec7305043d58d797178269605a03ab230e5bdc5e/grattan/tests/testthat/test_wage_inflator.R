context("Wage inflator")

test_that("Error handling", {
  expect_error(wage_inflator(from_fy = NA, to_fy = "2015-16"))
  
  expect_error(wage_inflator(1, from_fy = "2013-14", to_fy = "2045-46", allow.projection = FALSE), regexp = "wage index data")
})

test_that("upper/lower higher/lower", {
  expect_gte(wage_inflator(from_fy = "2013-14", to_fy = "2030-31", forecast.series = "upper"), 
             wage_inflator(from_fy = "2013-14", to_fy = "2030-31", forecast.series = "lower"))
})

test_that("Custom wage series", {
  
  y <- wage_inflator(1, from_fy = "2017-18", to_fy = "2020-21", 
                     forecast.series = "custom", 
                     wage.series = 0.1)
  
  expect_equal(y, 1.1^3)
})
  
test_that("Custom wage series error handling", {
  expect_error(wage_inflator(1, from_fy = "2015-16", to_fy = "2017-18", 
                             forecast.series = "custom", 
                             wage.series = data.table(fy_year = c("2015-16", "2016-17", "2017-18"), 
                                                      r = c(42, 0.1, 0.1))),
               regexp = "first fy in the custom series")
  
  expect_error(wage_inflator(1, from_fy = "2015-16", to_fy = "2017-18", 
                             forecast.series = "custom", 
                             wage.series = c(1, 2)),
               regexp = "length-one vector or a data.table")
  
  expect_message(wage_inflator(1, from_fy = "2015-16", to_fy = "2018-19", 
                               forecast.series = "custom", 
                               wage.series = data.table(fy_year = c("2017-18", "2018-19"), 
                                                        r = c(2.5, 10.0))),
                 regexp = "unlikely")
})

test_that("from > to deflates and is not a warning", {
  x <- wage_inflator(from_fy = c("2013-14", "2015-16", "2016-17", "2017-18"), 
                     to_fy = "2017-18")
  y <- wage_inflator(to_fy = c("2013-14", "2015-16", "2016-17", "2017-18"), 
                     from_fy = "2017-18")
  expect_equal(x, 1/y)
})

# Issue #24 in general:
test_that("from > to deflates and is not a warning for inflators", {
  x <- lf_inflator_fy(from_fy = c("2013-14", "2015-16", "2016-17", "2017-18"), 
                     to_fy = "2017-18")
  y <- lf_inflator_fy(to_fy = c("2013-14", "2015-16", "2016-17", "2017-18"), 
                     from_fy = "2017-18")
  expect_equal(x, 1/y)
  
  x <- cpi_inflator(from_fy = c("2013-14", "2015-16", "2016-17", "2017-18"), 
                    to_fy = "2017-18")
  y <- cpi_inflator(to_fy = c("2013-14", "2015-16", "2016-17", "2017-18"), 
                    from_fy = "2017-18")
  expect_equal(x, 1/y)
})

