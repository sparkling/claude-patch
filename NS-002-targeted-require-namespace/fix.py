# NS-002: Targeted ops (store/delete/retrieve) accept wrong namespace
# GitHub: #581, #1137, #1135
# Rule: Require explicit namespace, block 'all'
# 14 ops: 20a-i (store/delete) + 21a,b,e,f,h (retrieve)

# ── Store ops (from old Patch 20) ──

# 20a: MCP store — add 'namespace' to required fields in schema
patch("20a: MCP store require namespace",
    MCP_MEMORY,
    "required: ['key', 'value'],",
    "required: ['key', 'value', 'namespace'],")

# 20b: MCP store — remove || 'default' fallback + add runtime throw
patch("20b: MCP store namespace no fallback",
    MCP_MEMORY,
    "const namespace = input.namespace || 'default';\n            const value = typeof",
    "const namespace = input.namespace;\n            if (!namespace || namespace === 'all') {\n                throw new Error('Namespace is required (cannot be \"all\"). Use namespace: \"patterns\", \"solutions\", or \"tasks\"');\n            }\n            const value = typeof")

# 20c: MCP delete — add 'namespace' to required + update description
patch("20c: MCP delete require namespace",
    MCP_MEMORY,
    """        description: 'Delete a memory entry by key',
        category: 'memory',
        inputSchema: {
            type: 'object',
            properties: {
                key: { type: 'string', description: 'Memory key' },
                namespace: { type: 'string', description: 'Namespace (default: "default")' },
            },
            required: ['key'],""",
    """        description: 'Delete a memory entry by key',
        category: 'memory',
        inputSchema: {
            type: 'object',
            properties: {
                key: { type: 'string', description: 'Memory key' },
                namespace: { type: 'string', description: 'Namespace (e.g. "patterns", "solutions", "tasks")' },
            },
            required: ['key', 'namespace'],""")

# 20d: MCP delete — remove || 'default' fallback + add runtime throw
patch("20d: MCP delete namespace no fallback",
    MCP_MEMORY,
    "const { deleteEntry } = await getMemoryFunctions();\n            const key = input.key;\n            const namespace = input.namespace || 'default';",
    "const { deleteEntry } = await getMemoryFunctions();\n            const key = input.key;\n            const namespace = input.namespace;\n            if (!namespace || namespace === 'all') {\n                throw new Error('Namespace is required (cannot be \"all\"). Use namespace: \"patterns\", \"solutions\", or \"tasks\"');\n            }")

# 20e: CLI store — add namespace-required check after key check
patch("20e: CLI store require namespace",
    CLI_MEMORY,
    """        if (!key) {
            output.printError('Key is required. Use --key or -k');
            return { success: false, exitCode: 1 };
        }
        if (!value && ctx.interactive) {""",
    """        if (!key) {
            output.printError('Key is required. Use --key or -k');
            return { success: false, exitCode: 1 };
        }
        if (!namespace || namespace === 'all') {
            output.printError('Namespace is required (cannot be "all"). Use --namespace or -n (e.g. "patterns", "solutions", "tasks")');
            return { success: false, exitCode: 1 };
        }
        if (!value && ctx.interactive) {""")

# 20f: CLI delete — remove || 'default' fallback and fix error message
patch("20f: CLI delete namespace no fallback",
    CLI_MEMORY,
    "const namespace = ctx.flags.namespace || 'default';\n        const force = ctx.flags.force;\n        if (!key) {\n            output.printError('Key is required. Use: memory delete -k \"key\" [-n \"namespace\"]');",
    "const namespace = ctx.flags.namespace;\n        const force = ctx.flags.force;\n        if (!key) {\n            output.printError('Key is required. Use: memory delete -k \"key\" -n \"namespace\"');")

# 20g: CLI delete — add namespace-required check
patch("20g: CLI delete namespace check",
    CLI_MEMORY,
    """            output.printError('Key is required. Use: memory delete -k "key" -n "namespace"');
            return { success: false, exitCode: 1 };
        }
        if (!force && ctx.interactive) {""",
    """            output.printError('Key is required. Use: memory delete -k "key" -n "namespace"');
            return { success: false, exitCode: 1 };
        }
        if (!namespace || namespace === 'all') {
            output.printError('Namespace is required (cannot be "all"). Use: memory delete -k "key" -n "namespace" (e.g. "patterns", "solutions", "tasks")');
            return { success: false, exitCode: 1 };
        }
        if (!force && ctx.interactive) {""")

# 20h: Core storeEntry() — remove dead 'default' parameter default + throw
patch("20h: storeEntry no default namespace",
    MI,
    "const { key, value, namespace = 'default', generateEmbeddingFlag = true, tags = [], ttl, dbPath: customPath, upsert = false } = options;",
    "const { key, value, namespace, generateEmbeddingFlag = true, tags = [], ttl, dbPath: customPath, upsert = false } = options;\n    if (!namespace || namespace === 'all') throw new Error('storeEntry: namespace is required (cannot be \"all\")');")

# 20i: Core deleteEntry() — remove dead 'default' parameter default + throw
patch("20i: deleteEntry no default namespace",
    MI,
    "export async function deleteEntry(options) {\n    const { key, namespace = 'default', dbPath: customPath } = options;\n    const swarmDir = path.join(process.cwd(), '.swarm');\n    const dbPath = customPath || path.join(swarmDir, 'memory.db');",
    "export async function deleteEntry(options) {\n    const { key, namespace, dbPath: customPath } = options;\n    if (!namespace || namespace === 'all') throw new Error('deleteEntry: namespace is required (cannot be \"all\")');\n    const swarmDir = path.join(process.cwd(), '.swarm');\n    const dbPath = customPath || path.join(swarmDir, 'memory.db');")

# ── Retrieve ops (from old Patch 21) ──

# 21a: MCP retrieve — add 'namespace' to required + update description
patch("21a: MCP retrieve require namespace",
    MCP_MEMORY,
    """        description: 'Retrieve a value from memory by key',
        category: 'memory',
        inputSchema: {
            type: 'object',
            properties: {
                key: { type: 'string', description: 'Memory key' },
                namespace: { type: 'string', description: 'Namespace (default: "default")' },
            },
            required: ['key'],""",
    """        description: 'Retrieve a value from memory by key',
        category: 'memory',
        inputSchema: {
            type: 'object',
            properties: {
                key: { type: 'string', description: 'Memory key' },
                namespace: { type: 'string', description: 'Namespace (e.g. "patterns", "solutions", "tasks")' },
            },
            required: ['key', 'namespace'],""")

# 21b: MCP retrieve — remove || 'default' fallback + add runtime throw
patch("21b: MCP retrieve namespace no fallback",
    MCP_MEMORY,
    "const { getEntry } = await getMemoryFunctions();\n            const key = input.key;\n            const namespace = input.namespace || 'default';",
    "const { getEntry } = await getMemoryFunctions();\n            const key = input.key;\n            const namespace = input.namespace;\n            if (!namespace || namespace === 'all') {\n                throw new Error('Namespace is required (cannot be \"all\"). Use namespace: \"patterns\", \"solutions\", or \"tasks\"');\n            }")

# 21e: CLI retrieve — remove default: 'default' from flag definition
patch("21e: CLI retrieve remove default",
    CLI_MEMORY,
    "            type: 'string',\n            default: 'default'\n        }\n    ],\n    action: async (ctx) => {\n        const key = ctx.flags.key || ctx.args[0];\n        const namespace = ctx.flags.namespace;\n        if (!key) {\n            output.printError('Key is required');",
    "            type: 'string'\n        }\n    ],\n    action: async (ctx) => {\n        const key = ctx.flags.key || ctx.args[0];\n        const namespace = ctx.flags.namespace;\n        if (!key) {\n            output.printError('Key is required');")

# 21f: CLI retrieve — add namespace-required check
patch("21f: CLI retrieve namespace check",
    CLI_MEMORY,
    """        if (!key) {
            output.printError('Key is required');
            return { success: false, exitCode: 1 };
        }
        // Use sql.js directly for consistent data access""",
    """        if (!key) {
            output.printError('Key is required');
            return { success: false, exitCode: 1 };
        }
        if (!namespace || namespace === 'all') {
            output.printError('Namespace is required (cannot be "all"). Use --namespace or -n (e.g. "patterns", "solutions", "tasks")');
            return { success: false, exitCode: 1 };
        }
        // Use sql.js directly for consistent data access""")

# 21h: Core getEntry() — remove dead 'default' parameter default + throw
patch("21h: getEntry no default namespace",
    MI,
    "const { key, namespace = 'default', dbPath: customPath } = options;\n    const swarmDir = path.join(process.cwd(), '.swarm');\n    const dbPath = customPath || path.join(swarmDir, 'memory.db');",
    "const { key, namespace, dbPath: customPath } = options;\n    if (!namespace || namespace === 'all') throw new Error('getEntry: namespace is required (cannot be \"all\")');\n    const swarmDir = path.join(process.cwd(), '.swarm');\n    const dbPath = customPath || path.join(swarmDir, 'memory.db');")
