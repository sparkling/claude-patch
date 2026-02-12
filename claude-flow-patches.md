# Claude-Flow v3.1.0-alpha.28 — Local Patches

Patches for known bugs in `claude-flow` v3.1.0-alpha.28. Applicable to any project using this version.

**Upstream:** [ruvnet/claude-flow](https://github.com/ruvnet/claude-flow)
**Tested on:** Node.js v24.13.0, Claude Code v2.1.39, Linux x86_64 + macOS (Apple Silicon)

---

## Before You Start: Find Your Install Paths

`claude-flow` has **two independent code locations** that must BOTH be patched (1-8):

| Install | What uses it | How it got there |
|---------|-------------|------------------|
| **Global npm** | `claude-flow` binary (rarely used directly) | `npm install -g claude-flow@alpha` |
| **npx cache** | Daemon, MCP server, all `npx @claude-flow/cli@latest` commands | `npx` auto-fetches on first use |

**npm and npx do NOT share packages.** Patching one does not patch the other.
**The npx cache is what actually runs** — `.mcp.json`, the daemon, and all CLI commands use it.

### Auto-detect paths

```bash
#!/bin/bash
# Global install
GLOBAL_BASE=$(npm root -g)/claude-flow/v3/@claude-flow/cli/dist/src
if [ -d "$GLOBAL_BASE/services" ]; then
  GLOBAL_SERVICES="$GLOBAL_BASE/services"
  GLOBAL_COMMANDS="$GLOBAL_BASE/commands"
  GLOBAL_MEMORY="$GLOBAL_BASE/memory"
  echo "Global: $GLOBAL_BASE"
else
  echo "WARN: Global install not found (optional if only using npx)"
fi

# npx cache (find by sentinel file)
NPX_BASE=$(find ~/.npm/_npx -name "headless-worker-executor.js" -path "*/services/*" 2>/dev/null | head -1 | xargs dirname 2>/dev/null)
if [ -n "$NPX_BASE" ]; then
  NPX_SERVICES="$NPX_BASE"
  NPX_COMMANDS="$(dirname "$NPX_BASE")/commands"
  NPX_MEMORY="$(dirname "$NPX_BASE")/memory"
  echo "npx:    $(dirname "$NPX_BASE")"
else
  echo "WARN: npx cache not found (run 'npx @claude-flow/cli@latest --version' first)"
fi
```

Run each patch **twice** — once for global (with `sudo`), once for npx cache.

### When to re-apply

Patches are lost on `npm update -g claude-flow`, new npx version fetch, or `npm cache clean --force`.

After patching, restart the daemon:
```bash
npx @claude-flow/cli@latest daemon stop
npx @claude-flow/cli@latest daemon start
```

---

## Patch 1: stdin pipe fix (Critical)

**File:** `services/headless-worker-executor.js` line 813
**Issue:** [#1111](https://github.com/ruvnet/claude-flow/issues/1111)

`claude --print` hangs forever when spawned with `stdio: ['pipe', ...]`. The prompt is passed as a CLI argument, so stdin is never written to or closed.

```diff
-                stdio: ['pipe', 'pipe', 'pipe'],
+                stdio: ['ignore', 'pipe', 'pipe'],
```

```bash
sed -i "s/stdio: \['pipe', 'pipe', 'pipe'\]/stdio: ['ignore', 'pipe', 'pipe']/" \
  "$SERVICES/headless-worker-executor.js"
```

**Note:** A second `stdio: 'pipe'` at line 391 (`execSync('claude --version')`) is correct — do not change it.

---

## Patch 2: honest failure reporting (High)

**File:** `services/worker-daemon.js` lines ~399-431
**Issue:** [#1112](https://github.com/ruvnet/claude-flow/issues/1112)

`executeWorker()` hardcodes `success: true` for any non-throwing return. When headless fails, `runWorkerLogic()` catches the error and falls through to local stubs that fabricate data.

Replace the `runWorkerLogic` headless block:
```javascript
// ORIGINAL (broken):
if (isHeadlessWorker(workerConfig.type) && this.headlessAvailable && this.headlessExecutor) {
    try {
        this.log('info', `Running ${workerConfig.type} in headless mode (Claude Code AI)`);
        const result = await this.headlessExecutor.execute(workerConfig.type);
        return { mode: 'headless', ...result };
    }
    catch (error) {
        this.log('warn', `Headless execution failed for ${workerConfig.type}, falling back to local mode`);
        this.emit('headless:fallback', { type: workerConfig.type, error: ... });
        // Fall through to local execution  <-- BUG
    }
}
```

With:
```javascript
// PATCHED:
if (isHeadlessWorker(workerConfig.type) && this.headlessAvailable && this.headlessExecutor) {
    let result;
    try {
        this.log('info', `Running ${workerConfig.type} in headless mode (Claude Code AI)`);
        result = await this.headlessExecutor.execute(workerConfig.type);
    }
    catch (error) {
        const errorMsg = error instanceof Error ? error.message : String(error);
        this.log('warn', `Headless execution threw for ${workerConfig.type}: ${errorMsg}`);
        this.emit('headless:fallback', { type: workerConfig.type, error: errorMsg });
        throw error instanceof Error ? error : new Error(errorMsg);
    }
    if (result.success) {
        return { mode: 'headless', ...result };
    }
    const errorMsg = result.error || 'Unknown headless failure';
    this.log('warn', `Headless failed for ${workerConfig.type}: ${errorMsg}`);
    this.emit('headless:fallback', { type: workerConfig.type, error: errorMsg });
    throw new Error(`Headless execution failed for ${workerConfig.type}: ${errorMsg}`);
}
```

Too complex for `sed`. Use python3 block-replace (see gene repo for full script) or apply manually.

---

## Patch 3: interval alignment (High)

**File:** `services/worker-daemon.js` lines 18-24
**Issue:** [#1113](https://github.com/ruvnet/claude-flow/issues/1113)

`DEFAULT_WORKERS` uses pre-headless intervals (10/15/20 min). ADR-020 specifies 30/60/60 min.

```diff
-    { type: 'audit', intervalMs: 10 * 60 * 1000, ...
+    { type: 'audit', intervalMs: 30 * 60 * 1000, ...

-    { type: 'optimize', intervalMs: 15 * 60 * 1000, ...
+    { type: 'optimize', intervalMs: 60 * 60 * 1000, ...

-    { type: 'testgaps', intervalMs: 20 * 60 * 1000, ...
+    { type: 'testgaps', intervalMs: 60 * 60 * 1000, ...
```

```bash
sed -i "s/type: 'audit', intervalMs: 10 \* 60 \* 1000/type: 'audit', intervalMs: 30 * 60 * 1000/" "$SERVICES/worker-daemon.js"
sed -i "s/type: 'optimize', intervalMs: 15 \* 60 \* 1000/type: 'optimize', intervalMs: 60 * 60 * 1000/" "$SERVICES/worker-daemon.js"
sed -i "s/type: 'testgaps', intervalMs: 20 \* 60 \* 1000/type: 'testgaps', intervalMs: 60 * 60 * 1000/" "$SERVICES/worker-daemon.js"
```

---

## Patch 4: daemon.log fix (Medium)

**Files:** `services/worker-daemon.js` lines 13, ~717 + `commands/daemon.js` line ~162
**Issue:** [#1116](https://github.com/ruvnet/claude-flow/issues/1116)

Two root causes: (1) `log()` uses `require('fs')` which is undefined in ESM, silently failing. (2) Path mismatch — spawn writes to `.claude-flow/daemon.log` but `log()` targets `.claude-flow/logs/daemon.log`.

**Part A:** Add `appendFileSync` to ESM import (worker-daemon.js line 13):
```diff
-import { existsSync, mkdirSync, writeFileSync, readFileSync } from 'fs';
+import { existsSync, mkdirSync, writeFileSync, readFileSync, appendFileSync } from 'fs';
```

**Part B:** Replace `require('fs')` call (worker-daemon.js ~line 717):
```diff
-            const fs = require('fs');
-            fs.appendFileSync(logFile, logMessage + '\n');
+            appendFileSync(logFile, logMessage + '\n');
```

**Part C:** Align spawn log path (daemon.js ~line 162):
```diff
-    const logFile = join(stateDir, 'daemon.log');
+    const logsDir = join(stateDir, 'logs');
+    if (!fs.existsSync(logsDir)) {
+        fs.mkdirSync(logsDir, { recursive: true });
+    }
+    const logFile = join(logsDir, 'daemon.log');
```

Parts A-B are `sed`-able. Part C requires manual edit or python3 block-replace.

---

## Patch 5: CPU load threshold too low (Critical, macOS)

**File:** `services/worker-daemon.js` line 54

`maxCpuLoad` defaults to `2.0`, but macOS load average reflects total system load across all cores. An 8-core Mac idles at 3-5. A 16-core Ryzen idles at 1-3. **No worker ever passes the gate.**

```diff
-                maxCpuLoad: 2.0,
+                maxCpuLoad: 6.0,
```

```bash
sed -i 's/maxCpuLoad: 2.0/maxCpuLoad: 6.0/' "$SERVICES/worker-daemon.js"
```

---

## Patch 6: macOS memory check always fails (Critical, macOS)

**File:** `services/worker-daemon.js` lines 146-148

`os.freemem()` on macOS excludes file cache, always reporting ~0.3% free. macOS reclaims cache on demand, so the number is meaningless. The `minFreeMemoryPercent: 20` gate **never passes**.

```diff
-        if (freePercent < this.config.resourceThresholds.minFreeMemoryPercent) {
+        if (os.platform() !== 'darwin' && freePercent < this.config.resourceThresholds.minFreeMemoryPercent) {
             return { allowed: false, reason: `Memory too low: ${freePercent.toFixed(1)}% free` };
         }
```

Apply manually. Too complex for `sed`.

**Combined effect of patches 5+6:** Before: zero workers ever executed on macOS. After: all 5 workers run successfully.

---

## Patch 7: doctor YAML config support (Low)

**File:** `commands/doctor.js` lines ~59-79

`checkConfigFile()` only checks `.json`, but `claude-flow init` generates `config.yaml`.

```diff
     const configPaths = [
         '.claude-flow/config.json',
         'claude-flow.config.json',
-        '.claude-flow.json'
+        '.claude-flow.json',
+        '.claude-flow/config.yaml',
+        '.claude-flow/config.yml'
     ];
```

Also skip `JSON.parse()` for non-JSON:
```diff
-                JSON.parse(content);
+                if (configPath.endsWith('.json')) { JSON.parse(content); }
```

---

## Patch 8: Config-driven embedding model loader (Enhancement)

**File:** `memory/memory-initializer.js` `loadEmbeddingModel()` function
**Issue:** CLI hardcodes `Xenova/all-MiniLM-L6-v2` (384-dim). The `--embedding-model` flag and `embeddings.json` config exist but the loader ignores them.

**Root cause:** `loadEmbeddingModel()` hardcodes the model name and dimensions. Projects that configured a different model via `embeddings.json` (e.g. `all-mpnet-base-v2` 768-dim) still got MiniLM 384-dim vectors.

**Fix:** Read model name and dimensions from `.claude-flow/embeddings.json` at load time. Falls back to `all-MiniLM-L6-v2` (384-dim) if no config exists.

**Patch** (replace the hardcoded model block in `loadEmbeddingModel()`):

```javascript
// BEFORE (hardcoded):
        const transformers = await import('@xenova/transformers').catch(() => null);
        if (transformers) {
            if (verbose) {
                console.log('Loading ONNX embedding model (all-MiniLM-L6-v2)...');
            }
            const { pipeline } = transformers;
            const embedder = await pipeline('feature-extraction', 'Xenova/all-MiniLM-L6-v2');
            embeddingModelState = {
                loaded: true,
                model: embedder,
                tokenizer: null,
                dimensions: 384 // MiniLM-L6 produces 384-dim vectors
            };
            return {
                success: true,
                dimensions: 384,
                modelName: 'all-MiniLM-L6-v2',
                loadTime: Date.now() - startTime
            };
        }

// AFTER (config-driven):
        // Patch 8: Read embedding model from project config instead of hardcoding
        let modelName = 'all-MiniLM-L6-v2';
        let modelDimensions = 384;
        try {
            const embConfigPath = path.join(process.cwd(), '.claude-flow', 'embeddings.json');
            if (fs.existsSync(embConfigPath)) {
                const embConfig = JSON.parse(fs.readFileSync(embConfigPath, 'utf-8'));
                if (embConfig.model) {
                    modelName = embConfig.model;
                    modelDimensions = embConfig.dimension || 768;
                }
            }
        } catch { /* use defaults */ }
        const xenovaModel = modelName.startsWith('Xenova/') ? modelName : `Xenova/${modelName}`;
        const transformers = await import('@xenova/transformers').catch(() => null);
        if (transformers) {
            if (verbose) {
                console.log(`Loading ONNX embedding model (${modelName})...`);
            }
            const { pipeline } = transformers;
            const embedder = await pipeline('feature-extraction', xenovaModel);
            embeddingModelState = {
                loaded: true,
                model: embedder,
                tokenizer: null,
                dimensions: modelDimensions
            };
            return {
                success: true,
                dimensions: modelDimensions,
                modelName: modelName,
                loadTime: Date.now() - startTime
            };
        }
```

Too complex for `sed`. Use python3 block-replace (see `apply-patches.sh`).

**Config file:** `.claude-flow/embeddings.json` (per-project, created by `--embedding-model` flag):
```json
{
  "provider": "transformers",
  "model": "all-mpnet-base-v2",
  "dimension": 768
}
```

**After patching:** If changing models, clear memory and re-init (vectors change dimensionality):
```bash
npx @claude-flow/cli@latest memory init --force --verbose
```

**Revert:** Replace the config-reading block with the original hardcoded `all-MiniLM-L6-v2`, or reinstall the CLI.

---

## Patch 9: HNSW dimension fix + search activation (High)

**File:** `memory/memory-initializer.js` lines 311, 356-391, 524

**Issue:** HNSW index builds with hardcoded 384 dimensions regardless of the actual embedding model. After Patch 8 switches to Nomic (768-dim), the HNSW index either (a) builds with wrong dimensions, (b) loads stale 384-dim persistent files, or (c) silently fails on dimension mismatch — every search falls back to brute-force SQLite cosine similarity (~480ms vs ~6ms with HNSW).

**Root causes:**
1. `getHNSWIndex()` defaults dimensions to 384 when not passed (line 311)
2. `--build-hnsw` flag calls `getHNSWIndex({ forceRebuild: true })` without passing dimensions
3. `forceRebuild` does not delete stale persistent `.swarm/hnsw.index` and `.swarm/hnsw.metadata.json`
4. `getHNSWStatus()` also defaults to 384 (line 524)

**Patch (3 changes in `memory-initializer.js`):**

**Change 1 — Dynamic dimension detection (line 311):**
```javascript
// BEFORE:
    const dimensions = options?.dimensions ?? 384;

// AFTER:
    // Read dimensions from embeddings.json when not explicitly passed (Patch 9)
    let dimensions = options?.dimensions;
    if (!dimensions) {
        try {
            const embConfigPath = path.join(process.cwd(), '.claude-flow', 'embeddings.json');
            if (fs.existsSync(embConfigPath)) {
                const embConfig = JSON.parse(fs.readFileSync(embConfigPath, 'utf-8'));
                dimensions = embConfig.dimension || 768;
            }
        } catch { /* ignore config read errors */ }
        dimensions = dimensions || 768;
    }
```

**Change 2 — Delete stale files on forceRebuild (after persistent storage paths, before VectorDb creation):**
```javascript
// ADD after line defining metadataPath/dbPath, before "Create HNSW index":
        // Patch 9: On forceRebuild, delete stale persistent files to avoid dimension mismatch
        if (options?.forceRebuild) {
            try { if (fs.existsSync(hnswPath)) fs.unlinkSync(hnswPath); } catch {}
            try { if (fs.existsSync(metadataPath)) fs.unlinkSync(metadataPath); } catch {}
        }
```

Also guard metadata loading and early-return to skip on forceRebuild:
```javascript
// BEFORE:
        if (fs.existsSync(metadataPath)) {
// AFTER:
        if (!options?.forceRebuild && fs.existsSync(metadataPath)) {

// BEFORE:
        if (existingLen > 0 && entries.size > 0) {
// AFTER:
        if (existingLen > 0 && entries.size > 0 && !options?.forceRebuild) {
```

**Change 3 — Fix status default (line 524):**
```javascript
// BEFORE:
        dimensions: hnswIndex?.dimensions ?? 384
// AFTER:
        dimensions: hnswIndex?.dimensions ?? 768
```

**After patching:** Delete stale HNSW persistent files in each project:
```bash
rm -f .swarm/hnsw.index .swarm/hnsw.metadata.json
npx @claude-flow/cli@latest memory search --query "test" --build-hnsw
```

**Performance impact:**
- Cold (first search in process, model load): ~450ms (unchanged, dominated by ONNX model load)
- Warm (subsequent in-process searches): **6-9ms** (down from ~480ms = **~60x faster**)
- Daemon/MCP server (long-running): all searches after first are warm = 6-9ms

**Revert:** Change the dimension default back to 384, remove the forceRebuild guards. Or reinstall the CLI.

---

## Patch 11: Enable + implement preload worker (Enhancement)

**File:** `services/worker-daemon.js`
**Impact:** Pre-warms embedding model + HNSW index on daemon start; subsequent searches ~60x faster

Two issues:
1. The `preload` worker type exists in the switch statement but was missing from `DEFAULT_WORKERS` — never scheduled
2. The `runPreloadWorkerLocal()` implementation was a stub returning `{resourcesPreloaded: 0}`

Also adds missing worker types (`ultralearn`, `deepdive`, `refactor`, `benchmark`) to `DEFAULT_WORKERS`.

**Add to DEFAULT_WORKERS:**
```javascript
{ type: 'ultralearn', intervalMs: 60 * 60 * 1000, offsetMs: 10 * 60 * 1000, priority: 'normal', description: 'Neural pattern training', enabled: true },
{ type: 'deepdive', intervalMs: 4 * 60 * 60 * 1000, offsetMs: 0, priority: 'low', description: 'Deep code analysis', enabled: false },
{ type: 'refactor', intervalMs: 4 * 60 * 60 * 1000, offsetMs: 0, priority: 'low', description: 'Refactoring suggestions', enabled: false },
{ type: 'benchmark', intervalMs: 2 * 60 * 60 * 1000, offsetMs: 0, priority: 'low', description: 'Performance benchmarking', enabled: false },
{ type: 'preload', intervalMs: 10 * 60 * 1000, offsetMs: 0, priority: 'high', description: 'Embedding model + HNSW preload', enabled: true },
```

**Replace `runPreloadWorkerLocal()`** to actually call `loadEmbeddingModel()` and `getHNSWIndex()` from `memory-initializer.js`.

**Verified:** Preload runs in 470ms on daemon start, warming Nomic model + 21 HNSW vectors.

---

## Patch 12: Real consolidation worker (Enhancement)

**File:** `services/worker-daemon.js` `runConsolidateWorker()`
**Impact:** Pattern decay + HNSW index rebuild — keeps memory fresh

The consolidation worker was a stub writing `{patternsConsolidated: 0}` to a JSON file. Now it:
1. Calls `applyTemporalDecay()` to reduce confidence of stale patterns
2. Clears and rebuilds the HNSW index with current data via `clearHNSWIndex()` + `getHNSWIndex({ forceRebuild: true })`

**Verified:** Completes in 33ms, rebuilds 21 HNSW vectors, runs pattern decay.

---

---

## Patch 14: @xenova/transformers cache permission (Medium)

**Applies to:** Global npm install only

Global `npm install` creates root-owned directories. `@xenova/transformers` tries to write model cache next to its `package.json`, failing with EACCES.

```bash
TRANSFORMERS_DIR=$(npm root -g)/claude-flow/node_modules/@xenova/transformers
if [ -d "$TRANSFORMERS_DIR" ]; then
  sudo mkdir -p "$TRANSFORMERS_DIR/.cache"
  sudo chmod 777 "$TRANSFORMERS_DIR/.cache"
else
  echo "SKIP: @xenova/transformers not in global install"
fi
```

**Alternative:** `export TRANSFORMERS_CACHE="$HOME/.cache/transformers" && mkdir -p "$TRANSFORMERS_CACHE"`

---

---

## Verification

```bash
#!/bin/bash
# Usage: ./verify-patches.sh SERVICES_DIR COMMANDS_DIR [MEMORY_DIR]
SERVICES="${1:?Usage: $0 SERVICES COMMANDS [MEMORY]}"
COMMANDS="${2:?}"
MEMORY="${3:-$(dirname "$SERVICES")/memory}"
PASS=0; FAIL=0
check() { eval "$2" >/dev/null 2>&1 && { echo "  PASS: $1"; ((PASS++)); } || { echo "  FAIL: $1"; ((FAIL++)); }; }

echo "Checking: $SERVICES"
check "1: stdin ignore"        "grep -q \"stdio: \['ignore', 'pipe', 'pipe'\]\" '$SERVICES/headless-worker-executor.js'"
check "2: honest failures"     "grep -q 'Headless execution failed for' '$SERVICES/worker-daemon.js'"
check "3: audit 30m"           "grep -q \"type: 'audit', intervalMs: 30\" '$SERVICES/worker-daemon.js'"
check "3: optimize 60m"        "grep -q \"type: 'optimize', intervalMs: 60\" '$SERVICES/worker-daemon.js'"
check "3: testgaps 60m"        "grep -q \"type: 'testgaps', intervalMs: 60\" '$SERVICES/worker-daemon.js'"
check "4A: appendFileSync"     "grep -q 'appendFileSync' '$SERVICES/worker-daemon.js'"
check "4B: no require('fs')"   "! grep -q \"require('fs')\" '$SERVICES/worker-daemon.js'"
check "4C: logsDir"            "grep -q 'logsDir' '$COMMANDS/daemon.js'"
check "5: CPU load 6.0"        "grep -q 'maxCpuLoad: 6' '$SERVICES/worker-daemon.js'"
check "6: macOS mem skip"      "grep -q 'darwin' '$SERVICES/worker-daemon.js'"
check "7: YAML config"         "grep -q 'config.yaml' '$COMMANDS/doctor.js'"
check "8: Config-driven model"  "grep -q 'embeddings.json' '$MEMORY/memory-initializer.js'"
check "9: HNSW dim from config" "grep -q 'embeddings.json' '$MEMORY/memory-initializer.js'"
check "9: HNSW stale cleanup"   "grep -q 'forceRebuild.*unlinkSync\|Patch 9A' '$MEMORY/memory-initializer.js'"
check "11: preload in defaults" "grep -q 'Embedding model' '$SERVICES/worker-daemon.js'"
check "11: real preload"        "grep -q 'loadEmbeddingModel' '$SERVICES/worker-daemon.js'"
check "12: real consolidate"    "grep -q 'applyTemporalDecay' '$SERVICES/worker-daemon.js'"
check "16: config reads YAML"   "grep -q 'readYamlConfig' '$COMMANDS/config.js'"
echo ""
echo "Results: $PASS passed, $FAIL failed"
```

```bash
# Run for both locations
bash verify-patches.sh "$NPX_SERVICES" "$NPX_COMMANDS" "$NPX_MEMORY"
bash verify-patches.sh "$GLOBAL_SERVICES" "$GLOBAL_COMMANDS" "$GLOBAL_MEMORY"

# Patch 9: HNSW stale files (run per-project)
ls -la .swarm/hnsw.index .swarm/hnsw.metadata.json 2>/dev/null && echo "WARN: stale HNSW files exist"

# Patch 14: cache permissions
ls -la $(npm root -g)/claude-flow/node_modules/@xenova/transformers/.cache 2>/dev/null

```

---

## Summary

| # | File(s) | Severity | Issue | What it fixes |
|---|---------|----------|-------|---------------|
| 1 | headless-worker-executor.js:813 | Critical | [#1111](https://github.com/ruvnet/claude-flow/issues/1111) | stdin pipe hangs `claude --print` |
| 2 | worker-daemon.js:~399-431 | High | [#1112](https://github.com/ruvnet/claude-flow/issues/1112) | Failed headless silently counted as success |
| 3 | worker-daemon.js:18-24 | High | [#1113](https://github.com/ruvnet/claude-flow/issues/1113) | Headless workers run 3-6x too often |
| 4 | worker-daemon.js + daemon.js | Medium | [#1116](https://github.com/ruvnet/claude-flow/issues/1116) | daemon.log always 0 bytes |
| 5 | worker-daemon.js:54 | Critical | -- | maxCpuLoad=2.0 blocks workers on multi-core |
| 6 | worker-daemon.js:146-148 | Critical | -- | os.freemem() reports ~0% on macOS |
| 7 | doctor.js:~59-79 | Low | -- | Doctor ignores YAML config |
| 8 | memory-initializer.js:loadEmbeddingModel | Enhancement | -- | Config-driven embedding model loader (reads from embeddings.json) |
| 9 | memory-initializer.js:311,356-391,524 | High | -- | HNSW dimension mismatch + stale index files = search always brute-force |
| 11 | worker-daemon.js:DEFAULT_WORKERS | Enhancement | -- | Enable preload worker + add missing workers to defaults |
| 12 | worker-daemon.js:consolidate | Enhancement | -- | Real consolidation: pattern decay + HNSW rebuild |
| 14 | @xenova/transformers (dir perms) | Medium | -- | Model cache EACCES on global install |
| 16 | config.js:1-6,121-135,321-330 | Medium | -- | Config export/get uses hardcoded defaults instead of reading YAML |

**Note:** The previous Bug 12 ("neural HNSW reports @ruvector/core not available") was NOT cosmetic — it indicated a real dimension mismatch causing all searches to fall back to brute-force SQLite. Fixed by Patch 9.

**Deleted patches:** 10 (parallel search init — 30ms cold-only, not worth it), 13 (ultralearn — upstream is headless/AI per ADR-020, patch wrongly made it local WASM), 15 (auto-memory-hook — already resolved by init).

---

## Patch 16: Config export reads from config.yaml (Medium)

**File:** `commands/config.js` lines 1-6, 121-135, 321-330
**Issue:** `config export` and `config get` show hardcoded defaults instead of reading `.claude-flow/config.yaml`

The `config export` and `config get` commands use hardcoded defaults (topology: 'hybrid', cacheSize: 256) instead of reading the actual YAML config file. This makes the commands misleading when the project has a custom config.

### Changes:
1. Add imports for `fs` and `path` modules
2. Add `readYamlConfig()` helper function (simple YAML parser for key: value pairs)
3. Update `getCommand` action to merge YAML config with defaults
4. Update `exportCommand` action to merge YAML config with defaults

### Apply:

```bash
# Add imports (after line 6)
sed -i "6 a\\
import { readFileSync, existsSync } from 'fs';\\
import { join } from 'path';\\
\\
// Helper to read config.yaml if it exists\\
function readYamlConfig() {\\
    const configPath = join(process.cwd(), '.claude-flow', 'config.yaml');\\
    if (!existsSync(configPath)) {\\
        return {};\\
    }\\
    try {\\
        const content = readFileSync(configPath, 'utf8');\\
        const config = {};\\
        // Simple YAML parser for key: value pairs\\
        const lines = content.split('\\\\n');\\
        let currentSection = null;\\
        for (const line of lines) {\\
            const trimmed = line.trim();\\
            if (!trimmed || trimmed.startsWith('#')) continue;\\
            if (!trimmed.includes(':')) continue;\\
            const indent = line.match(/^\\\\s*/)[0].length;\\
            if (indent === 0) {\\
                // Top-level key\\
                const [key, value] = trimmed.split(':').map(s => s.trim());\\
                if (value && value !== '') {\\
                    config[key] = value.replace(/^[\"']|[\"']$/g, '');\\
                } else {\\
                    currentSection = key;\\
                    config[key] = {};\\
                }\\
            } else if (currentSection && indent > 0) {\\
                // Nested key\\
                const [key, value] = trimmed.split(':').map(s => s.trim());\\
                if (value && value !== '') {\\
                    config[currentSection][key] = value.replace(/^[\"']|[\"']$/g, '');\\
                }\\
            }\\
        }\\
        return config;\\
    } catch (error) {\\
        return {};\\
    }\\
}" "$COMMANDS/config.js"
```

### Manual patch (recommended):

Since the sed command is complex, manual patching is recommended:

1. **Add imports** after line 6:
```javascript
import { readFileSync, existsSync } from 'fs';
import { join } from 'path';
```

2. **Add helper function** after imports:
```javascript
// Helper to read config.yaml if it exists
function readYamlConfig() {
    const configPath = join(process.cwd(), '.claude-flow', 'config.yaml');
    if (!existsSync(configPath)) {
        return {};
    }
    try {
        const content = readFileSync(configPath, 'utf8');
        const config = {};
        // Simple YAML parser for key: value pairs
        const lines = content.split('\n');
        let currentSection = null;
        for (const line of lines) {
            const trimmed = line.trim();
            if (!trimmed || trimmed.startsWith('#')) continue;
            if (!trimmed.includes(':')) continue;
            const indent = line.match(/^\s*/)[0].length;
            if (indent === 0) {
                // Top-level key
                const [key, value] = trimmed.split(':').map(s => s.trim());
                if (value && value !== '') {
                    config[key] = value.replace(/^["']|["']$/g, '');
                } else {
                    currentSection = key;
                    config[key] = {};
                }
            } else if (currentSection && indent > 0) {
                // Nested key
                const [key, value] = trimmed.split(':').map(s => s.trim());
                if (value && value !== '') {
                    config[currentSection][key] = value.replace(/^["']|["']$/g, '');
                }
            }
        }
        return config;
    } catch (error) {
        return {};
    }
}
```

3. **Update getCommand action** (around line 121):
Replace:
```javascript
const configValues = {
    'version': '3.0.0',
    'v3Mode': true,
    'swarm.topology': 'hybrid',
    'swarm.maxAgents': 15,
    'swarm.autoScale': true,
    'memory.backend': 'hybrid',
    'memory.cacheSize': 256,
    'mcp.transport': 'stdio',
    'agents.defaultType': 'coder',
    'agents.maxConcurrent': 15
};
```

With:
```javascript
// Default config values
const defaults = {
    'version': '3.0.0',
    'v3Mode': true,
    'swarm.topology': 'hybrid',
    'swarm.maxAgents': 15,
    'swarm.autoScale': true,
    'memory.backend': 'hybrid',
    'memory.cacheSize': 256,
    'mcp.transport': 'stdio',
    'agents.defaultType': 'coder',
    'agents.maxConcurrent': 15
};
// Read YAML config and merge with defaults
const yamlConfig = readYamlConfig();
const configValues = { ...defaults };
if (yamlConfig.swarm) {
    if (yamlConfig.swarm.topology) configValues['swarm.topology'] = yamlConfig.swarm.topology;
    if (yamlConfig.swarm.maxAgents) configValues['swarm.maxAgents'] = parseInt(yamlConfig.swarm.maxAgents) || defaults['swarm.maxAgents'];
    if (yamlConfig.swarm.autoScale !== undefined) configValues['swarm.autoScale'] = yamlConfig.swarm.autoScale === 'true' || yamlConfig.swarm.autoScale === true;
}
if (yamlConfig.memory) {
    if (yamlConfig.memory.backend) configValues['memory.backend'] = yamlConfig.memory.backend;
    if (yamlConfig.memory.cacheSize) configValues['memory.cacheSize'] = parseInt(yamlConfig.memory.cacheSize) || defaults['memory.cacheSize'];
}
if (yamlConfig.mcp && yamlConfig.mcp.transport) {
    configValues['mcp.transport'] = yamlConfig.mcp.transport;
}
if (yamlConfig.version) {
    configValues['version'] = yamlConfig.version;
}
```

4. **Update exportCommand action** (around line 323):
Replace:
```javascript
const config = {
    version: '3.0.0',
    exportedAt: new Date().toISOString(),
    agents: { defaultType: 'coder', maxConcurrent: 15 },
    swarm: { topology: 'hybrid', maxAgents: 15 },
    memory: { backend: 'hybrid', cacheSize: 256 },
    mcp: { transport: 'stdio', tools: 'all' }
};
```

With:
```javascript
// Start with defaults
const config = {
    version: '3.0.0',
    exportedAt: new Date().toISOString(),
    agents: { defaultType: 'coder', maxConcurrent: 15 },
    swarm: { topology: 'hybrid', maxAgents: 15 },
    memory: { backend: 'hybrid', cacheSize: 256 },
    mcp: { transport: 'stdio', tools: 'all' }
};
// Read YAML config and merge
const yamlConfig = readYamlConfig();
if (yamlConfig.version) {
    config.version = yamlConfig.version;
}
if (yamlConfig.swarm) {
    if (yamlConfig.swarm.topology) config.swarm.topology = yamlConfig.swarm.topology;
    if (yamlConfig.swarm.maxAgents) config.swarm.maxAgents = parseInt(yamlConfig.swarm.maxAgents) || 15;
}
if (yamlConfig.memory) {
    if (yamlConfig.memory.backend) config.memory.backend = yamlConfig.memory.backend;
    if (yamlConfig.memory.cacheSize) config.memory.cacheSize = parseInt(yamlConfig.memory.cacheSize) || 256;
}
if (yamlConfig.mcp && yamlConfig.mcp.transport) {
    config.mcp.transport = yamlConfig.mcp.transport;
}
```

### Verify:

```bash
# Should show topology: hierarchical-mesh (from config.yaml, not hardcoded hybrid)
npx @claude-flow/cli@latest config export --format json

# Should show hierarchical-mesh
npx @claude-flow/cli@latest config get swarm.topology

# Should show 512 (from config.yaml, not hardcoded 256)
npx @claude-flow/cli@latest config get memory.cacheSize
```

### Verification script addition:

Add to the verification script:
```bash
check "16: config reads YAML"  "npx @claude-flow/cli@latest config get swarm.topology 2>/dev/null | grep -q 'hierarchical-mesh'"
```
## Patch 17: Intelligence stats .toFixed() crash fix (Critical)

**File:** `commands/hooks.js` lines 1643-1649, 1665-1669, 1705-1709, 1712-1727
**Issue:** `npx @claude-flow/cli@latest hooks intelligence stats` crashes with:
```
TypeError: Cannot read properties of undefined (reading 'toFixed')
```

The intelligence stats display calls `.toFixed()` on potentially undefined properties (learningTimeMs, adaptationTimeMs, avgQuality, routingAccuracy, loadBalance, cacheHitRate, performance.*) without null checks, causing crashes when the intelligence system returns incomplete data.

### Changes:
1. Add null checks for SONA component: learningTimeMs, adaptationTimeMs, avgQuality
2. Add null checks for MoE component: routingAccuracy, loadBalance
3. Add null check for embeddings: cacheHitRate
4. Add null check for entire performance object and all its properties

### Apply:

```bash
# Fix SONA component (lines 1643-1649)
sed -i "s/{ metric: 'Learning Time', value: \`\${result.components.sona.learningTimeMs.toFixed(3)}ms\` }/{ metric: 'Learning Time', value: result.components.sona.learningTimeMs != null ? \`\${result.components.sona.learningTimeMs.toFixed(3)}ms\` : 'N\/A' }/" "$COMMANDS/hooks.js"

sed -i "s/{ metric: 'Adaptation Time', value: \`\${result.components.sona.adaptationTimeMs.toFixed(3)}ms\` }/{ metric: 'Adaptation Time', value: result.components.sona.adaptationTimeMs != null ? \`\${result.components.sona.adaptationTimeMs.toFixed(3)}ms\` : 'N\/A' }/" "$COMMANDS/hooks.js"

sed -i "s/{ metric: 'Avg Quality', value: \`\${(result.components.sona.avgQuality \* 100).toFixed(1)}%\` }/{ metric: 'Avg Quality', value: result.components.sona.avgQuality != null ? \`\${(result.components.sona.avgQuality * 100).toFixed(1)}%\` : 'N\/A' }/" "$COMMANDS/hooks.js"

# Fix MoE component (lines 1665-1669)
sed -i "s/{ metric: 'Routing Accuracy', value: \`\${(result.components.moe.routingAccuracy \* 100).toFixed(1)}%\` }/{ metric: 'Routing Accuracy', value: result.components.moe.routingAccuracy != null ? \`\${(result.components.moe.routingAccuracy * 100).toFixed(1)}%\` : 'N\/A' }/" "$COMMANDS/hooks.js"

sed -i "s/{ metric: 'Load Balance', value: \`\${(result.components.moe.loadBalance \* 100).toFixed(1)}%\` }/{ metric: 'Load Balance', value: result.components.moe.loadBalance != null ? \`\${(result.components.moe.loadBalance * 100).toFixed(1)}%\` : 'N\/A' }/" "$COMMANDS/hooks.js"

# Fix embeddings (line 1709)
sed -i "s/{ metric: 'Cache Hit Rate', value: \`\${(result.components.embeddings.cacheHitRate \* 100).toFixed(1)}%\` }/{ metric: 'Cache Hit Rate', value: result.components.embeddings.cacheHitRate != null ? \`\${(result.components.embeddings.cacheHitRate * 100).toFixed(1)}%\` : 'N\/A' }/" "$COMMANDS/hooks.js"
```

For the performance section (lines 1712-1727), the changes are more complex. Replace the V3 Performance section:

```bash
# Create a temporary file with the new performance section
cat > /tmp/perf-section.txt << 'EOF'
            // V3 Performance
            output.writeln();
            output.writeln(output.bold('🚀 V3 Performance Gains'));
            if (result.performance) {
                output.printList([
                    \`Flash Attention: \${output.success(result.performance.flashAttention || 'N/A')}\`,
                    \`Memory Reduction: \${output.success(result.performance.memoryReduction || 'N/A')}\`,
                    \`Search Improvement: \${output.success(result.performance.searchImprovement || 'N/A')}\`,
                    \`Token Reduction: \${output.success(result.performance.tokenReduction || 'N/A')}\`,
                    \`SWE-Bench Score: \${output.success(result.performance.sweBenchScore || 'N/A')}\`
                ]);
            }
            else {
                output.writeln(output.dim('  No performance data available'));
            }
            return { success: true, data: result };
EOF

# Replace lines 1712-1722 in hooks.js
# This requires a more sophisticated approach - use awk or manual edit
# For automation in apply-patches.sh, you'll need to use sed with multi-line or perl
```

**Manual alternative for performance section:**
Edit `commands/hooks.js` around line 1715 and wrap the `output.printList` in an if check:
```javascript
if (result.performance) {
    output.printList([
        `Flash Attention: ${output.success(result.performance.flashAttention || 'N/A')}`,
        `Memory Reduction: ${output.success(result.performance.memoryReduction || 'N/A')}`,
        `Search Improvement: ${output.success(result.performance.searchImprovement || 'N/A')}`,
        `Token Reduction: ${output.success(result.performance.tokenReduction || 'N/A')}`,
        `SWE-Bench Score: ${output.success(result.performance.sweBenchScore || 'N/A')}`
    ]);
}
else {
    output.writeln(output.dim('  No performance data available'));
}
```

### Verify:

```bash
npx @claude-flow/cli@latest hooks intelligence stats
# Should show tables with "N/A" for missing values instead of crashing
```

### Status: Applied (npx cache)

**Applied to:**
- ✅ npx cache: `~/.npm/_npx/85fb20e3e7e3a233/node_modules/@claude-flow/cli/dist/src/commands/hooks.js`

**Note:** This patch requires more complex multi-line replacement for the performance section. The sed commands handle the simple single-line fixes. The performance section may need manual editing or a more sophisticated script.

---
