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

## Patch 8: Nomic Embed Text v1 — upgrade default embedding model (Enhancement)

**File:** `memory/memory-initializer.js` lines 1162, 1166, 1171, 1175, 1176 (inside `loadEmbeddingModel()`)

**Previously:** This slot held an OpenAI embedding provider patch that added cloud API support. That patch has been **replaced** with a simpler 3-line model swap to a better local ONNX model.

CLI hardcodes `Xenova/all-MiniLM-L6-v2` (384-dim, MTEB 56.3, 512 token context). The `--embedding-model` CLI flag writes to `embeddings.json` but the loader never reads it. This patch switches to `Xenova/nomic-embed-text-v1` (768-dim, MTEB 62.3, 8192 token context, Matryoshka embeddings).

**Why Nomic over MiniLM:**
- +6.0 MTEB points (62.3 vs 56.3) — better pattern matching and routing accuracy
- 8192 token context (vs 512) — daemon workers can analyze full files
- Matryoshka embeddings — truncate to 256d for speed without re-embedding
- 86.2% BEIR retrieval accuracy (vs 78.1% for MiniLM)
- ~100MB model, works with existing `@xenova/transformers@2.17.2`

**Patch** (5 lines in `memory-initializer.js`):

```javascript
// Line 1162 — update log message
// BEFORE:
                console.log('Loading ONNX embedding model (all-MiniLM-L6-v2)...');
// AFTER:
                console.log('Loading ONNX embedding model (nomic-embed-text-v1)...');

// Line 1166 — change model identifier
// BEFORE:
            const embedder = await pipeline('feature-extraction', 'Xenova/all-MiniLM-L6-v2');
// AFTER:
            const embedder = await pipeline('feature-extraction', 'Xenova/nomic-embed-text-v1');

// Line 1171 — change dimensions in state object
// BEFORE:
                dimensions: 384 // MiniLM-L6 produces 384-dim vectors
// AFTER:
                dimensions: 768 // Nomic Embed Text v1 produces 768-dim vectors

// Line 1175 — change dimensions in return value
// BEFORE:
                dimensions: 384,
// AFTER:
                dimensions: 768,

// Line 1176 — change model name in return value
// BEFORE:
                modelName: 'all-MiniLM-L6-v2',
// AFTER:
                modelName: 'nomic-embed-text-v1',
```

**sed commands:**
```bash
sed -i "s|'Xenova/all-MiniLM-L6-v2'|'Xenova/nomic-embed-text-v1'|" "$MEMORY/memory-initializer.js"
sed -i "s|dimensions: 384 // MiniLM-L6 produces 384-dim vectors|dimensions: 768 // Nomic Embed Text v1 produces 768-dim vectors|" "$MEMORY/memory-initializer.js"
sed -i "s|dimensions: 384,|dimensions: 768,|" "$MEMORY/memory-initializer.js"
sed -i "s|modelName: 'all-MiniLM-L6-v2'|modelName: 'nomic-embed-text-v1'|" "$MEMORY/memory-initializer.js"
sed -i "s|Loading ONNX embedding model (all-MiniLM-L6-v2)|Loading ONNX embedding model (nomic-embed-text-v1)|" "$MEMORY/memory-initializer.js"
```

**Also update** `.claude-flow/embeddings.json` per-project:
```json
{
  "provider": "transformers",
  "model": "Xenova/nomic-embed-text-v1",
  "dimension": 768
}
```

**After patching:** Clear memory and re-init (vectors change dimensionality):
```bash
npx @claude-flow/cli@latest memory init --force --verbose
npx @claude-flow/cli@latest hooks pretrain --model-type moe --epochs 10
npx @claude-flow/cli@latest embeddings warmup
```

**Revert:** Reverse the sed commands (swap model names and dims back), or reinstall the CLI.

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

## Patch 10: Parallel search initialization (Enhancement)

**File:** `memory/memory-initializer.js` `searchEntries()` function
**Impact:** Shaves ~30ms off cold search; pre-warms HNSW index while ONNX model loads

The `searchEntries()` function runs three independent initialization steps sequentially:
1. `ensureSchemaColumns(dbPath)` — schema migration check (~5ms)
2. `generateEmbedding(query)` — triggers ONNX model load on first call (~450ms)
3. `searchHNSWIndex(queryEmbedding)` — initializes HNSW if needed (~30ms)

Steps 1 and 3 are independent of step 2's input. Running all three in parallel via `Promise.all` means HNSW is pre-warmed by the time the embedding is ready.

```diff
-        await ensureSchemaColumns(dbPath);
-        const queryEmb = await generateEmbedding(query);
-        const queryEmbedding = queryEmb.embedding;
-        const hnswResults = await searchHNSWIndex(queryEmbedding, { k: limit, namespace });
+        // Patch 10: Parallel schema check + embedding gen + HNSW warm-up
+        const [, queryEmb] = await Promise.all([
+            ensureSchemaColumns(dbPath),
+            generateEmbedding(query),
+            getHNSWIndex() // Pre-warm HNSW while model loads
+        ]);
+        const queryEmbedding = queryEmb.embedding;
+        const hnswResults = await searchHNSWIndex(queryEmbedding, { k: limit, namespace });
```

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

## Patch 13: Real ultralearn worker (Enhancement)

**File:** `services/worker-daemon.js` `runUltralearnWorkerLocal()`
**Impact:** Initializes WASM-accelerated neural training pipeline

The ultralearn worker was a stub. Now it:
1. Initializes `ruvector-training.js` with MicroLoRA, ScopedLoRA, FlashAttention, SONA, AdamW, InfoNCE
2. Runs SONA background tick for pattern consolidation
3. Applies reward-based adaptation from trajectory statistics

**Verified output:**
```json
{
  "insightsGained": ["Training init: MicroLoRA (256-dim, <1μs adaptation), ScopedLoRA (17 operators), TrajectoryBuffer, FlashAttention, AdamW Optimizer, InfoNCE Loss, SONA (256-dim, rank-4, 624k learn/s)"],
  "sonaEnabled": true
}
```

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

## Patch 15: auto-memory-hook.mjs missing after init (Medium)

**Applies to:** Per-project
**Issue:** [#1107](https://github.com/ruvnet/claude-flow/issues/1107)

`claude-flow init` writes `settings.json` referencing `.claude/helpers/auto-memory-hook.mjs` but fails to copy the file. Root cause: `findSourceHelpersDir()` uses `hook-handler.cjs` as a sentinel, which doesn't exist at init time.

**Fix:** Copy from installed package:
```bash
SOURCE=$(find $(npm root -g)/claude-flow -name "auto-memory-hook.mjs" -path "*/.claude/helpers/*" 2>/dev/null | head -1)
[ -z "$SOURCE" ] && SOURCE=$(find ~/.npm/_npx -name "auto-memory-hook.mjs" -path "*/.claude/helpers/*" 2>/dev/null | head -1)
[ -n "$SOURCE" ] && cp "$SOURCE" .claude/helpers/auto-memory-hook.mjs && echo "OK" || echo "ERROR: not found"
```

**Also fix CWD issue:** Claude Code runs Stop hooks with CWD = `.claude/helpers/`, doubling relative paths. Use absolute paths in `settings.json`:
```json
{
  "hooks": {
    "SessionStart": [{ "hooks": [{
      "command": "node \"$(git rev-parse --show-toplevel 2>/dev/null || echo .)/.claude/helpers/auto-memory-hook.mjs\" import",
      "timeout": 8000, "continueOnError": true
    }]}],
    "Stop": [{ "hooks": [{
      "command": "node \"$(git rev-parse --show-toplevel 2>/dev/null || echo .)/.claude/helpers/auto-memory-hook.mjs\" sync",
      "timeout": 8000, "continueOnError": true
    }]}]
  }
}
```

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
check "8: Nomic embed model"   "grep -q 'nomic-embed-text-v1' '$MEMORY/memory-initializer.js'"
check "9: HNSW dim from config" "grep -q 'embeddings.json' '$MEMORY/memory-initializer.js'"
check "9: HNSW stale cleanup"   "grep -q 'forceRebuild.*unlinkSync\|Patch 9A' '$MEMORY/memory-initializer.js'"
check "10: parallel search"     "grep -q 'Promise.all' '$MEMORY/memory-initializer.js'"
check "11: preload in defaults" "grep -q 'Embedding model' '$SERVICES/worker-daemon.js'"
check "11: real preload"        "grep -q 'loadEmbeddingModel' '$SERVICES/worker-daemon.js'"
check "12: real consolidate"    "grep -q 'applyTemporalDecay' '$SERVICES/worker-daemon.js'"
check "13: real ultralearn"     "grep -q 'initializeTraining' '$SERVICES/worker-daemon.js'"
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

# Patch 15: auto-memory-hook
ls -la .claude/helpers/auto-memory-hook.mjs
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
| 8 | memory-initializer.js:1162-1176 | Enhancement | -- | Upgrade embedding model to Nomic Embed Text v1 (768d, 8192 ctx) |
| 9 | memory-initializer.js:311,356-391,524 | High | -- | HNSW dimension mismatch + stale index files = search always brute-force |
| 10 | memory-initializer.js:searchEntries | Enhancement | -- | Parallel search init (schema + embedding + HNSW warm-up) |
| 11 | worker-daemon.js:DEFAULT_WORKERS | Enhancement | -- | Enable preload worker + add missing workers to defaults |
| 12 | worker-daemon.js:consolidate | Enhancement | -- | Real consolidation: pattern decay + HNSW rebuild |
| 13 | worker-daemon.js:ultralearn | Enhancement | -- | Real ultralearn: WASM neural training + SONA |
| 14 | @xenova/transformers (dir perms) | Medium | -- | Model cache EACCES on global install |
| 15 | Per-project setup | Medium | [#1107](https://github.com/ruvnet/claude-flow/issues/1107) | auto-memory-hook.mjs missing + CWD fix |

**Note:** The previous Bug 12 ("neural HNSW reports @ruvector/core not available") was NOT cosmetic — it indicated a real dimension mismatch causing all searches to fall back to brute-force SQLite. Fixed by Patch 9.
