# Internal validation and request helpers.
scalar_text <- function(x, name, empty = FALSE) {
  if (!is.character(x) || length(x) != 1L || is.na(x) || (!empty && !nzchar(x)))
    stop(name, " must be a single string", call. = FALSE)
  x
}

refmatdb <- function(url = "https://refmatdb.seq-space.com",
                     token = Sys.getenv("REFMATDB_TOKEN", ""), timeout = 60) {
  scalar_text(url, "url"); scalar_text(token, "token", TRUE)
  if (!grepl("^https?://", url) || grepl("[?#@]", url))
    stop("Use an HTTP(S) server URL without credentials, query, or fragment", call. = FALSE)
  if (nzchar(token) && !grepl("^https://", url))
    stop("API tokens require HTTPS", call. = FALSE)
  if (!is.numeric(timeout) || length(timeout) != 1L || !is.finite(timeout) || timeout <= 0)
    stop("timeout must be positive", call. = FALSE)
  url <- sub("/+$", "", url)
  url <- sub("/api/v1$", "", url)
  structure(list(url = url, token = token, timeout = timeout), class = "refmatdb_client")
}

print.refmatdb_client <- function(x, ...) {
  cat("<refmatdb_client> ", x$url, "\nAuthentication: ",
      if (nzchar(x$token)) "personal token" else "public", "\n", sep = "")
  invisible(x)
}

api_request <- function(client, path, query = list(), dest = NULL) {
  if (!inherits(client, "refmatdb_client")) stop("client must come from refmatdb()", call. = FALSE)
  req <- httr2::request(paste0(client$url, "/api/v1/", path))
  req <- httr2::req_user_agent(req, "refmatR/0.1.0")
  req <- httr2::req_timeout(req, client$timeout)
  req <- httr2::req_options(req, followlocation = FALSE)
  if (nzchar(client$token)) req <- httr2::req_auth_bearer_token(req, client$token)
  query <- query[!vapply(query, is.null, logical(1))]
  req <- do.call(httr2::req_url_query, c(list(req), query))
  req <- httr2::req_error(req, is_error = function(resp) FALSE)
  resp <- tryCatch(httr2::req_perform(req, path = dest), error = function(e)
    stop("RefmatDB request failed. Check the server URL, connection, and timeout.", call. = FALSE))
  status <- httr2::resp_status(resp)
  if (status < 200 || status >= 300) {
    message <- switch(as.character(status),
      `401` = "Authentication failed; check your personal API token and account access.",
      `403` = "Access denied.",
      `404` = "Reference not found or not visible to this account.",
      `429` = "Too many requests; try again later.",
      "Check the request parameters and server availability.")
    stop(sprintf("RefmatDB HTTP %s: %s", status, message), call. = FALSE)
  }
  if (!is.null(dest)) return(invisible(dest))
  httr2::resp_body_json(resp, simplifyVector = FALSE)
}

valid_id <- function(id) {
  scalar_text(id, "id")
  if (!grepl("^[[:xdigit:]]{8}-[[:xdigit:]]{4}-[[:xdigit:]]{4}-[[:xdigit:]]{4}-[[:xdigit:]]{12}$", id))
    stop("id must be a RefmatDB UUID", call. = FALSE)
  id
}

rows_frame <- function(rows) {
  if (!length(rows)) return(data.frame())
  keys <- unique(unlist(lapply(rows, names)))
  columns <- lapply(keys, function(key) {
    values <- lapply(rows, function(row) if (is.null(row[[key]])) NA else row[[key]])
    if (all(lengths(values) == 1L) && all(vapply(values, is.atomic, logical(1))))
      return(unlist(values, use.names = FALSE))
    I(values)
  })
  names(columns) <- keys
  as.data.frame(columns, stringsAsFactors = FALSE, check.names = FALSE)
}

fetch_pages <- function(client, path, query, limit, offset, all) {
  for (value in list(limit, offset)) {
    if (!is.numeric(value) || length(value) != 1L || !is.finite(value) || value != floor(value))
      stop("limit and offset must be integers", call. = FALSE)
  }
  if (limit < 1 || limit > 200 || offset < 0) stop("Use limit 1..200 and offset >= 0", call. = FALSE)
  if (!is.logical(all) || length(all) != 1 || is.na(all)) stop("all must be TRUE or FALSE", call. = FALSE)
  rows <- list(); start <- offset
  repeat {
    page <- api_request(client, path, c(query, list(limit = limit, offset = offset)))
    if (!is.list(page$items) || !is.numeric(page$total)) stop("Unexpected search response", call. = FALSE)
    rows <- c(rows, page$items)
    offset <- offset + length(page$items)
    if (!all || !length(page$items) || offset >= page$total) break
  }
  result <- rows_frame(rows)
  attr(result, "total") <- page$total
  attr(result, "offset") <- start
  result
}

refmat_search <- function(client = refmatdb(), q = NULL, species = NULL,
                          tissue = NULL, condition = NULL, owner = NULL,
                          cell_type = NULL, sort = "created_at",
                          limit = 50, offset = 0, all = FALSE) {
  if (!is.null(cell_type)) {
    scalar_text(cell_type, "cell_type")
    if (any(!vapply(list(q, tissue, condition, owner), is.null, logical(1))) || sort != "created_at")
      stop("Cell-type lookup supports only species and pagination filters", call. = FALSE)
    return(fetch_pages(client, paste0("celltypes/", utils::URLencode(cell_type, reserved = TRUE),
                                      "/refmats"), list(species = species), limit, offset, all))
  }
  sort <- match.arg(sort, c("created_at", "name", "n_celltypes"))
  fetch_pages(client, "refmats", list(q = q, species = species, tissue = tissue,
              condition = condition, owner = owner, sort = sort), limit, offset, all)
}

refmat_celltypes <- function(client = refmatdb(), q = NULL, species = NULL,
                             tissue = NULL, condition = NULL,
                             limit = 50, offset = 0, all = FALSE) {
  fetch_pages(client, "celltypes/search", list(q = q, species = species,
              tissue = tissue, condition = condition), limit, offset, all)
}

refmat_info <- function(id, client = refmatdb()) {
  api_request(client, paste0("refmats/", valid_id(id)))
}
