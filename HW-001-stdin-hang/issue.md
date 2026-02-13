# HW-001: Headless workers hang — stdin pipe never closed
**Severity**: Critical
**GitHub**: [#1111](https://github.com/ruvnet/claude-flow/issues/1111)
## Root Cause
`claude --print` is spawned with `stdio: ['pipe', 'pipe', 'pipe']`. The prompt is passed as a CLI argument, so stdin is never written to or closed. The child process hangs waiting for stdin EOF.
## Fix
Change stdin to `'ignore'` since it's unused.
## Files Patched
- services/headless-worker-executor.js
## Ops
1 op in fix.py
