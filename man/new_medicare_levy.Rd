% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/new_medicare_levy.R
\name{new_medicare_levy}
\alias{new_medicare_levy}
\title{New medicare levy}
\usage{
new_medicare_levy(parameter_table)
}
\arguments{
\item{parameter_table}{A \code{data.table} containing 
\describe{
\item{\code{switches}}{The value in a row specifying which different medicare function is to apply.}
\item{\code{lower_threshold}}{What is the lower medicare threshold, below which no medicare levy is applied, above which a tapering rate applies.}
\item{\code{taper}}{What is the taper above \code{lower_threshold}.}
\item{\code{rate}}{The medicare levy applicable above the medicare thresholds.}
\item{\code{lower_up_for_each_child}}{How much the lower threshold should increase with each \code{n_dependants}.}
\item{\code{lower_family_threshold}}{The threshold as applied to families (i.e. couples)}
}}
}
\value{
A function similar to \code{medicare_levy}.
}
\description{
Use a different way to calculate medicare levy.
}
