export interface TemplateInput {
    values: string;
    showOnly?: string;
    namespace?: string;
}
export interface TemplateResult {
    success: boolean;
    output?: string;
    error?: string;
    suggestion?: string;
}
/**
 * Render Helm templates for the RPI chart using the provided values YAML.
 */
export declare function template(input: TemplateInput): TemplateResult;
