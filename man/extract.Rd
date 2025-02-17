% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/extract.R
\name{extract}
\alias{extract}
\title{Extract a character column into multiple columns using regular
expression groups}
\usage{
extract(data, col, into, regex = "([[:alnum:]]+)", remove = TRUE,
  convert = FALSE, ...)
}
\arguments{
\item{data}{A data frame.}

\item{col}{Column name or position. This is passed to
\code{\link[tidyselect:vars_pull]{tidyselect::vars_pull()}}.

This argument is passed by expression and supports
\link[rlang:quasiquotation]{quasiquotation} (you can unquote column
names or column positions).}

\item{into}{Names of new variables to create as character vector.}

\item{regex}{a regular expression used to extract the desired values.
There should be one group (defined by \code{()}) for each element of \code{into}.}

\item{remove}{If \code{TRUE}, remove input column from output data frame.}

\item{convert}{If \code{TRUE}, will run \code{\link[=type.convert]{type.convert()}} with
\code{as.is = TRUE} on new columns. This is useful if the component
columns are integer, numeric or logical.}

\item{...}{Other arguments passed on to \code{\link[=regexec]{regexec()}} to control
how the regular expression is processed.}
}
\description{
Given a regular expression with capturing groups, \code{extract()} turns
each group into a new column. If the groups don't match, or the input
is NA, the output will be NA.
}
\examples{
library(dplyr)
df <- data.frame(x = c(NA, "a-b", "a-d", "b-c", "d-e"))
df \%>\% extract(x, "A")
df \%>\% extract(x, c("A", "B"), "([[:alnum:]]+)-([[:alnum:]]+)")

# If no match, NA:
df \%>\% extract(x, c("A", "B"), "([a-d]+)-([a-d]+)")
}
