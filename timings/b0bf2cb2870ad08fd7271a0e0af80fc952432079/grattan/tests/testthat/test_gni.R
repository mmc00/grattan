context("GNI")

test_that("GNI returns known results", {
  expect_equal(gni_qtr("1989-12-02", roll = "nearest"), 97145 * 1e6, tol = 0.01e9)
  expect_equal(gni_fy("1989-90"), 391176000000, tol = 0.01e9)
})

test_that("Error handling", {
  expect_warning(gni_fy("2017-18"))
})

context("GDP")

test_that("GDP returns known results", {
  expect_equal(gdp_qtr("1989-12-02", roll = "nearest"), 100576000000, tol = 0.01e9)
  expect_equal(gdp_fy("1989-90"), 404889000000, tol = 0.01e9)
})

test_that("Error handling", {
  expect_warning(gdp_fy("2017-18"))
})
