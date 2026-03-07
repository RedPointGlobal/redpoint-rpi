export interface GenerateInput {
    platform: "azure" | "amazon" | "google" | "selfhosted";
    mode?: "standard" | "demo";
    database?: {
        provider?: "sqlserver" | "postgresql" | "sqlserveronvm";
        server_host?: string;
        server_username?: string;
        server_password?: string;
        pulse_database_name?: string;
        pulse_logging_database_name?: string;
    };
    cloudIdentity?: {
        enabled?: boolean;
        azure?: {
            managedIdentityClientId?: string;
            tenantId?: string;
        };
        google?: {
            serviceAccountEmail?: string;
            projectId?: string;
        };
        amazon?: {
            roleArn?: string;
            region?: string;
        };
    };
    secretsProvider?: "kubernetes" | "sdk" | "csi";
    ingress?: {
        enabled?: boolean;
        hostname?: string;
        tlsSecretName?: string;
        className?: string;
    };
    realtimeapi?: {
        enabled?: boolean;
        cacheProvider?: "mongodb" | "redis" | "azureredis" | "inMemorySql" | "googlebigtable";
        mongoConnectionString?: string;
        redisConnectionString?: string;
    };
    smartActivation?: {
        enabled?: boolean;
    };
}
/**
 * Assemble a valid RPI overrides YAML from structured parameters.
 * This is the programmatic equivalent of the interactive rpi-init.sh.
 */
export declare function generate(input: GenerateInput): string;
