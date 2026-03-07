interface ExplainResult {
    keyPath: string;
    found: boolean;
    type?: string;
    description?: string;
    defaultValue?: unknown;
    enumValues?: unknown[];
    required?: boolean;
    dependencies?: string[];
    additionalContext?: string;
}
/**
 * Explain a specific values key path using the JSON Schema and the
 * hardcoded knowledge map.
 */
export declare function explain(keyPath: string): ExplainResult;
export {};
