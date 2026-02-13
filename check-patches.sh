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
MCP_TOOLS_DIR=$(dirname "$MEMORY")/../mcp-tools

# Quick sentinel checks by issue ID:
# EM-001 (embeddings.json), DM-002 (maxCpuLoad), DM-004 (loadEmbeddingModel),
# DM-005 (applyTemporalDecay), UI-002 (getHNSWIndex in neural.js),
# NS-001 (all namespaces), NS-002 (Namespace is required + cannot be 'all'),
# NS-001 (nsFilter), NS-003 ('patterns' typo)
if grep -q "embeddings.json" "$MEMORY" 2>/dev/null \
   && grep -q "maxCpuLoad:" "$SERVICES" 2>/dev/null \
   && grep -q "loadEmbeddingModel" "$SERVICES" 2>/dev/null \
   && grep -q "applyTemporalDecay" "$SERVICES" 2>/dev/null \
   && grep -q "getHNSWIndex" "$COMMANDS_DIR/neural.js" 2>/dev/null \
   && grep -q "all namespaces" "$MCP_TOOLS_DIR/memory-tools.js" 2>/dev/null \
   && grep -q "Namespace is required" "$MCP_TOOLS_DIR/memory-tools.js" 2>/dev/null \
   && grep -q "nsFilter" "$MEMORY" 2>/dev/null \
   && grep -q "|| 'patterns'" "$MCP_TOOLS_DIR/hooks-tools.js" 2>/dev/null \
   && grep -q "cannot be .all." "$MCP_TOOLS_DIR/memory-tools.js" 2>/dev/null; then
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

if [ -x "$SCRIPT_DIR/patch-all.sh" ]; then
  bash "$SCRIPT_DIR/patch-all.sh"
  echo ""
  echo "[PATCHES] Auto-reapplied. Restarting daemon..."
  npx @claude-flow/cli@latest daemon stop 2>/dev/null
  npx @claude-flow/cli@latest daemon start 2>/dev/null
  echo "[PATCHES] Daemon restarted with patched code."
  echo ""
else
  echo "[PATCHES] ERROR: patch-all.sh not found at $SCRIPT_DIR"
  echo "[PATCHES] Run manually: bash ~/src/claude-patch/patch-all.sh"
fi
