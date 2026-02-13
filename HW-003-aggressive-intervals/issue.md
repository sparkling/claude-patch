# HW-003: Worker scheduling intervals too aggressive
**Severity**: High
**GitHub**: [#1113](https://github.com/ruvnet/claude-flow/issues/1113)
## Root Cause
`DEFAULT_WORKERS` uses pre-headless intervals (audit: 10m, optimize: 15m, testgaps: 20m). ADR-020 specifies longer intervals (30/60/60m) for headless workers that invoke Claude.
## Fix
Align intervals to ADR-020: audit 30m, optimize 60m, testgaps 60m.
## Files Patched
- services/worker-daemon.js
## Ops
3 ops in fix.py
