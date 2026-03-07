import { execSync } from "node:child_process";

const EXEC_OPTS = { encoding: "utf-8" as const, timeout: 60_000 };

/**
 * Run `kubectl get` and return the output.
 */
export function kubectlGet(
  resource: string,
  namespace?: string,
  outputFormat: string = "wide",
): string {
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
export function kubectlDescribe(
  resource: string,
  name: string,
  namespace?: string,
): string {
  const parts = ["kubectl", "describe", resource, name];
  if (namespace) {
    parts.push("-n", namespace);
  }
  return execSync(parts.join(" "), EXEC_OPTS);
}

/**
 * Retrieve pod logs.
 */
export function kubectlLogs(
  pod: string,
  namespace?: string,
  tail: number = 100,
): string {
  const parts = ["kubectl", "logs", pod, `--tail=${tail}`];
  if (namespace) {
    parts.push("-n", namespace);
  }
  return execSync(parts.join(" "), EXEC_OPTS);
}

/**
 * Get recent events sorted by timestamp.
 */
export function kubectlEvents(namespace?: string): string {
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
export function isClusterAvailable(): boolean {
  try {
    execSync("kubectl cluster-info", {
      ...EXEC_OPTS,
      stdio: "pipe",
      timeout: 10_000,
    });
    return true;
  } catch {
    return false;
  }
}
