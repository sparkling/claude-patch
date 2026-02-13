# DM-003: macOS freemem() always ~0% — workers blocked
**Severity**: Critical (macOS only)
**GitHub**: [#1077](https://github.com/ruvnet/claude-flow/issues/1077)
## Root Cause
`os.freemem()` on macOS excludes file cache, always reporting ~0.3% free. macOS reclaims cache on demand, so the number is meaningless. The `minFreeMemoryPercent: 20` gate never passes.
## Fix
Skip the free memory check on macOS (`os.platform() !== 'darwin'`).
## Files Patched
- services/worker-daemon.js
## Ops
1 op in fix.py (skipped on Linux)
