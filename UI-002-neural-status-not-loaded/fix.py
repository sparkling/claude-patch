# UI-002: neural status shows "Not loaded" for installed components
# Absorbed from old patch-18. Applied manually to npx cache.

NEURAL = commands + "/neural.js"

# Update import to include getHNSWIndex
patch("18a: neural.js import getHNSWIndex",
    NEURAL,
    "const { getHNSWStatus, loadEmbeddingModel } = await import('../memory/memory-initializer.js');",
    "const { getHNSWIndex, getHNSWStatus, loadEmbeddingModel } = await import('../memory/memory-initializer.js');")

# Add initialization calls before status reads
patch("18b: neural.js init before status",
    NEURAL,
    "            const ruvectorStats = ruvector.getTrainingStats();",
    """            // Patch 18: Initialize RuVector WASM + SONA + HNSW so status reflects reality
            if (!ruvector.getTrainingStats().initialized) {
                await ruvector.initializeTraining({ useSona: true }).catch(() => {});
            }
            await getHNSWIndex().catch(() => null);
            const ruvectorStats = ruvector.getTrainingStats();""")
