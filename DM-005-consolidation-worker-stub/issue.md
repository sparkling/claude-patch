# DM-005: Consolidation worker stub (no decay/rebuild)
**Severity**: Enhancement
**GitHub**: [#1140](https://github.com/ruvnet/claude-flow/issues/1140)
## Root Cause
The consolidation worker was a stub writing `{patternsConsolidated: 0}` to a JSON file. No actual memory consolidation occurred.
## Fix
Call `applyTemporalDecay()` to reduce confidence of stale patterns, then `clearHNSWIndex()` + `getHNSWIndex({ forceRebuild: true })` to rebuild the index with current data.
## Files Patched
- services/worker-daemon.js
## Ops
1 op in fix.py
