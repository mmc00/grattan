
# 1.5.3.0
### 2017-11-25
* Include the small business tax offset as a standalone function and within `income_tax`.
* (internal) Extend `prohibit_vector_recycling` to return the maximum permissible length of a list of vectors.
* New function `model_income_tax`. 

# 1.5.2.5
### 2017-11-16
* Update wage data to 2017-Q3
* Update labour force data to 2017-09
* (internal) The `lf_trend` internal data table used to report the labour force in thousands of persons, as the ABS does. This seemed a bit strange, so now `obsValue` uses integers (i.e. just the labour force). 
* Vignettes now install `taxstats` to a temporary directory if not already installed, rather than the user or system's library.

### 2017-10-27
* Update CPI data
* Fix wage data

# 1.5.2.3
### 2017-10-21
* Update labour-force data

# grattan 1.5.2.0
### 2017-10-19
* New internal C++ functions for `income_tax`, and related functions
* BTO function now uses tax scales from the *Income Tax Regulations*

# grattan 1.5.1.2
### 2017-10-15
* Optional argument `age` in `income_tax` now `NULL` rather than `42`.  
The default argument continues to result in SAPTO being not applied if `.dots.ATO`.
However, if `.dots.ATO` is supplied (and the age variable has not been removed from it),
the individuals' SAPTO eligibility is determined by the age variable in `.dots.ATO`, rather
than setting each individual's SAPTO to 0.

### 2017-08-30
* Update labour force data. Avoid segfault in separate package in unit test.
* Added a `NEWS.md` file to track changes to the package.

### 2017-08-16
* Update wage, CPI, labour force data

### 2017-07-02
* Update wage and labour force data
* Fix breaking build due to change in dplyr API





