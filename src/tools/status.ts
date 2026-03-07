import {
  isClusterAvailable,
  kubectlGet,
} from "../lib/kubectl.js";

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
 * Parse kubectl get pods -o wide output into structured data.
 */
function parsePodLines(output: string): ServiceStatus[] {
  const lines = output.trim().split("\n");
  if (lines.length <= 1) return [];

  // Skip header line
  return lines.slice(1).map((line) => {
    const parts = line.trim().split(/\s+/);
    return {
      name: parts[0] ?? "",
      ready: parts[1] ?? "",
      status: parts[2] ?? "",
      restarts: parts[3] ?? "",
      age: parts[4] ?? "",
    };
  });
}

/**
 * Get the status of all RPI resources in a namespace.
 */
export function status(namespace?: string): StatusResult {
  const ns = namespace ?? "default";

  if (!isClusterAvailable()) {
    return {
      available: false,
      namespace: ns,
      error:
        "No Kubernetes cluster is reachable. Ensure kubectl is configured and the cluster is accessible.",
    };
  }

  try {
    // Pods
    const podsOutput = kubectlGet("pods", ns, "wide");
    const pods = parsePodLines(podsOutput);

    const summary = {
      total: pods.length,
      running: pods.filter((p) => p.status === "Running").length,
      pending: pods.filter((p) => p.status === "Pending").length,
      failed: pods.filter(
        (p) =>
          p.status === "CrashLoopBackOff" ||
          p.status === "Error" ||
          p.status === "Failed",
      ).length,
      other: 0,
    };
    summary.other =
      summary.total - summary.running - summary.pending - summary.failed;

    // Services
    let services: string | undefined;
    try {
      services = kubectlGet("services", ns);
    } catch {
      // non-fatal
    }

    // Ingress
    let ingress: string | undefined;
    try {
      ingress = kubectlGet("ingress", ns);
    } catch {
      // non-fatal
    }

    return {
      available: true,
      namespace: ns,
      summary,
      pods,
      services,
      ingress,
    };
  } catch (err) {
    return {
      available: true,
      namespace: ns,
      error: `Failed to query cluster: ${err instanceof Error ? err.message : String(err)}`,
    };
  }
}
