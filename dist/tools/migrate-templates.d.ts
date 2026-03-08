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
export declare function migrateTemplates(templatesPath: string): MigrateTemplatesResult;
export {};
