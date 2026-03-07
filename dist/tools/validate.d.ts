interface ValidationResult {
    path: string;
    message: string;
    severity: "error" | "warning" | "info";
    suggestion?: string;
}
/**
 * Validate a YAML values string (or file path) against the chart's
 * JSON Schema and heuristic rules.
 */
export declare function validate(valuesInput: string): {
    results: ValidationResult[];
    parsed: boolean;
};
export {};
