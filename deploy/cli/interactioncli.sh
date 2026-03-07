#!/usr/bin/env bash
# ============================================================
# Redpoint Interaction CLI
# ============================================================
# Interactive deployment generator for RPI on Kubernetes.
#
# Generates three files:
#   1. my-overrides.yaml    — Helm values (no secrets)
#   2. rpi-secrets.yaml     — Kubernetes Secret manifest
#   3. prereqs.sh           — kubectl commands for namespace, registry, TLS
#
# Usage:
#   bash deploy/cli/interactioncli.sh
#   bash deploy/cli/interactioncli.sh -o my-overrides.yaml
# ============================================================

set -euo pipefail

# --- Defaults ---
OUTPUT_FILE="my-overrides.yaml"
SECRETS_FILE="rpi-secrets.yaml"
PREREQS_FILE="prereqs.sh"
DEFAULT_TAG="7.7.20260220.1524"
DEFAULT_NAMESPACE="redpoint-rpi"
DEFAULT_REGISTRY="rg1acrpub.azurecr.io/docker/redpointglobal/releases"
SECRET_NAME="redpoint-rpi-secrets"

# --- Parse arguments ---
while getopts "o:h" opt; do
  case $opt in
    o) OUTPUT_FILE="$OPTARG" ;;
    h)
      echo "Usage: $0 [-o output-file]"
      echo "  -o  Output file path (default: my-overrides.yaml)"
      exit 0
      ;;
    *) echo "Unknown option: -$opt" >&2; exit 1 ;;
  esac
done

# --- Helpers ---
prompt() {
  local var_name=$1 prompt_text=$2 default=$3
  local value
  if [ -n "$default" ]; then
    read -rp "$prompt_text [$default]: " value
    value="${value:-$default}"
  else
    read -rp "$prompt_text: " value
  fi
  eval "$var_name=\"\$value\""
}

prompt_choice() {
  local var_name=$1 prompt_text=$2 options=$3 default=$4
  local value
  while true; do
    read -rp "$prompt_text ($options) [$default]: " value
    value="${value:-$default}"
    if echo "$options" | tr '|' '\n' | grep -qx "$value"; then
      break
    fi
    echo "  Invalid choice. Options: $options"
  done
  eval "$var_name=\"\$value\""
}

prompt_yesno() {
  local var_name=$1 prompt_text=$2 default=$3
  local value
  while true; do
    read -rp "$prompt_text (y/n) [$default]: " value
    value="${value:-$default}"
    case "$value" in
      y|Y|yes) eval "$var_name=true"; break ;;
      n|N|no)  eval "$var_name=false"; break ;;
      *) echo "  Please enter y or n" ;;
    esac
  done
}

echo ""
echo "============================================"
echo "  Redpoint Interaction CLI"
echo "============================================"
echo ""
echo "This tool generates:"
echo "  1. ${OUTPUT_FILE}    — Helm values overrides (no secrets)"
echo "  2. ${SECRETS_FILE}   — Kubernetes Secret manifest"
echo "  3. ${PREREQS_FILE}   — Prerequisite kubectl commands"
echo ""

# ============================================================
# 1. Platform & Mode
# ============================================================
echo "--- Platform & Deployment Mode ---"
prompt_choice PLATFORM "Cloud platform" "azure|amazon|google|selfhosted" "azure"
prompt_choice MODE "Deployment mode" "standard|demo" "standard"
prompt TAG "Image tag" "$DEFAULT_TAG"
prompt NAMESPACE "Kubernetes namespace" "$DEFAULT_NAMESPACE"

# ============================================================
# 2. Ingress
# ============================================================
echo ""
echo "--- Ingress ---"
prompt DOMAIN "Ingress domain (e.g., rpi.example.com)" "example.com"
prompt_yesno DEPLOY_CONTROLLER "Deploy chart-provided ingress controller?" "y"

# ============================================================
# 3. Database
# ============================================================
DB_HOST=""
DB_USER=""
DB_PASS=""
DB_PULSE="Pulse"
DB_LOGGING="Pulse_Logging"
DB_PROVIDER="sqlserver"

if [ "$MODE" = "standard" ]; then
  echo ""
  echo "--- Operational Database ---"
  prompt_choice DB_PROVIDER "Database provider" "sqlserver|postgresql|sqlserveronvm" "sqlserver"
  prompt DB_HOST "Database server host" ""
  prompt DB_USER "Database username" ""
  read -rsp "Database password: " DB_PASS; echo ""
  prompt DB_PULSE "Pulse database name" "Pulse"
  prompt DB_LOGGING "Pulse logging database name" "Pulse_Logging"
fi

# ============================================================
# 4. Cloud Identity (skip for selfhosted)
# ============================================================
CLOUD_IDENTITY_ENABLED=false
AZURE_CLIENT_ID=""
AZURE_TENANT_ID=""
AMAZON_ROLE_ARN=""
AMAZON_REGION=""
GOOGLE_SA_EMAIL=""

if [ "$PLATFORM" != "selfhosted" ]; then
  echo ""
  echo "--- Cloud Identity ---"
  prompt_yesno CLOUD_IDENTITY_ENABLED "Enable cloud identity (Workload Identity / IRSA)?" "y"

  if [ "$CLOUD_IDENTITY_ENABLED" = "true" ]; then
    case "$PLATFORM" in
      azure)
        prompt AZURE_CLIENT_ID "Azure Managed Identity Client ID" ""
        prompt AZURE_TENANT_ID "Azure Tenant ID" ""
        ;;
      amazon)
        prompt AMAZON_ROLE_ARN "IAM Role ARN for IRSA" ""
        prompt AMAZON_REGION "AWS Region" "us-east-1"
        ;;
      google)
        prompt GOOGLE_SA_EMAIL "GCP Service Account email" ""
        ;;
    esac
  fi
fi

# ============================================================
# 5. Realtime API
# ============================================================
echo ""
echo "--- Realtime API ---"
prompt_yesno REALTIME_ENABLED "Enable Realtime API?" "y"

RT_CACHE_PROVIDER=""
RT_CACHE_CONNSTR=""
RT_QUEUE_PROVIDER=""
RT_QUEUE_CONNSTR=""

if [ "$REALTIME_ENABLED" = "true" ]; then
  prompt_choice RT_CACHE_PROVIDER "Cache provider" "mongodb|redis|inMemorySql" "mongodb"
  if [ "$RT_CACHE_PROVIDER" = "mongodb" ]; then
    prompt RT_CACHE_CONNSTR "MongoDB connection string" ""
  fi

  if [ "$PLATFORM" = "azure" ]; then
    prompt_choice RT_QUEUE_PROVIDER "Queue provider" "azureservicebus|rabbitmq" "azureservicebus"
  elif [ "$PLATFORM" = "amazon" ]; then
    prompt_choice RT_QUEUE_PROVIDER "Queue provider" "amazonsqs|rabbitmq" "amazonsqs"
  elif [ "$PLATFORM" = "google" ]; then
    prompt_choice RT_QUEUE_PROVIDER "Queue provider" "googlepubsub|rabbitmq" "googlepubsub"
  else
    prompt_choice RT_QUEUE_PROVIDER "Queue provider" "rabbitmq" "rabbitmq"
  fi

  if [ "$RT_QUEUE_PROVIDER" = "azureservicebus" ]; then
    prompt RT_QUEUE_CONNSTR "Azure Service Bus connection string" ""
  fi
fi

# ============================================================
# Generate Realtime auth token
# ============================================================
RT_AUTH_TOKEN=""
if [ "$REALTIME_ENABLED" = "true" ]; then
  if command -v openssl &> /dev/null; then
    RT_AUTH_TOKEN=$(openssl rand -hex 16)
  else
    RT_AUTH_TOKEN=$(head -c 16 /dev/urandom | od -An -tx1 | tr -d ' \n')
  fi
fi

# ============================================================
# Build connection strings for the secret
# ============================================================
OPS_CONN=""
LOG_CONN=""

if [ "$MODE" = "standard" ]; then
  case "$DB_PROVIDER" in
    sqlserver)
      OPS_CONN="Server=tcp:${DB_HOST},1433;Database=${DB_PULSE};User ID=${DB_USER};Password=${DB_PASS};Encrypt=True;TrustServerCertificate=True;Connection Timeout=30;"
      LOG_CONN="Server=tcp:${DB_HOST},1433;Database=${DB_LOGGING};User ID=${DB_USER};Password=${DB_PASS};Encrypt=True;TrustServerCertificate=True;Connection Timeout=30;"
      ;;
    postgresql)
      OPS_CONN="PostgreSQL:Server=${DB_HOST};Database=${DB_PULSE};User Id=${DB_USER};Password=${DB_PASS};"
      LOG_CONN="PostgreSQL:Server=${DB_HOST};Database=${DB_LOGGING};User Id=${DB_USER};Password=${DB_PASS};"
      ;;
    sqlserveronvm)
      OPS_CONN="Server=${DB_HOST},1433;Database=${DB_PULSE};uid=${DB_USER};pwd=${DB_PASS};ConnectRetryCount=12;ConnectRetryInterval=10;Encrypt=True;TrustServerCertificate=True;"
      LOG_CONN="Server=${DB_HOST},1433;Database=${DB_LOGGING};uid=${DB_USER};pwd=${DB_PASS};ConnectRetryCount=12;ConnectRetryInterval=10;Encrypt=True;TrustServerCertificate=True;"
      ;;
  esac
fi

# ============================================================
# Generate rpi-secrets.yaml
# ============================================================
echo ""
echo "Generating ${SECRETS_FILE}..."

cat > "$SECRETS_FILE" << SECRETS_HEADER
# ============================================================
# RPI Kubernetes Secret — Generated by Interaction CLI
# $(date -u +"%Y-%m-%d %H:%M:%S UTC")
# ============================================================
# Apply BEFORE helm install:
#   kubectl apply -f ${SECRETS_FILE}
#
# WARNING: This file contains sensitive values.
#          Do NOT commit this file to version control.
# ============================================================
apiVersion: v1
kind: Secret
metadata:
  name: ${SECRET_NAME}
  namespace: ${NAMESPACE}
  annotations:
    helm.sh/resource-policy: keep
type: Opaque
stringData:
SECRETS_HEADER

if [ "$MODE" = "standard" ]; then
  cat >> "$SECRETS_FILE" << SECRETS_DB
  # -- Operational Database --
  ConnectionString_Operations_Database: "${OPS_CONN}"
  ConnectionString_Logging_Database: "${LOG_CONN}"
  Operations_Database_Server_Password: "${DB_PASS}"
  Operations_Database_ServerHost: "${DB_HOST}"
  Operations_Database_Server_Username: "${DB_USER}"
  Operations_Database_Pulse_Database_Name: "${DB_PULSE}"
  Operations_Database_Pulse_Logging_Database_Name: "${DB_LOGGING}"
SECRETS_DB
fi

if [ "$REALTIME_ENABLED" = "true" ]; then
  cat >> "$SECRETS_FILE" << SECRETS_RT
  # -- Realtime API --
  RealtimeAPI_Auth_Token: "${RT_AUTH_TOKEN}"
SECRETS_RT

  if [ "$RT_CACHE_PROVIDER" = "mongodb" ] && [ -n "$RT_CACHE_CONNSTR" ]; then
    cat >> "$SECRETS_FILE" << SECRETS_MONGO
  RealtimeAPI_MongoCache_ConnectionString: "${RT_CACHE_CONNSTR}"
SECRETS_MONGO
  fi

  if [ "$RT_QUEUE_PROVIDER" = "azureservicebus" ] && [ -n "$RT_QUEUE_CONNSTR" ]; then
    cat >> "$SECRETS_FILE" << SECRETS_SB
  RealtimeAPI_ServiceBus_ConnectionString: "${RT_QUEUE_CONNSTR}"
SECRETS_SB
  fi
fi

echo "  Created: ${SECRETS_FILE}"

# ============================================================
# Generate overrides YAML (no secrets)
# ============================================================
echo "Generating ${OUTPUT_FILE}..."

cat > "$OUTPUT_FILE" << YAML
# ============================================================
# RPI Helm Overrides — Generated by Interaction CLI
# $(date -u +"%Y-%m-%d %H:%M:%S UTC")
# ============================================================
# This file contains ONLY non-sensitive configuration.
# Secrets are in ${SECRETS_FILE} (applied separately).
# ============================================================

global:
  deployment:
    mode: ${MODE}
    platform: ${PLATFORM}
    images:
      repository: ${DEFAULT_REGISTRY}
      tag: "${TAG}"
      imagePullPolicy: Always
      imagePullSecret:
        enabled: true
        name: redpoint-rpi

secretsManagement:
  provider: kubernetes
  kubernetes:
    autoCreateSecrets: false
    secretName: ${SECRET_NAME}
YAML

# Database section (non-sensitive parts only)
if [ "$MODE" = "standard" ]; then
  cat >> "$OUTPUT_FILE" << YAML

databases:
  operational:
    provider: ${DB_PROVIDER}
    server_host: ${DB_HOST}
    server_username: ${DB_USER}
    pulse_database_name: ${DB_PULSE}
    pulse_logging_database_name: ${DB_LOGGING}
    encrypt: true
YAML
fi

# Cloud Identity
if [ "$CLOUD_IDENTITY_ENABLED" = "true" ]; then
  cat >> "$OUTPUT_FILE" << YAML

cloudIdentity:
  enabled: true
  serviceAccount:
    create: true
    name: redpoint-rpi
YAML

  case "$PLATFORM" in
    azure)
      cat >> "$OUTPUT_FILE" << YAML
  azure:
    managedIdentityClientId: ${AZURE_CLIENT_ID}
    tenantId: ${AZURE_TENANT_ID}
YAML
      ;;
    amazon)
      cat >> "$OUTPUT_FILE" << YAML
  amazon:
    roleArn: ${AMAZON_ROLE_ARN}
    region: ${AMAZON_REGION}
    useAccessKeys: false
YAML
      ;;
    google)
      cat >> "$OUTPUT_FILE" << YAML
  google:
    serviceAccountEmail: ${GOOGLE_SA_EMAIL}
YAML
      ;;
  esac
fi

# Ingress
cat >> "$OUTPUT_FILE" << YAML

ingress:
  controller:
    enabled: ${DEPLOY_CONTROLLER}
  domain: ${DOMAIN}
YAML

# Realtime API (non-sensitive parts only)
if [ "$REALTIME_ENABLED" = "true" ]; then
  cat >> "$OUTPUT_FILE" << YAML

realtimeapi:
  enabled: true
  replicas: 1
  cacheProvider:
    enabled: true
    provider: ${RT_CACHE_PROVIDER}
  queueProvider:
    enabled: true
    provider: ${RT_QUEUE_PROVIDER}
YAML

  if [ "$RT_QUEUE_PROVIDER" = "rabbitmq" ]; then
    cat >> "$OUTPUT_FILE" << YAML
    rabbitmq:
      type: internal
YAML
  fi
fi

# Pre-flight
cat >> "$OUTPUT_FILE" << YAML

preflight:
  enabled: true
  mode: test
YAML

echo "  Created: ${OUTPUT_FILE}"

# ============================================================
# Generate prerequisites script
# ============================================================
echo "Generating ${PREREQS_FILE}..."

cat > "$PREREQS_FILE" << 'PREREQS_HEADER'
#!/usr/bin/env bash
# ============================================================
# RPI Prerequisites — Generated by Interaction CLI
# Run this BEFORE helm install to create required resources.
# ============================================================
set -euo pipefail

PREREQS_HEADER

cat >> "$PREREQS_FILE" << PREREQS_BODY
NAMESPACE="${NAMESPACE}"

echo "Creating namespace..."
kubectl create namespace "\${NAMESPACE}" --dry-run=client -o yaml | kubectl apply -f -

echo ""
echo "Creating image pull secret..."
echo "  You will need credentials from Redpoint Support."
read -rp "Docker username: " DOCKER_USER
read -rsp "Docker password: " DOCKER_PASS; echo ""
kubectl create secret docker-registry redpoint-rpi \\
  --namespace "\${NAMESPACE}" \\
  --docker-server=${DEFAULT_REGISTRY%%/docker*} \\
  --docker-username="\${DOCKER_USER}" \\
  --docker-password="\${DOCKER_PASS}" \\
  --dry-run=client -o yaml | kubectl apply -f -

echo ""
echo "Creating TLS secret..."
read -rp "Path to TLS certificate (.crt): " CERT_PATH
read -rp "Path to TLS private key (.key): " KEY_PATH
kubectl create secret tls ingress-tls \\
  --namespace "\${NAMESPACE}" \\
  --cert="\${CERT_PATH}" \\
  --key="\${KEY_PATH}" \\
  --dry-run=client -o yaml | kubectl apply -f -

echo ""
echo "Prerequisites created successfully."
PREREQS_BODY

chmod +x "$PREREQS_FILE"
echo "  Created: ${PREREQS_FILE}"

# ============================================================
# Summary
# ============================================================
echo ""
echo "============================================"
echo "  Interaction CLI — Generation Complete"
echo "============================================"
echo ""
echo "Next steps:"
echo "  1. Review ${SECRETS_FILE} — ensure all values are correct"
echo "  2. Run prerequisites:     bash ${PREREQS_FILE}"
echo "  3. Apply secrets:         kubectl apply -f ${SECRETS_FILE}"
echo "  4. Deploy:                helm upgrade --install rpi ./chart -f ${OUTPUT_FILE} -n ${NAMESPACE}"
echo "  5. Validate:              helm test rpi -n ${NAMESPACE}"
echo ""
echo "WARNING: ${SECRETS_FILE} contains sensitive values."
echo "         Do NOT commit it to version control."
echo ""
