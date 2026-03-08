import { readFileSync, existsSync } from "node:fs";
import { resolve, dirname } from "node:path";
import { fileURLToPath } from "node:url";
import yaml from "js-yaml";

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

// ---------------------------------------------------------------------------
// Key rename map: v7.6 path → v7.7 path
// ---------------------------------------------------------------------------
const KEY_RENAMES: Record<string, string> = {
  // Cloud identity
  "cloudIdentity.provider": "__REMOVED__",
  "cloudIdentity.azureSettings": "cloudIdentity.azure",
  "cloudIdentity.amazonSettings": "cloudIdentity.amazon",
  "cloudIdentity.googleSettings": "cloudIdentity.google",
  "cloudIdentity.secretsManagement": "secretsManagement",

  // Global images consolidated
  "global.deployment.images.interactionapi": "__REMOVED__",
  "global.deployment.images.integrationapi": "__REMOVED__",
  "global.deployment.images.executionservice": "__REMOVED__",
  "global.deployment.images.nodemanager": "__REMOVED__",
  "global.deployment.images.callbackapi": "__REMOVED__",
  "global.deployment.images.deploymentapi": "__REMOVED__",
  "global.deployment.images.realtimeapi": "__REMOVED__",
  "global.deployment.images.queuereader": "__REMOVED__",
  "global.deployment.images.rabbitmq": "__REMOVED__",
  "global.deployment.images.rediscache": "__REMOVED__",
  "global.deployment.images.ingress_controller": "__REMOVED__",
  "global.deployment.images.net_utils": "__REMOVED__",
  "global.deployment.images.cdpauthservices": "__REMOVED__",
  "global.deployment.images.cdpinitservice": "__REMOVED__",
  "global.deployment.images.cdpservicesapi": "__REMOVED__",
  "global.deployment.images.cdpuiservice": "__REMOVED__",
  "global.deployment.images.cdpsocketio": "__REMOVED__",
  "global.deployment.images.cdpmessageq": "__REMOVED__",
  "global.deployment.images.cdpmaintenanceservice": "__REMOVED__",
  "global.deployment.images.keycloak": "__REMOVED__",
  "global.application": "__REMOVED__",

  // Ingress
  "ingress.tlsSecretName": "__MOVED_TO_TLS_ARRAY__",

  // Per-service labels/annotations renamed
  // These are handled generically in the mapping logic
};

// Keys that move from top-level to advanced: in v7.7
const ADVANCED_PREFIXES = [
  "securityContext",
  "topologySpreadConstraints",
];

// Per-service keys that move to advanced
const SERVICE_ADVANCED_KEYS = [
  "logging", "livenessProbe", "readinessProbe", "startupProbe",
  "type", "rollout", "customMetrics", "terminationGracePeriodSeconds",
  "service", "podDisruptionBudget",
];

// Service names in both v7.6 and v7.7
const SERVICES = [
  "realtimeapi", "callbackapi", "executionservice", "interactionapi",
  "integrationapi", "nodemanager", "deploymentapi", "queuereader",
];

// Keys that are user-facing in v7.7 (stay at top level for services)
const SERVICE_TOP_LEVEL_KEYS = [
  "enabled", "replicas", "resources", "cacheProvider", "queueProvider",
  "channelLabel", "multitenancy", "instances",
  "enableRPIAuthentication", "authMetaHttpEnabled", "enableSwagger",
  "enableHelpPages", "authentication", "rpiClientID",
  "isFormProcessingEnabled", "isEventProcessingEnabled",
  "isCacheProcessingEnabled", "isRecommendationsProcessingEnabled",
  "isListenerProcessingEnabled", "isCallbackProcessingEnabled",
  "jobExecution", "internalCache",
  "realtimeConfiguration", "errorQueuePath", "nonActiveQueuePath",
  "dataMaps", "idValidation", "customPlugins",
];

interface MigrateResult {
  summary: string;
  customizationCount: number;
  warnings: string[];
  v77Yaml: string;
}

/**
 * Deep-diff two objects. Returns paths where userObj differs from defaultObj.
 */
function deepDiff(
  defaultObj: Record<string, unknown>,
  userObj: Record<string, unknown>,
  prefix = "",
): Array<{ path: string; value: unknown }> {
  const diffs: Array<{ path: string; value: unknown }> = [];

  for (const key of Object.keys(userObj)) {
    const fullPath = prefix ? `${prefix}.${key}` : key;
    const userVal = userObj[key];
    const defaultVal = defaultObj?.[key];

    if (defaultVal === undefined) {
      // Key exists in user but not in defaults — it's a customization
      diffs.push({ path: fullPath, value: userVal });
    } else if (
      typeof userVal === "object" &&
      userVal !== null &&
      !Array.isArray(userVal) &&
      typeof defaultVal === "object" &&
      defaultVal !== null &&
      !Array.isArray(defaultVal)
    ) {
      // Recurse into nested objects
      diffs.push(
        ...deepDiff(
          defaultVal as Record<string, unknown>,
          userVal as Record<string, unknown>,
          fullPath,
        ),
      );
    } else {
      // Leaf comparison
      if (JSON.stringify(userVal) !== JSON.stringify(defaultVal)) {
        diffs.push({ path: fullPath, value: userVal });
      }
    }
  }

  return diffs;
}

/**
 * Set a deep key on an object. E.g., setDeep(obj, "a.b.c", 42)
 */
function setDeep(obj: Record<string, unknown>, path: string, value: unknown): void {
  const parts = path.split(".");
  let current = obj;
  for (let i = 0; i < parts.length - 1; i++) {
    if (!(parts[i] in current) || typeof current[parts[i]] !== "object") {
      current[parts[i]] = {};
    }
    current = current[parts[i]] as Record<string, unknown>;
  }
  current[parts[parts.length - 1]] = value;
}

/**
 * Load the bundled v7.6 defaults.
 */
function loadV76Defaults(): Record<string, unknown> {
  // In dev: src/resources/v76-defaults.yaml
  // In dist: dist/resources/v76-defaults.yaml
  const candidates = [
    resolve(__dirname, "..", "resources", "v76-defaults.yaml"),
    resolve(__dirname, "resources", "v76-defaults.yaml"),
  ];

  for (const p of candidates) {
    if (existsSync(p)) {
      return yaml.load(readFileSync(p, "utf-8")) as Record<string, unknown>;
    }
  }

  throw new Error("v7.6 defaults file not found. Expected at resources/v76-defaults.yaml");
}

/**
 * Migrate a v7.6 values file to v7.7 format.
 */
export function migrate(valuesInput: string): MigrateResult {
  const warnings: string[] = [];

  // Parse user's v7.6 values
  let userValues: Record<string, unknown>;
  if (existsSync(valuesInput)) {
    userValues = yaml.load(readFileSync(valuesInput, "utf-8")) as Record<string, unknown>;
  } else {
    userValues = yaml.load(valuesInput) as Record<string, unknown>;
  }

  if (!userValues || typeof userValues !== "object") {
    return {
      summary: "Could not parse the provided values file.",
      customizationCount: 0,
      warnings: ["Input is not valid YAML or is empty."],
      v77Yaml: "",
    };
  }

  // Load v7.6 defaults
  const v76Defaults = loadV76Defaults();

  // Find customizations (diffs from defaults)
  const diffs = deepDiff(v76Defaults, userValues);

  // Build v7.7 output
  const v77: Record<string, unknown> = {};
  const v77Advanced: Record<string, unknown> = {};
  let customizationCount = 0;

  for (const { path, value } of diffs) {
    // Skip commented-out or null values
    if (value === null || value === undefined) continue;

    // Check exact rename first
    const renamed = KEY_RENAMES[path];
    if (renamed === "__REMOVED__") {
      continue;
    }

    // Handle tlsSecretName → tls array
    if (renamed === "__MOVED_TO_TLS_ARRAY__") {
      setDeep(v77, "ingress.tls", [{ secretName: value }]);
      customizationCount++;
      continue;
    }

    // Handle explicit renames (exact path match)
    if (renamed) {
      setDeep(v77, renamed, value);
      customizationCount++;
      continue;
    }

    // Handle prefix-based renames: if a parent path is renamed, rewrite the child path
    const prefixMatch = Object.entries(KEY_RENAMES).find(
      ([oldPrefix, newPrefix]) =>
        path.startsWith(oldPrefix + ".") && newPrefix !== "__REMOVED__" && newPrefix !== "__MOVED_TO_TLS_ARRAY__",
    );
    if (prefixMatch) {
      const [oldPrefix, newPrefix] = prefixMatch;
      if (newPrefix === "__REMOVED__") {
        continue;
      }
      const suffix = path.slice(oldPrefix.length); // includes leading "."
      setDeep(v77, newPrefix + suffix, value);
      customizationCount++;
      continue;
    }

    // Check if path falls under a removed parent
    const removedParent = Object.entries(KEY_RENAMES).find(
      ([oldPrefix, newPrefix]) => path.startsWith(oldPrefix + ".") && newPrefix === "__REMOVED__",
    );
    if (removedParent) {
      continue;
    }

    // Handle top-level keys that move to advanced
    const topKey = path.split(".")[0];
    if (ADVANCED_PREFIXES.includes(topKey)) {
      setDeep(v77Advanced, path, value);
      customizationCount++;
      continue;
    }

    // Handle per-service keys
    if (SERVICES.includes(topKey)) {
      const serviceSubKey = path.split(".").slice(1).join(".");
      const firstSubKey = path.split(".")[1];

      // Per-service label/annotation renames
      if (firstSubKey === "customLabels") {
        const newPath = path.replace("customLabels", "podLabels");
        setDeep(v77Advanced, newPath, value);
        customizationCount++;
        continue;
      }
      if (firstSubKey === "customAnnotations") {
        const newPath = path.replace("customAnnotations", "podAnnotations");
        setDeep(v77Advanced, newPath, value);
        customizationCount++;
        continue;
      }

      // Service account → skip (centralized in v7.7)
      if (firstSubKey === "serviceAccount") {
        continue;
      }

      // Keys that move to advanced for services
      if (SERVICE_ADVANCED_KEYS.includes(firstSubKey)) {
        setDeep(v77Advanced, path, value);
        customizationCount++;
        continue;
      }

      // Everything else stays at top level
      setDeep(v77, path, value);
      customizationCount++;
      continue;
    }

    // Handle Smart Activation services (pass through)
    const saServices = [
      "authservice", "keycloak", "initservice", "messageq",
      "maintenanceservice", "servicesapi", "socketio", "uiservice", "cdpcache",
    ];
    if (saServices.includes(topKey)) {
      setDeep(v77Advanced, path, value);
      customizationCount++;
      continue;
    }

    // Handle queuereader key renames
    if (path === "queuereader.listenerQueueErrorQueuePath") {
      setDeep(v77, "queuereader.errorQueuePath", value);
      customizationCount++;
      continue;
    }
    if (path === "queuereader.listenerQueueNonActiveQueuePath") {
      setDeep(v77, "queuereader.nonActiveQueuePath", value);
      customizationCount++;
      continue;
    }

    // Default: keep at top level
    setDeep(v77, path, value);
    customizationCount++;
  }

  // Merge advanced into output
  if (Object.keys(v77Advanced).length > 0) {
    v77.advanced = v77Advanced;
  }

  // Handle image tag — extract from v7.6 and map to v7.7 global.deployment.images.tag
  const v76Images = (userValues as any)?.global?.deployment?.images;
  if (v76Images?.tag) {
    setDeep(v77, "global.deployment.images.tag", v76Images.tag);
    // Also set the consolidated repository if they used the default
    const defaultRepo = "rg1acrpub.azurecr.io/docker/redpointglobal/releases";
    const firstImageVal = v76Images.interactionapi;
    if (firstImageVal && firstImageVal.startsWith(defaultRepo)) {
      // They use the default repo — no need to set repository
    } else if (firstImageVal) {
      // Custom repo — extract the base path
      const parts = firstImageVal.split("/");
      parts.pop(); // remove image name
      setDeep(v77, "global.deployment.images.repository", parts.join("/"));
    }
  }

  // Add warnings for things that need manual attention
  if ((userValues as any)?.cloudIdentity?.secretsManagement?.enabled) {
    warnings.push(
      "secretsManagement has moved from cloudIdentity.secretsManagement to top-level secretsManagement. " +
      "Review the generated output to ensure provider settings are correct."
    );
  }

  const dbPassword = (v77 as any)?.databases?.operational?.server_password;
  if (dbPassword && !dbPassword.includes("SECRET") && !dbPassword.includes("CHANGE_ME")) {
    warnings.push(
      "Database password detected in plain text. Consider using secretsManagement (sdk or csi) " +
      "instead of embedding passwords in your values file."
    );
  }

  if ((userValues as any)?.ingress?.className === "nginx-redpoint-rpi") {
    warnings.push(
      "ingress.className default changed from 'nginx-redpoint-rpi' to the release namespace. " +
      "If you rely on the old class name, set it explicitly in your overrides."
    );
  }

  // Generate YAML
  const header = [
    "# ============================================================",
    "# RPI v7.7 Overrides — Migrated from v7.6",
    `# Generated by Interaction Copilot — ${new Date().toISOString().slice(0, 10)}`,
    "# ============================================================",
    `# ${customizationCount} customization(s) detected from your v7.6 values.`,
    "# Review this file before deploying. Unset values use chart defaults.",
    "# ============================================================",
    "",
  ].join("\n");

  const v77Yaml = header + yaml.dump(v77, { lineWidth: 120, noRefs: true, sortKeys: false });

  return {
    summary: `Found ${customizationCount} customization(s) from your v7.6 values file. ` +
      `${Object.keys(v77Advanced).length > 0
        ? `${Object.keys(v77Advanced).length} section(s) moved to the advanced: block.`
        : "No values needed in the advanced: block."}`,
    customizationCount,
    warnings,
    v77Yaml,
  };
}
