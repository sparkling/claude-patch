#!/bin/bash
# patch-all.sh — Orchestrator for folder-per-issue patches
# Safe to run multiple times. Each fix.py is idempotent via patch()/patch_all().

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

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Concatenate common.py + all fix.py files in explicit order, then run as one python3 process.
# Order matters: NS-002 must run before NS-003 (typo fix depends on namespace enforcement).
python3 <(
    cat "$SCRIPT_DIR/lib/common.py"

    # Daemon & Worker
    for d in \
        HW-001-stdin-hang \
        HW-002-failures-swallowed \
        HW-003-aggressive-intervals \
        DM-001-daemon-log-zero \
        DM-002-cpu-load-threshold \
        DM-003-macos-freemem \
        DM-004-preload-worker-stub \
        DM-005-consolidation-worker-stub; do
        fix="$SCRIPT_DIR/$d/fix.py"
        [ -f "$fix" ] && cat "$fix"
    done

    # Config & Doctor
    for d in \
        CF-001-doctor-yaml \
        CF-002-config-export-yaml; do
        fix="$SCRIPT_DIR/$d/fix.py"
        [ -f "$fix" ] && cat "$fix"
    done

    # Embedding & HNSW (EM-002 is fix.sh, handled separately)
    fix="$SCRIPT_DIR/EM-001-embedding-ignores-config/fix.py"
    [ -f "$fix" ] && cat "$fix"

    # Display & Cosmetic
    for d in \
        UI-001-intelligence-stats-crash \
        UI-002-neural-status-not-loaded; do
        fix="$SCRIPT_DIR/$d/fix.py"
        [ -f "$fix" ] && cat "$fix"
    done

    # Memory Namespace (order matters: NS-001 before NS-002 before NS-003)
    for d in \
        NS-001-discovery-default-namespace \
        NS-002-targeted-require-namespace \
        NS-003-namespace-typo-pattern; do
        fix="$SCRIPT_DIR/$d/fix.py"
        [ -f "$fix" ] && cat "$fix"
    done

    # Ghost Vector cleanup
    fix="$SCRIPT_DIR/GV-001-hnsw-ghost-vectors/fix.py"
    [ -f "$fix" ] && cat "$fix"

    echo 'print(f"\n[PATCHES] Done: {applied} applied, {skipped} already present")'
)

# EM-002: transformers cache permissions (shell-based, optional)
if [ -f "$SCRIPT_DIR/EM-002-transformers-cache-eacces/fix.sh" ]; then
    bash "$SCRIPT_DIR/EM-002-transformers-cache-eacces/fix.sh" 2>/dev/null || true
fi
