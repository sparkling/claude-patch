# CF-002: Config export shows hardcoded defaults
**Severity**: Medium
## Root Cause
`config export` and `config get` use hardcoded defaults (topology: 'hybrid', cacheSize: 256) instead of reading `.claude-flow/config.yaml`. The commands are misleading when the project has custom config.
## Fix
Add `readYamlConfig()` helper function. Merge YAML config values over defaults in both `getCommand` and `exportCommand` actions.
## Files Patched
- commands/config.js
## Ops
3 ops in fix.py
