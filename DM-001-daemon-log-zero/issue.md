# DM-001: daemon.log always 0 bytes
**Severity**: Medium
**GitHub**: [#1116](https://github.com/ruvnet/claude-flow/issues/1116)
## Root Cause
Two issues: (1) `log()` method uses `require('fs')` which is undefined in ESM modules — `appendFileSync` silently fails. (2) Path mismatch — daemon spawn writes to `.claude-flow/daemon.log` but `log()` targets `.claude-flow/logs/daemon.log`.
## Fix
(A) Add `appendFileSync` to ESM import. (B) Replace `require('fs')` call with imported function. (C) Align spawn log path to `.claude-flow/logs/daemon.log`.
## Files Patched
- services/worker-daemon.js (Parts A, B)
- commands/daemon.js (Part C)
## Ops
3 ops in fix.py
