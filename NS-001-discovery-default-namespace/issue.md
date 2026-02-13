# NS-001: Discovery ops default to wrong namespace
**Severity**: Critical
**GitHub**: [#1123](https://github.com/ruvnet/claude-flow/issues/1123)
## Root Cause
MCP `memory_search` defaulted to `namespace='default'`, but entries live in 'patterns', 'solutions', etc. Every MCP search returned 0 results. MCP `memory_list` had no 'all' support — truthiness check treated 'all' as truthy, generating `WHERE namespace = 'all'` which returns 0 results.
## Rule
Discovery ops (search, list) default to 'all' — search across all namespaces.
## Fix
MCP search, core searchEntries(), embeddings search, MCP list, CLI list all default to 'all'. Core listEntries() uses nsFilter variable to distinguish between 'all' sentinel and real namespace filtering.
## Files Patched
- mcp-tools/memory-tools.js (search + list)
- mcp-tools/embeddings-tools.js (search)
- memory/memory-initializer.js (searchEntries, listEntries)
- commands/memory.js (CLI list)
## Ops
10 ops in fix.py (19a-e + 21c,d,g,i,j)
