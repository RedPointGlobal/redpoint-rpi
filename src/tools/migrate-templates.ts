import { readFileSync, readdirSync, existsSync, statSync } from "node:fs";
import { resolve, dirname, basename } from "node:path";
import { fileURLToPath } from "node:url";
import { createHash } from "node:crypto";

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------
interface TemplateManifest {
  [filename: string]: { hash: string; content: string };
}

interface FileDiff {
  added: string[];
  removed: string[];
}

interface TemplateAnalysis {
  filename: string;
  status: "unchanged" | "modified" | "custom";
  v77Equivalent?: string;
  diff?: FileDiff;
  guidance: string;
}

interface MigrateTemplatesResult {
  summary: string;
  customFiles: TemplateAnalysis[];
  modifiedFiles: TemplateAnalysis[];
  unchangedCount: number;
  warnings: string[];
  guidance: string;
}

// ---------------------------------------------------------------------------
// v7.6 → v7.7 template filename mapping
// ---------------------------------------------------------------------------
// Files that exist in both versions (same name)
// Files that were removed in v7.7 (no equivalent)
// Files that were added in v7.7 (no v7.6 source)
const V76_REMOVED_IN_V77: Record<string, string> = {
  // No stock v7.6 templates were removed without replacement
};

const V76_RENAMED_IN_V77: Record<string, string> = {
  // v7.6 → v7.7 renames (none currently — names stayed the same)
};

// v7.7-only files (new in v7.7, no v7.6 equivalent)
const V77_NEW_FILES = new Set([
  "_defaults.tpl",
  "deploy-databases.yaml",
  "deploy-helmcopilot.yaml",
  "deploy-pvc.yaml",
  "deploy-rebrandly.yaml",
  "deploy-smoketests.yaml",
  "job-postinstall.yaml",
  "job-preflight.yaml",
  "job-upgradeservice.yaml",
  "secret-providerclass.yaml",
  "service-account.yaml",
  "service-mesh.yaml",
]);

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

function loadV76Templates(): TemplateManifest {
  const candidates = [
    resolve(__dirname, "..", "resources", "v76-templates.json"),
    resolve(__dirname, "resources", "v76-templates.json"),
  ];

  for (const p of candidates) {
    if (existsSync(p)) {
      return JSON.parse(readFileSync(p, "utf-8")) as TemplateManifest;
    }
  }

  throw new Error("v7.6 templates manifest not found. Expected at resources/v76-templates.json");
}

function sha256(content: string): string {
  return createHash("sha256").update(content).digest("hex");
}

/**
 * Simple line-level diff. Returns added and removed lines.
 */
function lineDiff(original: string, modified: string): FileDiff {
  const origLines = original.split("\n");
  const modLines = modified.split("\n");

  const origSet = new Set(origLines.map((l, i) => `${i}:${l}`));
  const modSet = new Set(modLines.map((l, i) => `${i}:${l}`));

  // Use a smarter approach: find lines in modified not in original (by content)
  const origContentCount: Record<string, number> = {};
  const modContentCount: Record<string, number> = {};

  for (const line of origLines) {
    origContentCount[line] = (origContentCount[line] ?? 0) + 1;
  }
  for (const line of modLines) {
    modContentCount[line] = (modContentCount[line] ?? 0) + 1;
  }

  const added: string[] = [];
  const removed: string[] = [];

  // Lines added in modified (appear more times in modified than original)
  const seenMod: Record<string, number> = {};
  for (const line of modLines) {
    seenMod[line] = (seenMod[line] ?? 0) + 1;
    if (seenMod[line] > (origContentCount[line] ?? 0)) {
      added.push(line);
    }
  }

  // Lines removed from original (appear more times in original than modified)
  const seenOrig: Record<string, number> = {};
  for (const line of origLines) {
    seenOrig[line] = (seenOrig[line] ?? 0) + 1;
    if (seenOrig[line] > (modContentCount[line] ?? 0)) {
      removed.push(line);
    }
  }

  return { added, removed };
}

/**
 * Categorize diff lines into meaningful change groups.
 */
function categorizeDiff(diff: FileDiff): string[] {
  const categories: string[] = [];

  const addedText = diff.added.join("\n");
  const removedText = diff.removed.join("\n");

  // Detect common patterns
  if (/initContainers|init[Cc]ontainer/.test(addedText)) {
    categories.push("Added init container(s)");
  }
  if (/sidecar|ambassador/i.test(addedText)) {
    categories.push("Added sidecar container(s)");
  }
  if (/env:|envFrom:|configMapRef|secretRef/.test(addedText) && !/env:|envFrom:/.test(removedText)) {
    categories.push("Added environment variables or config references");
  }
  if (/volumeMount|volumes:/.test(addedText) && !/volumeMount|volumes:/.test(removedText)) {
    categories.push("Added volume mounts");
  }
  if (/annotations:/.test(addedText)) {
    categories.push("Added or modified annotations");
  }
  if (/labels:/.test(addedText)) {
    categories.push("Added or modified labels");
  }
  if (/resources:|limits:|requests:/.test(addedText)) {
    categories.push("Modified resource limits/requests");
  }
  if (/tolerations:|nodeSelector:|affinity:/.test(addedText)) {
    categories.push("Modified scheduling constraints (tolerations/nodeSelector/affinity)");
  }
  if (/securityContext:/.test(addedText)) {
    categories.push("Modified security context");
  }
  if (/readinessProbe:|livenessProbe:|startupProbe:/.test(addedText)) {
    categories.push("Modified health probes");
  }
  if (/replicas:/.test(addedText)) {
    categories.push("Modified replica count");
  }
  if (/image:/.test(addedText)) {
    categories.push("Modified container image");
  }
  if (/port:|containerPort:|hostPort:/.test(addedText)) {
    categories.push("Modified port configuration");
  }

  if (categories.length === 0 && (diff.added.length > 0 || diff.removed.length > 0)) {
    categories.push(`${diff.added.length} line(s) added, ${diff.removed.length} line(s) removed`);
  }

  return categories;
}

// ---------------------------------------------------------------------------
// Main
// ---------------------------------------------------------------------------

export function migrateTemplates(templatesPath: string): MigrateTemplatesResult {
  const warnings: string[] = [];

  // Validate path
  if (!existsSync(templatesPath)) {
    return {
      summary: "Directory not found.",
      customFiles: [],
      modifiedFiles: [],
      unchangedCount: 0,
      warnings: [`Path does not exist: ${templatesPath}`],
      guidance: "Provide the absolute path to your v7.6 chart/templates/ (or redpoint-rpi/templates/) directory.",
    };
  }

  // Accept either the templates dir directly or a chart root
  let resolvedPath = templatesPath;
  if (existsSync(resolve(templatesPath, "templates"))) {
    resolvedPath = resolve(templatesPath, "templates");
  } else if (existsSync(resolve(templatesPath, "redpoint-rpi", "templates"))) {
    resolvedPath = resolve(templatesPath, "redpoint-rpi", "templates");
  }

  if (!statSync(resolvedPath).isDirectory()) {
    return {
      summary: "Path is not a directory.",
      customFiles: [],
      modifiedFiles: [],
      unchangedCount: 0,
      warnings: [`Not a directory: ${resolvedPath}`],
      guidance: "Provide the path to the templates directory, chart directory, or repository root.",
    };
  }

  // Load stock v7.6 templates
  const stock = loadV76Templates();
  const stockFilenames = new Set(Object.keys(stock));

  // Read user's templates
  const userFiles = readdirSync(resolvedPath).filter((f) => {
    const fullPath = resolve(resolvedPath, f);
    return statSync(fullPath).isFile();
  });

  const customFiles: TemplateAnalysis[] = [];
  const modifiedFiles: TemplateAnalysis[] = [];
  let unchangedCount = 0;

  for (const filename of userFiles) {
    const fullPath = resolve(resolvedPath, filename);
    const userContent = readFileSync(fullPath, "utf-8");
    const userHash = sha256(userContent);

    if (!stockFilenames.has(filename)) {
      // Custom file — not in stock v7.6
      const analysis: TemplateAnalysis = {
        filename,
        status: "custom",
        guidance: "",
      };

      // Determine guidance based on what it looks like
      if (filename.endsWith(".yaml") || filename.endsWith(".yml")) {
        if (/kind:\s*(Deployment|StatefulSet|DaemonSet)/i.test(userContent)) {
          analysis.guidance =
            "Custom workload template. Copy this file to your v7.7 chart/templates/ directory. " +
            "Review for compatibility: check image references, service account names, and " +
            "label selectors that may have changed in v7.7.";
        } else if (/kind:\s*(ConfigMap|Secret)/i.test(userContent)) {
          analysis.guidance =
            "Custom ConfigMap or Secret. Copy to v7.7 chart/templates/. " +
            "If it references values paths that changed in v7.7, update the paths " +
            "(see the key renames table in the migration guide).";
        } else if (/kind:\s*(CronJob|Job)/i.test(userContent)) {
          analysis.guidance =
            "Custom Job or CronJob. Copy to v7.7 chart/templates/. " +
            "Review for updated image references and service account names.";
        } else if (/kind:\s*(NetworkPolicy|PodDisruptionBudget|ServiceMonitor)/i.test(userContent)) {
          analysis.guidance =
            "Custom network/monitoring resource. Copy to v7.7 chart/templates/. " +
            "Update label selectors if they reference RPI pod labels that changed.";
        } else if (/kind:\s*(Ingress|IngressRoute)/i.test(userContent)) {
          analysis.guidance =
            "Custom ingress resource. Copy to v7.7 chart/templates/. " +
            "The v7.7 ingress-routes.yaml was restructured — verify this doesn't conflict " +
            "with the built-in ingress rules.";
        } else {
          analysis.guidance =
            "Custom template file. Copy to v7.7 chart/templates/ and review for " +
            "compatibility with v7.7 values paths and naming conventions.";
        }
      } else if (filename.endsWith(".tpl")) {
        analysis.guidance =
          "Custom template helper. Copy to v7.7 chart/templates/. " +
          "Check for references to helpers that were renamed or restructured in v7.7 " +
          "(e.g., _helpers.tpl was significantly rewritten).";
      } else {
        analysis.guidance = "Custom file. Review and copy to v7.7 if still needed.";
      }

      customFiles.push(analysis);
      continue;
    }

    // Stock file — check if modified
    const stockEntry = stock[filename];
    if (userHash === stockEntry.hash) {
      unchangedCount++;
      continue;
    }

    // Modified stock file
    const diff = lineDiff(stockEntry.content, userContent);
    const categories = categorizeDiff(diff);
    const v77Equivalent = V76_RENAMED_IN_V77[filename] ?? filename;
    const existsInV77 = !V76_REMOVED_IN_V77[filename];

    let guidance = "";

    if (filename === "_helpers.tpl") {
      guidance =
        "The _helpers.tpl was completely rewritten in v7.7 (new merge system, cloud identity helpers, " +
        "validation helpers). You cannot copy your v7.6 version over. Instead, review your custom " +
        "helpers below and re-implement them as additions to the v7.7 _helpers.tpl.";
      warnings.push(
        "You have customizations in _helpers.tpl. This file was extensively rewritten in v7.7. " +
        "Your custom helpers must be manually ported to the new version."
      );
    } else if (filename === "ingress-routes.yaml" || filename === "ingress-controller.yaml") {
      guidance =
        "The ingress templates were restructured in v7.7. Do not copy your v7.6 version. " +
        "Instead, review the changes below and apply your customizations to the v7.7 version. " +
        "Many ingress customizations can now be handled through values (ingress.hosts, ingress.tls, " +
        "ingress.className) instead of template edits.";
    } else if (filename === "deploy-secrets.yaml") {
      guidance =
        "The secrets template was restructured in v7.7 for the new secretsManagement system. " +
        "If you added custom secret keys, add them to the v7.7 version of deploy-secrets.yaml. " +
        "If you changed how secrets are mounted, check if the new secretsManagement provider " +
        "options (kubernetes, sdk, csi) cover your use case first.";
    } else if (filename.startsWith("deploy-")) {
      const serviceName = filename.replace("deploy-", "").replace(".yaml", "");
      guidance =
        `Review the changes below and apply them to the v7.7 version of ${filename}. ` +
        `The v7.7 deployment templates use the new three-tier merge system (_defaults.tpl → ` +
        `advanced: → user values), so many customizations (probes, resources, security context, ` +
        `labels, annotations) can now be set through values instead of template edits. ` +
        `Check if your changes can be expressed as values before editing the template.`;

      if (diff.added.some((l) => /initContainers|sidecar/i.test(l))) {
        guidance +=
          "\n\nYour init containers or sidecars will need to be re-added to the v7.7 template, " +
          "as these cannot be configured through values.";
      }
    } else if (filename === "hpa.yaml" || filename === "keda.yaml") {
      guidance =
        "Autoscaling templates. Copy your modifications to the v7.7 version. " +
        "The structure is largely unchanged.";
    } else if (filename === "networkpolicy.yaml") {
      guidance =
        "Network policy template. Copy your modifications to the v7.7 version. " +
        "Update any label selectors that reference RPI pod labels.";
    } else if (filename === "NOTES.txt") {
      guidance =
        "Post-install notes template. The v7.7 version has updated content. " +
        "If you customized this for your organization, merge your changes into the v7.7 version.";
    } else {
      guidance =
        `Review the diff below and apply relevant changes to the v7.7 version of ${v77Equivalent}.`;
    }

    // Add specific guidance for common change patterns
    if (categories.includes("Added environment variables or config references")) {
      guidance +=
        "\n\nCustom environment variables: In v7.7, you can add extra env vars through the " +
        "advanced: block (e.g., advanced.<service>.extraEnv) if supported, otherwise add them " +
        "directly to the v7.7 template.";
    }

    modifiedFiles.push({
      filename,
      status: "modified",
      v77Equivalent: existsInV77 ? v77Equivalent : undefined,
      diff: {
        added: diff.added.slice(0, 50), // Limit output size
        removed: diff.removed.slice(0, 50),
      },
      guidance: guidance + (categories.length > 0 ? `\n\nDetected changes: ${categories.join(", ")}` : ""),
    });
  }

  // Check for stock v7.6 files missing from user's directory (deleted files)
  for (const stockFile of stockFilenames) {
    if (!userFiles.includes(stockFile)) {
      warnings.push(
        `Stock v7.6 template ${stockFile} is missing from your templates directory. ` +
        `If you intentionally removed it, note that v7.7 may still include it.`
      );
    }
  }

  // Build summary
  const total = userFiles.length;
  const parts: string[] = [];
  parts.push(`Analyzed ${total} template file(s) in ${resolvedPath}.`);
  parts.push(`${unchangedCount} unchanged (stock v7.6).`);
  if (modifiedFiles.length > 0) {
    parts.push(`${modifiedFiles.length} modified from stock v7.6 — need manual review.`);
  }
  if (customFiles.length > 0) {
    parts.push(`${customFiles.length} custom file(s) not in stock v7.6 — need to be carried forward.`);
  }
  if (modifiedFiles.length === 0 && customFiles.length === 0) {
    parts.push("No template customizations detected — you can use the standard v7.7 templates as-is.");
  }

  // Overall guidance
  let overallGuidance =
    "## Migration Steps\n\n" +
    "1. Start with the stock v7.7 chart/templates/ directory.\n";

  if (customFiles.length > 0) {
    overallGuidance +=
      "2. Copy your custom template files into the v7.7 templates/ directory.\n" +
      "   Review each for compatibility with v7.7 values paths and conventions.\n";
  }

  if (modifiedFiles.length > 0) {
    overallGuidance +=
      `${customFiles.length > 0 ? "3" : "2"}. For each modified stock template, review the diff below ` +
      "and apply your changes to the v7.7 version of that file.\n" +
      "   Many v7.6 template-level customizations can now be handled through values in v7.7 " +
      "(resources, probes, labels, annotations, security context). Check values first before editing templates.\n";
  }

  overallGuidance +=
    `${customFiles.length > 0 && modifiedFiles.length > 0 ? "4" : customFiles.length > 0 || modifiedFiles.length > 0 ? "3" : "2"}. ` +
    "Run `helm template` with your v7.7 values to verify the rendered output is correct.\n";

  return {
    summary: parts.join(" "),
    customFiles,
    modifiedFiles,
    unchangedCount,
    warnings,
    guidance: overallGuidance,
  };
}
