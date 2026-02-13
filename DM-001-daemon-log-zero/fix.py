# DM-001: daemon.log always 0 bytes (ESM require + path mismatch)
# GitHub: #1116
patch("4A: appendFileSync import",
    WD,
    "import { existsSync, mkdirSync, writeFileSync, readFileSync } from 'fs';",
    "import { existsSync, mkdirSync, writeFileSync, readFileSync, appendFileSync } from 'fs';")

patch("4B: remove require('fs')",
    WD,
    """            const fs = require('fs');
            fs.appendFileSync(logFile, logMessage + '\\n');""",
    "            appendFileSync(logFile, logMessage + '\\n');")

patch("4C: daemon log path",
    DJ,
    """    const logFile = join(stateDir, 'daemon.log');
    // Validate all paths
    validatePath(stateDir, 'State directory');
    validatePath(pidFile, 'PID file');
    validatePath(logFile, 'Log file');
    // Ensure state directory exists
    if (!fs.existsSync(stateDir)) {
        fs.mkdirSync(stateDir, { recursive: true });
    }""",
    """    const logsDir = join(stateDir, 'logs');
    if (!fs.existsSync(logsDir)) {
        fs.mkdirSync(logsDir, { recursive: true });
    }
    const logFile = join(logsDir, 'daemon.log');
    // Validate all paths
    validatePath(stateDir, 'State directory');
    validatePath(pidFile, 'PID file');
    validatePath(logFile, 'Log file');
    // Ensure state directory exists
    if (!fs.existsSync(stateDir)) {
        fs.mkdirSync(stateDir, { recursive: true });
    }""")
