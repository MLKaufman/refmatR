# refmatR

An R client for [RefmatDB](https://refmatdb.seq-space.com). Search public or
accessible private references, inspect metadata, and retrieve a numeric
**genes × cell types** matrix for clustifyr.  

Version 0.1.0 is a read-only client;
it does not upload, change accounts, or send your query scRNA-seq data anywhere.

## Install from GitHub

Requires R 4.1 or newer. Install the current development version directly from
[MLKaufman/refmatR](https://github.com/MLKaufman/refmatR):

```r
install.packages("remotes")
remotes::install_github("MLKaufman/refmatR")
library(refmatR)

# Public RefmatDB access needs no RefmatDB account or API token.
db <- refmatdb(token = "")
refmat_search(db, limit = 5)
```

### Optional annotation packages

Searching and downloading references only requires refmatR. To compare your
own data with clustifyr and work with Seurat objects:

```r
if (!requireNamespace("BiocManager", quietly = TRUE)) {
  install.packages("BiocManager")
}
BiocManager::install("clustifyr", update = FALSE, ask = FALSE)
install.packages("Seurat")
```

Use the Bioconductor release appropriate to your R version. The fully executed
example in [qmd-tests](qmd-tests/README.md) includes an isolated renv environment,
Quarto report, annotation comparisons, and reproducible setup instructions.

## Find and retrieve a reference

```r
db <- refmatdb()
hits <- refmat_search(db, species = "human", q = "lung", all = TRUE)
hits
attr(hits, "total")

# Inspect results and choose the appropriate reference explicitly.
# Replace the placeholder with an id from hits$id.
id <- "YOUR-REFERENCE-UUID"
info <- refmat_info(id, db)
info[c("name", "species", "gene_id_type", "value_type", "source", "notes")]
reference <- refmat_get(id, db)
dim(reference)
head(rownames(reference))
colnames(reference)

# Keep the original file, byte-for-byte, with SHA-256 verification.
refmat_download(id, "reference.csv", db)
```

`q` searches reference names and descriptions. Species, tissue, and condition
are exact filters. Results are data frames, with `total` and `offset` attributes.
Use `limit` (1–200) and `offset` for one page, or `all = TRUE` to collect all
pages. Results may change while pagination is running.

```r
refmat_celltypes(db, q = "T cell", species = "human")
refmat_search(db, cell_type = "T cells", species = "human", all = TRUE)
```

Cell-type lookup uses the server's normalized exact label matching and only
supports species and pagination filters. Other search filters cannot be combined
with `cell_type` in this API version.

## Compare your dataset with clustifyr

Install clustifyr using the optional annotation package instructions above.
The query matrix and metadata stay in your R session. Start with a suitable
reference for the query species, tissue, and gene identifier convention.

```r
library(clustifyr)
# query: numeric genes x cells matrix of natural-log1p normalized expression
# metadata: data.frame with cell IDs as row names and a cluster column
stopifnot(!anyDuplicated(rownames(metadata)))
stopifnot(all(colnames(query) %in% rownames(metadata)))
metadata <- metadata[colnames(query), , drop = FALSE]
shared_genes <- intersect(rownames(query), rownames(reference))
stopifnot(length(shared_genes) > 0L)

scores <- clustifyr::clustify(
  input = query,
  ref_mat = reference,
  metadata = metadata,
  cluster_col = "cluster",
  query_genes = shared_genes,
  if_log = TRUE
)
calls <- clustifyr::cor_to_call(scores)
calls
```

`if_log` describes the **query** expression scale: use `FALSE` for linear
counts. The package does not normalize expression, translate gene identifiers,
merge duplicate genes, or filter genes automatically. Inspect overlap and
reference metadata before interpreting calls. Treat similarity-based calls as
annotation candidates and examine markers and biological context.
See the [clustifyr function documentation](https://rnabioco.github.io/clustifyr/reference/clustify.html)
for Seurat/SingleCellExperiment workflows and scoring options.

## Private references

Create a personal API token in RefmatDB's Account page. Store it in your local
R environment (for example, `REFMATDB_TOKEN` in your private `.Renviron`) and
restart R. Do not put it in scripts, Git, or shared notebooks.

```r
db <- refmatdb(token = Sys.getenv("REFMATDB_TOKEN"))
my_refs <- refmat_search(db, owner = "me")
```

The client respects server permissions. A hidden or missing reference returns
a 404. Printing the client omits its token, but the client object contains the
credential: do not save or share that object. Tokens are sent only over HTTPS;
HTTP redirects are rejected. Public browsing needs no account or token.
For a separate public-only client, use `refmatdb(token = "")`.

## File formats

`refmat_read()` reads CSV, TSV, and gzip-compressed versions regardless of the
filename extension. It accepts leading comment lines and UTF-8 BOMs, preserves
cell-type column names, rejects non-finite/non-numeric values and duplicate
identifiers, and follows RefmatDB's orientation detection. Headers such as
`cell_type` indicate a cell-types-by-genes file, which is transposed on import.
Use `orientation = "genes_by_celltypes"` or `"celltypes_by_genes"` to override
ambiguous headers. No expression transformations occur. Importing a reference
requires enough RAM for the full file and dense numeric matrix.

## Development

```sh
R CMD build .
R CMD check --no-manual refmatR_0.1.0.tar.gz
```

Offline tests run during package checks. Live smoke tests are run separately
so routine checks do not depend on network access or your production database.
