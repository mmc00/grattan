---
title: "Budget 2018 modelling"
author: "Hugh Parsonage"
date: "2018-05-27"
output:
  rmarkdown::html_document:
    toc: true
    toc_depth: 4
    keep_md: true
---

Width: 75.

```r
options(width = 100)
```




```r
grattan_percent <- function(number, digits = 1, .percent.suffix = " per cent") {
  grattanCharts::grattan_percent(number, digits, .percent.suffix)
}
```

## Introduction

This article outlines the calculations used in Grattan Institute's tax modelling. 
The model is simple:

1. Project ("uprate") the latest sample files to the years required
2. Use `model_income_tax` with the required parameters. 


First load the packages we'll need.




```r
library(fastmatch)
library(ggplot2)
library(scales)
library(magrittr)
library(ggrepel)
library(viridis)
library(knitr)
library(hutils)
library(magrittr)
library(data.table)
library(grattanCharts)
templib <- tempfile()
hutils::provide.dir(templib)
```

We also load the `taxstats` package. 
The other packages are private as the ATO has suppressed the information from the public: unfortunately, only approved institutions can use this data sets.


```r
library(taxstats)

sample_file_1415 <- SampleFile1415::sample_file_1415
sample_file_1516 <- fread("~/ozTaxData/data-raw/2016_sample_file.csv", logical01 = FALSE)

sample_files_all <-
    rbindlist(lapply(list(`2003-04` = sample_file_0304, 
                          `2004-05` = sample_file_0405,
                          `2005-06` = sample_file_0506, 
                          `2006-07` = sample_file_0607,
                          `2007-08` = sample_file_0708, 
                          `2008-09` = sample_file_0809,
                          `2009-10` = sample_file_0910, 
                          `2010-11` = sample_file_1011,
                          `2011-12` = sample_file_1112, 
                          `2012-13` = sample_file_1213,
                          `2013-14` = sample_file_1314,
                          `2014-15` = sample_file_1415,
                          `2015-16` = sample_file_1516), 
                     data.table::as.data.table),
              use.names = TRUE,
              fill = TRUE, 
              idcol = "fy.year")
sample_files_all[, WEIGHT := hutils::if_else(fy.year > '2010-11', 50L, 100L)]
sample_files_all[is.na(age_range), age_range := Birth_year]
sample_files_all[is.na(Othr_pnsn_amt), Othr_pnsn_amt := 0L]
sample_files_all[is.na(Med_Exp_TO_amt), Med_Exp_TO_amt := 0L]
sample_files_all[is.na(Spouse_adjusted_taxable_inc), Spouse_adjusted_taxable_inc := 0L]
age_range_decoder <- as.data.table(age_range_decoder)

## ----load-grattan--------------------------------------------------------
library(grattan)

ntile <- function(x, n) {
  if (requireNamespace("dplyr", quietly = TRUE)) {
    dplyr::ntile(x, n)
  } else {
    grattan::weighted_ntile(x, n = n)
  }
}
coalesce <- hutils::coalesce

sample_files_all[, Taxable_Income_percentile := ntile(Taxable_Income, 100)]
```


```r
sample_files_all %>%
  .[, tax := income_tax(Taxable_Income, fy.year = .BY[[1L]], .dots.ATO = .SD), keyby = "fy.year"] %>%
  .[, avg_tax_rate := coalesce(tax / Taxable_Income, 0)]
```


```r
revenue_foregone <- function(dt, revenue_positive = TRUE, digits = NULL) {
  out <- dt[, sum((as.integer(new_tax) - baseline_tax) * WEIGHT)]
  class(out) <- "revenue_foregone"
  setattr(out, "digits", digits)
  out
}

.revenue_foregone <- function(dt, revenue_positive = TRUE, digits = NULL) {
  out <- dt[, sum((as.integer(new_tax) - baseline_tax) * WEIGHT)]
  class(out) <- "revenue_foregone"
  setattr(out, "digits", digits)
  
  if (is_knitting()) {
    return(print.revenue_foregone(out))
  }
  out
}

print.revenue_foregone <- function(x, ...) {
  if (x < 0) {
    pre <- paste0("\u2212", if (is_knitting()) "\\$" else "$")
    x <- -x
  } else {
    pre <- "$"
  }
  d <- function(default) {
    if (is.null(attr(x, "digits"))) {
      default
    } else {
      attr(x, "digits")
    }
  }
  if (x > 10e9) {
    res <- paste0(pre, prettyNum(round(x / 1e9, d(0)), big.mark = ","), " billion")
  } else if (x > 1e9) {
    res <- paste0(pre, prettyNum(round(x / 1e9, d(1)), big.mark = ","), " billion")
  } else {
    res <- paste0(pre, prettyNum(round(x / 1e6, d(0)), big.mark = ","), " million")
  }
  print(res)
}
```


```r
## ------------------------------------------------------------------------
s1617 <- 
  if (file.exists("~/ozTaxData/data-raw/2016_sample_file.csv")) {
    sample_file_1516 <- fread("~/ozTaxData/data-raw/2016_sample_file.csv")
    project(sample_file_1516, h = 1L, fy.year.of.sample.file = "2015-16")
  } else {
    project(sample_file_1415_synth, h = 2L)
  }
s1617 <- model_income_tax(s1617, "2016-17")
```


```r
## ------------------------------------------------------------------------
s1718 <- 
  if (file.exists("~/ozTaxData/data-raw/2016_sample_file.csv")) {
    sample_file_1516 <- fread("~/ozTaxData/data-raw/2016_sample_file.csv")
    project(sample_file_1516, h = 2L, fy.year.of.sample.file = "2015-16")
  } else {
    project(sample_file_1415_synth, h = 3L)
  }
s1718 <- model_income_tax(s1718, "2017-18")
```



```r
## ------------------------------------------------------------------------
s1819 <- 
  if (file.exists("~/ozTaxData/data-raw/2016_sample_file.csv")) {
    sample_file_1516 <- fread("~/ozTaxData/data-raw/2016_sample_file.csv")
    project(sample_file_1516, h = 3L, fy.year.of.sample.file = "2015-16")
  } else {
    project(sample_file_1415_synth, h = 4L)
  } %>%
  model_income_tax("2018-19")
```

These tables come from the Budget papers and will be passed to `project` so that the uprating can be set with fixed values. (By default `project` forecasts the series using the `forecast` package.)

```r
wage_forecasts <- 
  data.table(fy_year = yr2fy(2018:2028),
             r = c(2.25, 2.75, 3.25, 3.5, 3.5, rep(3.5, 6)) / 100)
```


```r
lf_forecasts <- 
  data.table(fy_year = yr2fy(2018:2028),
             r = c(2.75, 1.50, 1.50, 1.50, 1.25, rep(1.25, 6)) / 100)
```

These are functions of years from 2015-16 that return the tax rates and tax thresholds that the Government has proposed in the Budget. They are used so that the out years can be modelled conveniently as a function of the year only.


```r
ordinary_tax_rates <- function(h) {
  if (h < 9) {
    c(0, 0.19, 0.325, 0.37, 0.45)
  } else {
    c(0, 0.19, 0.325, 0.45)  
  }
}

ordinary_tax_thresholds <- function(h) {
  if (h < 7) {
    c(0, 18200, 37e3, 90e3, 180e3)
  } else if (h < 9) {
    c(0, 18200, 41e3, 90e3, 180e3)
  } else {
    c(0, 18200, 41e3, 200e3)
  }
}
```

These functions increase the thresholds for the Medicare levy for low-income earners. 
Technically such measures have to be approved each financial year, but are as a matter of a routine.


```r
#' @param x2018 A length-one for the 2018-19 number.
#' @param fy The financial year
.do_medicare_levy <- function(x2018, fy) {
  stopifnot(length(fy) == 1L, is.fy(fy))
  if (fy == "2018-19") {
    return(x2018)
  } else {
    return(round(cpi_inflator(x2018, from_fy = "2018-19", to_fy = fy), -1))
  }
}

medicare_levy_lower_threshold <- function(fy) {
  .do_medicare_levy(21980, fy)
}

medicare_levy_lower_sapto_threshold <- function(fy) {
  .do_medicare_levy(34758, fy)
}

medicare_levy_lower_family_threshold <- function(fy) {
  .do_medicare_levy(48385, fy)
}

medicare_levy_lower_family_sapto_threshold <- function(fy) {
  .do_medicare_levy(48385, fy)
}

medicare_levy_lower_up_for_each_child <- function(fy) {
  .do_medicare_levy(3406, fy)
}

.project_to <- function(h, use.Treasury) {
  project(sample_file_1516,
          h = h,
          wage.series = if (use.Treasury) wage_forecasts,
          lf.series = if (use.Treasury) lf_forecasts) %>%
    setkey(Taxable_Income)
}
```


```r
.project_useTreasurys <- lapply(1:13, .project_to, use.Treasury = TRUE)
```


```r
.project_useGrattans <- lapply(1:13, .project_to, use.Treasury = FALSE)
```


```r
wage_r80 <- 
  data.table(fy_year = yr2fy(c(2017:2028)),
             i = wage_inflator(from_fy = "2015-16",
                               to_fy = yr2fy(c(2017:2028)),
                               forecast.level = 80,
                               forecast.series = "upper")) %>%
  .[, r := i / shift(i) - 1] %>%
  .[!is.na(r), .(fy_year, r)]
  
wage_r20 <- 
  data.table(fy_year = yr2fy(c(2017:2028)),
             i = wage_inflator(from_fy = "2015-16",
                               to_fy = yr2fy(c(2017:2028)),
                               forecast.level = 80,
                               forecast.series = "lower")) %>%
  .[, r := i / shift(i) - 1] %>%
  .[!is.na(r), .(fy_year, r)]
```


```r
.project_useGrattans80 <- lapply(1:13, function(h) {
  project(sample_file_1516, h = h, wage.series = wage_r80)
})
```


```r
.project_useGrattans20 <- lapply(1:13, function(h) {
  project(sample_file_1516, h = h, wage.series = wage_r20)
})
```


```r
.project_useGrattans2.75 <- lapply(1:13, function(h) {
  project(sample_file_1516, h = h, wage.series = 0.0275)
})
```


```r
#' @param level Prediction interval level.
#' @param wage.r A string like "2.75\%", the wage growth as a percentage.
model_Budgets <- function(fy_year, 
                          use.Treasury = TRUE,
                          .debug = FALSE,
                          level = NULL, 
                          wage.r = NULL) { 
  h <- as.integer(fy2yr(fy_year) - 2016L)
  s1920 <- NULL
  if (use.Treasury) {
    if (missing(level) && missing(wage.r)) {
      s1920 <- .project_useTreasurys[[h]]
    } else {
      stop("`use.Treasury = TRUE` yet `level` or `wage.r` are supplied.")
    }
  } else {
    if (is.null(level)) {
      if (is.null(wage.r)) {
        s1920 <- .project_useGrattans[[h]]
      } else {
        if (!is.character(wage.r) || length(wage.r) != 1) {
          stop("`wage.r` must be a string.")
        } 
        switch (wage.r, 
                "2.75%" = {
                  s1920 <- .project_useGrattans2.75[[h]]
                }, 
                stop("`wage.r = ", wage.r, "` not supported."))
      }
    } else {
      if (level == 20) {
        s1920 <- .project_useGrattans20[[h]]
      } else if (level == 80) {
        s1920 <- .project_useGrattans80[[h]]
      } else {
        stop("Level not supported.")
      }
    }
  }
  model_income_tax <- function(...,
                               lamington = FALSE,
                               lito_202223 = FALSE, 
                               watr = FALSE) {
    grattan::model_income_tax(
      sample_file = s1920, 
      baseline_fy = "2017-18",
      medicare_levy_lower_threshold = medicare_levy_lower_threshold(fy_year),
      medicare_levy_lower_sapto_threshold = medicare_levy_lower_sapto_threshold(fy_year),
      medicare_levy_lower_family_threshold = medicare_levy_lower_family_threshold(fy_year),
      medicare_levy_lower_family_sapto_threshold = medicare_levy_lower_family_sapto_threshold(fy_year),
      medicare_levy_lower_up_for_each_child = medicare_levy_lower_up_for_each_child(fy_year),
      warn_upper_thresholds = FALSE,
      Budget2018_lamington = lamington,
      Budget2018_lito_202223 = lito_202223,
      Budget2018_watr = watr,
      ...) %>%
      .[, new_tax := as.integer(new_tax)] %>%
      .[, delta := new_tax - baseline_tax] %>%
      setkey(Taxable_Income) %>%
      .[]
  }
  
  list(Budget2018_baseline = model_income_tax(),
       Budget2018_baseline_brackets_cpi = model_income_tax(ordinary_tax_thresholds = cpi_inflator(ordinary_tax_thresholds(1), from_fy = "2017-18", to_fy = fy_year)),
       Budget2018_baseline_no_SBTO = model_income_tax(sbto_discount = 0),
       Budget2018_just_rates = model_income_tax(ordinary_tax_rates =  ordinary_tax_rates(h),
                                                ordinary_tax_thresholds = ordinary_tax_thresholds(h),
                                                lito_202223 = FALSE,
                                                lamington = FALSE),
       Budget2018_just_LITO = model_income_tax(lito_202223 = h > 6,
                                               lamington = FALSE),
       Budget2018_just_LITO_and_rates = model_income_tax(ordinary_tax_rates =  ordinary_tax_rates(h),
                                                         ordinary_tax_thresholds = ordinary_tax_thresholds(h),
                                                         lito_202223 = h > 6,
                                                         lamington = FALSE),
       Budget2018_just_lamington = model_income_tax(lamington = TRUE),
       Budget2018_lamington_plus_LITO = model_income_tax(lito_202223 = h > 6,
                                                         lamington = fy_year %in% c("2018-19", "2019-20", "2020-21", "2021-22")),
       Budget2018_no_SBTO = model_income_tax(ordinary_tax_rates = ordinary_tax_rates(h),
                                             ordinary_tax_thresholds = ordinary_tax_thresholds(h),
                                             lito_202223 = h > 6,
                                             lamington = fy_year %in% c("2018-19", "2019-20", "2020-21", "2021-22"), 
                                             sbto_discount = 0),
       Budget2018 = model_income_tax(ordinary_tax_rates = ordinary_tax_rates(h),
                                     ordinary_tax_thresholds = ordinary_tax_thresholds(h),
                                     lito_202223 = h > 6,
                                     lamington = fy_year %in% c("2018-19", "2019-20", "2020-21", "2021-22")),
       ALP2018_no_SBTO = model_income_tax(ordinary_tax_rates = ordinary_tax_rates(3), 
                                          ordinary_tax_thresholds = ordinary_tax_thresholds(3),
                                          sbto_discount = 0,
                                          watr = fy_year >= "2019-20"),
       ALP2018 = model_income_tax(ordinary_tax_rates = ordinary_tax_rates(3), 
                                  ordinary_tax_thresholds = ordinary_tax_thresholds(3),
                                  lamington = fy_year < "2019-02",
                                  watr = fy_year >= "2019-20"))
}
```


```r
Budget_1922 <- lapply(yr2fy(2019:2028), model_Budgets)
```


```r
Budget_1922_Grattan <- lapply(yr2fy(2019:2028), model_Budgets, use.Treasury = FALSE)
```



```r
Budget_1922_Grattan80 <- lapply(yr2fy(2019:2028), model_Budgets, use.Treasury = FALSE, 
                                level = 80)
```


```r
Budget_1922_Grattan20 <- lapply(yr2fy(2019:2028), model_Budgets, use.Treasury = FALSE, 
                                level = 20)
```


```r
Budget_1922_Grattan2.75 <- lapply(yr2fy(2019:2028), model_Budgets, use.Treasury = FALSE, 
                                wage.r = "2.75%")
```

### Costings 2018-19 to 2027-28 (Govt and Grattan forecasts)


```r
names(Budget_1922) <- yr2fy(2019:2028)
names(Budget_1922_Grattan) <- yr2fy(2019:2028)
names(Budget_1922_Grattan2.75) <- yr2fy(2019:2028)
{sapply(Budget_1922, sapply, revenue_foregone, USE.NAMES = TRUE) / 1e9} %>%
  round(2) %>%
  kable(caption = "Budget costing under various settings, using the Budget paper's assumptions")
```



|                                 | 2018-19| 2019-20| 2020-21| 2021-22| 2022-23| 2023-24| 2024-25| 2025-26| 2026-27| 2027-28|
|:--------------------------------|-------:|-------:|-------:|-------:|-------:|-------:|-------:|-------:|-------:|-------:|
|Budget2018_baseline              |    0.00|   -0.05|   -0.09|   -0.13|   -0.18|   -0.22|   -0.25|   -0.29|   -0.32|   -0.35|
|Budget2018_baseline_brackets_cpi |   -2.28|   -4.44|   -6.75|   -9.17|  -11.74|  -14.44|  -17.29|  -20.29|  -23.45|  -26.78|
|Budget2018_baseline_no_SBTO      |    0.19|    0.15|    0.11|    0.06|    0.02|   -0.01|   -0.05|   -0.08|   -0.11|   -0.14|
|Budget2018_just_rates            |   -0.39|   -0.46|   -0.54|   -0.62|   -5.89|   -6.11|  -17.42|  -18.58|  -19.80|  -21.08|
|Budget2018_just_LITO             |    0.00|   -0.05|   -0.09|   -0.13|   -0.68|   -0.71|   -0.74|   -0.77|   -0.79|   -0.81|
|Budget2018_just_LITO_and_rates   |   -0.39|   -0.46|   -0.54|   -0.62|   -6.39|   -6.61|  -17.90|  -19.05|  -20.27|  -21.54|
|Budget2018_just_lamington        |   -3.79|   -3.90|   -4.00|   -4.09|   -4.17|   -4.24|   -4.30|   -4.35|   -4.40|   -4.44|
|Budget2018_lamington_plus_LITO   |   -3.79|   -3.90|   -4.00|   -4.09|   -0.68|   -0.71|   -0.74|   -0.77|   -0.79|   -0.81|
|Budget2018_no_SBTO               |   -4.00|   -4.13|   -4.27|   -4.38|   -6.20|   -6.42|  -17.71|  -18.85|  -20.07|  -21.33|
|Budget2018                       |   -4.18|   -4.32|   -4.45|   -4.57|   -6.39|   -6.61|  -17.90|  -19.05|  -20.27|  -21.54|
|ALP2018_no_SBTO                  |   -0.20|   -7.01|   -7.19|   -7.33|   -7.47|   -7.60|   -7.71|   -7.81|   -7.91|   -7.99|
|ALP2018                          |   -4.18|   -7.19|   -7.37|   -7.52|   -7.66|   -7.79|   -7.90|   -8.01|   -8.10|   -8.19|


```r
kable(round(sapply(Budget_1922_Grattan, sapply, revenue_foregone, USE.NAMES = TRUE) / 1e9, 2), 
      caption = "Budget costing under various settings, using the default Grattan forecasts")
```



|                                 | 2018-19| 2019-20| 2020-21| 2021-22| 2022-23| 2023-24| 2024-25| 2025-26| 2026-27| 2027-28|
|:--------------------------------|-------:|-------:|-------:|-------:|-------:|-------:|-------:|-------:|-------:|-------:|
|Budget2018_baseline              |    0.00|   -0.05|   -0.09|   -0.14|   -0.18|   -0.23|   -0.28|   -0.33|   -0.38|   -0.43|
|Budget2018_baseline_brackets_cpi |   -2.20|   -4.27|   -6.45|   -8.73|  -11.12|  -13.62|  -16.23|  -18.94|  -21.77|  -24.69|
|Budget2018_baseline_no_SBTO      |    0.18|    0.14|    0.10|    0.06|    0.02|   -0.03|   -0.07|   -0.12|   -0.16|   -0.21|
|Budget2018_just_rates            |   -0.37|   -0.44|   -0.51|   -0.57|   -5.64|   -5.85|  -15.16|  -15.90|  -16.66|  -17.43|
|Budget2018_just_LITO             |    0.00|   -0.05|   -0.09|   -0.14|   -0.72|   -0.77|   -0.82|   -0.87|   -0.92|   -0.97|
|Budget2018_just_LITO_and_rates   |   -0.37|   -0.44|   -0.51|   -0.57|   -6.17|   -6.39|  -15.70|  -16.44|  -17.20|  -17.97|
|Budget2018_just_lamington        |   -3.70|   -3.82|   -3.94|   -4.06|   -4.18|   -4.29|   -4.41|   -4.52|   -4.63|   -4.74|
|Budget2018_lamington_plus_LITO   |   -3.70|   -3.82|   -3.94|   -4.06|   -0.72|   -0.77|   -0.82|   -0.87|   -0.92|   -0.97|
|Budget2018_no_SBTO               |   -3.89|   -4.03|   -4.17|   -4.31|   -5.98|   -6.19|  -15.50|  -16.24|  -16.99|  -17.76|
|Budget2018                       |   -4.07|   -4.21|   -4.36|   -4.50|   -6.17|   -6.39|  -15.70|  -16.44|  -17.20|  -17.97|
|ALP2018_no_SBTO                  |   -0.19|   -6.85|   -7.04|   -7.24|   -7.43|   -7.61|   -7.80|   -7.98|   -8.16|   -8.34|
|ALP2018                          |   -4.07|   -7.03|   -7.23|   -7.42|   -7.61|   -7.80|   -7.99|   -8.18|   -8.36|   -8.55|


```r
names(Budget_1922_Grattan80) <- yr2fy(2019:2028)
kable(round(sapply(Budget_1922_Grattan80, sapply, revenue_foregone, USE.NAMES = TRUE) / 1e9, 2), 
      caption = "Budget costing under various settings, using Grattan's 80% optimistic wage forecasts")
```



|                                 | 2018-19| 2019-20| 2020-21| 2021-22| 2022-23| 2023-24| 2024-25| 2025-26| 2026-27| 2027-28|
|:--------------------------------|-------:|-------:|-------:|-------:|-------:|-------:|-------:|-------:|-------:|-------:|
|Budget2018_baseline              |    0.00|   -0.05|   -0.09|   -0.13|   -0.18|   -0.22|   -0.27|   -0.31|   -0.35|   -0.39|
|Budget2018_baseline_brackets_cpi |   -2.21|   -4.31|   -6.54|   -8.90|  -11.41|  -14.06|  -16.85|  -19.79|  -22.89|  -26.13|
|Budget2018_baseline_no_SBTO      |    0.18|    0.14|    0.10|    0.06|    0.02|   -0.02|   -0.06|   -0.10|   -0.14|   -0.18|
|Budget2018_just_rates            |   -0.38|   -0.45|   -0.52|   -0.59|   -5.75|   -6.00|  -16.40|  -17.42|  -18.49|  -19.60|
|Budget2018_just_LITO             |    0.00|   -0.05|   -0.09|   -0.13|   -0.70|   -0.74|   -0.78|   -0.82|   -0.86|   -0.89|
|Budget2018_just_LITO_and_rates   |   -0.38|   -0.45|   -0.52|   -0.59|   -6.27|   -6.51|  -16.91|  -17.93|  -19.00|  -20.10|
|Budget2018_just_lamington        |   -3.70|   -3.82|   -3.94|   -4.05|   -4.16|   -4.27|   -4.37|   -4.46|   -4.55|   -4.64|
|Budget2018_lamington_plus_LITO   |   -3.70|   -3.82|   -3.94|   -4.05|   -0.70|   -0.74|   -0.78|   -0.82|   -0.86|   -0.89|
|Budget2018_no_SBTO               |   -3.90|   -4.04|   -4.19|   -4.32|   -6.08|   -6.32|  -16.71|  -17.73|  -18.79|  -19.89|
|Budget2018                       |   -4.08|   -4.22|   -4.37|   -4.51|   -6.27|   -6.51|  -16.91|  -17.93|  -19.00|  -20.10|
|ALP2018_no_SBTO                  |   -0.19|   -6.86|   -7.06|   -7.25|   -7.44|   -7.62|   -7.79|   -7.95|   -8.11|   -8.26|
|ALP2018                          |   -4.08|   -7.04|   -7.24|   -7.43|   -7.62|   -7.81|   -7.98|   -8.15|   -8.31|   -8.46|


```r
names(Budget_1922_Grattan20) <- yr2fy(2019:2028)
kable(round(sapply(Budget_1922_Grattan20, sapply, revenue_foregone, USE.NAMES = TRUE) / 1e9, 2), 
      caption = "Budget costing under various settings, using Grattan's 20% pessimistic wage forecasts")
```



|                                 | 2018-19| 2019-20| 2020-21| 2021-22| 2022-23| 2023-24| 2024-25| 2025-26| 2026-27| 2027-28|
|:--------------------------------|-------:|-------:|-------:|-------:|-------:|-------:|-------:|-------:|-------:|-------:|
|Budget2018_baseline              |    0.00|   -0.05|   -0.09|   -0.14|   -0.19|   -0.24|   -0.29|   -0.34|   -0.39|   -0.45|
|Budget2018_baseline_brackets_cpi |   -2.19|   -4.23|   -6.36|   -8.55|  -10.83|  -13.17|  -15.58|  -18.04|  -20.57|  -23.15|
|Budget2018_baseline_no_SBTO      |    0.18|    0.14|    0.10|    0.06|    0.01|   -0.03|   -0.08|   -0.13|   -0.18|   -0.23|
|Budget2018_just_rates            |   -0.37|   -0.43|   -0.49|   -0.56|   -5.51|   -5.69|  -13.95|  -14.41|  -14.86|  -15.30|
|Budget2018_just_LITO             |    0.00|   -0.05|   -0.09|   -0.14|   -0.74|   -0.79|   -0.85|   -0.91|   -0.97|   -1.03|
|Budget2018_just_LITO_and_rates   |   -0.37|   -0.43|   -0.49|   -0.56|   -6.06|   -6.25|  -14.52|  -14.98|  -15.44|  -15.88|
|Budget2018_just_lamington        |   -3.70|   -3.82|   -3.94|   -4.06|   -4.18|   -4.30|   -4.42|   -4.55|   -4.67|   -4.80|
|Budget2018_lamington_plus_LITO   |   -3.70|   -3.82|   -3.94|   -4.06|   -0.74|   -0.79|   -0.85|   -0.91|   -0.97|   -1.03|
|Budget2018_no_SBTO               |   -3.89|   -4.02|   -4.16|   -4.29|   -5.87|   -6.05|  -14.32|  -14.77|  -15.23|  -15.67|
|Budget2018                       |   -4.07|   -4.20|   -4.34|   -4.48|   -6.06|   -6.25|  -14.52|  -14.98|  -15.44|  -15.88|
|ALP2018_no_SBTO                  |   -0.18|   -6.84|   -7.03|   -7.21|   -7.40|   -7.59|   -7.78|   -7.96|   -8.15|   -8.34|
|ALP2018                          |   -4.07|   -7.01|   -7.21|   -7.40|   -7.59|   -7.78|   -7.97|   -8.16|   -8.35|   -8.54|


```r
sapply(Budget_1922, sapply, revenue_foregone, USE.NAMES = TRUE) %>%
  rowSums %>%
  divide_by(1e9) %>%
  kable
```



|                                 |            x|
|:--------------------------------|------------:|
|Budget2018_baseline              |   -1.8812235|
|Budget2018_baseline_brackets_cpi | -136.6171602|
|Budget2018_baseline_no_SBTO      |    0.1334656|
|Budget2018_just_rates            |  -90.8877016|
|Budget2018_just_LITO             |   -4.7745694|
|Budget2018_just_LITO_and_rates   |  -93.7811173|
|Budget2018_just_lamington        |  -41.6702567|
|Budget2018_lamington_plus_LITO   |  -20.2884170|
|Budget2018_no_SBTO               | -107.3579413|
|Budget2018                       | -109.2950203|
|ALP2018_no_SBTO                  |  -68.2179170|
|ALP2018                          |  -73.9072620|

```r
sapply(Budget_1922_Grattan, sapply, revenue_foregone, USE.NAMES = TRUE) %>%
  rowSums %>% 
  divide_by(1e9) %>%
  kable
```



|                                 |            x|
|:--------------------------------|------------:|
|Budget2018_baseline              |   -2.0965981|
|Budget2018_baseline_brackets_cpi | -128.0254601|
|Budget2018_baseline_no_SBTO      |   -0.0773124|
|Budget2018_just_rates            |  -78.5322580|
|Budget2018_just_LITO             |   -5.3234925|
|Budget2018_just_LITO_and_rates   |  -81.7592156|
|Budget2018_just_lamington        |  -42.2930845|
|Budget2018_lamington_plus_LITO   |  -20.5694087|
|Budget2018_no_SBTO               |  -95.0640352|
|Budget2018                       |  -97.0051962|
|ALP2018_no_SBTO                  |  -68.6390267|
|ALP2018                          |  -74.2376411|

```r

write.csv(round(sapply(Budget_1922, sapply, revenue_foregone, USE.NAMES = TRUE) / 1e9, 2), 
          "Budget201718-summaries-2.csv")
write.csv(round(sapply(Budget_1922_Grattan, sapply, revenue_foregone, USE.NAMES = TRUE) / 1e9, 2), 
          "Budget201718-Grattan-summaries.csv")
write.csv(round(sapply(Budget_1922_Grattan80, sapply, revenue_foregone, USE.NAMES = TRUE) / 1e9, 2), 
          "Budget201718-Grattan-summaries-80pc.csv")
write.csv(round(sapply(Budget_1922_Grattan20, sapply, revenue_foregone, USE.NAMES = TRUE) / 1e9, 2), 
          "Budget201718-Grattan-summaries-20pc.csv")
```


```r
avg_individual_impact_by_Quintile_fy <- 
  lapply(Budget_1922, function(x) {
    x[["Budget2018"]] %>%
      setkey(Taxable_Income) %>%
      .[, Quintile := factor(ceiling(5 * .I / .N),
                             levels = 1:5)] %>%
      .[, .(avg_delta = mean(delta),
            max_income = max(Taxable_Income),
            min_income = min(Taxable_Income),
            avg_income = mean(Taxable_Income + 0)),
        keyby = .(Quintile)]
  }) %>%
  rbindlist(idcol = "fy_year") %>% 
  setkey(fy_year, Quintile) %>%
  .[, "Financial year ending" := fy2yr(fy_year)] %>%
  .[, avg_delta := round(avg_delta, 2)] %T>%
  fwrite("avg_individual_impact_by_Quintile_fy.csv") %>%
  .[] 

avg_individual_impact_by_Quintile_fy %>%
  grplot(aes(x = `Financial year ending`,
             y = avg_delta,
             fill = Quintile),
         reverse = TRUE) +
  geom_col(position = "dodge") + 
  ggtitle("Average individual impact") +
  scale_y_continuous(labels = grattan_dollar) + 
  guides(fill = guide_legend(reverse = FALSE)) +
  theme(axis.line.x = element_line(size = 0.5),
        legend.position = "right")
```

![plot of chunk avg_individual_impact_by_Quintile_fy](./Budget2018-atlas/avg_individual_impact_by_Quintile_fy-1.svg)


```r
avg_individual_impact_by_Quintile_fy <- 
  lapply(Budget_1922_Grattan2.75, function(x) {
    x[["Budget2018"]] %>%
      setkey(Taxable_Income) %>%
      .[, Quintile := factor(ceiling(5 * .I / .N),
                             levels = 1:5)] %>%
      .[, .(avg_delta = mean(delta),
            max_income = max(Taxable_Income),
            min_income = min(Taxable_Income),
            avg_income = mean(Taxable_Income + 0)),
        keyby = .(Quintile)]
  }) %>%
  rbindlist(idcol = "fy_year") %>% 
  setkey(fy_year, Quintile) %>%
  .[, "Financial year ending" := fy2yr(fy_year)] %>%
  .[, avg_delta := round(avg_delta, 2)] %T>%
  fwrite("avg_individual_impact_by_Quintile_fy-2p75.csv") %>%
  .[] 

avg_individual_impact_by_Quintile_fy %>%
  grplot(aes(x = `Financial year ending`,
             y = avg_delta,
             fill = Quintile),
         reverse = TRUE) +
  geom_col(position = "dodge") + 
  ggtitle("Average individual impact (2.75% wages)") +
  scale_y_continuous(labels = grattan_dollar) + 
  guides(fill = guide_legend(reverse = FALSE)) +
  theme(axis.line.x = element_line(size = 0.5),
        legend.position = "right")
```

![plot of chunk unnamed-chunk-10](./Budget2018-atlas/unnamed-chunk-10-1.svg)



```r
Brackets <- 
  data.table(Breaks = c(0, 37e3, 41e3, 87e3, 90e3, 120e3, 180e3, 200e3)) %>%
  .[, Taxable_Income := as.integer(Breaks)] %>%
  setkey(Taxable_Income)

avg_individual_impact_by_Bracket_fy <- 
  lapply(Budget_1922, function(x) {
    x[["Budget2018"]] %>%
      setkey(Taxable_Income) %>%
      Brackets[., roll=TRUE] %>%
      .[, .(avg_delta = mean(delta),
            max_income = max(Taxable_Income),
            avg_income = mean(Taxable_Income + 0)),
        keyby = .(Breaks)]
  }) %>%
  rbindlist(idcol = "fy_year") %>% 
  setkey(fy_year, Breaks) %>%
  .[, "Financial year ending" := fy2yr(fy_year)] 

avg_individual_impact_by_Bracket_fy %>%
  .[, avg_delta := round(avg_delta, 2)] %>%
  .[] %>%
  .[, "Income bracket" := factor(Breaks,
                                 levels = unique(Breaks),
                                 labels = grattan_dollar(unique(Breaks)),
                                 ordered = TRUE)] %>%
  grplot(aes(x = `Financial year ending`, y = avg_delta, fill = `Income bracket`),
         reverse = TRUE) +
  geom_col() + 
  ggtitle("Average individual impact") +
  scale_y_continuous(labels = grattan_dollar) + 
  guides(fill = guide_legend(reverse = TRUE)) +
  theme(legend.position = "right")
#> I'm going off-piste: The Palette Of Nine is thine. May John have mercy on your soul.
```

![plot of chunk unnamed-chunk-11](./Budget2018-atlas/unnamed-chunk-11-1.svg)

```r

lapply(Budget_1922, function(x) {
  x[["Budget2018"]] %>%
    setkey(Taxable_Income) %>%
    Brackets[., roll=TRUE] %>%
    .[, .(avg_delta = sum(delta * WEIGHT / 1e9),
          max_income = max(Taxable_Income),
          avg_income = mean(Taxable_Income + 0)),
      keyby = .(Breaks)]
}) %>%
  rbindlist(idcol = "fy_year") %>% 
  .[, "Financial year ending" := fy2yr(fy_year)] %>%
  .[, avg_delta := round(avg_delta, 2)] %>%
  .[order(-Breaks)] %>%
  .[, "Incomes above" := factor(Breaks,
                                levels = unique(Breaks),
                                labels = grattan_dollar(unique(Breaks)),
                                ordered = TRUE)] %>%
  grplot(aes(x = `Financial year ending`, y = avg_delta, fill = `Incomes above`)) +
  geom_col() + 
  ggtitle("Total revenue") +
  scale_y_continuous(labels = grattan_dollar) + 
  guides(fill = guide_legend(reverse = TRUE)) +
  theme(legend.position = "right")
#> I'm going off-piste: The Palette Of Nine is thine. May John have mercy on your soul.
```

![plot of chunk unnamed-chunk-11](./Budget2018-atlas/unnamed-chunk-11-2.svg)


```r
cost_by_policy <-
  sapply(Budget_1922, sapply, revenue_foregone, USE.NAMES = TRUE) %>% 
  rowSums %>%
  divide_by(1e9)
```


```r
cost_in_202728 <- revenue_foregone(Budget_1922[["2027-28"]][["Budget2018"]], FALSE, digits = 0)
cost_in_202728_top20 <- 
  Budget_1922[["2027-28"]][["Budget2018"]][ntile(Taxable_Income, 100) >= 80] %>%
  revenue_foregone(revenue_positive = FALSE, digits = 0)
```


```r
minIncome_by_decile <- 
  s1718[, .(minIncome = min(Taxable_Income)), keyby = .(Decile = ntile(Taxable_Income, 10))] %>%
  .[, minIncome := as.integer(round(minIncome, -3))] %>%
  .[]
```


```r
avg_tax_rates_by_percentile_facet_fy <- 
{
  rbindlist(
    list(
      "Budget2018" = {
        lapply(Budget_1922, function(x) {
          x[["Budget2018"]] %>%
            setkey(Taxable_Income) %>%
            .[, .(avg_tax_rate = mean(coalesce(new_tax / Taxable_Income, 0)),
                  avg_tax_bill = mean(new_tax),
                  total_tax = sum(new_tax * WEIGHT / 1e9),
                  min_income = min(Taxable_Income),
                  max_income = max(Taxable_Income),
                  avg_income = mean(Taxable_Income + 0)),
              keyby = .(Taxable_Income_percentile = weighted_ntile(Taxable_Income, n = 100))] %>%
            .[, facet := "Budget 2018"]
        }) %>% 
          rbindlist(idcol = "fy_year",
                    use.names = TRUE)
      },
      "Grattan 20%" = {
        lapply(Budget_1922_Grattan20, function(x) {
          x[["Budget2018"]] %>%
            setkey(Taxable_Income) %>%
            .[, .(avg_tax_rate = mean(coalesce(new_tax / Taxable_Income, 0)),
                  avg_tax_bill = mean(new_tax),
                  total_tax = sum(new_tax * WEIGHT / 1e9),
                  min_income = min(Taxable_Income),
                  max_income = max(Taxable_Income),
                  avg_income = mean(Taxable_Income + 0)),
              keyby = .(Taxable_Income_percentile = weighted_ntile(Taxable_Income, n = 100))] %>%
            .[, facet := "Budget 2018 (20% wage forecast)"]
        }) %>% 
          rbindlist(idcol = "fy_year",
                    use.names = TRUE)
      },
      "Grattan 80%" = {
        lapply(Budget_1922_Grattan80, function(x) {
          x[["Budget2018"]] %>%
            setkey(Taxable_Income) %>%
            .[, .(avg_tax_rate = mean(coalesce(new_tax / Taxable_Income, 0)),
                  avg_tax_bill = mean(new_tax),
                  total_tax = sum(new_tax * WEIGHT / 1e9),
                  min_income = min(Taxable_Income),
                  max_income = max(Taxable_Income),
                  avg_income = mean(Taxable_Income + 0)),
              keyby = .(Taxable_Income_percentile = weighted_ntile(Taxable_Income, n = 100))] %>%
            .[, facet := "Budget 2018 (80% wage forecast)"]
        }) %>% 
          rbindlist(idcol = "fy_year",
                    use.names = TRUE)
      },
      
      "Baseline" = {
        lapply(Budget_1922, function(x) {
          x[["Budget2018_baseline"]] %>%
            setkey(Taxable_Income) %>%
            .[, .(avg_tax_rate = mean(coalesce(new_tax / Taxable_Income, 0)),
                  avg_tax_bill = mean(new_tax),
                  total_tax = sum(new_tax * WEIGHT / 1e9),
                  min_income = min(Taxable_Income),
                  max_income = max(Taxable_Income),
                  avg_income = mean(Taxable_Income + 0)),
              keyby = .(Taxable_Income_percentile = weighted_ntile(Taxable_Income, n = 100))] %>%
            .[, facet := "Baseline"]
        }) %>% 
          rbindlist(idcol = "fy_year",
                    use.names = TRUE)
      },
      "Current" = {
        sample_file_1516 %>%
          project(h = 2L, 
                  fy.year.of.sample.file = "2015-16") %>%
          model_income_tax("2017-18") %>%
          # .[, tax := income_tax(Taxable_Income, "2017-18", .dots.ATO = .)] %>%
          .[, .(avg_tax_rate = mean(coalesce(new_tax / Taxable_Income, 0)),
                avg_tax_bill = mean(new_tax),
                min_income = min(Taxable_Income),
                max_income = max(Taxable_Income),
                total_tax = sum(new_tax * WEIGHT / 1e9),
                avg_income = mean(Taxable_Income + 0)), 
            keyby = .(Taxable_Income_percentile = weighted_ntile(Taxable_Income, n = 100))] %>%
          .[, facet := "2017-18"] %>%
          .[, fy_year :=  "2017-18"]
      }),
      use.names = TRUE, fill = TRUE, 
    idcol = "id")
  } %>% 
  .[, "Financial year ending" := fy2yr(fy_year)] %>%
  setkey(id, fy_year, Taxable_Income_percentile) %>%
  .[, avg_tax_rate := round(avg_tax_rate, 3)] %>%
  .[, total_tax := round(total_tax, 3)] %>%
  setnames("total_tax", "total_tax_bn") %T>%
  fwrite(file = "avg_tax_rates-by-facet-percentile.csv") %>%
  .[]
```


```r
avg_tax_rates_by_percentile_facet_fy %>%
  .[facet %in% c("Baseline", "Budget 2018", "2017-18")] %>%
  .[fy_year %in% range(fy_year)] %T>%
  {
    dot <- .
    dot[, .(facet, fy_year, Taxable_Income_percentile, avg_tax_rate)] %>%
      dcast.data.table(Taxable_Income_percentile ~ facet + fy_year,
                       value.var = "avg_tax_rate") %>%
      melt.data.table(id.vars = c("Taxable_Income_percentile", "2017-18_2017-18")) %>%
      setnames("2017-18_2017-18", "T201718") %>%
      .[, delta := value - T201718] %>%
      fwrite("change-in-tax-rate-vs-201718-by-percentile.csv")
  } %>%
  .[, Decile := ntile(Taxable_Income_percentile, n = 10), by = "facet"] %T>%
  {
    dot <- .
    dot %>%
      .[, .(total_tax_bn = sum(total_tax_bn)), keyby = .(facet, Decile)] %>%
      .[, "% tax paid" := 100 * total_tax_bn / sum(total_tax_bn), keyby = "facet"] %>%
      .[, lapply(.SD, signif, 3), keyby = .(facet, Decile)] %>%
      fwrite("prop-tax-paid-by-facet-decile.csv")
  } %>%
  grplot(aes(x = Taxable_Income_percentile, y = avg_tax_rate, color = facet)) + 
  geom_line() + 
  xlab("Taxable income percentile") +
  scale_y_continuous(labels = percent) +
  theme(legend.position = c(0, 1),
        axis.line.x = element_line(size = 0.5),
        legend.title = element_blank(),
        legend.justification = c(0, 1))
```

![plot of chunk avg_tax_rates_by_percentile_Budget_202728_vs_201718](./Budget2018-atlas/avg_tax_rates_by_percentile_Budget_202728_vs_201718-1.svg)


```r
avg_tax_rates_by_percentile_facet_fy %>%
  .[facet %in% c("Baseline", "Budget 2018", "2017-18", 
                 "Budget 2018 (20% wage forecast)", 
                 "Budget 2018 (80% wage forecast)")] %>%
  .[fy_year %in% range(fy_year)] %>%
  .[avg_tax_rate > 0] %>%
  .[, labeli := which.max(avg_tax_rate > 0.15), keyby = "facet"] %>%
  .[, i := seq_len(.N), keyby = "facet"] %>%
  .[labeli == i, label := as.character(facet)] %>%
  .[, label_color := "black"] %>%
  .[facet == "2017-18", label_color := "white"] %>% 
  .[, facet := factor(facet, 
                      levels = c("Baseline",
                                 "Budget 2018",
                                 "Budget 2018 (80% wage forecast)", 
                                 "Budget 2018 (20% wage forecast)",
                                 "2017-18"), 
                      ordered = TRUE)
    ] %>%
  
  grplot(aes(x = Taxable_Income_percentile,
             y = avg_tax_rate,
             color = facet)) + 
  geom_line() + 
  # geom_label_repel(data = dot, 
  #                  aes(label = label,
  #                      fill = facet),
  #                  color = "black",
  #                  force = 2,
  #                  na.rm = TRUE) +
  xlab("Taxable income percentile") +
  scale_y_continuous(labels = percent, expand = c(0, 0)) +
  theme(legend.position = c(0.9, 0.1),
        axis.line.x = element_line(size = 0.5),
        legend.title = element_blank(),
        legend.justification = c(1, 0))
```

![plot of chunk avg_tax_rates_by_percentile_Budget_202728_vs_201718_with_PI](./Budget2018-atlas/avg_tax_rates_by_percentile_Budget_202728_vs_201718_with_PI-1.svg)


```r
decile2income <- function(d) {
  d <- as.integer(d)
  grattan_dollar(minIncome_by_decile[.(d)][["minIncome"]])
}
```


```r
texNumD <- function(x) texNum(x, dollar = TRUE)
```


New Grattan Institute analysis highlights that most of the revenue
reductions from the Turnbull Government's full Personal Income Tax Plan
are the result of lower taxes on high-income earners. Once the
three-stage plan -- including removing the 37c bracket -- is complete,
**\$15.5~billion** of the annual **\$21.5~billion cost** of the plan will
result from collecting less tax from the top 20% of income earners, who
currently have a taxable income of $68,000 or more.

The PIT plan will do little to unwind bracket creep's gradual reduction
of the progressivity of the tax system. Even with the PIT plan, average
tax rates are forecast to be higher for all taxpayers in 2027-28 --
except for very high-income earners who are effectively shielded from
bracket creep by the plan. A taxpayer who earns 
$117,000 
today (more
than 90% of other taxpayers) will pay an average tax rate of 
28.9% in
2027-28, unchanged from today. In contrast, average tax rates for
middle-income earners will continue to rise. The average tax rate for a
taxpayer who earns $27,000-a-year today (more than 30% of other
taxpayers) will increase 6 percentage points (from 
9.2%
to
14.7%
). As a
result, the highest-income taxpayers will bear a lower share of the
total tax burden.

**Costing and distributional analysis of PIT plan **

The 2018-19 budget shows the annual cost of the PIT Plan until 2022. The
Treasurer has indicated the ten-year cost of the plan is \$140 billion.
Grattan's analysis shows the annual costs of the plan until 2028. The
Grattan costing takes into account all elements of the PIT plan.

Most of the revenue reductions until 2021-22 are a result of the Low and
Middle Income Tax Offset ("the Lamington"). But once the plan is fully
implemented in 2024-25, there are much bigger revenue reductions because
the top of the 32.5 cent bracket increases first to \$120,000 and then
to \$200,000 (removing the 37c bracket). In 2028, these bracket changes
account for \(-\)\$21.1~billion
of the \(-\)\$21.5~billion in lower revenue.



Once fully implemented, most of the reduction in revenue under the PIT
is retained by the top 20% of income earners, with a taxable income of
\$87,000 or more. In 2028, the reduction in tax collected from this
group will account for **\$15 billion** of the \$25 billion cost of the
plan.



```r
# Quintile and financial year to tax cut
Qfy2Cut <- function(Quintile, fy) {
  q <- factor(as.integer(Quintile), levels = 1:5)
  ans <- -1*avg_individual_impact_by_Quintile_fy[.(fy, q)][["avg_delta"]]
  grattan_dollar(round(ans, -2))
}
```


By 2024-25, the income tax cuts are much larger for high-income earners,
both in absolute terms and as a proportion of income. Those in the top
20 per cent will get an average tax cut of $4,300 a year, compared to
$400 a year for someone in the second income quintile ($9,000 -
$19,000).



**Impact of the PIT plan on tax system progressivity**

Australia's progressive tax system ensures that people with higher
incomes pay higher average rates of personal income tax. Without changes
to tax scales, bracket creep gradually increases average tax rates for
all taxpayers. Middle-income earners are affected most in terms of
higher average tax rates.

The government claims the PIT plan protects middle-income Australians
from bracket creep. Certainly the plan reduces average tax rates in
2027-28 for all taxpayers compared to what they would be if there were
no changes to rates or brackets over that period.

But middle-income earners are not spared from bracket creep under the
PIT plan. The average tax rate for a taxpayer at the 50^th^ percentile
will still increase by 
5
percentage points
(from 
14.6%
to 
19.1%
)
compared to
2017-18. Without further changes, average tax rates will be higher for
most taxpayers.

The exception is the top 10% of income earners. Average tax rates for
those on the highest incomes are virtually unchanged under this plan.



Once fully implemented, the PIT plan doesn't change the progressivity of
the tax system much. Overall, those on high incomes will pay a similar
proportion of total tax revenues with or without the plan. But because
of bracket creep, high income earners will be paying a lower proportion
than today.

**Table 1: Share of personal income tax paid falls for highest income
earners under PIT plan **

Share of total personal income tax paid by income decile (%)


```r
to_prop <- function(x) {
  if (is.double(x)) {
    grattan_percent(x / sum(x), .percent.suffix = "%", digits = 1)
  } else {
    x
  }
}
```


```r
avg_tax_rates_by_percentile_facet_fy %>%
  .[, .(tot_tax = sum(total_tax_bn)),
    keyby = .(id, fy_year, Decile = ntile(Taxable_Income_percentile, 10))] %>%
  .[fy_year %in% c("2017-18", "2027-28")] %>%
  dcast.data.table(Decile ~ id + fy_year, value.var = "tot_tax") %>%
  .[, lapply(.SD, to_prop)] %T>%
  fwrite("share-total-personal-income-tax-per-decile.csv") %>%
  kable(align = "rrrr")
```



| Decile| Baseline_2027-28| Budget2018_2027-28| Current_2017-18| Grattan 20%_2027-28| Grattan 80%_2027-28|
|------:|----------------:|------------------:|---------------:|-------------------:|-------------------:|
|      1|            0.00%|              0.00%|            0.0%|                0.0%|               0.00%|
|      2|            0.04%|              0.02%|            0.0%|                0.0%|               0.01%|
|      3|            0.84%|              0.81%|            0.4%|                0.4%|               0.71%|
|      4|            2.33%|              2.26%|            1.6%|                1.7%|               2.10%|
|      5|            4.29%|              4.30%|            3.4%|                3.5%|               4.13%|
|      6|            6.25%|              6.38%|            5.8%|                5.8%|               6.26%|
|      7|            8.67%|              8.92%|            8.5%|                8.6%|               8.86%|
|      8|           12.20%|             12.33%|           12.1%|               12.1%|              12.30%|
|      9|           17.88%|             17.65%|           17.8%|               17.6%|              17.67%|
|     10|           47.49%|             47.33%|           50.4%|               50.2%|              47.97%|
  


```r
scale01 <- function(x) {
  (x - min(x)) / (max(x) - min(x))
}
scale10 <- function(x) {
  1 - scale01(x)
}
```


```r
Grey <- function(fy) {
  Alpha <- 0.5 * scale10(fy2yr(fy))
  out <- grey(rep_len(1, length(fy)))
  for (i in seq_along(fy)) {
    out[i] <- grey(0.7, alpha = Alpha[i])
  }
  out
}
```


```r
sample_files_all %>%
  .[, Over65 := coalesce(age_range <= 1L, Birth_year <= 1L)] %>%
  .[, .(avg_tax_rate = mean(avg_tax_rate)), keyby = .(fy.year, Taxable_Income_percentile)] %>%
  setnames("fy.year", "fy_year") %>%
  rbind(avg_tax_rates_by_percentile_facet_fy[, .SD, .SDcols = c("id", names(.))],
        use.names = TRUE,
        fill = TRUE) %>%
  setkey(fy_year, Taxable_Income_percentile) %>%
  .[, z := fy_year %ein% "2017-18"] %>%
  .[, avg_tax_rate_rel := avg_tax_rate - median(avg_tax_rate[z]),
    keyby = .(Taxable_Income_percentile)] %>%

  .[, colour := if_else(is.na(id),
                        grey(0.5), 
                        if_else(id == "Baseline" & fy_year %in% c("2018-19", "2027-28"), 
                                if_else(fy_year == "2018-19", 
                                        gpal(6)[4],
                                        gpal(6)[5]),
                                if_else(fy_year == "2018-19", 
                                        gpal(6)[1],
                                        gpal(6)[2])))] %>%
  .[, alpha := if_else(is.na(id), 1.05 * scale01(fy2yr(fy_year)), 1)] %>%
  .[fy_year %in% c("2004-05", "2013-14"), c("alpha", "colour") := list(0.8, "black")] %>%
  .[implies(!is.na(id), fy_year %in% c("2018-19", "2027-28"))] %>%
  .[, size := 0.8] %>%
  .[fy_year %in% c("2004-05", "2013-14"), size := 1.1] %>%
  .[fy_year %in% c("2018-19", "2027-28"), size := 1.4] %>%
  .[Taxable_Income_percentile == 50L & !is.na(id), label := paste0(id, "\n", as.character(fy_year))] %>% 
  # .[Taxable_Income_percentile == 95L & !is.na(id), label := ""] %>%
  .[] %>%
  .[, group := paste0(fy_year, colour)] %>%
  .[, text := paste0(fy_year, " ", coalesce(id, ""), "\n",
                     formatC("Percentile: ", width = 24), Taxable_Income_percentile, "\n",
                     formatC("Avg. tax rate (03-04 = 0):", width = 24), " ", 100 * round(avg_tax_rate_rel, 4))] %>%
  .[] %>%
  setnames("Taxable_Income_percentile", 
           "Taxable income percentile") %T>%
  fwrite("Average-tax-rates-relative-201718-vs-Taxable-income-percentile-by-FY.csv") %>%
  as.data.frame %>%
  # .[Over65==FALSE] %>%
  grplot(aes(x = `Taxable income percentile`,
             y = avg_tax_rate_rel,
             colour = colour,
             group = group,
             text = text)) +
  annotate("label",
           x = 20,
           y = 0.09, 
           hjust = 1,
           label.size = NA,
           label = "2003-04",
           fontface = "bold") +
  annotate("label",
           x = 25,
           y = -0.04,
           hjust = 1,
           label.size = NA,
           label = "2013-14",
           fontface = "bold") +
  scale_color_identity() +
  scale_size_identity() +
  scale_alpha_identity() +
  geom_line(aes(alpha = alpha, size = size)) +
  # geom_blank(aes(x = 105, y = 0)) +
  geom_label_repel(aes(label = label),
                   nudge_x = 2, force = 0.8,
                   na.rm = TRUE,
                   fontface = "bold",
                   label.size = NA) +
  scale_y_continuous(labels = percent) +
  ggtitle("Average tax rates relative to 2017-18") +
  theme(legend.position = "right")
#> Scale for 'colour' is already present. Adding another scale for 'colour', which will replace the
#> existing scale.
```

![plot of chunk unnamed-chunk-22](./Budget2018-atlas/unnamed-chunk-22-1.svg)


```r
sample_files_all %>%
  .[, .(avg_tax_rate = mean(avg_tax_rate)), keyby = .(fy.year, Taxable_Income_percentile)] %>%
  setnames("fy.year", "fy_year") %>%
  rbind(avg_tax_rates_by_percentile_facet_fy[, .SD, .SDcols = c("id", names(.))],
        use.names = TRUE,
        fill = TRUE) %>%
  setkey(fy_year, Taxable_Income_percentile) %>%
  .[, avg_tax_rate_rel := avg_tax_rate - first(avg_tax_rate),
    keyby = .(Taxable_Income_percentile)] %>%
  .[, colour := if_else(is.na(id),
                        grey(0.5), 
                        if_else(id == "Baseline" & fy_year %in% c("2018-19", "2027-28"), 
                                if_else(fy_year == "2018-19", 
                                        gpal(6)[4],
                                        gpal(6)[5]),
                                if_else(fy_year == "2018-19", 
                                        gpal(6)[1],
                                        gpal(6)[2])))] %>%
  .[, alpha := if_else(is.na(id), 1.05 * scale01(fy2yr(fy_year)), 1)] %>%
  # .[fy_year %in% c("2013-14"), c("alpha", "colour") := list(0.8, "black")] %>%
  .[implies(!is.na(id), fy_year %in% c("2017-18", "2018-19", "2027-28"))] %>%
  .[, size := 0.8] %>%
  .[fy_year %in% c("2004-05", "2013-14"), size := 1.1] %>%
  .[fy_year %in% c("2018-19", "2027-28"), size := 1.4] %>%
  .[Taxable_Income_percentile == 50L & !is.na(id), label := paste0(id, "\n", as.character(fy_year))] %>% 
  # .[Taxable_Income_percentile == 95L & !is.na(id), label := ""] %>%
  .[] %>%
  .[, group := paste0(fy_year, colour)] %>%
  .[, text := paste0(fy_year, " ", coalesce(id, ""), "\n",
                     formatC("Percentile: ", width = 24), Taxable_Income_percentile, "\n",
                     formatC("Avg. tax rate (03-04 = 0):", width = 24), " ", 100 * round(avg_tax_rate_rel, 4))] %>%
  .[] %>%
  setnames("Taxable_Income_percentile", 
           "Taxable income percentile") %T>%
  fwrite("Average-tax-rates-relative-200304-vs-Taxable-income-percentile-by-FY.csv") %>%
  as.data.frame %>%
  # .[Over65==FALSE] %>%
  grplot(aes(x = `Taxable income percentile`,
             y = avg_tax_rate_rel,
             colour = colour,
             group = group,
             text = text)) +
  scale_color_identity() +
  scale_size_identity() +
  scale_alpha_identity() +
  geom_line(aes(alpha = 1, size = size)) +
  # geom_blank(aes(x = 105, y = 0)) +
  geom_label_repel(aes(label = label),
                   nudge_x = 2, force = 0.8,
                   na.rm = TRUE,
                   fontface = "bold",
                   label.size = NA) +
  scale_y_continuous(labels = percent) +
  ggtitle("Average tax rates relative to 2003-04") +
  theme(legend.position = "right") + 
  facet_wrap(~fy_year)
#> Scale for 'colour' is already present. Adding another scale for 'colour', which will replace the
#> existing scale.
```

![plot of chunk avg_tax_rate_by_percentile_fy_year_rel0304](./Budget2018-atlas/avg_tax_rate_by_percentile_fy_year_rel0304-1.svg)


```r
bound_models <- 
  Budget_1922 %>% 
  lapply(rbindlist, use.names = TRUE, fill = TRUE, idcol = "id") %>%
  rbindlist(use.names = TRUE, fill = TRUE, idcol = "fy_year")
```


```r
bound_models_Grattan <- 
  Budget_1922_Grattan %>% 
  lapply(rbindlist, use.names = TRUE, fill = TRUE, idcol = "id") %>%
  rbindlist(use.names = TRUE, fill = TRUE, idcol = "fy_year")
```


```r
bound_models_Grattan20 <- 
  Budget_1922_Grattan20 %>% 
  lapply(rbindlist, use.names = TRUE, fill = TRUE, idcol = "id") %>%
  rbindlist(use.names = TRUE, fill = TRUE, idcol = "fy_year")
```


```r
bound_models_Grattan80 <- 
  Budget_1922_Grattan80 %>% 
  lapply(rbindlist, use.names = TRUE, fill = TRUE, idcol = "id") %>%
  rbindlist(use.names = TRUE, fill = TRUE, idcol = "fy_year")
```


```r
bound_models_wage2.75 <- 
  Budget_1922_Grattan2.75 %>% 
  lapply(rbindlist, use.names = TRUE, fill = TRUE, idcol = "id") %>%
  rbindlist(use.names = TRUE, fill = TRUE, idcol = "fy_year")
```


```r
bound_models %>%
  .[id == "ALP2018"] %>%
  .[, tax_saving := baseline_tax - new_tax] %>%
  .[Taxable_Income <= 300e3] %>%
  .[fy_year %ein% "2019-20"] %>%
  .[age_range > 1] %>%
  .[, .(tax_saving = mean(tax_saving)),
    keyby = .(fy_year, Taxable_Income = round(Taxable_Income, -3))] %T>%
  fwrite("ALP-proposal-201920-vs-taxable-income.csv") %>%
  grplot(aes(x = Taxable_Income, y = tax_saving, color = fy_year)) + 
  geom_line() +
  scale_x_continuous("Taxable income", labels = grattan_dollar, limits = c(0, 225e3)) 
#> Warning: Removed 75 rows containing missing values (geom_path).
```

![plot of chunk unnamed-chunk-23](./Budget2018-atlas/unnamed-chunk-23-1.svg)





```r
list(
  {
    sample_files_all %>%
      .[, .(new_tax = tax), keyby = .(fy_year = fy.year, Taxable_Income)] %>%
      .[, id := "Current"] %>%
      .[]
  },
  bound_models[, .(id, fy_year, Taxable_Income, new_tax)],
  s1718[, .(id = "Current", fy_year = "2017-18", Taxable_Income, new_tax)],
  s1617[, .(id = "Current", fy_year = "2016-17", Taxable_Income, new_tax)]
) %>%
  rbindlist(use.names = TRUE,
            fill = TRUE)  %>%
  .[, .(progressivity = progressivity(Taxable_Income, new_tax)), keyby = c("id", "fy_year")] %>%
  .[id %chin% c("Budget2018", "Current", "Budget2018_baseline", "ALP2018")] %>%
  .[, Year := fy2yr(fy_year)] %>%
  .[id == "Budget2018_baseline", id := "Baseline"] %>%
  .[, progressivity := round(progressivity, 4)] %>%
  .[] %T>%
  fwrite("Reynolds-Smolensky-vs-year.csv") %>%
  grplot(aes(x = Year, y = progressivity, color = id, group = id)) + 
  scale_x_continuous(breaks = c(2005, 2010, 2015, 2020, 2025)) +
  geom_line() + 
  theme(legend.position = "right",
        legend.title = element_blank())
```

![plot of chunk progressivities](./Budget2018-atlas/progressivities-1.svg)


```r
progressivity_80 <- 
  bound_models_Grattan80 %>%
  .[id == "Budget2018"] %>%
  .[, .(progressivity = progressivity(Taxable_Income, new_tax)), keyby = c("fy_year")] %>%
  .[]
```


```r
progressivity_20 <- 
  bound_models_Grattan20 %>%
  .[id == "Budget2018"] %>%
  .[, .(progressivity = progressivity(Taxable_Income, new_tax)), keyby = c("fy_year")] %>%
  .[]
```


```r
progressivity2.75 <- 
  bound_models_wage2.75 %>%
  .[id == "Budget2018"] %>%
  .[, .(progressivity = progressivity(Taxable_Income, new_tax)), keyby = c("fy_year")] %>%
  .[, id := "Wages @ 2.75%"] %>%
  .[]
```


```r
rbindlist(list(progressivity2.75,
               fread("Reynolds-Smolensky-vs-year.csv")), 
          use.names = TRUE,
          fill = TRUE) %>%
  .[id %in% c("Current", "Baseline"), id := "Current/Baseline"] %>%
  setorder(-fy_year, -progressivity) %>%
  .[, id := factor(id, levels = unique(id), ordered = TRUE)] %>%
  .[, Year := coalesce(Year, as.integer(fy2yr(fy_year))), keyby = "fy_year"] %>%
  grplot(aes(x = Year, y = progressivity,
             color = id, 
             group = id)) + 
  geom_line() + 
  theme(legend.position = "right",
        legend.title = element_blank())
```

![plot of chunk progressivity2-75-plot](./Budget2018-atlas/progressivity2-75-plot-1.svg)


```r
avg_tax_rates_by_percentile_facet_fy_historical <- 
  list(
  {
    sample_files_all %>%
      .[, .(new_tax = tax), keyby = .(fy_year = fy.year, Taxable_Income)] %>%
      .[, id := "Current"] %>%
      .[]
  },
  bound_models[, .(id, fy_year, Taxable_Income, new_tax)],
  s1718[, .(id = "Current", fy_year = "2017-18", Taxable_Income, new_tax)],
  s1617[, .(id = "Current", fy_year = "2016-17", Taxable_Income, new_tax)]
) %>%
  rbindlist(use.names = TRUE,
            fill = TRUE) %>%
  .[, Taxable_Income_percentile := ntile(Taxable_Income, 100),
    keyby = .(id, fy_year)] %>%
  .[, new_avg_tax_rate := coalesce(new_tax / Taxable_Income, 0)] %>%
  .[, .(new_avg_tax_rate = mean(new_avg_tax_rate)), 
    keyby = .(fy_year, id, Taxable_Income_percentile)] %>%
  .[] %>%
  .[implies(id %pin% "_", endsWith(id, "baseline"))] %>%
  .[id %pin% c("aseline", "urrent"), id := "Baseline/Current"] %>%
  .[order(fy_year)] %>%
  dcast(fy_year + id ~ Taxable_Income_percentile, value.var = "new_avg_tax_rate", FUN = identity) %T>%
  fwrite("avg-tax-rate-wide-by-model-fy_year.tsv", quote = TRUE, sep = "\t") %>%
  .[]
```


## Effect of SBTO

```r
library(fastmatch)
bound_models[id %ein% c("Budget2018", "ALP2018",
                        "Budget2018_no_SBTO", "ALP2018_no_SBTO",
                        "Budget2018_baseline", "Budget2018_baseline_no_SBTO")] %>%
  .[, .(revenue = sum(delta), WEIGHT = first(WEIGHT)), keyby = .(id, fy_year)] %>%
  .[, SBTO := if_else(endsWith(id, "no_SBTO"), "No SBTO", "With SBTO")] %>%
  .[, policy := sub("_no_SBTO", "", id)] %>%
  .[, revenue_bn := revenue * WEIGHT / 1e9] %>%
  .[, revenue := NULL] %>%
  .[, .(policy, fy_year, SBTO, revenue_bn)] %>%
  .[] %>%
  dcast(policy + fy_year ~ SBTO, value.var = "revenue_bn") %>%
  .[, delta := `With SBTO` - `No SBTO`] %>%
  ggplot(aes(x = fy_year, y = delta, fill = policy)) +
  geom_col(position = "dodge")
```

![plot of chunk unnamed-chunk-25](./Budget2018-atlas/unnamed-chunk-25-1.svg)


```r
bound_models[id %ein% c("Budget2018", "ALP2018",
                        "Budget2018_no_SBTO", "ALP2018_no_SBTO",
                        "Budget2018_baseline", "Budget2018_baseline_no_SBTO")] %>%
  .[,
    Taxable_Income_percentile := ntile(Taxable_Income + Total_PP_BE_amt + Total_NPP_BE_amt, 100),
    keyby = .(id, fy_year)] %>%
  .[, .(delta = sum(delta)), keyby = .(id, fy_year, Taxable_Income_percentile)] %>%
  .[, p := coalesce(delta / sum(delta), 0), keyby = .(id, fy_year)] %>%
  .[, delta := NULL] %>%
  .[] %>%
  .[, SBTO := tolower(endsWith(id, "_no_SBTO"))] %>%
  .[, policy := sub("_no_SBTO", "", .BY[[1L]], fixed = TRUE), by = "id"] %>%
  dcast(Taxable_Income_percentile + policy + fy_year ~ SBTO, value.var = "p") %>%
  .[, revi := true - false] %>%
  ggplot(aes(x = Taxable_Income_percentile, y = revi, color = fy_year)) + 
  facet_wrap(~policy) +
  geom_line() 
```

![plot of chunk unnamed-chunk-26](./Budget2018-atlas/unnamed-chunk-26-1.svg)


```r
s202728_in_1920 <- 
  model_income_tax(s1819,
                   "2017-18", 
                   ordinary_tax_rates = ordinary_tax_rates(10), 
                   ordinary_tax_thresholds = ordinary_tax_thresholds(10),
                   Budget2018_lamington = TRUE,
                   Budget2018_lito_202223 = TRUE)
alternative <- 
  model_income_tax(s1819, 
                   "2017-18", 
                   ordinary_tax_rates = c(0, 0.19, 0.325, 0.37, 0.45), 
                   ordinary_tax_thresholds = c(0, 18200, 37000, 90000, 180000))

r1 <- 0
while (r1 < 20 && revenue_foregone(alternative) > revenue_foregone(s202728_in_1920)) {
  print(revenue_foregone(alternative))
  r1 <- r1 + 1
  alternative <- 
    model_income_tax(s1819, 
                     "2017-18", 
                     ordinary_tax_rates = c(0, 0.19 - r1/200, 0.325 - r1/200, 0.37, 0.45), 
                     ordinary_tax_thresholds = c(0, 18200, 37000, 90000, 180000))
}
#> [1] "-\\$373 million"
#> [1] "-\\$2.7 billion"
#> [1] "-\\$4.9 billion"
#> [1] "-\\$7.2 billion"
#> [1] "-\\$9.5 billion"
#> [1] "-\\$12 billion"
#> [1] "-\\$14 billion"

alternative %>%
  .[, new_avg_tax_rate := coalesce(new_tax / Taxable_Income, 0)] %>%
  .[, old_avg_tax_rate := coalesce(baseline_tax / Taxable_Income, 0)] %>%
  .[, delta := new_tax - baseline_tax] %>%
  .[, .(old_avg_tax_rate = mean(old_avg_tax_rate),
        new_avg_tax_rate = mean(new_avg_tax_rate),
        avg_delta = mean(delta)),
    keyby = .(Taxable_Income_percentile = ntile(Taxable_Income, 100))] %>%
  melt(id.vars = c("Taxable_Income_percentile", "avg_delta")) %>%
  .[, variable := factor(variable, levels = unique(.$variable), ordered = TRUE)] %>%
  ggplot(aes(x = Taxable_Income_percentile, y = value, color = variable)) + 
  geom_line()
```

![plot of chunk unnamed-chunk-27](./Budget2018-atlas/unnamed-chunk-27-1.svg)

```r

baseline_share <- 
  bound_models[id == "Budget2018_baseline" & fy_year == "2027-28"] %>%
  .[, .(total_delta = sum(delta)), keyby = .(Taxable_Income_percentile = ntile(Taxable_Income, 10))] %>%
  .[, prop := total_delta / sum(total_delta)] 

govt_share <- 
  bound_models[id == "Budget2018" & fy_year == "2027-28"] %>%
  .[, .(total_delta = sum(delta)), keyby = .(Taxable_Income_percentile = ntile(Taxable_Income, 10))] %>%
  .[, prop := total_delta / sum(total_delta)] %>%
  fwrite("prop-share-tax-benefit-govt-by-decile.csv")

alternative_share <- 
  alternative %>%
  .[, .(total_delta = sum(delta)), keyby = .(Taxable_Income_percentile = ntile(Taxable_Income, 10))] %>%
  .[, prop := total_delta / sum(total_delta)] %>%
  fwrite("prop-share-tax-benefit-alternative-by-decile.csv")

alternative %>%
  .[, .(old_tot_tax_paid = sum(baseline_tax * WEIGHT), 
        new_tot_tax_paid = sum(new_tax * WEIGHT)), 
    keyby = .(Taxable_Income_decile = ntile(Taxable_Income, 10))] %>%
  .[] %>%
  melt.data.table(id.vars = key(.)) %>%
  ggplot(aes(x = Taxable_Income_decile, y = value, fill = variable)) + 
  geom_col(position = "dodge") + 
  scale_y_continuous(labels = function(x) paste0(grattan_dollar(x / 1e9), " bn"))
```

![plot of chunk unnamed-chunk-27](./Budget2018-atlas/unnamed-chunk-27-2.svg)


```r
bound_models %>%
  .[id == "Budget2018"] %>%
  .[, Quintile := ntile(Taxable_Income, 5), keyby = "fy_year"] %>%
  .[, .(total_delta_bn = sum((new_tax - baseline_tax) * WEIGHT / 1e9), 
        max_income = max(Taxable_Income),
        min_income = min(Taxable_Income), 
        avg_income = mean(Taxable_Income)), 
    keyby = c("fy_year", "Quintile")] %>%
  .[, "Financial year ending" := fy2yr(.BY[[1]]), keyby = c("fy_year", "Quintile")] %>%
  .[, total_delta_bn := round(total_delta_bn, 2), keyby = c("fy_year", "Quintile")] %>%
  .[, avg_income := round(avg_income, 2), keyby = c("fy_year", "Quintile")] %>%
  setorder(fy_year, -Quintile) %>%
  fwrite("budget2018-total-revenue-vs-fy-by-quintile.csv")
```


```r
print(revenue_foregone(Budget_1922[["2018-19"]][["Budget2018_baseline_brackets_cpi"]]))
#> [1] "-\\$2.3 billion"
```


```r
avg_tax_rate_by_percentile_brackets_cpi <-
  lapply(Budget_1922, function(x) {
    x[["Budget2018_baseline_brackets_cpi"]][, .(Taxable_Income, new_tax)]
    }) %>%
  rbindlist(use.names = TRUE, fill = TRUE, idcol = "fy_year") %>%
  .[, avg_tax_rate := coalesce(new_tax / Taxable_Income, 0)] %>%
  .[, .(avg_tax_rate = mean(avg_tax_rate)), 
    keyby = .(fy_year, Taxable_Income_percentile = ntile(Taxable_Income, 100))]
fwrite(avg_tax_rate_by_percentile_brackets_cpi,
       "avg_tax_rate_by_percentile_brackets_cpi.csv")
```


```r
total_population_1516 <- 
  aus_pop_qtr_age(date = as.Date("2016-01-01"),
                  age = 15:100,
                  tbl = TRUE) %$%
  sum(Value) %>%
  multiply_by(s1718[1][["WEIGHT"]] / 50)
```


```r
taxable_individuals_1718 <- s1718[, sum(WEIGHT)]
```


```r
avg_tax_by_decile_allpersons201718 <- 
  s1718[, .(new_tax, baseline_tax = as.double(baseline_tax), Taxable_Income, WEIGHT)] %>%
  rbind(data.table(new_tax = 0,
                   baseline_tax = 0,
                   Taxable_Income = 0L,
                   WEIGHT = total_population_1516 - taxable_individuals_1718), 
        use.names = TRUE,
        fill = TRUE) %>%
  .[, Taxable_Income_decile := weighted_ntile(Taxable_Income, WEIGHT, 10)] %>%
  .[, .(total = sum(new_tax)), keyby = "Taxable_Income_decile"] %>%
  .[, share := round(total / sum(total), 3)] %T>%
  fwrite("avg_tax_by_decile_allpersons201718.csv") %>%
  .[]

wt_rel1718v202425 <- 
  .project_useTreasurys[[2025-2016]][1][["WEIGHT"]] / s1718[1][["WEIGHT"]]

avg_tax_by_decile_allpersons202425 <- 
  Budget_1922[["2027-28"]][["Budget2018"]] %>%
  rbind(data.table(new_tax = 0,
                   baseline_tax = 0,
                   Taxable_Income = 0L,
                   WEIGHT = wt_rel1718v202425 * (total_population_1516 - taxable_individuals_1718)), 
        use.names = TRUE, fill = TRUE) %>%
  .[, Taxable_Income_decile := weighted_ntile(Taxable_Income, WEIGHT, 10)] %>%
  .[, .(total = sum(new_tax)), keyby = "Taxable_Income_decile"] %>%
  .[, share := round(total / sum(total), 3)] %T>%
  fwrite("avg_tax_by_decile_allpersons202425.csv") %>%
  .[]

wt_rel1718v202728 <- 
  .project_useTreasurys[[12]][1][["WEIGHT"]] / s1718[1][["WEIGHT"]]

avg_tax_by_decile_allpersons202728 <- 
  Budget_1922[["2027-28"]][["Budget2018"]] %>%
  rbind(data.table(new_tax = 0,
                   baseline_tax = 0,
                   Taxable_Income = 0L,
                   WEIGHT = wt_rel1718v202728 * (total_population_1516 - taxable_individuals_1718)), 
        use.names = TRUE, fill = TRUE) %>%
  .[, Taxable_Income_decile := weighted_ntile(Taxable_Income, WEIGHT, 10)] %>%
  .[, .(total = sum(new_tax)), keyby = "Taxable_Income_decile"] %>%
  .[, share := round(total / sum(total), 3)] %T>%
  fwrite("avg_tax_by_decile_allpersons202728.csv") %>%
  .[]

```



```r
decile201718 <- 
  s1718[, .(new_tax, baseline_tax = as.double(baseline_tax), Taxable_Income, WEIGHT)] %>%
  rbind(data.table(new_tax = 0,
                   baseline_tax = 0,
                   Taxable_Income = 0L,
                   WEIGHT = total_population_1516 - sum(sample_files_all[fy.year == "2015-16"][["WEIGHT"]])), 
        use.names = TRUE,
        fill = TRUE) %>%
  .[, Taxable_Income_decile := weighted_ntile(Taxable_Income, WEIGHT, 10)] %>%
  .[, .(Taxable_Income = min(Taxable_Income),
        tot = sum(baseline_tax * WEIGHT / 1e9)),
    keyby = .(Taxable_Income_decile)] %>%
  .[, min_Taxable_Income := round(Taxable_Income, -3)] %>%
  .[, prop := tot / sum(tot)] %>%
  setkey(Taxable_Income) %>%
  .[]
```


```r
Budget_1922[["2027-28"]][["Budget2018"]] %>%
  rbind(data.table(new_tax = 0,
                   baseline_tax = 0,
                   Taxable_Income = 0L,
                   WEIGHT = wt_rel1718v202728 * (total_population_1516 - taxable_individuals_1718)), 
        use.names = TRUE, fill = TRUE) %>%
  .[, .(new_tax, baseline_tax, Taxable_Income, WEIGHT)] %>%
  setkey(Taxable_Income) %>%
  decile201718[., roll = TRUE] %>%
  .[, .(tot = sum(new_tax)), keyby = .(Taxable_Income_decile, min_Taxable_Income)] %>%
  .[, prop := tot / sum(tot)] %>%
  .[]
#>    Taxable_Income_decile min_Taxable_Income        tot         prop
#> 1:                     1                  0          0 0.0000000000
#> 2:                     4                  0          0 0.0000000000
#> 3:                     5              11000     692756 0.0001179139
#> 4:                     6              24000   56360042 0.0095930310
#> 5:                     7              37000  167886456 0.0285759187
#> 6:                     8              50000  438633631 0.0746597389
#> 7:                     9              68000  854864491 0.1455063068
#> 8:                    10              98000 4356665288 0.7415470907

Budget_1922[["2024-25"]][["Budget2018"]] %>%
  rbind(data.table(new_tax = 0,
                   baseline_tax = 0,
                   Taxable_Income = 0L,
                   WEIGHT = wt_rel1718v202728 * (total_population_1516 - taxable_individuals_1718)), 
        use.names = TRUE, fill = TRUE) %>%
  .[, .(new_tax, baseline_tax, Taxable_Income, WEIGHT)] %>%
  setkey(Taxable_Income) %>%
  decile201718[., roll = TRUE] %>%
  .[, .(tot = sum(new_tax * WEIGHT / 1e9)), keyby = .(Taxable_Income_decile, min_Taxable_Income)] %>%
  .[, prop := tot / sum(tot)] %>%
  .[]
#>    Taxable_Income_decile min_Taxable_Income          tot         prop
#> 1:                     1                  0   0.00000000 0.0000000000
#> 2:                     4                  0   0.00000000 0.0000000000
#> 3:                     5              11000   0.04636691 0.0001534935
#> 4:                     6              24000   3.65400226 0.0120962487
#> 5:                     7              37000  10.98884486 0.0363775910
#> 6:                     8              50000  26.13241133 0.0865090174
#> 7:                     9              68000  49.44407838 0.1636802125
#> 8:                    10              98000 211.81160689 0.7011834370
```


## JD 'How not to sell a tax cut'


```r
p_geq_120k_202728 <- 
  bound_models[fy_year == "2027-28" & id == "Budget2018"] %$%
  mean(Taxable_Income > 120e3)
stopifnot(round(p_geq_120k_202728, 1) == 0.2)
```

Of course, a tax cut of \$14 billion a year is a tricky sell when it benefits less than 2 in 10 of income earners in 2027-28. But the government has made its own life harder by using misleading statistics and not providing the numbers that could support its best argument.



```r
current_tax_paid_geq_180k <- 
  s1718 %>%
  .[, tax := income_tax(Taxable_Income, "2017-18", .dots.ATO = s1718)] %>%
  .[, .(Taxable_Income, tax)] %>%
  .[, .(tot = sum(tax)), keyby = .(Over180k = Taxable_Income > 180e3)] %>%
  .[, prop := tot / sum(tot)] %>%
  .[(Over180k)] %>%
  .[["prop"]] %>%
  grattan_percent(.percent.suffix = " per cent")

tax_paid_geq180k_Budget202728 <- 
  bound_models[fy_year == "2027-28" & id == "Budget2018"] %>%
  .[, .(Taxable_Income, tax = as.double(new_tax))] %>%
  .[, .(tot = sum(tax)), keyby = .(Over180k = Taxable_Income > 180e3)] %>%
  .[, prop := tot / sum(tot)] %>%
  .[(Over180k)] %>%
  .[["prop"]] %>%
  grattan_percent(.percent.suffix = " per cent")

prop_persons_geq180k_201718 <-
  s1718[, .(n = .N), keyby = .(Over180k = Taxable_Income > 180e3)] %>%
  .[, prop := n / sum(n)] %>%
  .[(Over180k)] %>%
  .[["prop"]]

prop_persons_geq180k_Budget202728 <- 
  bound_models[fy_year == "2027-28" & id == "Budget2018"] %>%
  .[, .(tot = sum(WEIGHT)), keyby = .(Over180k = Taxable_Income > 180e3)] %>%
  .[, prop := tot / sum(tot)] %>%
  .[(Over180k)] %>%
  .[["prop"]]

stopifnot(!exists("twice1"))
#> Error in eval(expr, envir, enclos): !exists("twice1") is not TRUE
twice1 <- 
  if (prop_persons_geq180k_Budget202728 / prop_persons_geq180k_201718 > 2) {
    "twice"
  } else {
    twice1
  }
```

Another tricky claim is that without change those earning over \$180,000 will go from paying 32 per cent to 43 per cent of income tax. But this is sleight of hand: twice as many people could be expected to be earning this income -- so of course they will collectively pay a greater share of income tax.


```r
prop_tax_earnt_by_quintile_201718 <- 
  s1718[,
        .(tax_earnt_bn = sum(Taxable_Income * WEIGHT / 1e9)),
        keyby = .(Quintile = ntile(Taxable_Income, 5))] %>%
  .[, prop := tax_earnt_bn / sum(tax_earnt_bn)] %>%
  .[]

prop_tax_paid_by_quintile_202728_baseline <- 
  Budget_1922[["2027-28"]][["Budget2018_baseline"]] %>%
  .[, .(tax_paid = sum(as.numeric(new_tax))), keyby = .(Quintile = ntile(Taxable_Income, 5))] %>%
  .[, prop := tax_paid / sum(tax_paid)] %>%
  .[]

prop_tax_paid_by_quintile_202728_Budget <- 
  Budget_1922[["2027-28"]][["Budget2018"]] %>%
  .[, .(tax_paid = sum(as.numeric(new_tax))), keyby = .(Quintile = ntile(Taxable_Income, 5))] %>%
  .[, prop := tax_paid / sum(tax_paid)] %>%
  .[]
```

The government's best and most honest argument is that the tax package as a whole won't materially change the progressivity of the income tax system. Without change, the top 20\% of income earners -- who earn 
51 per cent
per cent of taxable income -- will pay 65.4 per cent of income tax.
And under the package they will pay 65 per cent.



