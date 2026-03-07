/**
 * Run `kubectl get` and return the output.
 */
export declare function kubectlGet(resource: string, namespace?: string, outputFormat?: string): string;
/**
 * Run `kubectl describe` and return the output.
 */
export declare function kubectlDescribe(resource: string, name: string, namespace?: string): string;
/**
 * Retrieve pod logs.
 */
export declare function kubectlLogs(pod: string, namespace?: string, tail?: number): string;
/**
 * Get recent events sorted by timestamp.
 */
export declare function kubectlEvents(namespace?: string): string;
/**
 * Returns true if a Kubernetes cluster is reachable.
 */
export declare function isClusterAvailable(): boolean;
