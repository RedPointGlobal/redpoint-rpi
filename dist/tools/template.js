import { getChartDir } from "../lib/paths.js";
import { helmTemplate, isHelmAvailable } from "../lib/helm.js";
/**
 * Render Helm templates for the RPI chart using the provided values YAML.
 */
export function template(input) {
    if (!isHelmAvailable()) {
        return {
            success: false,
            error: "Helm CLI is not available on PATH.",
            suggestion: "Install Helm v3 (https://helm.sh/docs/intro/install/) and ensure 'helm' is on your PATH.",
        };
    }
    const chartDir = getChartDir();
    try {
        const output = helmTemplate(chartDir, input.values, {
            showOnly: input.showOnly,
            namespace: input.namespace,
        });
        return { success: true, output };
    }
    catch (err) {
        const message = err instanceof Error ? err.message : String(err);
        // Try to extract actionable hints from common Helm errors
        let suggestion;
        if (message.includes("could not find template")) {
            suggestion = `The --show-only path '${input.showOnly}' does not match any template file. Check chart/templates/ for valid names.`;
        }
        else if (message.includes("parse error")) {
            suggestion =
                "There is a syntax error in the values YAML. Validate the YAML first with rpi_validate.";
        }
        else if (message.includes("nil pointer")) {
            suggestion =
                "A template referenced a value path that resolved to nil. Ensure all required values are set.";
        }
        return {
            success: false,
            error: message,
            suggestion,
        };
    }
}
//# sourceMappingURL=template.js.map