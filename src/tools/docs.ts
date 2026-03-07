import https from "node:https";

const DOCS_BASE = "https://docs.redpointglobal.com/rpi";

/**
 * Sitemap of the RPI documentation site, organized by section.
 * Used for keyword matching when the user asks a question.
 */
const DOCS_INDEX: { slug: string; title: string; section: string }[] = [
  // Admin Guide
  { slug: "admin-introduction", title: "Admin Introduction", section: "Admin Guide" },
  { slug: "admin-key-concepts", title: "Key Concepts", section: "Admin Guide" },
  { slug: "admin-containerization", title: "Containerization", section: "Admin Guide" },
  { slug: "admin-regional-settings-in-containers", title: "Regional Settings in Containers", section: "Admin Guide" },
  { slug: "admin-deploying-rpi", title: "Deploying RPI", section: "Admin Guide" },
  { slug: "admin-rpi-licensing", title: "RPI Licensing", section: "Admin Guide" },
  { slug: "admin-authentication", title: "Authentication", section: "Admin Guide" },
  { slug: "admin-scheduler-rules", title: "Scheduler Rules", section: "Admin Guide" },
  { slug: "admin-logging", title: "Logging", section: "Admin Guide" },
  { slug: "increase-rpi-trace-logging", title: "Increase Trace Logging", section: "Admin Guide" },
  { slug: "gathering-logs-from-rpi", title: "Gathering Logs", section: "Admin Guide" },
  { slug: "admin-operational-management", title: "Operational Management", section: "Admin Guide" },
  { slug: "admin-rpi-client-application", title: "Client Application", section: "Admin Guide" },
  { slug: "admin-rpi-realtime", title: "Realtime Administration", section: "Admin Guide" },
  { slug: "admin-realtime-cache-setup", title: "Realtime Cache Setup", section: "Admin Guide" },
  { slug: "admin-realtime-helper-utility", title: "Realtime Helper Utility", section: "Admin Guide" },
  { slug: "admin-pre-and-post-processing-plugins", title: "Pre and Post Processing Plugins", section: "Admin Guide" },
  { slug: "admin-geolocation-setup", title: "Geolocation Setup", section: "Admin Guide" },
  { slug: "admin-load-web-cache-data-task-setup", title: "Load Web Cache Data Task Setup", section: "Admin Guide" },
  { slug: "admin-realtime-localization-setup", title: "Realtime Localization Setup", section: "Admin Guide" },
  { slug: "admin-security-concerns-using-sequential-keys", title: "Security Concerns Using Sequential Keys", section: "Admin Guide" },
  { slug: "admin-rpi-realtime-decisions-validate-memory-cache", title: "Realtime Decisions Validate Memory Cache", section: "Admin Guide" },
  { slug: "admin-rpi-realtime-decisions-advanced-validation", title: "Realtime Decisions Advanced Validation", section: "Admin Guide" },
  { slug: "admin-realtime-decisions-troubleshooting-guide", title: "Realtime Decisions Troubleshooting", section: "Admin Guide" },
  { slug: "admin-rpi-realtime-decisions-logging", title: "Realtime Decisions Logging", section: "Admin Guide" },
  { slug: "admin-rpi-realtime-decisions-enable-trace-logging-", title: "Realtime Decisions Trace Logging", section: "Admin Guide" },
  { slug: "admin-rpi-to-rpdm-integration", title: "RPI to RPDM Integration", section: "Admin Guide" },
  { slug: "admin-rpi-to-aml-integration", title: "RPI to AML Integration", section: "Admin Guide" },
  { slug: "admin-queue-reader-setup", title: "Queue Reader Setup", section: "Admin Guide" },
  { slug: "admin-secret-management", title: "Secret Management", section: "Admin Guide" },
  { slug: "admin-workflow-prioritization", title: "Workflow Prioritization", section: "Admin Guide" },
  { slug: "admin-rpi-integration-api", title: "Integration API", section: "Admin Guide" },
  { slug: "admin-offer-history", title: "Offer History", section: "Admin Guide" },
  { slug: "admin-basic-selection-rule-ai-integration", title: "Selection Rule AI Integration", section: "Admin Guide" },
  { slug: "admin-troubleshooting-performance-issues", title: "Troubleshooting Performance Issues", section: "Admin Guide" },
  { slug: "admin-rpi-selection-rule-audience-or-interaction-r", title: "Selection Rule Audience or Interaction", section: "Admin Guide" },
  { slug: "admin-appendix-a-database-preparation", title: "Appendix A: Database Preparation", section: "Admin Guide" },
  { slug: "admin-appendix-b-open-id-connect-oidc-configuratio", title: "Appendix B: OIDC Configuration", section: "Admin Guide" },
  { slug: "admin-appendix-c-queue-provider-configuration", title: "Appendix C: Queue Provider Configuration", section: "Admin Guide" },
  { slug: "admin-appendix-d-callback-service-configuration", title: "Appendix D: Callback Service Configuration", section: "Admin Guide" },
  { slug: "admin-appendix-e-external-service-endpoints-urls-a", title: "Appendix E: External Service Endpoints", section: "Admin Guide" },

  // External Configuration
  { slug: "external-configuration", title: "External Configuration Overview", section: "External Configuration" },
  { slug: "cache-configuration", title: "Cache Configuration", section: "External Configuration" },
  { slug: "cache-provider-azure-cosmosdb", title: "Cache Provider: Azure CosmosDB", section: "External Configuration" },
  { slug: "cache-provider-azure-redis", title: "Cache Provider: Azure Redis", section: "External Configuration" },
  { slug: "cache-provider-cassandra", title: "Cache Provider: Cassandra", section: "External Configuration" },
  { slug: "cache-provider-mongodb", title: "Cache Provider: MongoDB", section: "External Configuration" },
  { slug: "cache-provider-redis", title: "Cache Provider: Redis", section: "External Configuration" },
  { slug: "crm-configuration", title: "CRM Configuration", section: "External Configuration" },
  { slug: "data-onboarding-configuration", title: "Data Onboarding Configuration", section: "External Configuration" },
  { slug: "data-onboarding-provider-facebook", title: "Data Onboarding: Facebook", section: "External Configuration" },
  { slug: "data-onboarding-provider-google-ads-customer-match", title: "Data Onboarding: Google Ads", section: "External Configuration" },
  { slug: "data-onboarding-provider-liveramp", title: "Data Onboarding: LiveRamp", section: "External Configuration" },
  { slug: "database-provider-configuration", title: "Database Provider Configuration", section: "External Configuration" },
  { slug: "email-service-provider-configuration", title: "Email Service Provider Configuration", section: "External Configuration" },
  { slug: "email-service-providers-acoustic", title: "Email: Acoustic", section: "External Configuration" },
  { slug: "email-service-provider-eloqua", title: "Email: Eloqua", section: "External Configuration" },
  { slug: "email-service-provider-luxsci", title: "Email: LuxSci", section: "External Configuration" },
  { slug: "email-service-provider-marigold", title: "Email: Marigold", section: "External Configuration" },
  { slug: "email-service-provider-salesforce-marketing-cloud-", title: "Email: Salesforce Marketing Cloud", section: "External Configuration" },
  { slug: "email-service-provider-sendgrid", title: "Email: SendGrid", section: "External Configuration" },
  { slug: "external-content-provider-configuration", title: "External Content Provider Configuration", section: "External Configuration" },
  { slug: "external-content-provider-amazon-aws-s3", title: "External Content: AWS S3", section: "External Configuration" },
  { slug: "external-content-provider-azure", title: "External Content: Azure", section: "External Configuration" },
  { slug: "external-content-provider-azure-storage", title: "External Content: Azure Storage", section: "External Configuration" },
  { slug: "external-content-provider-contentful", title: "External Content: Contentful", section: "External Configuration" },
  { slug: "external-content-provider-drupal", title: "External Content: Drupal", section: "External Configuration" },
  { slug: "external-content-provider-google-cloud-storage", title: "External Content: Google Cloud Storage", section: "External Configuration" },
  { slug: "mobile-push-notification-configuration", title: "Push Notification Configuration", section: "External Configuration" },
  { slug: "push-notification-provider-airship-push-direct", title: "Push: Airship", section: "External Configuration" },
  { slug: "push-notification-azure-azure-push-direct", title: "Push: Azure", section: "External Configuration" },
  { slug: "push-notification-google-firebase-and-firebase-dir", title: "Push: Google Firebase", section: "External Configuration" },
  { slug: "mobile-sms-provider-configuration", title: "SMS Provider Configuration", section: "External Configuration" },
  { slug: "sms-provider-mpulse", title: "SMS: mPulse", section: "External Configuration" },
  { slug: "sms-provider-twilio", title: "SMS: Twilio", section: "External Configuration" },
  { slug: "queue-provider-configuration", title: "Queue Provider Configuration", section: "External Configuration" },
  { slug: "queue-provider-amazon-sqs", title: "Queue: Amazon SQS", section: "External Configuration" },
  { slug: "queue-provider-azure-event-hubs", title: "Queue: Azure Event Hubs", section: "External Configuration" },
  { slug: "queue-provider-azure-service-bus", title: "Queue: Azure Service Bus", section: "External Configuration" },
  { slug: "queue-provider-azure-storage-queue", title: "Queue: Azure Storage Queue", section: "External Configuration" },
  { slug: "queue-provider-google-pub-sub", title: "Queue: Google Pub/Sub", section: "External Configuration" },
  { slug: "queue-provider-kafka-aws-msk", title: "Queue: Kafka / AWS MSK", section: "External Configuration" },
  { slug: "queue-provider-rabbitmq", title: "Queue: RabbitMQ", section: "External Configuration" },
  { slug: "survey-provider-configuration", title: "Survey Provider Configuration", section: "External Configuration" },
  { slug: "web-adapter-configuration", title: "Web Adapter Configuration", section: "External Configuration" },
  { slug: "web-adapter-provider-bitly", title: "Web Adapter: Bitly", section: "External Configuration" },
  { slug: "web-adapter-provider-google-analytics", title: "Web Adapter: Google Analytics", section: "External Configuration" },
  { slug: "web-adpater-provider-rebrandly", title: "Web Adapter: Rebrandly", section: "External Configuration" },

  // Realtime
  { slug: "rpi-realtime", title: "RPI Realtime Overview", section: "Realtime" },
  { slug: "using-rpi-realtime", title: "Using RPI Realtime", section: "Realtime" },
  { slug: "building-up-visitor-profiles", title: "Building Visitor Profiles", section: "Realtime" },
  { slug: "making-realtime-decisions", title: "Making Realtime Decisions", section: "Realtime" },
  { slug: "rpi-web-forms", title: "Web Forms", section: "Realtime" },
  { slug: "rpi-web-events", title: "Web Events", section: "Realtime" },
  { slug: "rpi-realtime-and-the-data-warehouse", title: "Realtime and Data Warehouse", section: "Realtime" },
  { slug: "writing-realtime-data-to-files", title: "Writing Realtime Data to Files", section: "Realtime" },
  { slug: "rpi-realtime-authentication", title: "Realtime Authentication", section: "Realtime" },
  { slug: "rpi-realtime-architecture", title: "Realtime Architecture", section: "Realtime" },
  { slug: "rpi-realtime-audit", title: "Realtime Audit", section: "Realtime" },

  // Configuration
  { slug: "configuration", title: "Configuration Overview", section: "Configuration" },
  { slug: "configuration-workbench", title: "Configuration Workbench", section: "Configuration" },
  { slug: "configuring-channels", title: "Configuring Channels", section: "Configuration" },
  { slug: "configuring-the-tenant", title: "Configuring the Tenant", section: "Configuration" },
  { slug: "configuring-users", title: "Configuring Users", section: "Configuration" },
  { slug: "configuring-user-groups", title: "Configuring User Groups", section: "Configuration" },
  { slug: "configuring-joins", title: "Configuring Joins", section: "Configuration" },
  { slug: "configuring-the-catalog", title: "Configuring the Catalog", section: "Configuration" },
  { slug: "configuring-audience-definitions", title: "Configuring Audience Definitions", section: "Configuration" },
  { slug: "configuring-sql-database-definitions", title: "Configuring SQL Database Definitions", section: "Configuration" },
  { slug: "configuring-nosql-db-collection-definitions", title: "Configuring NoSQL DB Collection Definitions", section: "Configuration" },
  { slug: "configuring-resolution-levels", title: "Configuring Resolution Levels", section: "Configuration" },
  { slug: "configuring-state-flows", title: "Configuring State Flows", section: "Configuration" },
  { slug: "configuring-system-configuration-settings", title: "Configuring System Settings", section: "Configuration" },
  { slug: "configuring-value-lists", title: "Configuring Value Lists", section: "Configuration" },
  { slug: "configuring-web-adapters", title: "Configuring Web Adapters", section: "Configuration" },
  { slug: "configuring-realtime-queue-providers", title: "Configuring Realtime Queue Providers", section: "Configuration" },
  { slug: "configuring-queue-listener-providers", title: "Configuring Queue Listener Providers", section: "Configuration" },
  { slug: "configuring-external-content-providers", title: "Configuring External Content Providers", section: "Configuration" },

  // Designers
  { slug: "interaction-designer", title: "Interaction Designer", section: "Designers" },
  { slug: "audience-designer", title: "Audience Designer", section: "Designers" },
  { slug: "offer-designer", title: "Offer Designer", section: "Designers" },
  { slug: "smart-asset-designer", title: "Smart Asset Designer", section: "Designers" },
  { slug: "asset-designer", title: "Asset Designer", section: "Designers" },
  { slug: "rule-designer", title: "Rule Designer", section: "Designers" },
  { slug: "export-template-designer", title: "Export Template Designer", section: "Designers" },
  { slug: "landing-page-designer", title: "Landing Page Designer", section: "Designers" },
  { slug: "cell-list-designer", title: "Cell List Designer", section: "Designers" },
  { slug: "subscription-group-designer", title: "Subscription Group Designer", section: "Designers" },
  { slug: "data-import-designer", title: "Data Import Designer", section: "Designers" },
  { slug: "model-project-designer", title: "Model Project Designer", section: "Designers" },

  // Release Notes
  { slug: "release-notes", title: "Release Notes Overview", section: "Release Notes" },
  { slug: "rpi-v7-6-release-notes", title: "v7.6 Release Notes", section: "Release Notes" },
  { slug: "rpi-v7-5-release-notes", title: "v7.5 Release Notes", section: "Release Notes" },
  { slug: "rpi-v7-4-release-notes", title: "v7.4 Release Notes", section: "Release Notes" },
  { slug: "rpi-v7-3-release-notes", title: "v7.3 Release Notes", section: "Release Notes" },
  { slug: "rpi-v7-2-release-notes", title: "v7.2 Release Notes", section: "Release Notes" },
  { slug: "rpi-v7-1-release-notes", title: "v7.1 Release Notes", section: "Release Notes" },
  { slug: "rpi-v7-0-release-notes", title: "v7.0 Release Notes", section: "Release Notes" },

  // Operations
  { slug: "operations-interface", title: "Operations Interface", section: "Operations" },
  { slug: "system-health-tab", title: "System Health Tab", section: "Operations" },
  { slug: "system-tasks-tab", title: "System Tasks Tab", section: "Operations" },
  { slug: "execution-services-tab", title: "Execution Services Tab", section: "Operations" },
  { slug: "server-client-log-tab", title: "Server/Client Log Tab", section: "Operations" },
  { slug: "workflow-summaries-tab", title: "Workflow Summaries Tab", section: "Operations" },
  { slug: "workflow-instances-tab", title: "Workflow Instances Tab", section: "Operations" },
  { slug: "diagnostics-mode-tab", title: "Diagnostics Mode Tab", section: "Operations" },
  { slug: "telemetry-tab", title: "Telemetry Tab", section: "Operations" },
  { slug: "housekeeping-tab", title: "Housekeeping Tab", section: "Operations" },

  // General
  { slug: "welcome-to-rpi", title: "Welcome to RPI", section: "General" },
  { slug: "glossary", title: "Glossary", section: "General" },
  { slug: "rpi-feature-comparison-v6-vs-v7", title: "Feature Comparison v6 vs v7", section: "General" },
  { slug: "supported-connectors", title: "Supported Connectors", section: "General" },
  { slug: "connector-deprecation-plan", title: "Connector Deprecation Plan", section: "General" },
  { slug: "api-reference", title: "API Reference", section: "General" },
  { slug: "my-jobs", title: "My Jobs", section: "General" },
  { slug: "single-customer-view", title: "Single Customer View", section: "General" },
  { slug: "dashboards", title: "Dashboards", section: "General" },
  { slug: "reporting-hub", title: "Reporting Hub", section: "General" },
];

/**
 * Fetch a URL and return the body as a string.
 */
function fetchText(url: string): Promise<string> {
  return new Promise((resolve, reject) => {
    const req = https.get(url, { headers: { "User-Agent": "rpi-mcp-server/1.0" } }, (res) => {
      // Follow redirects
      if (res.statusCode && res.statusCode >= 300 && res.statusCode < 400 && res.headers.location) {
        fetchText(res.headers.location).then(resolve, reject);
        return;
      }
      if (res.statusCode && res.statusCode >= 400) {
        reject(new Error(`HTTP ${res.statusCode} fetching ${url}`));
        return;
      }
      const chunks: Buffer[] = [];
      res.on("data", (chunk: Buffer) => chunks.push(chunk));
      res.on("end", () => resolve(Buffer.concat(chunks).toString("utf-8")));
      res.on("error", reject);
    });
    req.on("error", reject);
    req.setTimeout(15000, () => {
      req.destroy(new Error("Request timed out"));
    });
  });
}

/**
 * Strip HTML tags and collapse whitespace to extract readable text.
 */
function htmlToText(html: string): string {
  // Remove script and style blocks
  let text = html.replace(/<script[\s\S]*?<\/script>/gi, "");
  text = text.replace(/<style[\s\S]*?<\/style>/gi, "");
  text = text.replace(/<nav[\s\S]*?<\/nav>/gi, "");
  text = text.replace(/<header[\s\S]*?<\/header>/gi, "");
  text = text.replace(/<footer[\s\S]*?<\/footer>/gi, "");
  // Convert common block elements to newlines
  text = text.replace(/<\/?(p|div|h[1-6]|li|br|tr|blockquote)[^>]*>/gi, "\n");
  // Strip remaining tags
  text = text.replace(/<[^>]+>/g, "");
  // Decode common HTML entities
  text = text.replace(/&amp;/g, "&");
  text = text.replace(/&lt;/g, "<");
  text = text.replace(/&gt;/g, ">");
  text = text.replace(/&quot;/g, '"');
  text = text.replace(/&#39;/g, "'");
  text = text.replace(/&nbsp;/g, " ");
  // Collapse whitespace
  text = text.replace(/[ \t]+/g, " ");
  text = text.replace(/\n{3,}/g, "\n\n");
  return text.trim();
}

/**
 * Score a doc entry against search keywords.
 */
function scoreEntry(entry: { slug: string; title: string; section: string }, keywords: string[]): number {
  let score = 0;
  const titleLower = entry.title.toLowerCase();
  const slugLower = entry.slug.toLowerCase();
  const sectionLower = entry.section.toLowerCase();

  for (const kw of keywords) {
    if (titleLower.includes(kw)) score += 3;
    if (slugLower.includes(kw)) score += 2;
    if (sectionLower.includes(kw)) score += 1;
  }
  return score;
}

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
export async function docsSearch(query: string, maxResults: number = 3): Promise<DocsSearchResult[]> {
  const keywords = query.toLowerCase().split(/\s+/).filter((w) => w.length > 2);

  if (keywords.length === 0) {
    return [{ url: DOCS_BASE, title: "RPI Documentation", section: "General", content: "Please provide a more specific query." }];
  }

  // Score and rank all entries
  const scored = DOCS_INDEX
    .map((entry) => ({ entry, score: scoreEntry(entry, keywords) }))
    .filter((s) => s.score > 0)
    .sort((a, b) => b.score - a.score)
    .slice(0, maxResults);

  if (scored.length === 0) {
    return [{
      url: DOCS_BASE,
      title: "No matches found",
      section: "General",
      content: `No documentation pages matched the query "${query}". Try different keywords.\n\nAvailable sections: Admin Guide, External Configuration, Realtime, Configuration, Designers, Operations, Release Notes.`,
    }];
  }

  // Fetch the top results in parallel
  const results = await Promise.all(
    scored.map(async ({ entry }): Promise<DocsSearchResult> => {
      const url = `${DOCS_BASE}/${entry.slug}`;
      try {
        const html = await fetchText(url);
        const text = htmlToText(html);
        // Truncate to ~4000 chars to keep responses manageable
        const content = text.length > 4000 ? text.slice(0, 4000) + "\n\n[Content truncated. Full page: " + url + "]" : text;
        return { url, title: entry.title, section: entry.section, content };
      } catch (err) {
        return { url, title: entry.title, section: entry.section, error: `Failed to fetch: ${err instanceof Error ? err.message : String(err)}` };
      }
    }),
  );

  return results;
}

/**
 * Fetch a specific documentation page by URL or slug.
 */
export async function docsFetch(urlOrSlug: string): Promise<DocsSearchResult> {
  const url = urlOrSlug.startsWith("http") ? urlOrSlug : `${DOCS_BASE}/${urlOrSlug}`;
  const slug = urlOrSlug.replace(/^.*\/rpi\//, "");
  const entry = DOCS_INDEX.find((e) => e.slug === slug);
  const title = entry?.title ?? slug;
  const section = entry?.section ?? "Unknown";

  try {
    const html = await fetchText(url);
    const text = htmlToText(html);
    const content = text.length > 8000 ? text.slice(0, 8000) + "\n\n[Content truncated. Full page: " + url + "]" : text;
    return { url, title, section, content };
  } catch (err) {
    return { url, title, section, error: `Failed to fetch: ${err instanceof Error ? err.message : String(err)}` };
  }
}
