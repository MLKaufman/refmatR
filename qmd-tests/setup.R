# Run from qmd-tests. Existing lockfiles are restored rather than updated.
options(repos = c(CRAN = "https://cloud.r-project.org"))
if (!requireNamespace("renv", quietly = TRUE)) install.packages("renv")
renv::consent(provided = TRUE)
if (file.exists("renv.lock")) {
  renv::restore(prompt = FALSE)
} else {
  renv::init(bare = TRUE, restart = FALSE)
  renv::settings$snapshot.type("all")
  renv::settings$bioconductor.version("3.23")
  renv::install(c("Seurat", "knitr", "rmarkdown", "jsonlite", "httr2", "digest", "BiocManager"), prompt = FALSE)
  renv::install("bioc::clustifyr", prompt = FALSE)
}
# Rebuild the client from the neighboring local package source.
renv::install("..", prompt = FALSE)
renv::snapshot(prompt = FALSE)
