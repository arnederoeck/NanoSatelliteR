% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/NanoSatelliteR_functions.R
\name{load_squiggles}
\alias{load_squiggles}
\title{Loads raw squiggle data generated by Signal2chunk.R}
\usage{
load_squiggles(dir, df = NULL)
}
\arguments{
\item{dir}{Path denoted as a character vector of length 1.}

\item{df}{An optional data.frame generated by qual_reads() to selectively
load squiggles.}
}
\description{
load_squiggles() returns a list of raw Oxford Nanopore current squiggle
data as generated by Signal2chunk.R
}
\details{
This function requires a path to the results produced by Signal2chunk.R 
load_squiggles() will recursively search the directory and read all
.chunk files. Results are shown in a list separated by their respective
positive or negative DNA strand origin. Optionally a data.frame generated
by qual_reads() can be provided to load only reads passing QC.
}
\examples{
df <- load_summary("/storage/NanoSatellite_chunks/")
qc <- summary_qc(df)
df2 <- qual_reads(df,qc$center_cutoff)
squiggles <- load_squiggles("/storage/NanoSatellite_chunks/",df2)
}
