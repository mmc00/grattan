context("project function")



test_that("Error handling", {
  a <- "foo"
  expect_error(project(a, 1:2), 
               regexp = "`h` had length-2, but must be a length-1 positive integer.", 
               fixed = TRUE)
  expect_error(project(a, 1), 
               regexp = "`h = 1` was type double, but must be type integer. (Did you mean `h = 1L`?)", 
               fixed = TRUE)
  expect_error(project(a, 1.5), 
               regexp = "`h = 1.5` was type double, but must be type integer.", 
               fixed = TRUE)
  expect_error(project(a, "x"), 
               regexp = '`h = "x"` was type character, but must be type integer.', 
               fixed = TRUE)
  expect_error(project(a, NA_integer_), 
               regexp = '`h = NA`. This is not permitted.', 
               fixed = TRUE)
  expect_error(project(a, -1L), 
               regexp = '`h = -1`, but must be a nonnegative integer. Change h to a nonnegative integer.', 
               fixed = TRUE)
  expect_error(project(a, 1L), 
               regexp = "`sample_file` was of class character, but must be a data.table.", 
               fixed = TRUE)
})

test_that("h = 0", {
  skip_on_cran()
  skip_if_not_installed("taxstats")
  library(taxstats)
  s1314 <- as.data.table(sample_file_1314)
  expect_identical(s1314, project(s1314, h = 0L))
  expect_identical(s1314, project(as.data.frame(s1314), h = 0L))
})

test_that("Columns do not vanish", {
  skip_if_not_installed("taxstats") 
  testH <- as.integer(sample(1:4, size = 1))
  y <- project(sample_file_1314, h = testH)
  all_zero <- function(x){
    all(abs(x) < .Machine$double.eps)
  }
  
  cols_zero <- sapply(grattan:::select_which_(y, is.numeric), all_zero)
  expect_false(any(cols_zero), info = paste0("h = ", testH, ". Col:", names(cols_zero)[cols_zero]))
})

test_that("Warnings", {
  skip_on_cran()
  skip_if_not_installed("taxstats")
  expect_warning(project(sample_file_1314, h = 1L, fy.year.of.sample.file = "2012-13"),
                 regexp = "nrow")
  expect_error(project(sample_file_1314, h = 1L, fy.year.of.sample.file = "2011-12"),
               regexp = "2012.13.*2013.14")
})

test_that("Error handling (sample files)", {
  skip_on_cran()
  skip_if_not_installed("taxstats")
  library(taxstats)
  expect_error(project(data.table(), h = 1L),
               regexp = "`fy.year.of.sample.file` was not provided, and its value could not be inferred from nrow(sample_file) = 0. Either use a 2% sample file of the years 2012-13, 2013-14, or 2014-15 or supply `fy.year.of.sample.file` manually.", 
               fixed = TRUE)
  
  
  expect_warning(project(sample_file_1112, h = 1L, fy.year.of.sample.file = "2013-14"), 
                 regexp = "nrow(sample_file) != 254318.", 
                 fixed = TRUE)
  expect_warning(project(sample_file_1112, h = 1L, fy.year.of.sample.file = "2014-15"), 
                 regexp = "nrow(sample_file) != 263339", 
                 fixed = TRUE)
  expect_warning(project(sample_file_1112, h = 1L, fy.year.of.sample.file = "2015-16"), 
                 regexp = "nrow(sample_file) != 269639", 
                 fixed = TRUE)
  expect_error(project_to(sample_file_1112, "2013-14"),
               regexp = "`fy.year.of.sample.file` was not provided, yet its value could not be inferred from nrow(sample_file) = 254273. Either use a 2% sample file of the years 2012-13, 2013-14, or 2014-15 or supply `fy.year.of.sample.file` manually.",
               fixed = TRUE)
})

test_that("Switch off differentially uprating", {
  skip_on_cran()
  skip_if_not_installed("taxstats")
  library(taxstats)
  s1314 <- as.data.table(sample_file_1314)
  s1516A <- project(s1314, h = 2L)
  s1516B <- project(s1314, h = 2L, differentially_uprate_Sw = FALSE)
  expect_identical(s1516A$Ind, s1516B$Ind)
  swa <- .subset2(s1516A, "Sw_amt")
  swb <- .subset2(s1516B, "Sw_amt")
  len <- length(swa)
  swa_sorted <- sort(swa)
  swb_sorted <- sort(swb)
  expect_lt(swa_sorted[len %/% 2], swb_sorted[len %/% 2])
  expect_gt(swa_sorted[floor(0.95 * len)], swb_sorted[floor(0.95 * len)])
  expect_gt(swa_sorted[floor(0.25 * len)], swb_sorted[floor(0.25 * len)])
})

test_that("Custom lf/wage series", {
  skip_on_cran()
  skip_if_not_installed("taxstats")
  library(taxstats)
  s1314 <- as.data.table(sample_file_1314)
  s2021 <- project(s1314, h = 7L)
  s2021_LA <- project(s1314, h = 7L, lf.series = 0.0)
  s2021_LB <- project(s1314, h = 7L, lf.series = 0.1)
  expect_lt(s2021_LA[, sum(WEIGHT)], 
            s2021[, sum(WEIGHT)])
  expect_gt(s2021_LB[, sum(WEIGHT)], 
            s2021[, sum(WEIGHT)])
  
  s2021_WA <- project(s1314, h = 7L, wage.series = 0.0)
  s2021_WB <- project(s1314, h = 7L, wage.series = 0.035)
  expect_lt(s2021_WA[, mean(Sw_amt)], 
            s2021[, mean(Sw_amt)])
  expect_gt(s2021_WB[, mean(Sw_amt)], 
            s2021[, mean(Sw_amt)])
  
  
})

test_that("Coverage", {
  skip_on_cran()
  skip_if_not_installed("taxstats1516")
  skip_if_not_installed("taxstats")
  library(taxstats1516)
  library(taxstats)
  s1516 <- as.data.table(sample_file_1516_synth)
  out1 <- project(s1516,
                  h = 1L,
                  .recalculate.inflators = FALSE)
  out2 <- project(hutils::drop_col(s1516, "Med_Exp_TO_amt"),
                 h = 1L,
                 fy.year.of.sample.file = "2015-16",
                 .recalculate.inflators = TRUE)
  expect_equal(out1, out2, tol = 0.1)
  
  expect_error(project(sample_file_1112,
                       h = 1L,
                       fy.year.of.sample.file = "2011-12",
                       check_fy_sample_file = FALSE),
               regexp = "Precalculated inflators")
  
  out3 <- project(s1516, h = 1L, excl_vars = "Other_foreign_inc_amt")
  expect_identical(out3[, Other_foreign_inc_amt], s1516[, Other_foreign_inc_amt])
  
  
})


