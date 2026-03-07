export interface DocsSearchResult {
    url: string;
    title: string;
    section: string;
    content?: string;
    error?: string;
}
/**
 * Search the RPI documentation and return matching pages with content.
 */
export declare function docsSearch(query: string, maxResults?: number): Promise<DocsSearchResult[]>;
/**
 * Fetch a specific documentation page by URL or slug.
 */
export declare function docsFetch(urlOrSlug: string): Promise<DocsSearchResult>;
