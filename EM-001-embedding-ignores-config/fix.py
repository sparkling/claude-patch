# EM-001: Embedding system ignores project config (model + HNSW dims)
# Merged from old patches 8 (config-driven model) + 9 (HNSW dimension fix)

# --- Old Patch 8: Config-driven embedding model loader ---
patch("8: config-driven model",
    MI,
    """        // Try to import @xenova/transformers for ONNX embeddings
        const transformers = await import('@xenova/transformers').catch(() => null);
        if (transformers) {
            if (verbose) {
                console.log('Loading ONNX embedding model (all-MiniLM-L6-v2)...');
            }
            // Use small, fast model for local embeddings
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

# --- Old Patch 9: HNSW dimension fix ---
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

patch("9: HNSW metadata guard",
    MI,
    "        if (fs.existsSync(metadataPath)) {",
    "        if (!options?.forceRebuild && fs.existsSync(metadataPath)) {")

patch("9: HNSW early-return guard",
    MI,
    "        if (existingLen > 0 && entries.size > 0) {",
    "        if (existingLen > 0 && entries.size > 0 && !options?.forceRebuild) {")

patch("9: HNSW status default",
    MI,
    "dimensions: hnswIndex?.dimensions ?? 384",
    "dimensions: hnswIndex?.dimensions ?? 768")
