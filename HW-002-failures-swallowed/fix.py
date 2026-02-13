# HW-002: Headless failures silently swallowed as success
# GitHub: #1112
patch("2: honest failures",
    WD,
    """        if (isHeadlessWorker(workerConfig.type) && this.headlessAvailable && this.headlessExecutor) {
            try {
                this.log('info', `Running ${workerConfig.type} in headless mode (Claude Code AI)`);
                const result = await this.headlessExecutor.execute(workerConfig.type);
                return {
                    mode: 'headless',
                    ...result,
                };
            }
            catch (error) {
                this.log('warn', `Headless execution failed for ${workerConfig.type}, falling back to local mode`);
                this.emit('headless:fallback', {
                    type: workerConfig.type,
                    error: error instanceof Error ? error.message : String(error),
                });
                // Fall through to local execution
            }
        }""",
    """        if (isHeadlessWorker(workerConfig.type) && this.headlessAvailable && this.headlessExecutor) {
            let result;
            try {
                this.log('info', `Running ${workerConfig.type} in headless mode (Claude Code AI)`);
                result = await this.headlessExecutor.execute(workerConfig.type);
            }
            catch (error) {
                const errorMsg = error instanceof Error ? error.message : String(error);
                this.log('warn', `Headless execution threw for ${workerConfig.type}: ${errorMsg}`);
                this.emit('headless:fallback', { type: workerConfig.type, error: errorMsg });
                throw error instanceof Error ? error : new Error(errorMsg);
            }
            if (result.success) {
                return { mode: 'headless', ...result };
            }
            const errorMsg = result.error || 'Unknown headless failure';
            this.log('warn', `Headless failed for ${workerConfig.type}: ${errorMsg}`);
            this.emit('headless:fallback', { type: workerConfig.type, error: errorMsg });
            throw new Error(`Headless execution failed for ${workerConfig.type}: ${errorMsg}`);
        }""")
