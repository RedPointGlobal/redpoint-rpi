import { readFileSync, existsSync } from "node:fs";
import { resolve } from "node:path";
import { ListResourcesRequestSchema, ReadResourceRequestSchema, } from "@modelcontextprotocol/sdk/types.js";
import { getChartDir, getDocsDir, getSchemaPath, getRepoRoot } from "../lib/paths.js";
function buildResourceList() {
    const chartDir = getChartDir();
    const docsDir = getDocsDir();
    const repoRoot = getRepoRoot();
    return [
        {
            uri: "rpi://schema",
            name: "values.schema.json",
            description: "JSON Schema (draft-07) for chart values.yaml",
            mimeType: "application/json",
            resolvePath: () => getSchemaPath(),
        },
        {
            uri: "rpi://reference",
            name: "values-reference.yaml",
            description: "Annotated reference values file with all configurable keys",
            mimeType: "application/x-yaml",
            resolvePath: () => resolve(docsDir, "values-reference.yaml"),
        },
        {
            uri: "rpi://docs/greenfield",
            name: "greenfield.md",
            description: "Greenfield deployment guide",
            mimeType: "text/markdown",
            resolvePath: () => resolve(docsDir, "greenfield.md"),
        },
        {
            uri: "rpi://docs/migration",
            name: "migration.md",
            description: "Migration guide from previous versions",
            mimeType: "text/markdown",
            resolvePath: () => resolve(docsDir, "migration.md"),
        },
        {
            uri: "rpi://docs/argocd",
            name: "readme-argocd.md",
            description: "ArgoCD deployment guide",
            mimeType: "text/markdown",
            resolvePath: () => resolve(docsDir, "readme-argocd.md"),
        },
        {
            uri: "rpi://docs/values",
            name: "readme-values.md",
            description: "Values configuration reference documentation",
            mimeType: "text/markdown",
            resolvePath: () => resolve(docsDir, "readme-values.md"),
        },
        {
            uri: "rpi://docs/terraform",
            name: "readme-terraform.md",
            description: "Terraform integration guide",
            mimeType: "text/markdown",
            resolvePath: () => resolve(docsDir, "readme-terraform.md"),
        },
    ];
}
export function registerResources(server) {
    const resources = buildResourceList();
    server.setRequestHandler(ListResourcesRequestSchema, async () => {
        return {
            resources: resources.map((r) => ({
                uri: r.uri,
                name: r.name,
                description: r.description,
                mimeType: r.mimeType,
            })),
        };
    });
    server.setRequestHandler(ReadResourceRequestSchema, async (request) => {
        const uri = request.params.uri;
        const resource = resources.find((r) => r.uri === uri);
        if (!resource) {
            throw new Error(`Unknown resource URI: ${uri}`);
        }
        const filePath = resource.resolvePath();
        if (!existsSync(filePath)) {
            throw new Error(`Resource file not found: ${filePath}. The file may not have been created yet.`);
        }
        const content = readFileSync(filePath, "utf-8");
        return {
            contents: [
                {
                    uri: resource.uri,
                    mimeType: resource.mimeType,
                    text: content,
                },
            ],
        };
    });
}
//# sourceMappingURL=index.js.map