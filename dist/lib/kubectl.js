import { execSync } from "node:child_process";
const EXEC_OPTS = { encoding: "utf-8", timeout: 60_000 };
/**
 * Run `kubectl get` and return the output.
 */
export function kubectlGet(resource, namespace, outputFormat = "wide") {
    const parts = ["kubectl", "get", resource];
    if (namespace) {
        parts.push("-n", namespace);
    }
    parts.push("-o", outputFormat);
    return execSync(parts.join(" "), EXEC_OPTS);
}
/**
 * Run `kubectl describe` and return the output.
 */
export function kubectlDescribe(resource, name, namespace) {
    const parts = ["kubectl", "describe", resource, name];
    if (namespace) {
        parts.push("-n", namespace);
    }
    return execSync(parts.join(" "), EXEC_OPTS);
}
/**
 * Retrieve pod logs.
 */
export function kubectlLogs(pod, namespace, tail = 100) {
    const parts = ["kubectl", "logs", pod, `--tail=${tail}`];
    if (namespace) {
        parts.push("-n", namespace);
    }
    return execSync(parts.join(" "), EXEC_OPTS);
}
/**
 * Get recent events sorted by timestamp.
 */
export function kubectlEvents(namespace) {
    const parts = [
        "kubectl",
        "get",
        "events",
        "--sort-by=.lastTimestamp",
    ];
    if (namespace) {
        parts.push("-n", namespace);
    }
    return execSync(parts.join(" "), EXEC_OPTS);
}
/**
 * Returns true if a Kubernetes cluster is reachable.
 */
export function isClusterAvailable() {
    try {
        execSync("kubectl cluster-info", {
            ...EXEC_OPTS,
            stdio: "pipe",
            timeout: 10_000,
        });
        return true;
    }
    catch {
        return false;
    }
}
//# sourceMappingURL=kubectl.js.map