# common.py — shared patch infrastructure
# Extracted from apply-patches.sh. Provides patch()/patch_all() + path variables.

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

# ── Target file paths ──
HWE = services + "/headless-worker-executor.js"
WD = services + "/worker-daemon.js"
DJ = commands + "/daemon.js"
DOC = commands + "/doctor.js"
MI = memory + "/memory-initializer.js"

MCP_MEMORY = base + "/mcp-tools/memory-tools.js"
MCP_HOOKS = base + "/mcp-tools/hooks-tools.js"
CLI_MEMORY = commands + "/memory.js"
EMB_TOOLS = base + "/mcp-tools/embeddings-tools.js"
