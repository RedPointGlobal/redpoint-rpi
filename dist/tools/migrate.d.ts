interface MigrateResult {
    summary: string;
    customizationCount: number;
    warnings: string[];
    v77Yaml: string;
}
/**
 * Migrate a v7.6 values file to v7.7 format.
 */
export declare function migrate(valuesInput: string): MigrateResult;
export {};
