# DM-004: Preload worker stub + missing from defaults
**Severity**: Enhancement
## Root Cause
The `preload` worker type exists in the switch statement but was missing from `DEFAULT_WORKERS` — never scheduled. The `runPreloadWorkerLocal()` was a stub returning `{resourcesPreloaded: 0}`. Also missing: ultralearn, deepdive, refactor, benchmark workers.
## Fix
Add missing workers to DEFAULT_WORKERS. Implement real preload that calls `loadEmbeddingModel()` and `getHNSWIndex()` from memory-initializer.js.
## Files Patched
- services/worker-daemon.js
## Ops
2 ops in fix.py
