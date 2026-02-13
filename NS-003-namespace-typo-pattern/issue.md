# NS-003: Namespace typo 'pattern' vs 'patterns'
**Severity**: Medium
**GitHub**: [#1136](https://github.com/ruvnet/claude-flow/issues/1136)
## Root Cause
hooks-tools.js used singular 'pattern' in 4 locations while every other file (memory-tools.js, CLI, README) uses 'patterns' (plural). Patterns stored via hooks were invisible to search.
## Fix
Replace all 4 occurrences of 'pattern' with 'patterns' in hooks-tools.js.
## Files Patched
- mcp-tools/hooks-tools.js
## Ops
4 ops in fix.py (22a-d)
