# CF-001: Doctor ignores YAML config files
patch("7: YAML config",
    DOC,
    """    const configPaths = [
        '.claude-flow/config.json',
        'claude-flow.config.json',
        '.claude-flow.json'
    ];""",
    """    const configPaths = [
        '.claude-flow/config.json',
        'claude-flow.config.json',
        '.claude-flow.json',
        '.claude-flow/config.yaml',
        '.claude-flow/config.yml'
    ];""")

patch("7: YAML JSON.parse skip",
    DOC,
    "                JSON.parse(content);",
    "                if (configPath.endsWith('.json')) { JSON.parse(content); }")
