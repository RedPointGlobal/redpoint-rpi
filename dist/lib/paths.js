import { resolve, dirname } from "node:path";
import { fileURLToPath } from "node:url";
import { existsSync } from "node:fs";
const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);
/**
 * Resolve the package root (deploy/mcp/).
 * In dev (tsx) __dirname is src/lib; in dist it is dist/lib.
 * Either way, going up two levels reaches the package root.
 */
function packageRoot() {
    return resolve(__dirname, "..", "..");
}
/**
 * Returns the absolute path to the Helm chart directory.
 * Honours the CHART_DIR environment variable; otherwise resolves
 * ../../chart relative to the package root (deploy/mcp/../../chart).
 */
export function getChartDir() {
    if (process.env.CHART_DIR) {
        return resolve(process.env.CHART_DIR);
    }
    return resolve(packageRoot(), "..", "..", "chart");
}
/**
 * Returns the absolute path to the docs directory.
 */
export function getDocsDir() {
    if (process.env.DOCS_DIR) {
        return resolve(process.env.DOCS_DIR);
    }
    return resolve(packageRoot(), "..", "..", "docs");
}
/**
 * Returns the absolute path to values.schema.json inside the chart directory.
 */
export function getSchemaPath() {
    return resolve(getChartDir(), "values.schema.json");
}
/**
 * Returns the absolute path to values.yaml inside the chart directory.
 */
export function getValuesPath() {
    return resolve(getChartDir(), "values.yaml");
}
/**
 * Returns the absolute path to the repo root.
 */
export function getRepoRoot() {
    return resolve(packageRoot(), "..", "..");
}
/**
 * Check whether the schema file exists on disk.
 */
export function schemaExists() {
    return existsSync(getSchemaPath());
}
//# sourceMappingURL=paths.js.map