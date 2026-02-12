# Patch 18: Neural status initializes WASM/SONA/HNSW before checking

**File:** `commands/neural.js`
**Severity:** Low (cosmetic)
**Issue:** `neural status` shows RuVector WASM, SONA Engine, and HNSW Index as "Not loaded" even when packages are installed, because it reads module-level flags without calling init functions.

## Problem

The status command imports `ruvector-training.js` and `memory-initializer.js` but only calls `initializeIntelligence()`. It never calls `initializeTraining()` or `getHNSWIndex()`, so the lazy-init module flags remain at their defaults (false/null).

## Changes

1. Updated import to include `getHNSWIndex` from `memory-initializer.js`
2. Added `ruvector.initializeTraining({ useSona: true })` call before reading stats
3. Added `getHNSWIndex()` call before reading HNSW status
4. Both wrapped in `.catch()` so failures don't break the status display

## Verification

```bash
# Should show all components as Active/Ready (not "Not loaded")
npx @claude-flow/cli@latest neural status
```

## Status

Applied and verified 2026-02-12.
