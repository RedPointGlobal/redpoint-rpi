/**
 * Returns the absolute path to the Helm chart directory.
 * Honours the CHART_DIR environment variable; otherwise resolves
 * ../../chart relative to the package root (deploy/mcp/../../chart).
 */
export declare function getChartDir(): string;
/**
 * Returns the absolute path to the docs directory.
 */
export declare function getDocsDir(): string;
/**
 * Returns the absolute path to values.schema.json inside the chart directory.
 */
export declare function getSchemaPath(): string;
/**
 * Returns the absolute path to values.yaml inside the chart directory.
 */
export declare function getValuesPath(): string;
/**
 * Returns the absolute path to the repo root.
 */
export declare function getRepoRoot(): string;
/**
 * Check whether the schema file exists on disk.
 */
export declare function schemaExists(): boolean;
