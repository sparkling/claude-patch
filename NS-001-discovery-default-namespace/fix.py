# NS-001: Discovery ops (search + list) default to wrong namespace
# GitHub: #1123
# Rule: Default to 'all' (search across all namespaces)
# 10 ops: 19a-e (search) + 21c,d,g,i,j (list)

# ── Search ops (from old Patch 19) ──

# 19a: MCP search handler — change default from 'default' to 'all'
patch("19a: MCP search namespace default",
    MCP_MEMORY,
    "const query = input.query;\n            const namespace = input.namespace || 'default';",
    "const query = input.query;\n            const namespace = input.namespace || 'all';")

# 19b: MCP search schema — update description to reflect 'all' default
patch("19b: MCP search namespace description",
    MCP_MEMORY,
    """namespace: { type: 'string', description: 'Namespace to search (default: "default")' }""",
    """namespace: { type: 'string', description: 'Namespace to search (default: "all" = all namespaces)' }""")

# 19c: Core searchEntries() — change function default from 'default' to 'all'
patch("19c: searchEntries default all",
    MI,
    "const { query, namespace = 'default', limit = 10, threshold = 0.3, dbPath: customPath } = options;",
    "const { query, namespace = 'all', limit = 10, threshold = 0.3, dbPath: customPath } = options;")

# 19d: Embeddings search — pass 'all' instead of 'default' to searchEntries
patch("19d: embeddings search namespace all",
    EMB_TOOLS,
    "namespace: namespace || 'default'\n                });",
    "namespace: namespace || 'all'\n                });")

# 19e: Embeddings metadata — all occurrences of namespace fallback
patch_all("19e: embeddings metadata namespace all",
    EMB_TOOLS,
    "namespace: namespace || 'default',",
    "namespace: namespace || 'all',")

# ── List ops (from old Patch 21) ──

# 21c: MCP list — update description to reflect 'all' default
patch("21c: MCP list namespace description",
    MCP_MEMORY,
    "namespace: { type: 'string', description: 'Filter by namespace' },",
    "namespace: { type: 'string', description: 'Namespace to list (default: \"all\" = all namespaces)' },")

# 21d: MCP list — default to 'all' (read-only discovery, like search)
patch("21d: MCP list namespace default all",
    MCP_MEMORY,
    "const { listEntries } = await getMemoryFunctions();\n            const namespace = input.namespace;\n            const limit = input.limit || 50;",
    "const { listEntries } = await getMemoryFunctions();\n            const namespace = input.namespace || 'all';\n            const limit = input.limit || 50;")

# 21g: CLI list — default to 'all' (read-only discovery, like search)
patch("21g: CLI list namespace default all",
    CLI_MEMORY,
    "        const namespace = ctx.flags.namespace;\n        const limit = ctx.flags.limit;\n        // Use sql.js directly for consistent data access",
    "        const namespace = ctx.flags.namespace || 'all';\n        const limit = ctx.flags.limit;\n        // Use sql.js directly for consistent data access")

# 21i: Core listEntries() — use nsFilter variable instead of truthiness check
patch("21i: listEntries nsFilter variable",
    MI,
    "        // Get total count\n        const countQuery = namespace",
    "        // Get total count\n        const nsFilter = namespace && namespace !== 'all';\n        const countQuery = nsFilter")

# 21j: Core listEntries() — use nsFilter in list query too
patch("21j: listEntries listQuery all support",
    MI,
    "        ${namespace ? `AND namespace",
    "        ${nsFilter ? `AND namespace")
