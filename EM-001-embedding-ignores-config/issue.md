# EM-001: Embedding system ignores project config (model + HNSW dims)
**Severity**: High
**GitHub**: [#1143](https://github.com/ruvnet/claude-flow/issues/1143)
## Root Cause
`loadEmbeddingModel()` hardcodes `Xenova/all-MiniLM-L6-v2` (384-dim). Projects configured with a different model via `embeddings.json` (e.g. `all-mpnet-base-v2` 768-dim) still get MiniLM 384-dim vectors. HNSW index also hardcodes 384 dimensions, causing dimension mismatch when the actual model produces 768-dim vectors. Every search falls back to brute-force SQLite.
## Fix
Read model name and dimensions from `.claude-flow/embeddings.json` at load time. Fall back to all-MiniLM-L6-v2 (384-dim) if no config exists. Delete stale persistent HNSW files on forceRebuild. Guard metadata loading and early-return to skip on forceRebuild.
## Files Patched
- memory/memory-initializer.js
## Ops
6 ops in fix.py (merged from old patches 8 + 9)
