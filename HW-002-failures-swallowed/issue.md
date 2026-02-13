# HW-002: Headless failures silently swallowed as success
**Severity**: High
**GitHub**: [#1112](https://github.com/ruvnet/claude-flow/issues/1112)
## Root Cause
`executeWorker()` hardcodes `success: true` for any non-throwing return. When headless execution fails (returns `{success: false}`), `runWorkerLogic()` catches the error and falls through to local stubs that fabricate data. Failures are never surfaced.
## Fix
Check `result.success` after headless execution. If false, throw with the error message instead of falling through.
## Files Patched
- services/worker-daemon.js
## Ops
1 op in fix.py
