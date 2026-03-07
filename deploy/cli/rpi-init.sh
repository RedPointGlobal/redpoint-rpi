#!/usr/bin/env bash
# ============================================================
# rpi-init.sh — Interactive RPI Helm overrides generator
# ============================================================
# Generates a ready-to-use Helm values file and a prerequisites
# script from interactive prompts. No dependencies beyond bash.
#
# Usage:
#   bash deploy/cli/rpi-init.sh
#   bash deploy/cli/rpi-init.sh -o my-overrides.yaml
# ============================================================

set -euo pipefail

# --- Defaults ---
OUTPUT_FILE="my-overrides.yaml"
PREREQS_FILE="prereqs.sh"
DEFAULT_TAG="7.7.20260220.1524"
DEFAULT_NAMESPACE="redpoint-rpi"
DEFAULT_REGISTRY="rg1acrpub.azurecr.io/docker/redpointglobal/releases"

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
echo "  RPI Helm Overrides Generator"
echo "============================================"
echo ""
echo "This script will generate:"
echo "  1. ${OUTPUT_FILE} — Helm values overrides file"
echo "  2. ${PREREQS_FILE} — Prerequisite kubectl commands"
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
# 3. Database (skip for demo)
# ============================================================
DB_HOST=""
DB_USER=""
DB_PASS=""
DB_PULSE=""
DB_LOGGING=""
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
# 5. Secrets Management
# ============================================================
echo ""
echo "--- Secrets Management ---"
prompt_choice SECRETS_PROVIDER "Secrets provider" "kubernetes|sdk|csi" "kubernetes"

SDK_VAULT_URI=""
if [ "$SECRETS_PROVIDER" = "sdk" ] && [ "$PLATFORM" = "azure" ]; then
  prompt SDK_VAULT_URI "Azure Key Vault URI" "https://myvault.vault.azure.net/"
fi

# ============================================================
# 6. Realtime API
# ============================================================
echo ""
echo "--- Realtime API ---"
prompt_yesno REALTIME_ENABLED "Enable Realtime API?" "y"

RT_CACHE_PROVIDER=""
RT_CACHE_CONNSTR=""
RT_QUEUE_PROVIDER=""

if [ "$REALTIME_ENABLED" = "true" ]; then
  prompt_choice RT_CACHE_PROVIDER "Cache provider" "mongodb|redis|inMemorySql" "mongodb"
  if [ "$RT_CACHE_PROVIDER" = "mongodb" ]; then
    prompt RT_CACHE_CONNSTR "MongoDB connection string" ""
  fi
  prompt_choice RT_QUEUE_PROVIDER "Queue provider" "amazonsqs|azureservicebus|rabbitmq|googlepubsub" "rabbitmq"
fi

# ============================================================
# 7. Post-Install Automation
# ============================================================
echo ""
echo "--- Post-Install Automation ---"
prompt_yesno POSTINSTALL_ENABLED "Enable automated post-install (license + DB setup)?" "n"

PI_ACTIVATION_KEY=""
PI_SYSTEM_NAME=""
PI_ADMIN_PASS=""
PI_ADMIN_EMAIL=""

if [ "$POSTINSTALL_ENABLED" = "true" ]; then
  prompt PI_ACTIVATION_KEY "License activation key" ""
  prompt PI_SYSTEM_NAME "System name" "my-rpi-system"
  read -rsp "Admin password: " PI_ADMIN_PASS; echo ""
  prompt PI_ADMIN_EMAIL "Admin email" "admin@example.com"
fi

# ============================================================
# Generate overrides YAML
# ============================================================
echo ""
echo "Generating ${OUTPUT_FILE}..."

cat > "$OUTPUT_FILE" << YAML
# ============================================================
# RPI Helm Overrides — Generated by rpi-init.sh
# $(date -u +"%Y-%m-%d %H:%M:%S UTC")
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
YAML

# Database section
if [ "$MODE" = "standard" ]; then
  cat >> "$OUTPUT_FILE" << YAML

databases:
  operational:
    provider: ${DB_PROVIDER}
    server_host: ${DB_HOST}
    server_username: ${DB_USER}
    server_password: ${DB_PASS}
    pulse_database_name: ${DB_PULSE}
    pulse_logging_database_name: ${DB_LOGGING}
    encrypt: true
YAML
else
  cat >> "$OUTPUT_FILE" << YAML

# Demo mode: embedded MSSQL + MongoDB (no external DB needed)
databases:
  operational:
    server_host: rpi-demo-mssql
    server_username: sa
    server_password: RETRIEVE_FROM_SECRET
    pulse_database_name: Pulse
    pulse_logging_database_name: Pulse_Logging
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
else
  cat >> "$OUTPUT_FILE" << YAML

cloudIdentity:
  enabled: false
YAML
fi

# Secrets Management
cat >> "$OUTPUT_FILE" << YAML

secretsManagement:
  provider: ${SECRETS_PROVIDER}
YAML

if [ "$SECRETS_PROVIDER" = "sdk" ] && [ -n "$SDK_VAULT_URI" ]; then
  cat >> "$OUTPUT_FILE" << YAML
  sdk:
    azure:
      vaultUri: ${SDK_VAULT_URI}
YAML
fi

# Ingress
cat >> "$OUTPUT_FILE" << YAML

ingress:
  controller:
    enabled: ${DEPLOY_CONTROLLER}
  domain: ${DOMAIN}
YAML

# Realtime API
if [ "$REALTIME_ENABLED" = "true" ]; then
  cat >> "$OUTPUT_FILE" << YAML

realtimeapi:
  enabled: true
  replicas: 1
  cacheProvider:
    enabled: true
    provider: ${RT_CACHE_PROVIDER}
YAML

  if [ "$RT_CACHE_PROVIDER" = "mongodb" ] && [ -n "$RT_CACHE_CONNSTR" ]; then
    cat >> "$OUTPUT_FILE" << YAML
    mongodb:
      connectionString: "${RT_CACHE_CONNSTR}"
YAML
  fi

  cat >> "$OUTPUT_FILE" << YAML
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

# Post-Install
if [ "$POSTINSTALL_ENABLED" = "true" ]; then
  cat >> "$OUTPUT_FILE" << YAML

postInstall:
  enabled: true
  activationKey: "${PI_ACTIVATION_KEY}"
  systemName: "${PI_SYSTEM_NAME}"
  adminUsername: coreuser
  adminPassword: "${PI_ADMIN_PASS}"
  adminEmail: "${PI_ADMIN_EMAIL}"
YAML
fi

# Pre-flight (always enable as test mode)
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
# RPI Prerequisites — Generated by rpi-init.sh
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
echo "Prerequisites created. Deploy with:"
echo "  helm upgrade --install rpi ./chart -f ${OUTPUT_FILE} -n \${NAMESPACE} --create-namespace"
PREREQS_BODY

chmod +x "$PREREQS_FILE"
echo "  Created: ${PREREQS_FILE}"

# ============================================================
# Summary
# ============================================================
echo ""
echo "============================================"
echo "  Generation Complete"
echo "============================================"
echo ""
echo "Next steps:"
echo "  1. Review ${OUTPUT_FILE} and update any placeholder values"
echo "  2. Run prerequisites:  bash ${PREREQS_FILE}"
echo "  3. Deploy:  helm upgrade --install rpi ./chart -f ${OUTPUT_FILE} -n ${NAMESPACE} --create-namespace"
echo "  4. Validate: helm test rpi -n ${NAMESPACE}"
echo ""
