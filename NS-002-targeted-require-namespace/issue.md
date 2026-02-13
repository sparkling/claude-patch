# NS-002: Store/delete/retrieve fall back to 'default' + accept 'all'
**Severity**: Critical
**GitHub**: [#581](https://github.com/ruvnet/claude-flow/issues/581), [#1137](https://github.com/ruvnet/claude-flow/issues/1137), [#1135](https://github.com/ruvnet/claude-flow/issues/1135)
## Root Cause
MCP/CLI/Core used `namespace || 'default'`, silently routing entries to wrong namespace. Also accepted 'all' (search/list sentinel) as a write namespace, creating invisible entries.
## Rule
Targeted ops (store, delete, retrieve) require explicit namespace. Block 'all' with clear error.
## Fix
Remove fallback. Add 'namespace' to MCP schema required fields. Add runtime throw for missing/invalid namespace. CLI commands check before executing. Core functions throw on missing namespace.
## Files Patched
- mcp-tools/memory-tools.js (store, delete, retrieve)
- commands/memory.js (store, delete, retrieve)
- memory/memory-initializer.js (storeEntry, deleteEntry, getEntry)
## Ops
14 ops in fix.py (20a-i + 21a,b,e,f,h)
