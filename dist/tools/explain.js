import { readFileSync } from "node:fs";
import { schemaExists, getSchemaPath } from "../lib/paths.js";
/**
 * Hardcoded knowledge map for the most important keys — provides
 * context that goes beyond what the JSON Schema captures.
 */
const KNOWLEDGE_MAP = {
    "global.deployment.platform": "Controls which cloud-specific templates are activated (workload identity annotations, CSI drivers, etc.). Changing platform after initial deploy requires re-creating cloud identity resources.",
    "global.deployment.mode": "Set to 'demo' only for local development/demos. Demo mode deploys embedded MSSQL and MongoDB containers inside the cluster. Never use demo mode in production.",
    "global.deployment.images.tag": "The RPI container image tag. Format: <major.minor>.<year>-<MMDD>-<HHMM>. All services share the same tag. Upgrade by changing this value and running helm upgrade.",
    "cloudIdentity.enabled": "Enables pod-to-cloud authentication (Workload Identity / IRSA). Required when secretsManagement.provider is 'sdk' or 'csi'. When enabled, the chart creates a ServiceAccount with the appropriate cloud-specific annotations.",
    "cloudIdentity.serviceAccount.create": "When true, creates a single shared ServiceAccount for all RPI pods. When false, each service deployment creates its own SA, enabling per-service identity federation.",
    "secretsManagement.provider": "Three modes: 'kubernetes' (chart-managed K8s Secrets), 'sdk' (app reads directly from cloud vault at runtime), 'csi' (CSI Secret Store driver syncs vault to K8s Secret). Both 'sdk' and 'csi' require cloudIdentity.enabled=true.",
    "databases.operational.provider": "The operational database engine. 'sqlserver' is the most common. 'postgresql' is supported on all platforms. 'sqlserveronvm' is for self-hosted SQL Server instances.",
    "realtimeapi.enabled": "Enables the Realtime API deployment. The Realtime API powers real-time decisioning, visitor tracking, and recommendations.",
    "realtimeapi.cacheProvider.provider": "The backing store for the real-time cache. Options: mongodb (most common), azureredis, redis, inMemorySql (dev only), googlebigtable (GCP only). Each provider requires its own connection configuration block below.",
    "realtimeapi.authentication.type": "API authentication mode. 'basic' uses API key authentication. 'oauth' uses OAuth2 with configurable token lifetimes.",
    "storage.persistentVolumeClaims.FileOutputDirectory": "Mount a PVC for file output (execution results, exports). Required when RPI needs to write files to shared storage.",
    "ingress.enabled": "When true, the chart creates Ingress resources for external access. Requires an Ingress controller (nginx, traefik, ALB, etc.) to be installed in the cluster.",
    "secretsManagement.sdk.azure.vaultUri": "The URI of the Azure Key Vault (e.g., https://myvault.vault.azure.net/). Used when secretsManagement.provider is 'sdk' and platform is 'azure'.",
    "secretsManagement.csi.secretProviderClasses": "Array of SecretProviderClass definitions that map cloud vault secrets to Kubernetes Secrets via the CSI driver.",
    "databases.datawarehouse.redshift": "Configuration for Amazon Redshift data warehouse connections. Each connection entry specifies server endpoint, port, database, and credentials.",
    "databases.datawarehouse.bigquery": "Configuration for Google BigQuery data warehouse connections. Requires a service account JSON key mounted via ConfigMap.",
    "databases.datawarehouse.snowflake": "Configuration for Snowflake data warehouse. Supports JWT-based authentication with an RSA key mounted via ConfigMap.",
    "databases.datawarehouse.databricks": "Configuration for Databricks data warehouse connections. Uses personal access tokens for authentication.",
    "smartActivation.enabled": "Enables Smart Activation (SA) services — a set of Java-based microservices for ML-driven audience targeting. Requires additional infrastructure (typically its own database and cache).",
    "global.deployment.images.imagePullSecret": "Configuration for the image pull secret used to authenticate with the container registry. Required for private registries.",
};
/**
 * Walk a JSON Schema object to find the sub-schema at the given dot-path.
 */
function walkSchema(schema, segments) {
    let current = schema;
    for (const seg of segments) {
        // Try properties
        const props = current.properties;
        if (props && props[seg]) {
            current = props[seg];
            continue;
        }
        // Try items.properties (for arrays)
        const items = current.items;
        if (items) {
            const itemProps = items.properties;
            if (itemProps && itemProps[seg]) {
                current = itemProps[seg];
                continue;
            }
        }
        // Try additionalProperties
        const addlProps = current.additionalProperties;
        if (addlProps && typeof addlProps === "object") {
            current = addlProps;
            continue;
        }
        return null;
    }
    return current;
}
/**
 * Explain a specific values key path using the JSON Schema and the
 * hardcoded knowledge map.
 */
export function explain(keyPath) {
    const segments = keyPath.split(".");
    const result = { keyPath, found: false };
    // Schema lookup
    if (schemaExists()) {
        try {
            const schemaContent = readFileSync(getSchemaPath(), "utf-8");
            const schema = JSON.parse(schemaContent);
            const node = walkSchema(schema, segments);
            if (node) {
                result.found = true;
                result.type = node.type;
                result.description = node.description;
                result.defaultValue = node.default;
                result.enumValues = node.enum;
                // Check if this key is required by its parent
                if (segments.length > 1) {
                    const parent = walkSchema(schema, segments.slice(0, -1));
                    if (parent) {
                        const req = parent.required;
                        result.required = req?.includes(segments[segments.length - 1]);
                    }
                }
            }
        }
        catch {
            // Schema read failed — fall through to knowledge map
        }
    }
    // Knowledge map enrichment
    const extra = KNOWLEDGE_MAP[keyPath];
    if (extra) {
        result.found = true;
        result.additionalContext = extra;
    }
    if (!result.found) {
        // Provide partial matches as hints
        const partialMatches = Object.keys(KNOWLEDGE_MAP).filter((k) => k.includes(segments[segments.length - 1]));
        if (partialMatches.length > 0) {
            result.additionalContext = `Key not found. Did you mean one of: ${partialMatches.join(", ")}?`;
        }
    }
    return result;
}
//# sourceMappingURL=explain.js.map