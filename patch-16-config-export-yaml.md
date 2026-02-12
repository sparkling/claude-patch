# Patch 16: Config export reads from config.yaml

**File:** `commands/config.js`
**Severity:** Medium
**Issue:** `config export` and `config get` show hardcoded defaults instead of reading `.claude-flow/config.yaml`

## Problem

The `config export` and `config get` commands use hardcoded defaults (topology: 'hybrid', cacheSize: 256) instead of reading the actual YAML config file. This makes the commands misleading when the project has a custom config.

## Changes

1. Added imports for `fs.readFileSync`, `fs.existsSync`, and `path.join`
2. Added `readYamlConfig()` helper — simple YAML parser for key: value pairs
3. Updated `getCommand` action to merge YAML config values over defaults
4. Updated `exportCommand` action to merge YAML config values over defaults

## Verification

```bash
# Should show topology: hierarchical-mesh (from config.yaml, not hardcoded hybrid)
npx @claude-flow/cli@latest config export --format json

# Should show 512 (from config.yaml, not hardcoded 256)
npx @claude-flow/cli@latest config get memory.cacheSize

# Should show hierarchical-mesh
npx @claude-flow/cli@latest config get swarm.topology
```

## Status

Applied and verified 2026-02-12.
