interface Finding {
    category: string;
    severity: "critical" | "warning" | "info";
    message: string;
    fix?: string;
}
interface TroubleshootResult {
    available: boolean;
    namespace: string;
    findings: Finding[];
    rawEvents?: string;
}
/**
 * Troubleshoot an RPI deployment. Gathers cluster state, runs
 * diagnostics, and returns findings with suggested fixes.
 */
export declare function troubleshoot(namespace?: string, symptom?: string): TroubleshootResult;
export {};
