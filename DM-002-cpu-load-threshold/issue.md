# DM-002: maxCpuLoad=2.0 blocks all workers on multi-core
**Severity**: Critical
**GitHub**: [#1138](https://github.com/ruvnet/claude-flow/issues/1138)
## Root Cause
`maxCpuLoad` defaults to 2.0, but load average reflects total system load across all cores. An 8-core Mac idles at 3-5. A 32-core server idles at 1-3 but spikes above 2.0 easily. No worker ever passes the resource gate.
## Fix
Raise threshold to match hardware. Currently set to 28.0 for 32-core server. Adjust per machine (8-core Mac: 6.0).
## Files Patched
- services/worker-daemon.js
## Ops
1 op in fix.py
