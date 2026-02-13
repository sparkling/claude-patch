# NS-003: Namespace typo 'pattern' vs 'patterns'
# GitHub: #1136
# 4 ops: 22a-d

patch("22a: hooks pattern-store namespace",
    MCP_HOOKS,
    "namespace: 'pattern',",
    "namespace: 'patterns',")

patch("22b: hooks pattern-search default",
    MCP_HOOKS,
    "const namespace = params.namespace || 'pattern';",
    "const namespace = params.namespace || 'patterns';")

patch("22c: hooks pattern-search description",
    MCP_HOOKS,
    "description: 'Namespace to search (default: pattern)'",
    "description: 'Namespace to search (default: patterns)'")

patch("22d: hooks pattern-search note",
    MCP_HOOKS,
    'namespace "pattern".',
    'namespace "patterns".')
