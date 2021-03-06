% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/project_to.R
\name{project_to}
\alias{project_to}
\title{A function for simple projections of sample files}
\usage{
project_to(sample_file, to_fy, fy.year.of.sample.file = NULL, ...)
}
\arguments{
\item{sample_file}{A sample file, most likely the 2012-13 sample file. It is intended that to be the most recent.}

\item{to_fy}{A string like "1066-67" representing the financial year for which forecasts of the sample file are desired.}

\item{fy.year.of.sample.file}{The financial year of \code{sample_file}. See \code{\link{project}} for the default.}

\item{...}{Other arguments passed to \code{\link{project}}.}
}
\value{
A sample file of the same number of rows as \code{sample_file} with inflated values (including WEIGHT).
}
\description{
A function for simple projections of sample files
}
