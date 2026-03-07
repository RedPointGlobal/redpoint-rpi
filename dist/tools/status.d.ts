interface ServiceStatus {
    name: string;
    ready: string;
    status: string;
    restarts: string;
    age: string;
}
interface StatusResult {
    available: boolean;
    namespace: string;
    summary?: {
        total: number;
        running: number;
        pending: number;
        failed: number;
        other: number;
    };
    pods?: ServiceStatus[];
    services?: string;
    ingress?: string;
    error?: string;
}
/**
 * Get the status of all RPI resources in a namespace.
 */
export declare function status(namespace?: string): StatusResult;
export {};
