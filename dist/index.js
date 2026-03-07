#!/usr/bin/env node
import { Server } from "@modelcontextprotocol/sdk/server/index.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { CallToolRequestSchema, ListToolsRequestSchema, } from "@modelcontextprotocol/sdk/types.js";
import { registerResources } from "./resources/index.js";
import { validate } from "./tools/validate.js";
import { generate } from "./tools/generate.js";
import { template } from "./tools/template.js";
import { explain } from "./tools/explain.js";
import { status } from "./tools/status.js";
import { troubleshoot } from "./tools/troubleshoot.js";
import { docsSearch, docsFetch } from "./tools/docs.js";
const server = new Server({ name: "rpi-helm", version: "1.0.0" }, { capabilities: { tools: {}, resources: {} } });
// ---------------------------------------------------------------------------
// Tool definitions
// ---------------------------------------------------------------------------
const TOOLS = [
    {
        name: "rpi_validate",
        description: "Validate an RPI Helm chart values file against the JSON Schema and heuristic rules. " +
            "Detects schema violations, placeholder values, missing required fields, and common misconfigurations. " +
            "Input can be raw YAML content or an absolute file path.",
        inputSchema: {
            type: "object",
            properties: {
                values: {
                    type: "string",
                    description: "YAML content or absolute file path to validate",
                },
            },
            required: ["values"],
        },
    },
    {
        name: "rpi_generate",
        description: "Generate a starter RPI overrides YAML from structured parameters. " +
            "Produces a valid values file customized for the target platform, secrets mode, " +
            "and optional features (Realtime API, Smart Activation, ingress, etc.).",
        inputSchema: {
            type: "object",
            properties: {
                platform: {
                    type: "string",
                    enum: ["azure", "amazon", "google", "selfhosted"],
                    description: "Target cloud platform",
                },
                mode: {
                    type: "string",
                    enum: ["standard", "demo"],
                    description: "Deployment mode (default: standard)",
                },
                database: {
                    type: "object",
                    description: "Operational database configuration",
                    properties: {
                        provider: {
                            type: "string",
                            enum: ["sqlserver", "postgresql", "sqlserveronvm"],
                        },
                        server_host: { type: "string" },
                        server_username: { type: "string" },
                        server_password: { type: "string" },
                        pulse_database_name: { type: "string" },
                        pulse_logging_database_name: { type: "string" },
                    },
                },
                cloudIdentity: {
                    type: "object",
                    description: "Cloud identity (Workload Identity / IRSA) settings",
                    properties: {
                        enabled: { type: "boolean" },
                        azure: {
                            type: "object",
                            properties: {
                                managedIdentityClientId: { type: "string" },
                                tenantId: { type: "string" },
                            },
                        },
                        google: {
                            type: "object",
                            properties: {
                                serviceAccountEmail: { type: "string" },
                                projectId: { type: "string" },
                            },
                        },
                        amazon: {
                            type: "object",
                            properties: {
                                roleArn: { type: "string" },
                                region: { type: "string" },
                            },
                        },
                    },
                },
                secretsProvider: {
                    type: "string",
                    enum: ["kubernetes", "sdk", "csi"],
                    description: "Secrets management provider (default: kubernetes)",
                },
                ingress: {
                    type: "object",
                    description: "Ingress configuration",
                    properties: {
                        enabled: { type: "boolean" },
                        hostname: { type: "string" },
                        tlsSecretName: { type: "string" },
                        className: { type: "string" },
                    },
                },
                realtimeapi: {
                    type: "object",
                    description: "Realtime API configuration",
                    properties: {
                        enabled: { type: "boolean" },
                        cacheProvider: {
                            type: "string",
                            enum: [
                                "mongodb",
                                "redis",
                                "azureredis",
                                "inMemorySql",
                                "googlebigtable",
                            ],
                        },
                        mongoConnectionString: { type: "string" },
                        redisConnectionString: { type: "string" },
                    },
                },
                smartActivation: {
                    type: "object",
                    description: "Smart Activation settings",
                    properties: {
                        enabled: { type: "boolean" },
                    },
                },
            },
            required: ["platform"],
        },
    },
    {
        name: "rpi_template",
        description: "Render Helm templates for the RPI chart using provided values YAML. " +
            "Returns the fully rendered Kubernetes manifests. Requires Helm CLI on PATH. " +
            "Use showOnly to render a single template file (e.g., 'templates/deploy-realtimeapi.yaml').",
        inputSchema: {
            type: "object",
            properties: {
                values: {
                    type: "string",
                    description: "YAML content for values override",
                },
                showOnly: {
                    type: "string",
                    description: "Render only this template (relative to chart/, e.g., 'templates/deploy-realtimeapi.yaml')",
                },
                namespace: {
                    type: "string",
                    description: "Kubernetes namespace for the release",
                },
            },
            required: ["values"],
        },
    },
    {
        name: "rpi_explain",
        description: "Explain a specific values.yaml key path. Returns the type, description, default, " +
            "valid values, and additional context from the knowledge base. " +
            "Example key paths: 'realtimeapi.cacheProvider.provider', 'cloudIdentity.enabled'.",
        inputSchema: {
            type: "object",
            properties: {
                keyPath: {
                    type: "string",
                    description: "Dot-delimited key path (e.g., 'secretsManagement.provider')",
                },
            },
            required: ["keyPath"],
        },
    },
    {
        name: "rpi_status",
        description: "Get the status of an RPI deployment in a Kubernetes namespace. " +
            "Shows pod health, services, and ingress. Requires kubectl and cluster access.",
        inputSchema: {
            type: "object",
            properties: {
                namespace: {
                    type: "string",
                    description: "Kubernetes namespace (default: 'default')",
                },
            },
        },
    },
    {
        name: "rpi_troubleshoot",
        description: "Diagnose issues with an RPI deployment. Checks pod health, secrets, ingress, " +
            "cloud identity, and recent events. Optionally target a specific symptom " +
            "(e.g., 'crashloop', 'pending', 'imagepull'). Requires kubectl and cluster access.",
        inputSchema: {
            type: "object",
            properties: {
                namespace: {
                    type: "string",
                    description: "Kubernetes namespace (default: 'default')",
                },
                symptom: {
                    type: "string",
                    description: "Optional symptom keyword: 'crashloop', 'pending', 'imagepull'",
                },
            },
        },
    },
    {
        name: "rpi_docs_search",
        description: "Search the official RPI product documentation at docs.redpointglobal.com/rpi. " +
            "Finds relevant pages by keyword and returns their content. Use this to answer questions " +
            "about RPI features, configuration, channels, realtime decisions, audience design, " +
            "administration, troubleshooting, and more.",
        inputSchema: {
            type: "object",
            properties: {
                query: {
                    type: "string",
                    description: "Search keywords (e.g., 'realtime cache setup', 'queue provider rabbitmq', 'authentication OIDC')",
                },
                maxResults: {
                    type: "number",
                    description: "Maximum number of pages to return (default: 3, max: 5)",
                },
            },
            required: ["query"],
        },
    },
    {
        name: "rpi_docs_fetch",
        description: "Fetch a specific page from the RPI documentation site. Use this when you know the exact " +
            "page URL or slug (e.g., 'admin-realtime-cache-setup' or the full URL). Returns the page content as text.",
        inputSchema: {
            type: "object",
            properties: {
                url: {
                    type: "string",
                    description: "Full URL (https://docs.redpointglobal.com/rpi/...) or just the slug (e.g., 'admin-authentication')",
                },
            },
            required: ["url"],
        },
    },
];
// ---------------------------------------------------------------------------
// Register tool list handler
// ---------------------------------------------------------------------------
server.setRequestHandler(ListToolsRequestSchema, async () => {
    return { tools: TOOLS };
});
// ---------------------------------------------------------------------------
// Register tool call handler
// ---------------------------------------------------------------------------
server.setRequestHandler(CallToolRequestSchema, async (request) => {
    const { name, arguments: args } = request.params;
    switch (name) {
        case "rpi_validate": {
            const input = args;
            const result = validate(input.values);
            return {
                content: [{ type: "text", text: JSON.stringify(result, null, 2) }],
            };
        }
        case "rpi_generate": {
            const input = args;
            const yamlOutput = generate(input);
            return {
                content: [{ type: "text", text: yamlOutput }],
            };
        }
        case "rpi_template": {
            const input = args;
            const result = template(input);
            return {
                content: [{ type: "text", text: JSON.stringify(result, null, 2) }],
            };
        }
        case "rpi_explain": {
            const input = args;
            const result = explain(input.keyPath);
            return {
                content: [{ type: "text", text: JSON.stringify(result, null, 2) }],
            };
        }
        case "rpi_status": {
            const input = args;
            const result = status(input.namespace);
            return {
                content: [{ type: "text", text: JSON.stringify(result, null, 2) }],
            };
        }
        case "rpi_troubleshoot": {
            const input = args;
            const result = troubleshoot(input.namespace, input.symptom);
            return {
                content: [{ type: "text", text: JSON.stringify(result, null, 2) }],
            };
        }
        case "rpi_docs_search": {
            const input = args;
            const max = Math.min(input.maxResults ?? 3, 5);
            const results = await docsSearch(input.query, max);
            return {
                content: [{ type: "text", text: JSON.stringify(results, null, 2) }],
            };
        }
        case "rpi_docs_fetch": {
            const input = args;
            const result = await docsFetch(input.url);
            return {
                content: [{ type: "text", text: JSON.stringify(result, null, 2) }],
            };
        }
        default:
            throw new Error(`Unknown tool: ${name}`);
    }
});
// ---------------------------------------------------------------------------
// Register resources and start server
// ---------------------------------------------------------------------------
registerResources(server);
const transport = new StdioServerTransport();
await server.connect(transport);
//# sourceMappingURL=index.js.map