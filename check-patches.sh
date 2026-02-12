#!/bin/bash
# Patch sentinel — checks if claude-flow patches are applied
# On session start: detects wipe, auto-reapplies, warns user

MEMORY=$(find ~/.npm/_npx -name "memory-initializer.js" -path "*/memory/*" 2>/dev/null | head -1)
SERVICES=$(find ~/.npm/_npx -name "worker-daemon.js" -path "*/services/*" 2>/dev/null | head -1)

if [ -z "$MEMORY" ] || [ -z "$SERVICES" ]; then
  echo "[PATCHES] WARN: Cannot find claude-flow CLI files"
  exit 0
fi

VERSION=$(grep -o '"version":"[^"]*"' "$(dirname "$MEMORY")/../../package.json" 2>/dev/null | cut -d'"' -f4)
COMMANDS_DIR=$(dirname "$SERVICES")/../commands

# Quick check: Patch 8 (Nomic) + Patch 11 (preload worker) + Patch 13 (ultralearn)
if grep -q "nomic-embed-text-v1" "$MEMORY" 2>/dev/null \
   && grep -q "maxCpuLoad: 6" "$SERVICES" 2>/dev/null \
   && grep -q "loadEmbeddingModel" "$SERVICES" 2>/dev/null \
   && grep -q "initializeTraining" "$SERVICES" 2>/dev/null; then
  echo "[PATCHES] OK: All patches verified (v$VERSION)"
  exit 0
fi

# Patches wiped — auto-reapply
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
echo "[PATCHES] Version update detected (v$VERSION) — patches wiped, auto-reapplying..."

if [ -x "$SCRIPT_DIR/apply-patches.sh" ]; then
  bash "$SCRIPT_DIR/apply-patches.sh"
  echo "[PATCHES] Reapplied. Daemon restart recommended: npx @claude-flow/cli daemon stop && npx @claude-flow/cli daemon start"
else
  echo "[PATCHES] ERROR: apply-patches.sh not found at $SCRIPT_DIR"
  echo "[PATCHES] Run manually: bash scripts/apply-patches.sh"
fi
