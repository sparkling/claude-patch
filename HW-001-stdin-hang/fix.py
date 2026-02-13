# HW-001: Headless workers hang — stdin pipe never closed
# GitHub: #1111
patch("1: stdin pipe",
    HWE,
    "stdio: ['pipe', 'pipe', 'pipe']",
    "stdio: ['ignore', 'pipe', 'pipe']")
