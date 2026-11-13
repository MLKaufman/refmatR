# Standalone refmatR package

This directory is independent of the RefmatDB server project. Open it as its own
Codex project or RStudio project for future client work. No server deployment is
required to develop this client. No Git remote or published package exists yet.

Server source: ../RefmatDB/src/refmatdb/api.py
Public server: https://refmatdb.seq-space.com
API: /api/v1; OpenAPI schema: /api/openapi.json

Current scope: read-only searches, metadata, file downloads, matrix parsing.
Use existing server authorization; never add client-side access workarounds.
Do not include tokens, live datasets, .Renviron, or serialized clients in Git.

Next possible features: reference marker retrieval, reference comparison reports,
optional clustifyr wrapper with explicit preprocessing choices, package release CI.
Keep clustifyr optional so downloading references does not require its full
Bioconductor dependency tree. Document the provenance of selected references.
