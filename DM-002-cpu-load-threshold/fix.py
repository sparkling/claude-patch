# DM-002: maxCpuLoad=2.0 blocks all workers on multi-core
# NOTE: 32-core server uses 28.0. Adjust per machine (8-core Mac: 6.0).
patch("5: CPU load threshold",
    WD,
    "maxCpuLoad: 2.0",
    "maxCpuLoad: 28.0")
