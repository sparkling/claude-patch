# UI-001: intelligence stats crashes on .toFixed()
**Severity**: Critical
## Root Cause
`hooks intelligence stats` calls `.toFixed()` on potentially undefined properties (learningTimeMs, adaptationTimeMs, avgQuality, routingAccuracy, loadBalance, cacheHitRate, performance.*) without null checks. Crashes when the intelligence system returns incomplete data.
## Fix
Add null checks with 'N/A' fallback for all numeric display values. Wrap performance section in an `if (result.performance)` guard.
## Files Patched
- commands/hooks.js
## Ops
7 ops in fix.py
