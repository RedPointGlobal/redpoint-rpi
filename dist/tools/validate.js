import { readFileSync, existsSync } from "node:fs";
import yaml from "js-yaml";
import AjvModule from "ajv";
import addFormatsModule from "ajv-formats";
const Ajv = AjvModule.default ?? AjvModule;
const addFormats = addFormatsModule.default ?? addFormatsModule;
import { getSchemaPath, schemaExists } from "../lib/paths.js";
/**
 * Placeholder pattern: detects values like <my-something> that the user
 * forgot to replace.
 */
const PLACEHOLDER_RE = /^<[^>]+>$/;
/**
 * Walk an object recursively and collect placeholder warnings.
 */
function findPlaceholders(obj, prefix, results) {
    if (obj === null || obj === undefined)
        return;
    if (typeof obj === "string" && PLACEHOLDER_RE.test(obj)) {
        results.push({
            path: prefix,
            message: `Placeholder value detected: ${obj}`,
            severity: "warning",
            suggestion: `Replace ${obj} with an actual value before deploying.`,
        });
    }
    else if (Array.isArray(obj)) {
        obj.forEach((item, i) => findPlaceholders(item, `${prefix}[${i}]`, results));
    }
    else if (typeof obj === "object") {
        for (const [key, value] of Object.entries(obj)) {
            findPlaceholders(value, prefix ? `${prefix}.${key}` : key, results);
        }
    }
}
/**
 * Heuristic checks that go beyond JSON Schema validation.
 */
function heuristicChecks(values, results) {
    // Check for placeholders
    findPlaceholders(values, "", results);
    // Check: demo mode should not be used in production-like configs
    const global = values.global;
    const deployment = global?.deployment;
    if (deployment?.mode === "demo") {
        const secretsMgmt = values.secretsManagement;
        if (secretsMgmt?.provider && secretsMgmt.provider !== "kubernetes") {
            results.push({
                path: "global.deployment.mode",
                message: "Demo mode is set with a non-kubernetes secrets provider. Demo mode is intended for development only.",
                severity: "warning",
                suggestion: "Set global.deployment.mode to 'standard' for non-development environments.",
            });
        }
    }
    // Check: cloudIdentity required for sdk/csi secrets
    const secretsMgmt = values.secretsManagement;
    const cloudIdentity = values.cloudIdentity;
    if (secretsMgmt?.provider &&
        (secretsMgmt.provider === "sdk" || secretsMgmt.provider === "csi")) {
        if (!cloudIdentity?.enabled) {
            results.push({
                path: "cloudIdentity.enabled",
                message: `secretsManagement.provider is '${secretsMgmt.provider}' but cloudIdentity is not enabled.`,
                severity: "error",
                suggestion: "Set cloudIdentity.enabled to true when using sdk or csi secrets.",
            });
        }
    }
    // Check: realtimeapi cache provider mongodb needs connection string
    const rtapi = values.realtimeapi;
    const cacheProvider = rtapi?.cacheProvider;
    if (cacheProvider?.enabled && cacheProvider?.provider === "mongodb") {
        const mongo = cacheProvider.mongodb;
        if (!mongo?.connectionString || PLACEHOLDER_RE.test(String(mongo.connectionString))) {
            results.push({
                path: "realtimeapi.cacheProvider.mongodb.connectionString",
                message: "MongoDB cache provider is enabled but connectionString is missing or a placeholder.",
                severity: "warning",
                suggestion: "Provide a valid MongoDB connection string.",
            });
        }
    }
    // Check: platform must be one of the known values
    if (deployment?.platform) {
        const validPlatforms = ["azure", "amazon", "google", "selfhosted"];
        if (!validPlatforms.includes(String(deployment.platform))) {
            results.push({
                path: "global.deployment.platform",
                message: `Unknown platform '${deployment.platform}'.`,
                severity: "error",
                suggestion: `Valid platforms: ${validPlatforms.join(", ")}`,
            });
        }
    }
}
/**
 * Validate a YAML values string (or file path) against the chart's
 * JSON Schema and heuristic rules.
 */
export function validate(valuesInput) {
    const results = [];
    // Determine if input is a file path or raw YAML
    let yamlContent;
    if (!valuesInput.includes("\n") && existsSync(valuesInput)) {
        yamlContent = readFileSync(valuesInput, "utf-8");
    }
    else {
        yamlContent = valuesInput;
    }
    // Parse YAML
    let values;
    try {
        values = yaml.load(yamlContent);
        if (typeof values !== "object" || values === null) {
            return {
                results: [
                    {
                        path: "(root)",
                        message: "YAML did not parse to an object. Expected a mapping at the top level.",
                        severity: "error",
                    },
                ],
                parsed: false,
            };
        }
    }
    catch (err) {
        return {
            results: [
                {
                    path: "(root)",
                    message: `YAML parse error: ${err instanceof Error ? err.message : String(err)}`,
                    severity: "error",
                },
            ],
            parsed: false,
        };
    }
    // Schema validation (if schema file exists)
    if (schemaExists()) {
        try {
            const schemaContent = readFileSync(getSchemaPath(), "utf-8");
            const schema = JSON.parse(schemaContent);
            const ajv = new Ajv({ allErrors: true, strict: false });
            addFormats(ajv);
            const valid = ajv.validate(schema, values);
            if (!valid && ajv.errors) {
                for (const err of ajv.errors) {
                    results.push({
                        path: err.instancePath || "(root)",
                        message: err.message ?? "Schema validation error",
                        severity: "error",
                        suggestion: err.params
                            ? `Details: ${JSON.stringify(err.params)}`
                            : undefined,
                    });
                }
            }
        }
        catch (err) {
            results.push({
                path: "(schema)",
                message: `Could not load or parse schema: ${err instanceof Error ? err.message : String(err)}`,
                severity: "warning",
            });
        }
    }
    else {
        results.push({
            path: "(schema)",
            message: "values.schema.json not found; skipping JSON Schema validation. Heuristic checks still apply.",
            severity: "info",
        });
    }
    // Heuristic checks
    heuristicChecks(values, results);
    return { results, parsed: true };
}
//# sourceMappingURL=validate.js.map