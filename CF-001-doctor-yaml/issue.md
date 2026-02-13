# CF-001: Doctor ignores YAML config files
**Severity**: Low
## Root Cause
`checkConfigFile()` only checks `.json` paths, but `claude-flow init` generates `config.yaml`. Also, `JSON.parse()` runs on all config content, crashing on YAML.
## Fix
Add `.claude-flow/config.yaml` and `.claude-flow/config.yml` to the config search paths. Skip `JSON.parse()` for non-JSON files.
## Files Patched
- commands/doctor.js
## Ops
2 ops in fix.py
