import {
  isClusterAvailable,
  kubectlGet,
  kubectlDescribe,
  kubectlLogs,
  kubectlEvents,
} from "../lib/kubectl.js";

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
 * Known symptom patterns and their diagnostic procedures.
 */
const SYMPTOM_HANDLERS: Record<
  string,
  (ns: string, findings: Finding[]) => void
> = {
  crashloop: (ns, findings) => {
    try {
      const pods = kubectlGet("pods", ns);
      const crashPods = pods
        .split("\n")
        .filter((l) => l.includes("CrashLoopBackOff") || l.includes("Error"));
      for (const line of crashPods) {
        const podName = line.trim().split(/\s+/)[0];
        if (!podName) continue;
        try {
          const logs = kubectlLogs(podName, ns, 30);
          findings.push({
            category: "pod-crash",
            severity: "critical",
            message: `Pod ${podName} is in CrashLoopBackOff. Last 30 log lines:\n${logs}`,
            fix: "Check the log output for configuration errors (missing env vars, bad connection strings, etc.).",
          });
        } catch {
          findings.push({
            category: "pod-crash",
            severity: "critical",
            message: `Pod ${podName} is crashing but logs could not be retrieved.`,
            fix: "Try: kubectl logs <pod> --previous -n " + ns,
          });
        }
      }
    } catch {
      // ignore
    }
  },

  pending: (ns, findings) => {
    try {
      const pods = kubectlGet("pods", ns);
      const pendingPods = pods
        .split("\n")
        .filter((l) => l.includes("Pending"));
      for (const line of pendingPods) {
        const podName = line.trim().split(/\s+/)[0];
        if (!podName) continue;
        try {
          const desc = kubectlDescribe("pod", podName, ns);
          // Extract events section
          const eventsIdx = desc.indexOf("Events:");
          const events =
            eventsIdx >= 0 ? desc.slice(eventsIdx) : "(no events)";
          findings.push({
            category: "pod-pending",
            severity: "warning",
            message: `Pod ${podName} is Pending.\n${events}`,
            fix: "Common causes: insufficient CPU/memory, unbound PVCs, image pull errors, node affinity constraints.",
          });
        } catch {
          // ignore
        }
      }
    } catch {
      // ignore
    }
  },

  imagepull: (ns, findings) => {
    try {
      const pods = kubectlGet("pods", ns);
      const errPods = pods
        .split("\n")
        .filter(
          (l) =>
            l.includes("ImagePullBackOff") || l.includes("ErrImagePull"),
        );
      for (const line of errPods) {
        const podName = line.trim().split(/\s+/)[0];
        if (!podName) continue;
        findings.push({
          category: "image-pull",
          severity: "critical",
          message: `Pod ${podName} cannot pull its container image.`,
          fix: "Verify global.deployment.images.repository and tag are correct. Ensure the imagePullSecret exists and has valid credentials.",
        });
      }
    } catch {
      // ignore
    }
  },
};

/**
 * Run general diagnostic checks across the namespace.
 */
function generalDiagnostics(ns: string, findings: Finding[]): void {
  // Check pods
  try {
    const pods = kubectlGet("pods", ns);
    const lines = pods.trim().split("\n").slice(1);

    if (lines.length === 0 || (lines.length === 1 && lines[0].trim() === "")) {
      findings.push({
        category: "deployment",
        severity: "warning",
        message: "No pods found in namespace.",
        fix: `Verify the Helm release is installed: helm list -n ${ns}`,
      });
      return;
    }

    for (const line of lines) {
      const parts = line.trim().split(/\s+/);
      const status = parts[2];
      if (
        status === "CrashLoopBackOff" ||
        status === "Error" ||
        status === "Failed"
      ) {
        SYMPTOM_HANDLERS.crashloop(ns, findings);
        break;
      }
    }

    for (const line of lines) {
      const parts = line.trim().split(/\s+/);
      if (parts[2] === "Pending") {
        SYMPTOM_HANDLERS.pending(ns, findings);
        break;
      }
    }

    for (const line of lines) {
      const parts = line.trim().split(/\s+/);
      if (
        parts[2] === "ImagePullBackOff" ||
        parts[2] === "ErrImagePull"
      ) {
        SYMPTOM_HANDLERS.imagepull(ns, findings);
        break;
      }
    }
  } catch {
    findings.push({
      category: "query",
      severity: "warning",
      message: "Could not list pods in namespace " + ns,
    });
  }

  // Check secrets
  try {
    const secrets = kubectlGet("secrets", ns, "name");
    if (!secrets.includes("redpoint-rpi")) {
      findings.push({
        category: "secrets",
        severity: "warning",
        message:
          "No secret matching 'redpoint-rpi' found. RPI services may fail to start.",
        fix: "Ensure secretsManagement is configured correctly and secrets are created.",
      });
    }
  } catch {
    // ignore
  }

  // Check ingress
  try {
    const ingress = kubectlGet("ingress", ns);
    if (ingress.includes("No resources found")) {
      findings.push({
        category: "ingress",
        severity: "info",
        message: "No Ingress resources found. External access may not be configured.",
      });
    }
  } catch {
    // ignore
  }
}

/**
 * Troubleshoot an RPI deployment. Gathers cluster state, runs
 * diagnostics, and returns findings with suggested fixes.
 */
export function troubleshoot(
  namespace?: string,
  symptom?: string,
): TroubleshootResult {
  const ns = namespace ?? "default";

  if (!isClusterAvailable()) {
    return {
      available: false,
      namespace: ns,
      findings: [
        {
          category: "cluster",
          severity: "critical",
          message:
            "No Kubernetes cluster is reachable. Ensure kubectl is configured and the cluster is accessible.",
          fix: "Run 'kubectl cluster-info' to verify connectivity. Check KUBECONFIG env var.",
        },
      ],
    };
  }

  const findings: Finding[] = [];

  // If a specific symptom is provided, run its handler
  if (symptom) {
    const key = symptom.toLowerCase().replace(/[^a-z]/g, "");
    const handler = SYMPTOM_HANDLERS[key];
    if (handler) {
      handler(ns, findings);
    } else {
      // Run all checks
      generalDiagnostics(ns, findings);
    }
  } else {
    generalDiagnostics(ns, findings);
  }

  // Gather recent events
  let rawEvents: string | undefined;
  try {
    rawEvents = kubectlEvents(ns);
  } catch {
    // non-fatal
  }

  if (findings.length === 0) {
    findings.push({
      category: "general",
      severity: "info",
      message: "No issues detected. All checks passed.",
    });
  }

  return { available: true, namespace: ns, findings, rawEvents };
}
