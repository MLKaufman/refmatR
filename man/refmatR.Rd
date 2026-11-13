\name{refmatR}
\alias{refmatR}
\alias{refmatdb}
\alias{refmat_search}
\alias{refmat_celltypes}
\alias{refmat_info}
\alias{refmat_download}
\alias{refmat_read}
\alias{refmat_get}
\title{Search and retrieve RefmatDB reference matrices}
\description{Read-only access to public and authorized private RefmatDB references, with checksum-verified downloads and numeric matrix import.}
\usage{
refmatdb(url = "https://refmatdb.seq-space.com",
         token = Sys.getenv("REFMATDB_TOKEN", ""), timeout = 60)
refmat_search(client = refmatdb(), q = NULL, species = NULL,
              tissue = NULL, condition = NULL, owner = NULL,
              cell_type = NULL, sort = "created_at",
              limit = 50, offset = 0, all = FALSE)
refmat_celltypes(client = refmatdb(), q = NULL, species = NULL,
                 tissue = NULL, condition = NULL,
                 limit = 50, offset = 0, all = FALSE)
refmat_info(id, client = refmatdb())
refmat_download(id, path, client = refmatdb(), overwrite = FALSE)
refmat_read(path, orientation = c("auto", "genes_by_celltypes", "celltypes_by_genes"))
refmat_get(id, client = refmatdb(), orientation = "auto")
}
\arguments{
\item{url}{Server root URL, optionally including a deployment path or trailing /api/v1.}
\item{token}{Personal API token, or empty string for public access. HTTPS is required for tokens.}
\item{timeout}{Request timeout in seconds.}
\item{client}{Connection created by \code{refmatdb()}. Contains credentials if supplied; do not share or serialize it.}
\item{q}{Text search. Reference searches match names/descriptions; cell-type searches match labels.}
\item{species, tissue, condition}{Exact metadata filters.}
\item{owner}{Owner username or \code{"me"} for an authenticated client.}
\item{cell_type}{Normalized exact cell-type label. Only species and pagination filters can accompany it.}
\item{sort}{One of created_at, name, n_celltypes.}
\item{limit}{Page size, 1 to 200.}
\item{offset}{Zero-based result offset.}
\item{all}{Collect all pages when TRUE.}
\item{id}{Reference UUID from search results.}
\item{path}{Local file path. Download directories must already exist.}
\item{overwrite}{Allow replacement of an existing destination after verification.}
\item{orientation}{Import orientation; auto matches RefmatDB header conventions.}
}
\value{\code{refmatdb()} returns a client object; searches return data frames with total and offset attributes (an empty result has no columns). \code{refmat_info()} returns a metadata list. \code{refmat_download()} invisibly returns the verified file path. \code{refmat_read()} and \code{refmat_get()} return a numeric genes-by-cell-type matrix.}
\details{Downloads verify the server-provided SHA-256 before moving the file into place. CSV, TSV, and gzip files are supported. A first header of celltype, cell type, or cell types (after case, underscore and hyphen normalization) indicates transposed data. Import preserves numeric values without normalization or gene conversion. Matrix imports are dense and require sufficient memory. Hidden references return the same error as missing references. Public reads require no credentials.}
\examples{
db <- refmatdb(token = "")
print(db)
f <- tempfile()
writeLines(c("gene,T cell,B cell", "CD3D,8,0", "MS4A1,0,9"), f)
refmat_read(f)
unlink(f)
\dontrun{
hits <- refmat_search(db, species = "human", all = TRUE)
# Choose an appropriate reference after reviewing metadata.
info <- refmat_info(hits$id[1], db)
reference <- refmat_get(hits$id[1], db)
}
}
\seealso{\url{https://refmatdb.seq-space.com/api/docs}, \url{https://rnabioco.github.io/clustifyr/}}
