# GV-001: Remove HNSW ghost vectors on memory delete
# GitHub: #1122
# After SQLite soft-delete, remove entry from persisted HNSW metadata file
# and in-memory map. Each CLI invocation is a fresh process so hnswIndex is
# usually null — the file-based cleanup is the primary path.
# 1 op

patch("GV-001: remove HNSW entry on delete",
    MI,
    """        // Get remaining count
        const countResult = db.exec(`SELECT COUNT(*) FROM memory_entries WHERE status = 'active'`);
        const remainingEntries = countResult[0]?.values?.[0]?.[0] || 0;
        // Save updated database""",
    """        // Remove ghost vector from HNSW metadata file
        const entryId = String(checkResult[0].values[0][0]);
        try {
            const swarmDir = path.join(process.cwd(), '.swarm');
            const metadataPath = path.join(swarmDir, 'hnsw.metadata.json');
            if (fs.existsSync(metadataPath)) {
                const metadata = JSON.parse(fs.readFileSync(metadataPath, 'utf-8'));
                const filtered = metadata.filter(([id]) => id !== entryId);
                if (filtered.length < metadata.length) {
                    fs.writeFileSync(metadataPath, JSON.stringify(filtered));
                }
            }
        } catch { /* best-effort */ }
        // Also clear in-memory index if loaded
        if (hnswIndex?.entries?.has(entryId)) {
            hnswIndex.entries.delete(entryId);
        }
        // Get remaining count
        const countResult = db.exec(`SELECT COUNT(*) FROM memory_entries WHERE status = 'active'`);
        const remainingEntries = countResult[0]?.values?.[0]?.[0] || 0;
        // Save updated database""")
