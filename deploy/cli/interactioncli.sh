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
OUTPUT_FILE="values-overrides.yaml"
SECRETS_FILE="redpoint-rpi-secrets.yaml"
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

# --- Colors & Symbols ---
if [ -t 1 ] && command -v tput &> /dev/null && [ "$(tput colors 2>/dev/null || echo 0)" -ge 8 ]; then
  BOLD=$(tput bold)
  CYAN=$(tput setaf 6)
  GREEN=$(tput setaf 2)
  YELLOW=$(tput setaf 3)
  RED=$(tput setaf 1)
  DIM=$(tput dim)
  RESET=$(tput sgr0)
else
  BOLD="" CYAN="" GREEN="" YELLOW="" RED="" DIM="" RESET=""
fi

ICON_CHECK="${GREEN}✔${RESET}"
ICON_WARN="${YELLOW}⚠${RESET}"
ICON_FILE="${CYAN}📄${RESET}"
ICON_KEY="${YELLOW}🔑${RESET}"
ICON_ROCKET="${GREEN}🚀${RESET}"

# --- Helpers ---
section() {
  echo ""
  echo "${CYAN}${BOLD}━━━ $1 ━━━${RESET}"
}

prompt() {
  local var_name=$1 prompt_text=$2 default=$3
  local value
  if [ -n "$default" ]; then
    read -rp "  ${prompt_text} ${DIM}[${default}]${RESET}: " value
    value="${value:-$default}"
  else
    read -rp "  ${prompt_text}: " value
  fi
  eval "$var_name=\"\$value\""
}

prompt_choice() {
  local var_name=$1 prompt_text=$2 options=$3 default=$4
  local value
  while true; do
    read -rp "  ${prompt_text} ${DIM}(${options}) [${default}]${RESET}: " value
    value="${value:-$default}"
    if echo "$options" | tr '|' '\n' | grep -qx "$value"; then
      break
    fi
    echo "  ${RED}Invalid choice. Options: ${options}${RESET}"
  done
  eval "$var_name=\"\$value\""
}

prompt_yesno() {
  local var_name=$1 prompt_text=$2 default=$3
  local value
  while true; do
    read -rp "  ${prompt_text} ${DIM}(y/n) [${default}]${RESET}: " value
    value="${value:-$default}"
    case "$value" in
      y|Y|yes) eval "$var_name=true"; break ;;
      n|N|no)  eval "$var_name=false"; break ;;
      *) echo "  ${RED}Please enter y or n${RESET}" ;;
    esac
  done
}

echo ""
echo "${CYAN}${BOLD}╔══════════════════════════════════════════════╗${RESET}"
echo "${CYAN}${BOLD}║        Redpoint Interaction CLI               ║${RESET}"
echo "${CYAN}${BOLD}║        Deployment Generator for RPI           ║${RESET}"
echo "${CYAN}${BOLD}╚══════════════════════════════════════════════╝${RESET}"
echo ""
echo "  This tool generates the files needed to deploy"
echo "  Redpoint Interaction (RPI) on Kubernetes."
echo ""
echo "  ${ICON_FILE} ${OUTPUT_FILE}    — Helm values overrides"
echo "  ${ICON_KEY} ${SECRETS_FILE}   — Kubernetes Secret manifest"
echo "  ${ICON_ROCKET} ${PREREQS_FILE}   — Prerequisite kubectl commands"
echo ""

# ============================================================
# 1. Platform & Mode
# ============================================================
section "Platform & Deployment Mode"
prompt_choice PLATFORM "Cloud platform" "azure|amazon|google|selfhosted" "azure"
prompt_choice MODE "Deployment mode" "standard|demo" "standard"
prompt TAG "Image tag" "$DEFAULT_TAG"
prompt NAMESPACE "Kubernetes namespace" "$DEFAULT_NAMESPACE"

# ============================================================
# 2. Ingress
# ============================================================
section "Ingress"
prompt DOMAIN "Ingress domain (e.g., redpointcdp.com)" "example.com"
prompt HOST_PREFIX "Hostname prefix (e.g., 'rpi' produces rpi-deploymentapi.${DOMAIN})" "rpi"
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
  section "Operational Database"
  prompt_choice DB_PROVIDER "Database provider" "sqlserver|postgresql|sqlserveronvm" "sqlserver"
  prompt DB_HOST "Database server host" ""
  prompt DB_USER "Database username" ""
  read -rsp "  Database password: " DB_PASS; echo ""
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
  section "Cloud Identity"
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
section "Realtime API"
prompt_yesno REALTIME_ENABLED "Enable Realtime API?" "y"

RT_CACHE_PROVIDER=""
RT_CACHE_CONNSTR=""
RT_QUEUE_PROVIDER=""
RT_QUEUE_CONNSTR=""

if [ "$REALTIME_ENABLED" = "true" ]; then
  if [ "$DB_PROVIDER" = "sqlserveronvm" ]; then
    prompt_choice RT_CACHE_PROVIDER "Cache provider" "mongodb|redis|inMemorySql" "mongodb"
  else
    prompt_choice RT_CACHE_PROVIDER "Cache provider" "mongodb|redis" "mongodb"
  fi
  if [ "$RT_CACHE_PROVIDER" = "mongodb" ]; then
    prompt RT_CACHE_CONNSTR "MongoDB connection string" ""
  elif [ "$RT_CACHE_PROVIDER" = "redis" ]; then
    prompt RT_CACHE_CONNSTR "Redis connection string" ""
  elif [ "$RT_CACHE_PROVIDER" = "inMemorySql" ]; then
    prompt RT_CACHE_CONNSTR "SQL Server in-memory cache connection string" ""
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
# Generate auto-generated passwords and tokens
# ============================================================
gen_password() {
  if command -v openssl &> /dev/null; then
    openssl rand -hex 16
  else
    head -c 16 /dev/urandom | od -An -tx1 | tr -d ' \n'
  fi
}

RT_AUTH_TOKEN=""
RT_RABBITMQ_PASSWORD=""
RT_REDIS_CACHE_PASSWORD=""
QS_REDIS_PASSWORD=""
QS_RABBITMQ_PASSWORD=""

QUEUE_PREFIX=""
if [ "$REALTIME_ENABLED" = "true" ]; then
  RT_AUTH_TOKEN=$(gen_password)
  RT_RABBITMQ_PASSWORD=$(gen_password)
  RT_REDIS_CACHE_PASSWORD=$(gen_password)
  QS_REDIS_PASSWORD=$(gen_password)
  QS_RABBITMQ_PASSWORD=$(gen_password)
  # Generate a short unique ID for queue name isolation
  QUEUE_UID=$(head -c 3 /dev/urandom | od -An -tx1 | tr -d ' \n')
  QUEUE_PREFIX="${HOST_PREFIX}_${QUEUE_UID}_"
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
printf "${CYAN}${BOLD}Generating files ${RESET}"
for i in $(seq 1 30); do
  printf "${CYAN}▪${RESET}"
  sleep 1
done
echo ""

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

  # Cache provider connection string (user-provided)
  if [ "$RT_CACHE_PROVIDER" = "mongodb" ] && [ -n "$RT_CACHE_CONNSTR" ]; then
    cat >> "$SECRETS_FILE" << SECRETS_MONGO
  RealtimeAPI_MongoCache_ConnectionString: "${RT_CACHE_CONNSTR}"
SECRETS_MONGO
  elif [ "$RT_CACHE_PROVIDER" = "redis" ] && [ -n "$RT_CACHE_CONNSTR" ]; then
    cat >> "$SECRETS_FILE" << SECRETS_REDIS_CONN
  RealtimeAPI_RedisCache_ConnectionString: "${RT_CACHE_CONNSTR}"
SECRETS_REDIS_CONN
  elif [ "$RT_CACHE_PROVIDER" = "inMemorySql" ] && [ -n "$RT_CACHE_CONNSTR" ]; then
    cat >> "$SECRETS_FILE" << SECRETS_INMEM
  RealtimeAPI_inMemorySql_ConnectionString: "${RT_CACHE_CONNSTR}"
SECRETS_INMEM
  fi

  # Queue provider connection string (user-provided)
  if [ "$RT_QUEUE_PROVIDER" = "azureservicebus" ] && [ -n "$RT_QUEUE_CONNSTR" ]; then
    cat >> "$SECRETS_FILE" << SECRETS_SB
  RealtimeAPI_ServiceBus_ConnectionString: "${RT_QUEUE_CONNSTR}"
SECRETS_SB
  fi

  # Auto-generated passwords (always included when Realtime is enabled)
  cat >> "$SECRETS_FILE" << SECRETS_AUTO
  RealtimeAPI_RabbitMQ_Password: "${RT_RABBITMQ_PASSWORD}"
  RealtimeAPI_RedisCache_Password: "${RT_REDIS_CACHE_PASSWORD}"
  QueueService_RedisCache_Password: "${QS_REDIS_PASSWORD}"
  QueueService_internalCache_ConnectionString: "rpi-queuereader-cache:6379,password=${QS_REDIS_PASSWORD},abortConnect=False"
  QueueService_RabbitMQ_Password: "${QS_RABBITMQ_PASSWORD}"
SECRETS_AUTO
fi

# ============================================================
# Generate overrides YAML (no secrets)
# ============================================================

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
  hosts:
    config: ${HOST_PREFIX}-deploymentapi
    client: ${HOST_PREFIX}-interactionapi
    integration: ${HOST_PREFIX}-integrationapi
    realtime: ${HOST_PREFIX}-realtimeapi
    callbackapi: ${HOST_PREFIX}-callbackapi
    queuereader: ${HOST_PREFIX}-queuereader
    rabbitmqconsole: ${HOST_PREFIX}-rabbitmq-console
    smartactivation: ${HOST_PREFIX}-smartActivation
YAML

# Storage (commented-out, platform-specific examples)
case "$PLATFORM" in
  azure)
    cat >> "$OUTPUT_FILE" << 'YAML'

# ---------------------------------------------------------------
# Storage — Uncomment and configure for your environment.
# See README.md > Configure Storage for details.
# ---------------------------------------------------------------
# storage:
#   persistentVolumeClaims:
#     FileOutputDirectory:
#       enabled: true
#       claimName: rpifileoutputdir
#       mountPath: /rpifileoutputdir
#     Plugins:
#       enabled: true
#       claimName: realtimeplugins
#       mountPath: /app/plugins
#     DataManagementUploadDirectory:
#       enabled: true
#       claimName: rpdmuploaddirectory
#       mountPath: /rpdmuploaddirectory
#   persistentVolumes:
#     - name: rpi-blob-storage
#       capacity: 100Gi
#       accessModes: [ReadWriteMany]
#       storageClassName: blob-fuse
#       reclaimPolicy: Retain
#       mountOptions:
#         - -o allow_other
#         - --file-cache-timeout-in-seconds=120
#       csi:
#         driver: blob.csi.azure.com
#         volumeHandle: unique-volume-handle
#         volumeAttributes:
#           containerName: rpi-data
#           storageAccount: <my-storage-account>
#       pvc:
#         claimName: rpifileoutputdir
YAML
    ;;
  amazon)
    cat >> "$OUTPUT_FILE" << 'YAML'

# ---------------------------------------------------------------
# Storage — Uncomment and configure for your environment.
# See README.md > Configure Storage for details.
# ---------------------------------------------------------------
# storage:
#   persistentVolumeClaims:
#     FileOutputDirectory:
#       enabled: true
#       claimName: rpifileoutputdir
#       mountPath: /rpifileoutputdir
#     Plugins:
#       enabled: true
#       claimName: realtimeplugins
#       mountPath: /app/plugins
#     DataManagementUploadDirectory:
#       enabled: true
#       claimName: rpdmuploaddirectory
#       mountPath: /rpdmuploaddirectory
#   persistentVolumes:
#     - name: rpi-efs-storage
#       capacity: 100Gi
#       accessModes: [ReadWriteMany]
#       storageClassName: efs-sc
#       reclaimPolicy: Retain
#       csi:
#         driver: efs.csi.aws.com
#         volumeHandle: <my-efs-filesystem-id>
#       pvc:
#         claimName: rpifileoutputdir
YAML
    ;;
  google)
    cat >> "$OUTPUT_FILE" << 'YAML'

# ---------------------------------------------------------------
# Storage — Uncomment and configure for your environment.
# See README.md > Configure Storage for details.
# ---------------------------------------------------------------
# storage:
#   persistentVolumeClaims:
#     FileOutputDirectory:
#       enabled: true
#       claimName: rpifileoutputdir
#       mountPath: /rpifileoutputdir
#     Plugins:
#       enabled: true
#       claimName: realtimeplugins
#       mountPath: /app/plugins
#     DataManagementUploadDirectory:
#       enabled: true
#       claimName: rpdmuploaddirectory
#       mountPath: /rpdmuploaddirectory
#   persistentVolumes:
#     - name: rpi-filestore
#       capacity: 100Gi
#       accessModes: [ReadWriteMany]
#       storageClassName: filestore-sc
#       reclaimPolicy: Retain
#       csi:
#         driver: filestore.csi.storage.gke.io
#         volumeHandle: "modeInstance/<my-zone>/<my-filestore-instance>/<my-share-name>"
#       pvc:
#         claimName: rpifileoutputdir
YAML
    ;;
  *)
    cat >> "$OUTPUT_FILE" << 'YAML'

# ---------------------------------------------------------------
# Storage — Uncomment and configure for your environment.
# See README.md > Configure Storage for details.
# ---------------------------------------------------------------
# storage:
#   persistentVolumeClaims:
#     FileOutputDirectory:
#       enabled: true
#       claimName: rpifileoutputdir
#       mountPath: /rpifileoutputdir
#     Plugins:
#       enabled: true
#       claimName: realtimeplugins
#       mountPath: /app/plugins
#     DataManagementUploadDirectory:
#       enabled: true
#       claimName: rpdmuploaddirectory
#       mountPath: /rpdmuploaddirectory
YAML
    ;;
esac

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
    queueNames:
      formQueuePath: ${QUEUE_PREFIX}RPIWebFormSubmission
      eventsQueuePath: ${QUEUE_PREFIX}RPIWebEvents
      cacheOutputQueuePath: ${QUEUE_PREFIX}RPIWebCacheData
      recommendationsQueuePath: ${QUEUE_PREFIX}RPIWebRecommendations
      listenerQueuePath: ${QUEUE_PREFIX}RPIQueueListener
      callbackServiceQueuePath: ${QUEUE_PREFIX}RPICallbackApiQueue
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

# Optional features (commented-out reference)
cat >> "$OUTPUT_FILE" << 'YAML'

# ---------------------------------------------------------------
# Database Upgrade — Automatically upgrades operational databases
# when the image tag changes. Recommended for all environments.
# See README.md > Configure Automatic Database Upgrades.
# ---------------------------------------------------------------
# databaseUpgrade:
#   enabled: true
#   notification:
#     enabled: true
#     recipientEmail: admin@example.com

# ---------------------------------------------------------------
# Queue Reader — Drains Queue Listener and Realtime queues.
# See README.md > RPI Queue Reader.
# ---------------------------------------------------------------
# queuereader:
#   enabled: true
#   realtimeConfiguration:
#     isDistributed: false
#     tenantIds:
#       - "<my-rpi-client-id>"

# ---------------------------------------------------------------
# Autoscaling — Resource-based (HPA) or custom metrics (KEDA).
# See README.md > Configure Autoscaling.
# ---------------------------------------------------------------
# realtimeapi:
#   autoscaling:
#     enabled: true
#     type: hpa
#     minReplicas: 1
#     maxReplicas: 5
#     targetCPUUtilizationPercentage: 80
#     targetMemoryUtilizationPercentage: 80
#
# executionservice:
#   autoscaling:
#     enabled: true
#     type: keda
#     kedaScaledObject:
#       serverAddress: <my-prometheus-query-endpoint>

# ---------------------------------------------------------------
# Custom Metrics — Expose /metrics endpoints for Prometheus.
# See README.md > Configure Custom Metrics.
# ---------------------------------------------------------------
# customMetrics:
#   enabled: true
#   prometheus_scrape: true

# ---------------------------------------------------------------
# Service Mesh — Linkerd Server CRDs for L7 traffic policy.
# See README.md > Configure Service Mesh.
# ---------------------------------------------------------------
# serviceMesh:
#   enabled: true
#   provider: linkerd
#   servers:
#     - name: realtimeapi
#       podSelector:
#         app.kubernetes.io/name: rpi-realtimeapi
#       port: 8080
#       proxyProtocol: HTTP/1
#     - name: executionservice
#       podSelector:
#         app.kubernetes.io/name: rpi-executionservice
#       port: 8080
#       proxyProtocol: HTTP/1

# ---------------------------------------------------------------
# Smoke Tests — Deploy minimal pods to validate storage mounts
# and CSI drivers before running the full application.
# See README.md > Smoke Tests.
# ---------------------------------------------------------------
# smokeTests:
#   enabled: true
#   deployments:
#     - name: blob
#       type: pvc
#       claimName: rpifileoutputdir
#       mountPath: /mnt/rpifileoutputdir
#     - name: kv-secrets
#       type: csiSecret
#       secretProviderClass: rpi-secrets
#       mountPath: /mnt/secrets

# ---------------------------------------------------------------
# Microsoft Entra ID — SSO for the RPI Client.
# See README.md > Configure Microsoft Entra ID.
# ---------------------------------------------------------------
# MicrosoftEntraID:
#   enabled: true
#   name: Microsoft
#   interaction_client_id: <interaction-client-id>
#   interaction_api_id: <interaction-api-id>
#   tenant_id: <azure-tenant-id>

# ---------------------------------------------------------------
# SMTP — Email delivery for notifications and workflows.
# ---------------------------------------------------------------
# SMTPSettings:
#   UseCredentials: true
#   SMTP_Server: smtp.example.com
#   SMTP_Port: "587"
#   SMTP_From: noreply@example.com
#   SMTP_Username: <my-smtp-username>

# ---------------------------------------------------------------
# Content Generation — OpenAI and Azure Cognitive Search.
# See README.md > Configure Content Generation Tools.
# ---------------------------------------------------------------
# redpointAI:
#   enabled: true

# ---------------------------------------------------------------
# Advanced Overrides — Fine-tune any internal default without
# forking the chart: probes, security context, logging, ports,
# rollout strategy, thread pools, retry policies, and more.
# See docs/values-reference.yaml for every available key.
# ---------------------------------------------------------------
# advanced:
#   securityContext:
#     runAsUser: 7777
#     runAsGroup: 777
#     fsGroup: 777
#   livenessProbe:
#     periodSeconds: 30
#     failureThreshold: 5
#   realtimeapi:
#     logging:
#       realtimeapi:
#         default: Debug
YAML

# ============================================================
# Generate prerequisites script
# ============================================================

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
echo "Applying RPI secrets..."
kubectl apply -f ${SECRETS_FILE}

echo ""
echo "Prerequisites created successfully."
PREREQS_BODY

chmod +x "$PREREQS_FILE"

# ============================================================
# Summary
# ============================================================
echo ""
echo "${GREEN}${BOLD}╔══════════════════════════════════════════════╗${RESET}"
echo "${GREEN}${BOLD}║   ${ICON_CHECK}  Interaction CLI — Complete                ║${RESET}"
echo "${GREEN}${BOLD}╚══════════════════════════════════════════════╝${RESET}"
echo ""
echo "  ${BOLD}Generated files:${RESET}"
echo "  ${ICON_KEY} ${SECRETS_FILE}"
echo "  ${ICON_FILE} ${OUTPUT_FILE}"
echo "  ${ICON_ROCKET} ${PREREQS_FILE}"
echo ""
echo "  ${BOLD}Next steps:${RESET}"
echo "  ${CYAN}1.${RESET} Review ${BOLD}${SECRETS_FILE}${RESET} — ensure all values are correct"
echo "  ${CYAN}2.${RESET} Run prerequisites:  ${DIM}bash ${PREREQS_FILE}${RESET}"
echo "  ${CYAN}3.${RESET} Deploy:             ${DIM}helm upgrade --install rpi ./chart -f ${OUTPUT_FILE} -n ${NAMESPACE}${RESET}"
echo "  ${CYAN}4.${RESET} Validate:           ${DIM}helm test rpi -n ${NAMESPACE}${RESET}"
echo ""
echo "  ${ICON_WARN}  ${YELLOW}${SECRETS_FILE} contains sensitive values.${RESET}"
echo "     ${YELLOW}Do NOT commit it to version control.${RESET}"
echo ""
echo "${DIM}──────────────────────────────────────────────${RESET}"
echo "  ${BOLD}Redpoint Global${RESET}"
echo "  ${DIM}https://www.redpointglobal.com${RESET}"
echo "  ${DIM}Support: support@redpointglobal.com${RESET}"
echo "  ${DIM}Docs:    https://docs.redpointglobal.com/rpi${RESET}"
echo "${DIM}──────────────────────────────────────────────${RESET}"
echo ""
