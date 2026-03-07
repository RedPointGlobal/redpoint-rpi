import { execSync } from "node:child_process";
import { writeFileSync, unlinkSync } from "node:fs";
import { join } from "node:path";
import { tmpdir } from "node:os";
import { randomUUID } from "node:crypto";
const EXEC_OPTS = { encoding: "utf-8", timeout: 60_000 };
/**
 * Render Helm templates for the given chart directory using the supplied
 * values YAML string.  Returns the rendered manifest YAML.
 */
export function helmTemplate(chartDir, valuesYaml, opts = {}) {
    const tmpFile = join(tmpdir(), `rpi-mcp-values-${randomUUID()}.yaml`);
    try {
        writeFileSync(tmpFile, valuesYaml, "utf-8");
        const releaseName = opts.releaseName ?? "rpi";
        const parts = [
            "helm",
            "template",
            releaseName,
            chartDir,
            "-f",
            tmpFile,
        ];
        if (opts.namespace) {
            parts.push("--namespace", opts.namespace);
        }
        if (opts.showOnly) {
            parts.push("--show-only", opts.showOnly);
        }
        return execSync(parts.join(" "), EXEC_OPTS);
    }
    finally {
        try {
            unlinkSync(tmpFile);
        }
        catch {
            // best-effort cleanup
        }
    }
}
/**
 * Returns the installed Helm version string.
 */
export function helmVersion() {
    return execSync("helm version --short", EXEC_OPTS).trim();
}
/**
 * Checks whether the helm CLI is available on PATH.
 */
export function isHelmAvailable() {
    try {
        execSync("helm version --short", { ...EXEC_OPTS, stdio: "pipe" });
        return true;
    }
    catch {
        return false;
    }
}
//# sourceMappingURL=helm.js.map