# End-to-end RefmatDB / clustifyr / Seurat workflow

## Get the workflow from GitHub

The QMD and renv files live in the source repository and are excluded from the
installed R package. Clone the repository using an authenticated Git client
(the repository is currently private and requires access):

```sh
git clone https://github.com/MLKaufman/refmatR.git
cd refmatR/qmd-tests
```

Place your own Seurat object at `qmd-tests/so.rds` before rendering; the input
RDS, downloaded references, generated report, and outputs are not committed.
Review `workflow.qmd` parameters for your species, tissue, reference UUID,
cluster column, and existing-label column. The current defaults describe the
mouse mammary integration test, not arbitrary scRNA-seq data.

Install Quarto separately and use R compatible with the lockfile (this run used
R 4.6.1 and Bioconductor 3.23). From this directory:

```sh
Rscript setup.R
quarto render workflow.qmd
```

Open `workflow.html` for the executed report. `workflow.qmd` contains the full
workflow and editable parameters. `so.rds` is your original input and is never
overwritten. No query expression data are uploaded to RefmatDB.

The environment is isolated with renv: `.Rprofile`, `renv/activate.R`,
`renv/settings.json`, and `renv.lock`. It was run with R 4.6.1 and Bioconductor
3.23. Quarto is an external system dependency (its version is recorded below).
`setup.R` restores the lockfile, rebuilds the local refmatR package from `..`,
and refreshes the lock. Keep the parent package alongside this directory.
To update dependencies intentionally, use renv and re-render the report.

## Inputs and assumptions

- `so.rds`: supplied Seurat object, RNA assay, existing `seurat_clusters`.
- Species/tissue: mouse mammary; inferred from mouse symbols and existing
  mammary annotations, and recorded explicitly in workflow parameters.
- Reference: `36ca870e-74c0-4cb2-b070-606c3067f0e0`, selected explicitly from
  the public RefmatDB species/tissue search results.
- Query counts are freshly LogNormalized (10,000 scale factor); 2,000 variable
  genes are requested, and only genes shared with the reference are scored.
- All cells and existing clusters are retained. No clustering or embedding is
  re-run. Existing metadata are retained and new fields have a `refmatR_` prefix.
- Cluster-level Spearman scores use clustifyr, with a configurable 0.3 minimum
  score for candidate calls. Score margins are descriptive, not probabilities.

The reference may originate from the same dataset. This workflow validates
software integration, not independent cell-type annotation performance. The
existing-label comparison is descriptive and does not constitute ground truth.

## Outputs

- `workflow.html`: self-contained executed report with plots and code.
- `data/<UUID>.refmat`: downloaded original reference, verified against SHA-256.
- `outputs/so_refmatR_annotated.rds`: separate annotated object.
- `outputs/cluster-calls.csv`: cluster labels, scores, margins, and cell counts.
- `outputs/cluster-correlations.csv`: complete cluster/reference score matrix.
- `outputs/existing-label-comparison.csv`: previous-vs-predicted label counts.
- `outputs/reference-metadata.json`: source reference metadata and checksum.
- `outputs/run-manifest.json`: parameters, input checksum, versions, provenance.
- `outputs/query-genes.txt`, `outputs/input-summary.csv`, `outputs/session-info.txt`.

The original and generated datasets, HTML output, downloads, renv library, and
render intermediates are ignored by Git. The entire qmd-tests directory is
excluded from refmatR package builds. Keep the QMD, setup script, lockfile,
and renv activation files under version control in the repository.

See `quarto-version.txt` for the Quarto version used in this run.

## Annotation review

The report includes side-by-side UMAPs using shared coordinates and colors,
a confusion matrix with counts and row percentages, and a shaded cluster review
table. Review thresholds are QMD parameters: correlation below 0.7 or
best-minus-runner-up margin below 0.05; any disagreement among known original
labels is also flagged. These are review heuristics, not calibrated confidence.

Additional exports: `outputs/umap-comparison.png`, `confusion-matrix.png`,
`confusion-counts.csv`, `confusion-row-percent.csv`, `cluster-review.csv`,
`flagged-clusters.csv`, and `review-summary.csv` (all under `outputs/`).
