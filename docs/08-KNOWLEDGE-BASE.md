# 08 - Knowledge base

Phase 4 specification, reconstructed on 2026-10-02. The foundation exposes an honest empty UI only.

Upload documents with short-lived signed URLs, scoped to the authenticated workspace. Ingestion
validates file type/size, extracts supported PDF/DOCX/TXT/Markdown content, chunks by structure,
and stores embeddings behind the Shared service boundary. URL ingestion needs SSRF protections,
redirect limits, private-address blocking, and bounded downloads before it is exposed.

Use workspace-scoped retrieval with lexical and vector signals and reciprocal-rank fusion. Preserve
source metadata for citations. RLS and cross-workspace tests are required. No untrusted document
instruction may become an agent instruction. Deletion removes originals, chunks, and indexes.

Evaluate 50-page ingestion time and top-4 retrieval recall on EN/TR before claiming roadmap targets.
Verify embedding dimensionality, provider language quality, pricing, and data-use terms at integration.
