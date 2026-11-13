library(refmatR)
expect_error <- function(expr, pattern) {
  error <- tryCatch({force(expr); NULL}, error = identity)
  stopifnot(inherits(error, "error"), grepl(pattern, conditionMessage(error)))
}
local({
  f <- tempfile(); on.exit(unlink(f))
  writeLines(c('# refmat-rs version: test', 'gene,"T cell","B cell"', '001,1,2', 'G2,3,4'), f)
  m <- refmat_read(f)
  stopifnot(identical(dim(m), c(2L, 2L)), identical(rownames(m), c('001', 'G2')),
            identical(colnames(m), c('T cell', 'B cell')), m[2, 2] == 4)
  con <- gzfile(f, 'wt'); writeLines(c('cell_type\t001\tG2', 'T cell\t1\t3', 'B cell\t2\t4'), con); close(con)
  stopifnot(identical(refmat_read(f), m))
  writeLines(c('\ufeffgene,T,B', 'G,NaN,2'), f)
  expect_error(refmat_read(f), 'numeric and finite')
  writeLines(c('gene,T,B', 'G,1,2', 'G,3,4'), f)
  expect_error(refmat_read(f), 'unique')
  writeLines(c('gene,T-cell,T_cell', 'G,1,2'), f)
  expect_error(refmat_read(f), 'unique')
  writeLines(c('gene,T,B', 'G,1,2,3'), f)
  expect_error(refmat_read(f), '.')
})
expect_error(refmatdb('http://example.org', token = 'secret'), 'HTTPS')
expect_error(refmat_info('../admin'), 'UUID')
stopifnot(!any(grepl('fake-secret', capture.output(print(refmatdb(token = 'fake-secret'))))))
# Copy functions into an isolated environment for deterministic offline transport tests.
e <- new.env(parent = asNamespace('refmatR'))
for (name in c('fetch_pages', 'refmat_search', 'refmat_info', 'refmat_download')) {
  fun <- get(name, asNamespace('refmatR')); environment(fun) <- e; e[[name]] <- fun
}
seen <- list()
e$api_request <- function(client, path, query = list(), dest = NULL) {
  seen[[length(seen) + 1L]] <<- list(path = path, query = query)
  if (query$offset == 0) list(items = list(list(id = 'one', name = 'A', source = NULL)), total = 2L)
  else list(items = list(list(id = 'two', name = 'B', source = 'paper')), total = 2L)
}
hits <- e$refmat_search(refmatdb(token = ''), q = 'T & B', limit = 1, all = TRUE)
stopifnot(nrow(hits) == 2, is.na(hits$source[1]), attr(hits, 'total') == 2,
          seen[[2]]$query$offset == 1, seen[[1]]$query$q == 'T & B')
e$refmat_search(refmatdb(token = ''), cell_type = 'T/NK cells', limit = 1)
stopifnot(tail(seen, 1)[[1]]$path == 'celltypes/T%2FNK%20cells/refmats')
expect_error(refmat_search(cell_type = 'T', q = 'ignored'), 'only species')
local({
  f <- tempfile(); on.exit(unlink(f))
  writeLines('preserve me', f)
  id <- '00000000-0000-0000-0000-000000000001'
  e$api_request <- function(client, path, query = list(), dest = NULL) {
    if (is.null(dest)) return(list(sha256 = paste(rep('0', 64), collapse = '')))
    writeLines('corrupt', dest)
  }
  expect_error(e$refmat_download(id, f, overwrite = TRUE), 'SHA-256')
  stopifnot(readLines(f) == 'preserve me')
  e$api_request <- function(client, path, query = list(), dest = NULL) {
    raw <- charToRaw('gene,T,B\nG,1,2\n')
    if (is.null(dest)) return(list(sha256 = digest::digest(raw, algo = 'sha256', serialize = FALSE)))
    writeBin(raw, dest)
  }
  e$refmat_download(id, f, overwrite = TRUE)
  stopifnot(refmat_read(f)[1, 2] == 2)
})
