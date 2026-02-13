# UI-002: neural status shows "Not loaded"
**Severity**: Low (cosmetic)
**GitHub**: [#1146](https://github.com/ruvnet/claude-flow/issues/1146)
## Root Cause
`neural status` reads module-level flags (`initialized`, `sonaAvailable`, `hnswIndex`) without calling their init functions. RuVector WASM, SONA Engine, and HNSW Index always show "Not loaded" even when packages are installed and working.
## Fix
Add `initializeTraining()` and `getHNSWIndex()` calls before reading status. Update import to include `getHNSWIndex`.
## Files Patched
- commands/neural.js
## Ops
2 ops in fix.py
