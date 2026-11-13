refmat_download <- function(id, path, client = refmatdb(), overwrite = FALSE) {
  scalar_text(path, "path")
  if (file.exists(path) && !overwrite) stop("Destination exists; use overwrite = TRUE", call. = FALSE)
  if (!dir.exists(dirname(path))) stop("Destination directory does not exist", call. = FALSE)
  info <- refmat_info(id, client)
  tmp <- tempfile("refmat-", tmpdir = dirname(path))
  on.exit(unlink(tmp), add = TRUE)
  api_request(client, paste0("refmats/", valid_id(id), "/download"), dest = tmp)
  if (is.null(info$sha256) || !identical(tolower(info$sha256), digest::digest(file = tmp, algo = "sha256")))
    stop("Downloaded file failed SHA-256 verification; destination was not changed", call. = FALSE)
  if (!file.rename(tmp, path)) stop("Could not move verified download to destination", call. = FALSE)
  invisible(normalizePath(path))
}

refmat_read <- function(path, orientation = c("auto", "genes_by_celltypes", "celltypes_by_genes")) {
  scalar_text(path, "path")
  orientation <- match.arg(orientation)
  # gzfile transparently reads gzip and uncompressed files, regardless of suffix.
  con <- gzfile(path, open = "rt", encoding = "UTF-8")
  on.exit(close(con), add = TRUE)
  lines <- readLines(con, warn = FALSE)
  if (!length(lines)) stop("Empty reference file", call. = FALSE)
  lines[1] <- sub("^\ufeff", "", lines[1])
  while (length(lines) && startsWith(lines[1], "#")) lines <- lines[-1]
  if (length(lines) < 2) stop("Reference has no expression rows", call. = FALSE)
  sep <- if (grepl("\t", lines[1], fixed = TRUE)) "\t" else ","
  fields_con <- textConnection(lines)
  fields <- tryCatch(utils::count.fields(fields_con, sep = sep, quote = "\"",
    comment.char = "", blank.lines.skip = FALSE), finally = close(fields_con))
  widths <- fields[!is.na(fields)]
  if (!length(widths) || any(widths != widths[1]))
    stop("Inconsistent number of fields in reference rows", call. = FALSE)
  tab <- utils::read.table(text = paste(lines, collapse = "\n"), header = TRUE,
    sep = sep, quote = "\"", comment.char = "", check.names = FALSE,
    colClasses = "character", row.names = NULL, fill = FALSE, blank.lines.skip = FALSE)
  if (ncol(tab) < 2 || !nrow(tab)) stop("Expected identifiers and expression columns", call. = FALSE)
  normalize <- function(x) tolower(gsub("[[:space:]_-]+", " ", trimws(x)))
  if (orientation == "auto") orientation <- if (normalize(names(tab)[1]) %in%
    c("celltype", "cell type", "cell types")) "celltypes_by_genes" else "genes_by_celltypes"
  labels <- tab[[1]]
  values <- suppressWarnings(matrix(as.numeric(as.matrix(tab[-1])), nrow = nrow(tab),
                                    dimnames = list(labels, names(tab)[-1])))
  if (any(!is.finite(values))) stop("Expression values must be numeric and finite", call. = FALSE)
  if (orientation == "celltypes_by_genes") values <- t(values)
  rownames(values) <- trimws(rownames(values))
  if (any(!nzchar(rownames(values))) || anyDuplicated(rownames(values)))
    stop("Gene identifiers must be non-empty and unique", call. = FALSE)
  cells <- normalize(colnames(values))
  if (any(!nzchar(cells)) || anyDuplicated(cells))
    stop("Cell-type labels must be non-empty and unique after normalization", call. = FALSE)
  values
}

refmat_get <- function(id, client = refmatdb(), orientation = "auto") {
  tmp <- tempfile("refmat-")
  on.exit(unlink(tmp), add = TRUE)
  refmat_download(id, tmp, client)
  refmat_read(tmp, orientation)
}
