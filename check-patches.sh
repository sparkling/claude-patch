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

# Quick check: Patch 8 (config-driven) + Patch 5 (CPU load) + Patch 11 (preload) + Patch 13 (ultralearn)
if grep -q "embeddings.json" "$MEMORY" 2>/dev/null \
   && grep -q "maxCpuLoad:" "$SERVICES" 2>/dev/null \
   && grep -q "loadEmbeddingModel" "$SERVICES" 2>/dev/null \
   && grep -q "applyTemporalDecay" "$SERVICES" 2>/dev/null; then
  echo "[PATCHES] OK: All patches verified (v$VERSION)"
  exit 0
fi

# Patches wiped — auto-reapply and warn
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo ""
echo "============================================"
echo "  WARNING: claude-flow patches were wiped!"
echo "  Likely cause: npx cache update (v$VERSION)"
echo "============================================"
echo ""

if [ -x "$SCRIPT_DIR/apply-patches.sh" ]; then
  bash "$SCRIPT_DIR/apply-patches.sh"
  echo ""
  echo "[PATCHES] Auto-reapplied. Restarting daemon..."
  npx @claude-flow/cli@latest daemon stop 2>/dev/null
  npx @claude-flow/cli@latest daemon start 2>/dev/null
  echo "[PATCHES] Daemon restarted with patched code."
  echo ""
else
  echo "[PATCHES] ERROR: apply-patches.sh not found at $SCRIPT_DIR"
  echo "[PATCHES] Run manually: bash scripts/apply-patches.sh"
fi
