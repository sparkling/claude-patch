## Patch 17: Intelligence stats .toFixed() crash fix (Critical)

**File:** `commands/hooks.js` lines 1643-1649, 1665-1669, 1705-1709, 1712-1727
**Issue:** `npx @claude-flow/cli@latest hooks intelligence stats` crashes with:
```
TypeError: Cannot read properties of undefined (reading 'toFixed')
```

The intelligence stats display calls `.toFixed()` on potentially undefined properties (learningTimeMs, adaptationTimeMs, avgQuality, routingAccuracy, loadBalance, cacheHitRate, performance.*) without null checks, causing crashes when the intelligence system returns incomplete data.

### Changes:
1. Add null checks for SONA component: learningTimeMs, adaptationTimeMs, avgQuality
2. Add null checks for MoE component: routingAccuracy, loadBalance
3. Add null check for embeddings: cacheHitRate
4. Add null check for entire performance object and all its properties

### Apply:

```bash
# Fix SONA component (lines 1643-1649)
sed -i "s/{ metric: 'Learning Time', value: \`\${result.components.sona.learningTimeMs.toFixed(3)}ms\` }/{ metric: 'Learning Time', value: result.components.sona.learningTimeMs != null ? \`\${result.components.sona.learningTimeMs.toFixed(3)}ms\` : 'N\/A' }/" "$COMMANDS/hooks.js"

sed -i "s/{ metric: 'Adaptation Time', value: \`\${result.components.sona.adaptationTimeMs.toFixed(3)}ms\` }/{ metric: 'Adaptation Time', value: result.components.sona.adaptationTimeMs != null ? \`\${result.components.sona.adaptationTimeMs.toFixed(3)}ms\` : 'N\/A' }/" "$COMMANDS/hooks.js"

sed -i "s/{ metric: 'Avg Quality', value: \`\${(result.components.sona.avgQuality \* 100).toFixed(1)}%\` }/{ metric: 'Avg Quality', value: result.components.sona.avgQuality != null ? \`\${(result.components.sona.avgQuality * 100).toFixed(1)}%\` : 'N\/A' }/" "$COMMANDS/hooks.js"

# Fix MoE component (lines 1665-1669)
sed -i "s/{ metric: 'Routing Accuracy', value: \`\${(result.components.moe.routingAccuracy \* 100).toFixed(1)}%\` }/{ metric: 'Routing Accuracy', value: result.components.moe.routingAccuracy != null ? \`\${(result.components.moe.routingAccuracy * 100).toFixed(1)}%\` : 'N\/A' }/" "$COMMANDS/hooks.js"

sed -i "s/{ metric: 'Load Balance', value: \`\${(result.components.moe.loadBalance \* 100).toFixed(1)}%\` }/{ metric: 'Load Balance', value: result.components.moe.loadBalance != null ? \`\${(result.components.moe.loadBalance * 100).toFixed(1)}%\` : 'N\/A' }/" "$COMMANDS/hooks.js"

# Fix embeddings (line 1709)
sed -i "s/{ metric: 'Cache Hit Rate', value: \`\${(result.components.embeddings.cacheHitRate \* 100).toFixed(1)}%\` }/{ metric: 'Cache Hit Rate', value: result.components.embeddings.cacheHitRate != null ? \`\${(result.components.embeddings.cacheHitRate * 100).toFixed(1)}%\` : 'N\/A' }/" "$COMMANDS/hooks.js"
```

For the performance section (lines 1712-1727), the changes are more complex. Replace the V3 Performance section:

```bash
# Create a temporary file with the new performance section
cat > /tmp/perf-section.txt << 'EOF'
            // V3 Performance
            output.writeln();
            output.writeln(output.bold('🚀 V3 Performance Gains'));
            if (result.performance) {
                output.printList([
                    \`Flash Attention: \${output.success(result.performance.flashAttention || 'N/A')}\`,
                    \`Memory Reduction: \${output.success(result.performance.memoryReduction || 'N/A')}\`,
                    \`Search Improvement: \${output.success(result.performance.searchImprovement || 'N/A')}\`,
                    \`Token Reduction: \${output.success(result.performance.tokenReduction || 'N/A')}\`,
                    \`SWE-Bench Score: \${output.success(result.performance.sweBenchScore || 'N/A')}\`
                ]);
            }
            else {
                output.writeln(output.dim('  No performance data available'));
            }
            return { success: true, data: result };
EOF

# Replace lines 1712-1722 in hooks.js
# This requires a more sophisticated approach - use awk or manual edit
# For automation in apply-patches.sh, you'll need to use sed with multi-line or perl
```

**Manual alternative for performance section:**
Edit `commands/hooks.js` around line 1715 and wrap the `output.printList` in an if check:
```javascript
if (result.performance) {
    output.printList([
        `Flash Attention: ${output.success(result.performance.flashAttention || 'N/A')}`,
        `Memory Reduction: ${output.success(result.performance.memoryReduction || 'N/A')}`,
        `Search Improvement: ${output.success(result.performance.searchImprovement || 'N/A')}`,
        `Token Reduction: ${output.success(result.performance.tokenReduction || 'N/A')}`,
        `SWE-Bench Score: ${output.success(result.performance.sweBenchScore || 'N/A')}`
    ]);
}
else {
    output.writeln(output.dim('  No performance data available'));
}
```

### Verify:

```bash
npx @claude-flow/cli@latest hooks intelligence stats
# Should show tables with "N/A" for missing values instead of crashing
```

### Status: Applied (npx cache)

**Applied to:**
- ✅ npx cache: `~/.npm/_npx/85fb20e3e7e3a233/node_modules/@claude-flow/cli/dist/src/commands/hooks.js`

**Note:** This patch requires more complex multi-line replacement for the performance section. The sed commands handle the simple single-line fixes. The performance section may need manual editing or a more sophisticated script.

---
