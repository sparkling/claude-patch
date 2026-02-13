#!/bin/bash
# EM-002: @xenova/transformers cache EACCES on global install
# Global npm install creates root-owned dirs. Model cache write fails.

TRANSFORMERS_DIR=$(npm root -g)/claude-flow/node_modules/@xenova/transformers
if [ -d "$TRANSFORMERS_DIR" ]; then
    sudo mkdir -p "$TRANSFORMERS_DIR/.cache"
    sudo chmod 777 "$TRANSFORMERS_DIR/.cache"
    echo "  Applied: EM-002 transformers cache permissions"
else
    echo "  SKIP: EM-002 — @xenova/transformers not in global install"
fi
