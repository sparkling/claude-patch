#!/bin/bash
# Auto-apply all claude-flow patches (1-13) to the active npx cache.
# Safe to run multiple times. Uses python3 for reliable multiline replacements.

set -euo pipefail

# Find the active npx cache (most recently modified)
MEMORY=$(ls -t ~/.npm/_npx/*/node_modules/@claude-flow/cli/dist/src/memory/memory-initializer.js 2>/dev/null | head -1)
if [ -z "$MEMORY" ]; then
  echo "[PATCHES] No claude-flow CLI found in npx cache"
  exit 1
fi

export BASE=$(echo "$MEMORY" | sed 's|/memory/memory-initializer.js||')
SERVICES="$BASE/services"
COMMANDS="$BASE/commands"
VERSION=$(grep -o '"version": "[^"]*"' "$BASE/../../package.json" 2>/dev/null | head -1 | cut -d'"' -f4)

echo "[PATCHES] Patching v$VERSION at: $BASE"

python3 << 'PYEOF'
import sys, os, re

base = os.environ.get("BASE") or sys.exit("No BASE")
services = base + "/services"
commands = base + "/commands"
memory = base + "/memory"

applied = 0
skipped = 0

def patch(label, filepath, old, new):
    global applied, skipped
    try:
        with open(filepath, 'r') as f:
            code = f.read()
        if new in code:
            skipped += 1
            return
        if old not in code:
            print(f"  WARN: {label} — pattern not found (code may have changed)")
            return
        code = code.replace(old, new, 1)
        with open(filepath, 'w') as f:
            f.write(code)
        print(f"  Applied: {label}")
        applied += 1
    except Exception as e:
        print(f"  ERROR: {label} — {e}")

def patch_all(label, filepath, old, new):
    """Replace ALL occurrences"""
    global applied, skipped
    try:
        with open(filepath, 'r') as f:
            code = f.read()
        if new in code and old not in code:
            skipped += 1
            return
        if old not in code:
            print(f"  WARN: {label} — pattern not found")
            return
        code = code.replace(old, new)
        with open(filepath, 'w') as f:
            f.write(code)
        print(f"  Applied: {label}")
        applied += 1
    except Exception as e:
        print(f"  ERROR: {label} — {e}")

HWE = services + "/headless-worker-executor.js"
WD = services + "/worker-daemon.js"
DJ = commands + "/daemon.js"
DOC = commands + "/doctor.js"
MI = memory + "/memory-initializer.js"

# ── Patch 1: stdin pipe fix ──
patch("1: stdin pipe",
    HWE,
    "stdio: ['pipe', 'pipe', 'pipe']",
    "stdio: ['ignore', 'pipe', 'pipe']")

# ── Patch 2: honest failure reporting ──
patch("2: honest failures",
    WD,
    """        if (isHeadlessWorker(workerConfig.type) && this.headlessAvailable && this.headlessExecutor) {
            try {
                this.log('info', `Running ${workerConfig.type} in headless mode (Claude Code AI)`);
                const result = await this.headlessExecutor.execute(workerConfig.type);
                return {
                    mode: 'headless',
                    ...result,
                };
            }
            catch (error) {
                this.log('warn', `Headless execution failed for ${workerConfig.type}, falling back to local mode`);
                this.emit('headless:fallback', {
                    type: workerConfig.type,
                    error: error instanceof Error ? error.message : String(error),
                });
                // Fall through to local execution
            }
        }""",
    """        if (isHeadlessWorker(workerConfig.type) && this.headlessAvailable && this.headlessExecutor) {
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
        }""")

# ── Patch 3: interval alignment ──
patch("3: audit 30m",
    WD,
    "type: 'audit', intervalMs: 10 * 60 * 1000",
    "type: 'audit', intervalMs: 30 * 60 * 1000")

patch("3: optimize 60m",
    WD,
    "type: 'optimize', intervalMs: 15 * 60 * 1000",
    "type: 'optimize', intervalMs: 60 * 60 * 1000")

patch("3: testgaps 60m",
    WD,
    "type: 'testgaps', intervalMs: 20 * 60 * 1000",
    "type: 'testgaps', intervalMs: 60 * 60 * 1000")

# ── Patch 4A: appendFileSync import ──
patch("4A: appendFileSync import",
    WD,
    "import { existsSync, mkdirSync, writeFileSync, readFileSync } from 'fs';",
    "import { existsSync, mkdirSync, writeFileSync, readFileSync, appendFileSync } from 'fs';")

# ── Patch 4B: replace require('fs') ──
patch("4B: remove require('fs')",
    WD,
    """            const fs = require('fs');
            fs.appendFileSync(logFile, logMessage + '\\n');""",
    "            appendFileSync(logFile, logMessage + '\\n');")

# ── Patch 4C: daemon log path ──
patch("4C: daemon log path",
    DJ,
    """    const logFile = join(stateDir, 'daemon.log');
    // Validate all paths
    validatePath(stateDir, 'State directory');
    validatePath(pidFile, 'PID file');
    validatePath(logFile, 'Log file');
    // Ensure state directory exists
    if (!fs.existsSync(stateDir)) {
        fs.mkdirSync(stateDir, { recursive: true });
    }""",
    """    const logsDir = join(stateDir, 'logs');
    if (!fs.existsSync(logsDir)) {
        fs.mkdirSync(logsDir, { recursive: true });
    }
    const logFile = join(logsDir, 'daemon.log');
    // Validate all paths
    validatePath(stateDir, 'State directory');
    validatePath(pidFile, 'PID file');
    validatePath(logFile, 'Log file');
    // Ensure state directory exists
    if (!fs.existsSync(stateDir)) {
        fs.mkdirSync(stateDir, { recursive: true });
    }""")

# ── Patch 5: CPU load threshold ──
# NOTE: Default in doc is 6.0 for 8-core. Adjust per machine.
# 32-core server: 28.0. 8-core Mac: 6.0.
patch("5: CPU load threshold",
    WD,
    "maxCpuLoad: 2.0",
    "maxCpuLoad: 28.0")

# ── Patch 6: macOS memory skip ──
patch("6: macOS memory",
    WD,
    "if (freePercent < this.config.resourceThresholds.minFreeMemoryPercent) {",
    "if (os.platform() !== 'darwin' && freePercent < this.config.resourceThresholds.minFreeMemoryPercent) {")

# ── Patch 7: YAML config support ──
patch("7: YAML config",
    DOC,
    """    const configPaths = [
        '.claude-flow/config.json',
        'claude-flow.config.json',
        '.claude-flow.json'
    ];""",
    """    const configPaths = [
        '.claude-flow/config.json',
        'claude-flow.config.json',
        '.claude-flow.json',
        '.claude-flow/config.yaml',
        '.claude-flow/config.yml'
    ];""")

patch("7: YAML JSON.parse skip",
    DOC,
    "                JSON.parse(content);",
    "                if (configPath.endsWith('.json')) { JSON.parse(content); }")

# ── Patch 8: Config-driven embedding model loader ──
patch("8: config-driven model",
    MI,
    """        // Try to import @xenova/transformers for ONNX embeddings
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
        }""",
    """        // Patch 8: Read embedding model from project config instead of hardcoding
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
        // Try to import @xenova/transformers for ONNX embeddings
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
        }""")

# ── Patch 9: HNSW dimension fix ──
patch("9: HNSW dim default",
    MI,
    "    const dimensions = options?.dimensions ?? 384;",
    """    // Patch 9: Read dims from embeddings.json
    let dimensions = options?.dimensions;
    if (!dimensions) {
        try {
            const embConfigPath = path.join(process.cwd(), '.claude-flow', 'embeddings.json');
            if (fs.existsSync(embConfigPath)) {
                const embConfig = JSON.parse(fs.readFileSync(embConfigPath, 'utf-8'));
                dimensions = embConfig.dimension || 768;
            }
        } catch { /* ignore */ }
        dimensions = dimensions || 768;
    }""")

# Patch 9: stale file cleanup on forceRebuild
patch("9: HNSW stale cleanup",
    MI,
    """        const dbPath = options?.dbPath || path.join(swarmDir, 'memory.db');
        // Create HNSW index with persistent storage""",
    """        const dbPath = options?.dbPath || path.join(swarmDir, 'memory.db');
        // Patch 9: delete stale persistent files on forceRebuild
        if (options?.forceRebuild) {
            try:
                if (fs.existsSync(hnswPath)) fs.unlinkSync(hnswPath);
            catch {}
            try:
                if (fs.existsSync(metadataPath)) fs.unlinkSync(metadataPath);
            catch {}
        }
        // Create HNSW index with persistent storage""".replace("try:", "try {").replace("catch {}", "} catch {}"))

# Patch 9: guard metadata on forceRebuild
patch("9: HNSW metadata guard",
    MI,
    "        if (fs.existsSync(metadataPath)) {",
    "        if (!options?.forceRebuild && fs.existsSync(metadataPath)) {")

# Patch 9: guard early return on forceRebuild
patch("9: HNSW early-return guard",
    MI,
    "        if (existingLen > 0 && entries.size > 0) {",
    "        if (existingLen > 0 && entries.size > 0 && !options?.forceRebuild) {")

# Patch 9: status default
patch("9: HNSW status default",
    MI,
    "dimensions: hnswIndex?.dimensions ?? 384",
    "dimensions: hnswIndex?.dimensions ?? 768")

# ── Patch 10: DELETED (parallel search init — ~30ms cold only, not worth it) ──

# ── Patch 11: Enable + implement preload worker ──
# The preload worker is disabled by default and is a stub.
# Enable it and make it pre-warm the embedding model + HNSW index.
# Add missing workers to DEFAULT_WORKERS (they exist in switch but not in defaults)
patch("11: add missing workers to defaults",
    WD,
    "    { type: 'document', intervalMs: 60 * 60 * 1000, offsetMs: 0, priority: 'low', description: 'Auto-documentation', enabled: false },\n];",
    """    { type: 'document', intervalMs: 60 * 60 * 1000, offsetMs: 0, priority: 'low', description: 'Auto-documentation', enabled: false },
    { type: 'ultralearn', intervalMs: 0, offsetMs: 0, priority: 'normal', description: 'Deep knowledge acquisition (headless, manual trigger)', enabled: false },
    { type: 'deepdive', intervalMs: 4 * 60 * 60 * 1000, offsetMs: 0, priority: 'low', description: 'Deep code analysis', enabled: false },
    { type: 'refactor', intervalMs: 4 * 60 * 60 * 1000, offsetMs: 0, priority: 'low', description: 'Refactoring suggestions', enabled: false },
    { type: 'benchmark', intervalMs: 2 * 60 * 60 * 1000, offsetMs: 0, priority: 'low', description: 'Performance benchmarking', enabled: false },
    { type: 'preload', intervalMs: 10 * 60 * 1000, offsetMs: 0, priority: 'high', description: 'Embedding model + HNSW preload', enabled: true },
];""")

patch("11: real preload worker",
    WD,
    """    async runPreloadWorkerLocal() {
        return {
            timestamp: new Date().toISOString(),
            mode: 'local',
            resourcesPreloaded: 0,
            cacheStatus: 'active',
        };
    }""",
    """    async runPreloadWorkerLocal() {
        const result = { timestamp: new Date().toISOString(), mode: 'local', resourcesPreloaded: 0, cacheStatus: 'active' };
        try {
            const mi = await import('../memory/memory-initializer.js');
            const modelResult = await mi.loadEmbeddingModel({ verbose: false });
            if (modelResult.success) { result.resourcesPreloaded++; result.embeddingModel = modelResult.modelName; }
            const hnswResult = await mi.getHNSWIndex();
            if (hnswResult) { result.resourcesPreloaded++; result.hnswEntries = hnswResult.entries?.size ?? 0; }
        } catch (e) { result.error = e?.message || String(e); }
        return result;
    }""")

# ── Patch 12: Real consolidation worker ──
# The consolidate worker is a stub. Make it call pattern decay + rebuild HNSW.
patch("12: real consolidate worker",
    WD,
    """    async runConsolidateWorker() {
        // Memory consolidation - clean up old patterns
        const consolidateFile = join(this.projectRoot, '.claude-flow', 'metrics', 'consolidation.json');
        const metricsDir = join(this.projectRoot, '.claude-flow', 'metrics');
        if (!existsSync(metricsDir)) {
            mkdirSync(metricsDir, { recursive: true });
        }
        const result = {
            timestamp: new Date().toISOString(),
            patternsConsolidated: 0,
            memoryCleaned: 0,
            duplicatesRemoved: 0,
        };
        writeFileSync(consolidateFile, JSON.stringify(result, null, 2));
        return result;
    }""",
    """    async runConsolidateWorker() {
        const consolidateFile = join(this.projectRoot, '.claude-flow', 'metrics', 'consolidation.json');
        const metricsDir = join(this.projectRoot, '.claude-flow', 'metrics');
        if (!existsSync(metricsDir)) {
            mkdirSync(metricsDir, { recursive: true });
        }
        const result = {
            timestamp: new Date().toISOString(),
            patternsConsolidated: 0,
            memoryCleaned: 0,
            duplicatesRemoved: 0,
        };
        try {
            const mi = await import('../memory/memory-initializer.js');
            // 1. Apply temporal decay (reduce confidence of stale patterns)
            const decayResult = await mi.applyTemporalDecay();
            if (decayResult?.success) result.patternsConsolidated = decayResult.patternsDecayed || 0;
            // 2. Rebuild HNSW index with current data
            mi.clearHNSWIndex();
            const hnsw = await mi.getHNSWIndex({ forceRebuild: true });
            if (hnsw) result.hnswRebuilt = hnsw.entries?.size ?? 0;
            result.memoryCleaned = 1;
        } catch (e) { result.error = e?.message || String(e); }
        writeFileSync(consolidateFile, JSON.stringify(result, null, 2));
        return result;
    }""")

# ── Patch 13: DELETED (ultralearn is headless/AI-powered per ADR-020, not local WASM) ──

# ── Patch 19: MCP memory_search namespace default ──
# Bug: MCP defaults to namespace='default', CLI defaults to 'all'.
# All entries are in 'patterns' namespace, so MCP search always returns 0.
# Threshold stays at 0.3 — matches CLI (memory.js:266), searchEntries() (memory-initializer.js:1615),
# and is consistent with ADR-024 embeddings/search using 0.5.
# See: https://github.com/ruvnet/claude-flow/issues/1131
MCP_MEMORY = base + "/mcp-tools/memory-tools.js"
MCP_HOOKS = base + "/mcp-tools/hooks-tools.js"
CLI_MEMORY = commands + "/memory.js"

# Use unique context (const query) to target memory_search specifically, not memory_store
patch("19: MCP search namespace default",
    MCP_MEMORY,
    "const query = input.query;\n            const namespace = input.namespace || 'default';",
    "const query = input.query;\n            const namespace = input.namespace || 'all';")

patch("19: MCP search namespace description",
    MCP_MEMORY,
    """namespace: { type: 'string', description: 'Namespace to search (default: "default")' }""",
    """namespace: { type: 'string', description: 'Namespace to search (default: "all" = all namespaces)' }""")

# ── Patch 20: Enforce --namespace on write ops + fix 'pattern' typo ──
# Makes namespace required on store/delete to prevent silent misrouting to 'default'.
# Fixes inconsistent 'pattern' (singular) vs 'patterns' (plural) in hooks-tools.js.
# See: https://github.com/ruvnet/claude-flow/issues/1131

# 20a: MCP memory_store — require namespace in schema (unique pattern)
patch("20a: MCP store require namespace",
    MCP_MEMORY,
    "required: ['key', 'value'],",
    "required: ['key', 'value', 'namespace'],")

# 20b: MCP memory_store — remove || 'default' fallback + add runtime check
# (MCP framework does NOT enforce 'required' server-side, so handler must check)
patch("20b: MCP store namespace no fallback",
    MCP_MEMORY,
    "const namespace = input.namespace || 'default';\n            const value = typeof",
    "const namespace = input.namespace;\n            if (!namespace) {\n                throw new Error('Namespace is required. Use namespace: \"patterns\", \"solutions\", or \"tasks\"');\n            }\n            const value = typeof")

# 20c: MCP memory_delete — require namespace + update description
patch("20c: MCP delete require namespace",
    MCP_MEMORY,
    """        description: 'Delete a memory entry by key',
        category: 'memory',
        inputSchema: {
            type: 'object',
            properties: {
                key: { type: 'string', description: 'Memory key' },
                namespace: { type: 'string', description: 'Namespace (default: "default")' },
            },
            required: ['key'],""",
    """        description: 'Delete a memory entry by key',
        category: 'memory',
        inputSchema: {
            type: 'object',
            properties: {
                key: { type: 'string', description: 'Memory key' },
                namespace: { type: 'string', description: 'Namespace (e.g. "patterns", "solutions", "tasks")' },
            },
            required: ['key', 'namespace'],""")

# 20d: MCP memory_delete — remove || 'default' fallback + add runtime check
patch("20d: MCP delete namespace no fallback",
    MCP_MEMORY,
    "const { deleteEntry } = await getMemoryFunctions();\n            const key = input.key;\n            const namespace = input.namespace || 'default';",
    "const { deleteEntry } = await getMemoryFunctions();\n            const key = input.key;\n            const namespace = input.namespace;\n            if (!namespace) {\n                throw new Error('Namespace is required. Use namespace: \"patterns\", \"solutions\", or \"tasks\"');\n            }")

# 20e: CLI memory store — add namespace-required check after key check
patch("20e: CLI store require namespace",
    CLI_MEMORY,
    """        if (!key) {
            output.printError('Key is required. Use --key or -k');
            return { success: false, exitCode: 1 };
        }
        if (!value && ctx.interactive) {""",
    """        if (!key) {
            output.printError('Key is required. Use --key or -k');
            return { success: false, exitCode: 1 };
        }
        if (!namespace) {
            output.printError('Namespace is required. Use --namespace or -n (e.g. "patterns", "solutions", "tasks")');
            return { success: false, exitCode: 1 };
        }
        if (!value && ctx.interactive) {""")

# 20f: CLI memory delete — remove || 'default' fallback and add namespace check
patch("20f: CLI delete namespace no fallback",
    CLI_MEMORY,
    "const namespace = ctx.flags.namespace || 'default';\n        const force = ctx.flags.force;\n        if (!key) {\n            output.printError('Key is required. Use: memory delete -k \"key\" [-n \"namespace\"]');",
    "const namespace = ctx.flags.namespace;\n        const force = ctx.flags.force;\n        if (!key) {\n            output.printError('Key is required. Use: memory delete -k \"key\" -n \"namespace\"');")

patch("20f: CLI delete namespace check",
    CLI_MEMORY,
    """            output.printError('Key is required. Use: memory delete -k "key" -n "namespace"');
            return { success: false, exitCode: 1 };
        }
        if (!force && ctx.interactive) {""",
    """            output.printError('Key is required. Use: memory delete -k "key" -n "namespace"');
            return { success: false, exitCode: 1 };
        }
        if (!namespace) {
            output.printError('Namespace is required. Use: memory delete -k "key" -n "namespace" (e.g. "patterns", "solutions", "tasks")');
            return { success: false, exitCode: 1 };
        }
        if (!force && ctx.interactive) {""")

# 20g: hooks-tools.js — fix 'pattern' (singular) → 'patterns' (plural)
patch("20g: hooks pattern-store namespace",
    MCP_HOOKS,
    "namespace: 'pattern',",
    "namespace: 'patterns',")

patch("20g: hooks pattern-search default",
    MCP_HOOKS,
    "const namespace = params.namespace || 'pattern';",
    "const namespace = params.namespace || 'patterns';")

patch("20g: hooks pattern-search description",
    MCP_HOOKS,
    "description: 'Namespace to search (default: pattern)'",
    "description: 'Namespace to search (default: patterns)'")

patch("20g: hooks pattern-search note",
    MCP_HOOKS,
    'namespace "pattern".',
    'namespace "patterns".')

print(f"\n[PATCHES] Done: {applied} applied, {skipped} already present")
PYEOF
