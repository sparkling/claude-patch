# GV-001: HNSW ghost vectors persist after memory delete
**Severity**: Medium
**GitHub**: [#1122](https://github.com/ruvnet/claude-flow/issues/1122)
## Root Cause
`deleteEntry()` soft-deletes the SQLite row but never removes the vector from the in-memory HNSW index or its persisted metadata. The search code (`searchHNSWIndex`) iterates HNSW results and looks up each ID in `hnswIndex.entries` Map — ghost vectors match but return stale metadata (key, namespace, content) because the Map entry was never removed.
## Fix
After the SQLite soft-delete, remove the entry from `hnswIndex.entries` Map and save updated metadata. The HNSW vector DB (`@ruvector/core`) doesn't support point removal, but the search code already skips entries missing from the Map (`if (!entry) continue`), so removing from the Map is sufficient to suppress ghost results.
## Files Patched
- memory/memory-initializer.js
## Ops
1 op in fix.py
