export interface HelmTemplateOptions {
    showOnly?: string;
    releaseName?: string;
    namespace?: string;
}
/**
 * Render Helm templates for the given chart directory using the supplied
 * values YAML string.  Returns the rendered manifest YAML.
 */
export declare function helmTemplate(chartDir: string, valuesYaml: string, opts?: HelmTemplateOptions): string;
/**
 * Returns the installed Helm version string.
 */
export declare function helmVersion(): string;
/**
 * Checks whether the helm CLI is available on PATH.
 */
export declare function isHelmAvailable(): boolean;
