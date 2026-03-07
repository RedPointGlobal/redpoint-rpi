import yaml from "js-yaml";

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
    azure?: { managedIdentityClientId?: string; tenantId?: string };
    google?: { serviceAccountEmail?: string; projectId?: string };
    amazon?: { roleArn?: string; region?: string };
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
export function generate(input: GenerateInput): string {
  const values: Record<string, unknown> = {};

  // -- Global --
  values.global = {
    deployment: {
      mode: input.mode ?? "standard",
      platform: input.platform,
    },
  };

  // -- Databases --
  if (input.database) {
    values.databases = {
      operational: {
        provider: input.database.provider ?? "sqlserver",
        server_host: input.database.server_host ?? "<my-database-server-host>",
        server_username: input.database.server_username ?? "<my-database-server-username>",
        server_password: input.database.server_password ?? "<my-database-server-password>",
        pulse_database_name: input.database.pulse_database_name ?? "<my-pulse-database-name>",
        pulse_logging_database_name:
          input.database.pulse_logging_database_name ?? "<my-logging-database-name>",
        encrypt: true,
      },
    };
  }

  // -- Cloud Identity --
  const ciInput = input.cloudIdentity;
  const ciEnabled = ciInput?.enabled ?? (input.platform !== "selfhosted");
  const cloudIdentity: Record<string, unknown> = {
    enabled: ciEnabled,
    serviceAccount: {
      create: true,
      name: "redpoint-rpi",
    },
  };

  if (input.platform === "azure") {
    cloudIdentity.azure = {
      managedIdentityClientId:
        ciInput?.azure?.managedIdentityClientId ?? "<your-workload-identity-client-id>",
      tenantId: ciInput?.azure?.tenantId ?? "<your-azure-tenant-id>",
    };
  } else if (input.platform === "google") {
    cloudIdentity.google = {
      serviceAccountEmail:
        ciInput?.google?.serviceAccountEmail ??
        "<my-gsa>@<my-project>.iam.gserviceaccount.com",
      projectId: ciInput?.google?.projectId ?? "<your-gcp-project-id>",
    };
  } else if (input.platform === "amazon") {
    cloudIdentity.amazon = {
      roleArn:
        ciInput?.amazon?.roleArn ?? "arn:aws:iam::<account-id>:role/<role-name>",
      region: ciInput?.amazon?.region ?? "us-east-1",
    };
  }
  values.cloudIdentity = cloudIdentity;

  // -- Secrets Management --
  const secretsProvider = input.secretsProvider ?? "kubernetes";
  const secretsMgmt: Record<string, unknown> = {
    provider: secretsProvider,
  };
  if (secretsProvider === "kubernetes") {
    secretsMgmt.kubernetes = {
      autoCreateSecrets: true,
      secretName: "redpoint-rpi-secrets",
    };
  } else if (secretsProvider === "sdk") {
    if (input.platform === "azure") {
      secretsMgmt.sdk = {
        azure: {
          vaultUri: "https://<your-vault>.vault.azure.net/",
        },
      };
    } else if (input.platform === "amazon") {
      secretsMgmt.sdk = { amazon: { secretTagKey: "" } };
    } else if (input.platform === "google") {
      secretsMgmt.sdk = { google: { projectId: "" } };
    }
  } else if (secretsProvider === "csi") {
    secretsMgmt.csi = {
      secretName: "redpoint-rpi-secrets",
      secretProviderClasses: [],
    };
  }
  values.secretsManagement = secretsMgmt;

  // -- Ingress --
  if (input.ingress?.enabled) {
    values.ingress = {
      enabled: true,
      hostname: input.ingress.hostname ?? "<your-hostname>",
      tls: {
        enabled: !!input.ingress.tlsSecretName,
        secretName: input.ingress.tlsSecretName ?? "",
      },
      className: input.ingress.className ?? "nginx",
    };
  }

  // -- Realtime API --
  if (input.realtimeapi) {
    const rtapi: Record<string, unknown> = {
      enabled: input.realtimeapi.enabled ?? true,
      replicas: 1,
    };

    if (input.realtimeapi.cacheProvider) {
      const cp: Record<string, unknown> = {
        enabled: true,
        provider: input.realtimeapi.cacheProvider,
      };
      if (input.realtimeapi.cacheProvider === "mongodb") {
        cp.mongodb = {
          connectionString:
            input.realtimeapi.mongoConnectionString ??
            "<your-mongodb-connection-string>",
          databaseName: "RPIRealtimeCache",
        };
      } else if (
        input.realtimeapi.cacheProvider === "redis" ||
        input.realtimeapi.cacheProvider === "azureredis"
      ) {
        cp.redis = {
          connectionString:
            input.realtimeapi.redisConnectionString ??
            "<your-redis-connection-string>",
        };
      }
      rtapi.cacheProvider = cp;
    }
    values.realtimeapi = rtapi;
  }

  // -- Smart Activation --
  if (input.smartActivation?.enabled) {
    values.smartActivation = { enabled: true };
  }

  // Serialize
  const header = [
    "# ============================================================",
    "# Redpoint RPI Overrides",
    `# Generated by rpi-mcp-server — ${new Date().toISOString().slice(0, 10)}`,
    `# Platform: ${input.platform} | Mode: ${input.mode ?? "standard"}`,
    "# ============================================================",
    "",
  ].join("\n");

  return header + yaml.dump(values, { lineWidth: 120, noRefs: true, sortKeys: false });
}
