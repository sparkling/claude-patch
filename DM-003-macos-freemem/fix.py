# DM-003: macOS freemem() always ~0% — workers blocked
# GitHub: #1077
# SKIPPED on Linux (only affects macOS)
patch("6: macOS memory",
    WD,
    "if (freePercent < this.config.resourceThresholds.minFreeMemoryPercent) {",
    "if (os.platform() !== 'darwin' && freePercent < this.config.resourceThresholds.minFreeMemoryPercent) {")
