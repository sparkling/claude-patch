# EM-002: @xenova/transformers cache EACCES
**Severity**: Medium
## Root Cause
Global `npm install` creates root-owned directories. `@xenova/transformers` tries to write model cache next to its `package.json`, failing with EACCES.
## Fix
Create `.cache` directory with open permissions. Alternative: set `TRANSFORMERS_CACHE` env var.
## Files Patched
- N/A (filesystem permissions, not code)
## Ops
fix.sh (chmod, not Python)
