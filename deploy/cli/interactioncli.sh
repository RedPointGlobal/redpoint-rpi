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
OUTPUT_FILE="overrides.yaml"
SECRETS_FILE="secrets.yaml"
PREREQS_FILE="prereqs.sh"
DEFAULT_TAG="7.7.20260220.1524"
DEFAULT_NAMESPACE="redpoint-rpi"
DEFAULT_REGISTRY="rg1acrpub.azurecr.io/docker/redpointglobal/releases"
SECRET_NAME="redpoint-rpi-secrets"

# --- Parse arguments ---
ADD_MODE=false
ADD_FEATURE=""
FILE_MODE=false
INPUT_FILE="inputs.yaml"
while getopts "o:a:fh" opt; do
  case $opt in
    o) OUTPUT_FILE="$OPTARG" ;;
    a) ADD_MODE=true; ADD_FEATURE="$OPTARG" ;;
    f) FILE_MODE=true ;;
    h)
      echo "Usage: $0 [-o output-file] [-a feature] [-f]"
      echo ""
      echo "  No flags       Full interactive setup"
      echo "  -f             File-driven setup — reads values from inputs.yaml"
      echo "  -a <feature>   Add a feature to an existing overrides file"
      echo "  -a menu        Show interactive feature menu"
      echo "  -o <file>      Output file path (default: overrides.yaml)"
      echo ""
      echo "  Available features:"
      echo "    database_upgrade  Automatic database schema upgrades"
      echo "    queue_reader      Queue Listener and Realtime queue processing"
      echo "    autoscaling       HPA or KEDA autoscaling for services"
      echo "    custom_metrics    Prometheus /metrics endpoints"
      echo "    service_mesh      Linkerd Server CRDs"
      echo "    smoke_tests       PVC and CSI mount validation"
      echo "    entra_id          Microsoft Entra ID (Azure AD) SSO"
      echo "    oidc              OpenID Connect (Keycloak, Okta, etc.)"
      echo "    smtp              Email delivery configuration"
      echo "    redpoint_ai       OpenAI and Azure Cognitive Search"
      echo "    storage           PVC and CSI storage volumes"
      echo "    helm_copilot      AI assistant for chart configuration"
      echo "    data_warehouse    Snowflake, Redshift, or BigQuery"
      echo "    extra_envs        Debug and plugin environment variables"
      echo "    advanced          Fine-tune internal defaults"
      echo ""
      echo "  Examples:"
      echo "    bash interactioncli.sh                        # Interactive setup"
      echo "    bash interactioncli.sh -f                     # File-driven (reads inputs.yaml)"
      echo "    bash interactioncli.sh -a redpoint_ai         # Add a feature"
      echo "    bash interactioncli.sh -a menu                # Feature menu"
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

prompt_secret() {
  local var_name=$1 prompt_text=$2
  local value
  read -rsp "  ${prompt_text}: " value
  echo ""
  eval "$var_name=\"\$value\""
}

# Append a key-value pair to the secrets file.
# Creates the secrets file if it does not exist (for --add mode).
append_secret() {
  local key=$1 value=$2
  if [ ! -f "$SECRETS_FILE" ]; then
    cat > "$SECRETS_FILE" << SECRETS_INIT
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
  name: redpoint-rpi
  namespace: ${DEFAULT_NAMESPACE}
  annotations:
    helm.sh/resource-policy: keep
type: Opaque
stringData:
SECRETS_INIT
  fi
  echo "  ${key}: \"${value}\"" >> "$SECRETS_FILE"
}

# ============================================================
# Utility: generate a random password
# ============================================================
gen_password() {
  if command -v openssl &> /dev/null; then
    openssl rand -hex 16
  else
    head -c 16 /dev/urandom | od -An -tx1 | tr -d ' \n'
  fi
}

# ============================================================
# File mode: read values from YAML input instead of prompting
# ============================================================
if [ "$FILE_MODE" = "true" ]; then
  if [ "$ADD_MODE" = "true" ]; then
    echo "${RED}Error: -f and -a cannot be used together.${RESET}" >&2; exit 1
  fi
  if [ ! -f "$INPUT_FILE" ]; then
    echo "${RED}Error: ${INPUT_FILE} not found.${RESET}" >&2
    echo "  Copy the template and fill in your values:" >&2
    echo "    cp deploy/values/input-template.yaml ${INPUT_FILE}" >&2
    exit 1
  fi

  # Auto-install yq if not present
  if ! command -v yq &>/dev/null; then
    echo "  ${CYAN}Installing yq...${RESET}"
    _yq_version="v4.44.6"
    _yq_arch=$(uname -m)
    case "$_yq_arch" in
      x86_64)  _yq_arch="amd64" ;;
      aarch64) _yq_arch="arm64" ;;
    esac
    _yq_os=$(uname -s | tr '[:upper:]' '[:lower:]')
    _yq_url="https://github.com/mikefarah/yq/releases/download/${_yq_version}/yq_${_yq_os}_${_yq_arch}"
    if curl -fsSL "$_yq_url" -o /usr/local/bin/yq 2>/dev/null && chmod +x /usr/local/bin/yq; then
      echo "  ${ICON_CHECK} yq installed to /usr/local/bin/yq"
    elif curl -fsSL "$_yq_url" -o "${HOME}/.local/bin/yq" 2>/dev/null && chmod +x "${HOME}/.local/bin/yq"; then
      export PATH="${HOME}/.local/bin:${PATH}"
      echo "  ${ICON_CHECK} yq installed to ${HOME}/.local/bin/yq"
    else
      echo "${RED}Error: Failed to install yq. Install manually:${RESET}" >&2
      echo "  https://github.com/mikefarah/yq#install" >&2
      exit 1
    fi
  fi

  # Helper: read a value from the input YAML with a default fallback
  cfg() {
    local val
    val=$(yq eval "$1" "$INPUT_FILE" 2>/dev/null)
    if [ "$val" = "null" ] || [ -z "$val" ]; then echo "${2:-}"; else echo "$val"; fi
  }

  # Associative array holding all config values keyed by shell variable name
  declare -A _CFG=()

  # --- Core settings ---
  _CFG[PLATFORM]=$(cfg '.platform' 'azure')
  _CFG[MODE]=$(cfg '.mode' 'standard')
  _CFG[TAG]=$(cfg '.image_tag' "$DEFAULT_TAG")
  _CFG[NAMESPACE]=$(cfg '.namespace' "$DEFAULT_NAMESPACE")

  # --- Ingress ---
  _CFG[DOMAIN]=$(cfg '.ingress.domain' 'example.com')
  _CFG[HOST_PREFIX]=$(cfg '.ingress.host_prefix' 'rpi')
  _CFG[DEPLOY_CONTROLLER]=$(cfg '.ingress.deploy_controller' 'true')

  # --- Database ---
  _CFG[DB_PROVIDER]=$(cfg '.database.provider' 'sqlserver')
  _CFG[DB_HOST]=$(cfg '.database.host' '')
  _CFG[DB_USER]=$(cfg '.database.username' '')
  _CFG[DB_PASS]=$(cfg '.database.password' '')
  _CFG[DB_PULSE]=$(cfg '.database.pulse_database' 'Pulse')
  _CFG[DB_LOGGING]=$(cfg '.database.logging_database' 'Pulse_Logging')

  # --- Data warehouse ---
  _dw_provider=$(cfg '.data_warehouse.provider' '')
  if [ -n "$_dw_provider" ]; then
    _CFG[DW_ENABLED]="true"
  else
    _CFG[DW_ENABLED]="false"
  fi

  # --- Cloud identity ---
  _CFG[CLOUD_IDENTITY_ENABLED]=$(cfg '.cloud_identity.enabled' 'false')
  _CFG[AZURE_CLIENT_ID]=$(cfg '.cloud_identity.azure.client_id' '')
  _CFG[AZURE_TENANT_ID]=$(cfg '.cloud_identity.azure.tenant_id' '')
  _CFG[AMAZON_ROLE_ARN]=$(cfg '.cloud_identity.amazon.role_arn' '')
  _CFG[AMAZON_REGION]=$(cfg '.cloud_identity.amazon.region' 'us-east-1')
  _CFG[GOOGLE_SA_EMAIL]=$(cfg '.cloud_identity.google.service_account_email' '')

  # --- Realtime ---
  _CFG[REALTIME_ENABLED]=$(cfg '.realtime.enabled' 'true')
  _CFG[RT_CACHE_PROVIDER]=$(cfg '.realtime.cache.provider' 'mongodb')
  _CFG[RT_CACHE_CONNSTR]=$(cfg '.realtime.cache.connection_string' '')
  _CFG[RT_CACHE_BIGTABLE_PROJECT]=$(cfg '.realtime.cache.bigtable_project' '')
  _CFG[RT_CACHE_BIGTABLE_INSTANCE]=$(cfg '.realtime.cache.bigtable_instance' '')
  _CFG[RT_QUEUE_PROVIDER]=$(cfg '.realtime.queue.provider' 'rabbitmq')
  _CFG[RT_QUEUE_CONNSTR]=$(cfg '.realtime.queue.connection_string' '')
  _CFG[RT_EVENTHUB_NAME]=$(cfg '.realtime.queue.event_hub_name' 'RPIQueueListener')
  _CFG[RT_EVENTHUB_NAMESPACE]=$(cfg '.realtime.queue.namespace' '')
  _CFG[RT_PUBSUB_PROJECT]=$(cfg '.realtime.queue.pubsub_project' '')

  # --- Feature: SMTP ---
  _CFG[server]=$(cfg '.features.smtp.host' '')
  _CFG[port]=$(cfg '.features.smtp.port' '')
  _CFG[from_addr]=$(cfg '.features.smtp.from' '')
  _CFG[sender_name]=$(cfg '.features.smtp.sender_name' '')
  _CFG[enable_ssl]=$(cfg '.features.smtp.enable_ssl' '')
  _CFG[use_creds]=$(cfg '.features.smtp.use_credentials' '')
  _CFG[username]=$(cfg '.features.smtp.username' '')
  _CFG[smtp_password]=$(cfg '.features.smtp.password' '')

  # --- Feature: Entra ID ---
  _CFG[client_id]=$(cfg '.features.entra_id.client_id' '')
  _CFG[api_id]=$(cfg '.features.entra_id.api_id' '')
  _CFG[tenant_id]=$(cfg '.features.entra_id.tenant_id' '')

  # --- Feature: OIDC ---
  _CFG[provider_name]=$(cfg '.features.oidc.provider' '')
  _CFG[auth_host]=$(cfg '.features.oidc.authority' '')
  # client_id already mapped from entra_id — will be overwritten per feature context
  _CFG[audience]=$(cfg '.features.oidc.audience' '')
  _CFG[redirect_url]=$(cfg '.features.oidc.redirect_url' '')
  _CFG[enable_refresh]=$(cfg '.features.oidc.enable_refresh' '')
  _CFG[validate_issuer]=$(cfg '.features.oidc.validate_issuer' '')
  _CFG[validate_audience]=$(cfg '.features.oidc.validate_audience' '')
  _CFG[logout_param]=$(cfg '.features.oidc.logout_param' '')
  _CFG[supports_user_mgmt]=$(cfg '.features.oidc.supports_user_management' '')
  _CFG[add_scope]="false"   # custom scopes not supported in file mode

  # --- Feature: Redpoint AI ---
  _CFG[api_base]=$(cfg '.features.redpoint_ai.endpoint' '')
  _CFG[api_version]=$(cfg '.features.redpoint_ai.api_version' '')
  _CFG[engine]=$(cfg '.features.redpoint_ai.deployment' '')
  _CFG[temp]=$(cfg '.features.redpoint_ai.temperature' '')
  _CFG[search_endpoint]=$(cfg '.features.redpoint_ai.search_endpoint' '')
  _CFG[vector_profile]=$(cfg '.features.redpoint_ai.vector_profile' '')
  _CFG[vector_config]=$(cfg '.features.redpoint_ai.vector_config' '')
  _CFG[embeddings_model]=$(cfg '.features.redpoint_ai.embeddings_model' '')
  _CFG[model_dims]=$(cfg '.features.redpoint_ai.model_dimensions' '')
  _CFG[container_name]=$(cfg '.features.redpoint_ai.container_name' '')
  _CFG[blob_folder]=$(cfg '.features.redpoint_ai.blob_folder' '')
  _CFG[nlp_api_key]=$(cfg '.features.redpoint_ai.nlp_api_key' '')
  _CFG[nlp_search_key]=$(cfg '.features.redpoint_ai.search_key' '')
  _CFG[nlp_model_connstr]=$(cfg '.features.redpoint_ai.blob_connection_string' '')

  # --- Feature: Queue Reader ---
  _CFG[tenant_id_qr]=$(cfg '.features.queue_reader.tenant_id' '')
  _CFG[distributed]=$(cfg '.features.queue_reader.distributed' '')

  # --- Feature: Data Warehouse (from top-level data_warehouse section) ---
  _CFG[provider]="$_dw_provider"
  _CFG[conn_name]=$(cfg '.data_warehouse.redshift.connection_name' 'rsh-tenant1')
  _CFG[rs_server]=$(cfg '.data_warehouse.redshift.host' '')
  _CFG[rs_database]=$(cfg '.data_warehouse.redshift.database' '')
  _CFG[rs_username]=$(cfg '.data_warehouse.redshift.username' '')
  _CFG[rs_password]=$(cfg '.data_warehouse.redshift.password' '')
  _CFG[sf_configmap]=$(cfg '.data_warehouse.snowflake.configmap_name' '')
  _CFG[sf_keyname]=$(cfg '.data_warehouse.snowflake.key_name' '')
  _CFG[bq_name]=$(cfg '.data_warehouse.bigquery.connection_name' '')
  _CFG[bq_configmap]=$(cfg '.data_warehouse.bigquery.configmap_name' '')
  _CFG[bq_sa_email]=$(cfg '.data_warehouse.bigquery.service_account_email' '')
  _CFG[bq_project]=$(cfg '.data_warehouse.bigquery.project_id' '')

  # --- Feature: Autoscaling ---
  _CFG[svc]=$(cfg '.features.autoscaling.service' '')
  _CFG[type]=$(cfg '.features.autoscaling.type' '')
  _CFG[min_r]=$(cfg '.features.autoscaling.min_replicas' '')
  _CFG[max_r]=$(cfg '.features.autoscaling.max_replicas' '')
  _CFG[cpu_pct]=$(cfg '.features.autoscaling.target_cpu' '')

  # --- Feature: Database Upgrade ---
  _CFG[notify]=$(cfg '.features.database_upgrade.notification' '')
  _CFG[email]=$(cfg '.features.database_upgrade.notification_email' '')

  # --- Feature: Storage ---
  _CFG[storage_type]=$(cfg '.features.storage.type' '')
  _CFG[claim]=$(cfg '.features.storage.pvc_claim_name' '')
  _CFG[mount_path]=$(cfg '.features.storage.mount_path' '')

  # Helper: check if a feature is enabled in the input file
  _feature_enabled() {
    local val
    val=$(yq eval ".features.$1" "$INPUT_FILE" 2>/dev/null)
    case "$val" in
      true) return 0 ;;
      false|null|"") return 1 ;;
      *) return 0 ;;   # it's a map/object, so feature is enabled
    esac
  }

  # Override prompt functions — read from _CFG silently
  prompt() {
    local var_name=$1 prompt_text=$2 default=$3
    local value="${_CFG[$var_name]:-}"
    eval "$var_name=\"\${value:-\$default}\""
  }

  prompt_choice() {
    local var_name=$1 prompt_text=$2 options=$3 default=$4
    local value="${_CFG[$var_name]:-}"
    eval "$var_name=\"\${value:-\$default}\""
  }

  prompt_yesno() {
    local var_name=$1 prompt_text=$2 default=$3
    local value="${_CFG[$var_name]:-}"
    if [ -n "$value" ]; then
      case "$value" in
        true|y|Y|yes) eval "$var_name=true" ;;
        *) eval "$var_name=false" ;;
      esac
    else
      case "$default" in
        y|Y) eval "$var_name=true" ;;
        *) eval "$var_name=false" ;;
      esac
    fi
  }

  prompt_secret() {
    local var_name=$1 prompt_text=$2
    local value="${_CFG[$var_name]:-}"
    eval "$var_name=\"\$value\""
  }

  # Quieter section headers in file mode
  _orig_section=$(declare -f section)
  section() { echo "  ${CYAN}▸${RESET} $1"; }
fi

# ============================================================
# --add mode: append a feature block to an existing overrides
# ============================================================

has_block() {
  local file=$1 key=$2
  grep -qE "^[[:space:]]*${key}:" "$file" 2>/dev/null
}

append_block() {
  local file=$1 block=$2 heading=$3
  echo "" >> "$file"
  if [ -n "$heading" ]; then
    echo "# ----------------------------------------------------------" >> "$file"
    echo "#  ${heading}" >> "$file"
    echo "# ----------------------------------------------------------" >> "$file"
  fi
  echo "$block" >> "$file"
}

add_database_upgrade() {
  local file=$1
  if has_block "$file" "databaseUpgrade"; then
    echo "  ${ICON_WARN} ${YELLOW}databaseUpgrade already exists in ${file}${RESET}"; return 0
  fi
  local notify email
  prompt_yesno notify "Send email notifications on upgrade?" "n"
  if [ "$notify" = "true" ]; then
    prompt email "Notification email address" ""
    append_block "$file" "$(cat <<BLOCK
databaseUpgrade:
  enabled: true
  notification:
    enabled: true
    recipientEmail: ${email}
BLOCK
)" "Database Upgrade"
  else
    append_block "$file" "$(cat <<'BLOCK'
databaseUpgrade:
  enabled: true
BLOCK
)" "Database Upgrade"
  fi
  echo "  ${ICON_CHECK} Added databaseUpgrade to ${file}"
}

add_queue_reader() {
  local file=$1
  if has_block "$file" "queuereader"; then
    echo "  ${ICON_WARN} ${YELLOW}queuereader already exists in ${file}${RESET}"; return 0
  fi
  local tenant_id distributed
  prompt tenant_id "RPI Client (Tenant) ID" ""
  prompt_yesno distributed "Enable distributed mode?" "n"
  if [ "$distributed" = "true" ]; then
    local cache_type queue_type
    prompt_choice cache_type "Internal cache Redis type" "internal|external" "internal"
    prompt_choice queue_type "Internal queue RabbitMQ type" "internal|external" "internal"
    local cache_block="" queue_block=""
    if [ "$cache_type" = "external" ]; then
      local redis_conn
      prompt redis_conn "External Redis connection string" "my-redis-host:6379,password=<password>,abortConnect=False"
      cache_block="      redisSettings:
        connectionString: \"${redis_conn}\""
    fi
    if [ "$queue_type" = "external" ]; then
      local rmq_host rmq_user
      prompt rmq_host "External RabbitMQ hostname" ""
      prompt rmq_user "RabbitMQ username" "rabbitmq"
      queue_block="      rabbitmqSettings:
        hostname: \"${rmq_host}\"
        username: ${rmq_user}"
    fi
    append_block "$file" "$(cat <<BLOCK
queuereader:
  enabled: true
  realtimeConfiguration:
    isDistributed: true
    internalCache:
      provider: redis
      type: ${cache_type}
${cache_block}
    distributedQueue:
      provider: rabbitmq
      type: ${queue_type}
${queue_block}
    tenantIds:
      - "${tenant_id}"
  errorQueuePath: listenerQueueError
  nonActiveQueuePath: listenerQueueNonActive
BLOCK
)" "Queue Reader"
    echo ""
    echo "  ${ICON_CHECK} Added queuereader (distributed) to ${file}"
    if [ "$cache_type" = "internal" ]; then
      local qs_redis_pass
      qs_redis_pass=$(gen_password)
      append_secret "QueueService_RedisCache_Password" "$qs_redis_pass"
      append_secret "QueueService_internalCache_ConnectionString" "rpi-queuereader-cache:6379,password=${qs_redis_pass},abortConnect=False"
      echo "  ${ICON_CHECK} Added QueueService Redis secrets to ${SECRETS_FILE}"
    fi
    if [ "$queue_type" = "internal" ]; then
      local qs_rmq_pass
      qs_rmq_pass=$(gen_password)
      append_secret "QueueService_RabbitMQ_Password" "$qs_rmq_pass"
      echo "  ${ICON_CHECK} Added QueueService RabbitMQ password to ${SECRETS_FILE}"
    fi
  else
    append_block "$file" "$(cat <<BLOCK
queuereader:
  enabled: true
  realtimeConfiguration:
    isDistributed: false
    tenantIds:
      - "${tenant_id}"
  errorQueuePath: listenerQueueError
  nonActiveQueuePath: listenerQueueNonActive
BLOCK
)" "Queue Reader"
    echo "  ${ICON_CHECK} Added queuereader to ${file}"
  fi
}

add_autoscaling() {
  local file=$1
  local svc
  prompt_choice svc "Service to autoscale" "realtimeapi|executionservice|interactionapi|integrationapi" "realtimeapi"
  if grep -qE "^${svc}:" "$file" 2>/dev/null && grep -qA5 "^${svc}:" "$file" | grep -q "autoscaling:"; then
    echo "  ${ICON_WARN} ${YELLOW}autoscaling for ${svc} already exists in ${file}${RESET}"; return 0
  fi
  local type min_r max_r
  prompt_choice type "Autoscaling type" "hpa|keda" "hpa"
  prompt min_r "Min replicas" "1"
  prompt max_r "Max replicas" "5"
  if [ "$type" = "hpa" ]; then
    local cpu_pct
    prompt cpu_pct "Target CPU utilization %" "80"
    append_block "$file" "$(cat <<BLOCK
${svc}:
  autoscaling:
    enabled: true
    type: hpa
    minReplicas: ${min_r}
    maxReplicas: ${max_r}
    targetCPUUtilizationPercentage: ${cpu_pct}
BLOCK
)" "Autoscaling"
  else
    local prom_addr threshold
    prompt prom_addr "Prometheus server address" "http://prometheus-server.monitoring.svc.cluster.local"
    prompt threshold "KEDA threshold" "5"
    append_block "$file" "$(cat <<BLOCK
${svc}:
  autoscaling:
    enabled: true
    type: keda
    minReplicas: ${min_r}
    maxReplicas: ${max_r}
    keda:
      serverAddress: ${prom_addr}
      threshold: "${threshold}"
BLOCK
)" "Autoscaling"
  fi
  echo "  ${ICON_CHECK} Added autoscaling (${type}) for ${svc} to ${file}"
}

add_custom_metrics() {
  local file=$1
  if has_block "$file" "customMetrics"; then
    echo "  ${ICON_WARN} ${YELLOW}customMetrics already exists in ${file}${RESET}"; return 0
  fi
  append_block "$file" "$(cat <<'BLOCK'
customMetrics:
  enabled: true
BLOCK
)" "Custom Metrics"
  echo "  ${ICON_CHECK} Added customMetrics to ${file}"
}

add_service_mesh() {
  local file=$1
  if has_block "$file" "serviceMesh"; then
    echo "  ${ICON_WARN} ${YELLOW}serviceMesh already exists in ${file}${RESET}"; return 0
  fi
  append_block "$file" "$(cat <<'BLOCK'
serviceMesh:
  enabled: true
  provider: linkerd
BLOCK
)" "Service Mesh"
  echo "  ${ICON_CHECK} Added serviceMesh to ${file}"
}

add_smoke_tests() {
  local file=$1
  if has_block "$file" "smokeTests"; then
    echo "  ${ICON_WARN} ${YELLOW}smokeTests already exists in ${file}${RESET}"; return 0
  fi
  local deployments=""
  local more="true"
  while [ "$more" = "true" ]; do
    local test_name test_type
    prompt test_name "Smoke test name" "storage-check"
    prompt_choice test_type "Type" "pvc|csiSecret" "pvc"
    if [ "$test_type" = "pvc" ]; then
      local pvc_name mount_path
      prompt pvc_name "PVC claim name" "rpifileoutputdir"
      prompt mount_path "Mount path" "/mnt/rpifileoutputdir"
      deployments="${deployments}
    - name: ${test_name}
      type: pvc
      claimName: ${pvc_name}
      mountPath: ${mount_path}"
    else
      local spc mount_path
      prompt spc "SecretProviderClass name" "rpi-secret-provider"
      prompt mount_path "Mount path" "/mnt/secrets"
      deployments="${deployments}
    - name: ${test_name}
      type: csiSecret
      secretProviderClass: ${spc}
      mountPath: ${mount_path}"
    fi
    prompt_yesno more "Add another smoke test?" "n"
  done
  append_block "$file" "$(cat <<BLOCK
smokeTests:
  enabled: true
  deployments:${deployments}
BLOCK
)" "Smoke Tests"
  echo "  ${ICON_CHECK} Added smokeTests to ${file}"
}

add_entra_id() {
  local file=$1
  if has_block "$file" "MicrosoftEntraID"; then
    echo "  ${ICON_WARN} ${YELLOW}MicrosoftEntraID already exists in ${file}${RESET}"; return 0
  fi
  local client_id api_id tenant_id
  prompt client_id "Interaction Client App ID" ""
  prompt api_id "Interaction API App ID" ""
  prompt tenant_id "Azure AD Tenant ID" ""
  append_block "$file" "$(cat <<BLOCK
MicrosoftEntraID:
  enabled: true
  interaction_client_id: ${client_id}
  interaction_api_id: ${api_id}
  tenant_id: ${tenant_id}
BLOCK
)" "Microsoft Entra ID"
  echo "  ${ICON_CHECK} Added MicrosoftEntraID to ${file}"
}

add_oidc() {
  local file=$1
  if has_block "$file" "OpenIdProviders"; then
    echo "  ${ICON_WARN} ${YELLOW}OpenIdProviders already exists in ${file}${RESET}"; return 0
  fi
  local provider_name auth_host client_id audience redirect_url
  local enable_refresh validate_issuer validate_audience logout_param supports_user_mgmt
  prompt_choice provider_name "OIDC provider" "Keycloak|Okta" "Keycloak"
  prompt auth_host "Authorization host URL" ""
  prompt client_id "Client ID" ""
  prompt audience "Audience" ""
  prompt redirect_url "Redirect URL (RPI client URL)" ""
  prompt_yesno enable_refresh "Enable refresh tokens?" "y"
  prompt_yesno validate_issuer "Validate issuer?" "n"
  prompt_yesno validate_audience "Validate audience?" "y"
  prompt logout_param "Logout ID token parameter" "id_token_hint"
  prompt_yesno supports_user_mgmt "Supports user management?" "n"
  local scopes_block=""
  local add_scope
  prompt_yesno add_scope "Add custom scopes?" "n"
  if [ "$add_scope" = "true" ]; then
    scopes_block=$'\n  customScopes:'
    local scope more="true"
    while [ "$more" = "true" ]; do
      prompt scope "Custom scope URI" ""
      scopes_block="${scopes_block}"$'\n'"    - ${scope}"
      prompt_yesno more "Add another scope?" "n"
    done
  fi
  append_block "$file" "$(cat <<BLOCK
OpenIdProviders:
  enabled: true
  name: ${provider_name}
  authorizationHost: ${auth_host}
  clientID: ${client_id}
  audience: ${audience}
  redirectURL: ${redirect_url}
  enableRefreshTokens: ${enable_refresh}
  validateIssuer: ${validate_issuer}
  validateAudience: ${validate_audience}
  logoutIdTokenParameter: ${logout_param}
  supportsUserManagement: ${supports_user_mgmt}${scopes_block}
BLOCK
)" "OpenID Connect (OIDC)"
  echo "  ${ICON_CHECK} Added OpenIdProviders to ${file}"
}

add_smtp() {
  local file=$1
  if has_block "$file" "SMTPSettings"; then
    echo "  ${ICON_WARN} ${YELLOW}SMTPSettings already exists in ${file}${RESET}"; return 0
  fi
  local server port from_addr sender_name enable_ssl use_creds username
  prompt server "SMTP server hostname" "smtp.example.com"
  prompt port "SMTP port" "587"
  prompt from_addr "Sender email address" "noreply@example.com"
  prompt sender_name "Sender display name" "Redpoint Global"
  prompt_yesno enable_ssl "Enable SSL/TLS?" "y"
  prompt_yesno use_creds "Use SMTP credentials?" "y"
  local creds_block=""
  if [ "$use_creds" = "true" ]; then
    prompt username "SMTP username" ""
    creds_block="
  SMTP_Username: ${username}"
  fi
  local smtp_password=""
  if [ "$use_creds" = "true" ]; then
    prompt_secret smtp_password "SMTP password"
  fi
  append_block "$file" "$(cat <<BLOCK
SMTPSettings:
  SMTP_Address: ${server}
  SMTP_Port: ${port}
  SMTP_SenderAddress: ${from_addr}
  SMTP_SenderName: "${sender_name}"
  EnableSSL: ${enable_ssl}
  UseCredentials: ${use_creds}${creds_block}
BLOCK
)" "SMTP Email Configuration"
  echo "  ${ICON_CHECK} Added SMTPSettings to ${file}"
  if [ "$use_creds" = "true" ] && [ -n "$smtp_password" ]; then
    append_secret "SMTP_Password" "$smtp_password"
    echo "  ${ICON_CHECK} Added SMTP_Password to ${SECRETS_FILE}"
  fi
}

add_redpoint_ai() {
  local file=$1
  if has_block "$file" "redpointAI"; then
    echo "  ${ICON_WARN} ${YELLOW}redpointAI already exists in ${file}${RESET}"; return 0
  fi
  echo ""
  echo "  ${BOLD}Natural Language (OpenAI)${RESET}"
  local api_base api_version engine temp
  prompt api_base "OpenAI API base URL" "https://example.openai.azure.com/"
  prompt api_version "API version" "2023-07-01-preview"
  prompt engine "ChatGPT engine/model" "gpt-5.1"
  prompt temp "ChatGPT temperature (0.0–1.0)" "0.5"
  echo ""
  echo "  ${BOLD}Azure Cognitive Search${RESET}"
  local search_endpoint vector_profile vector_config
  prompt search_endpoint "Search endpoint URL" "https://example.search.windows.net"
  prompt vector_profile "Vector search profile" "vector-profile-000000000000"
  prompt vector_config "Vector search config" "vector-config-000000000000"
  echo ""
  echo "  ${BOLD}Model Storage${RESET}"
  local embeddings_model model_dims container_name blob_folder
  prompt embeddings_model "Embeddings model" "text-embedding-ada-002"
  prompt model_dims "Model dimensions" "1536"
  prompt container_name "Blob container name" ""
  prompt blob_folder "Blob folder name" ""
  echo ""
  echo "  ${BOLD}Secrets${RESET}"
  local nlp_api_key nlp_search_key nlp_model_connstr
  prompt_secret nlp_api_key "OpenAI API key"
  prompt_secret nlp_search_key "Cognitive Search key"
  prompt_secret nlp_model_connstr "Blob storage connection string"

  append_block "$file" "$(cat <<BLOCK
redpointAI:
  enabled: true
  naturalLanguage:
    ApiBase: ${api_base}
    ApiVersion: ${api_version}
    ChatGptEngine: ${engine}
    ChatGptTemp: ${temp}
  cognitiveSearch:
    SearchEndpoint: ${search_endpoint}
    VectorSearchProfile: ${vector_profile}
    VectorSearchConfig: ${vector_config}
  modelStorage:
    EmbeddingsModel: ${embeddings_model}
    ModelDimensions: ${model_dims}
    ContainerName: ${container_name}
    BlobFolder: ${blob_folder}
BLOCK
)" "Redpoint AI"
  echo ""
  echo "  ${ICON_CHECK} Added redpointAI to ${file}"

  if [ -n "$nlp_api_key" ]; then
    append_secret "RPI_NLP_API_KEY" "$nlp_api_key"
  fi
  if [ -n "$nlp_search_key" ]; then
    append_secret "RPI_NLP_SEARCH_KEY" "$nlp_search_key"
  fi
  if [ -n "$nlp_model_connstr" ]; then
    append_secret "RPI_NLP_MODEL_CONNECTION_STRING" "$nlp_model_connstr"
  fi
  echo "  ${ICON_CHECK} Added AI secrets to ${SECRETS_FILE}"
}

add_storage() {
  local file=$1

  local storage_type
  prompt_choice storage_type "Storage type" "pvc|csi" "pvc"

  if [ "$storage_type" = "pvc" ]; then
    if has_block "$file" "persistentVolumeClaims"; then
      echo "  ${ICON_WARN} ${YELLOW}persistentVolumeClaims already exists in ${file}${RESET}"; return 0
    fi
    local claim mount_path
    prompt claim "PVC claim name" "rpifileoutputdir"
    prompt mount_path "Mount path" "/rpifileoutputdir"
    if has_block "$file" "storage"; then
      # Append under existing storage: block
      sed -i "/^storage:/a\\
  persistentVolumeClaims:\\
    FileOutputDirectory:\\
      enabled: true\\
      claimName: ${claim}\\
      mountPath: ${mount_path}" "$file"
    else
      append_block "$file" "$(cat <<BLOCK
storage:
  persistentVolumeClaims:
    FileOutputDirectory:
      enabled: true
      claimName: ${claim}
      mountPath: ${mount_path}
BLOCK
)" "Storage Configuration"
    fi
    echo "  ${ICON_CHECK} Added PVC storage to ${file}"

  else
    # Detect platform from overrides file, or prompt
    local csi_platform
    csi_platform=$(grep -A2 'platform:' "$file" 2>/dev/null | grep 'platform:' | head -1 | sed 's/.*platform: *//' | tr -d ' "'"'"'')
    if [ -z "$csi_platform" ] || ! echo "azure|amazon|google" | tr '|' '\n' | grep -qx "$csi_platform"; then
      prompt_choice csi_platform "Cloud platform" "azure|amazon|google" "azure"
    else
      echo "  ${DIM}Detected platform: ${csi_platform}${RESET}"
    fi

    local pv_name storage_account container_name client_id resource_group volume_handle claim_name
    # pv_entry holds just the "- name: ..." list item (no persistentVolumes: header)
    local pv_entry pv_comment

    case "$csi_platform" in
      azure)
        local azure_type
        prompt_choice azure_type "Azure storage type" "blob|fileshare" "blob"
        prompt pv_name "PV name" "rpifileoutputdir"
        prompt storage_account "Storage account name" ""
        prompt claim_name "PVC claim name" "pvc-${azure_type}"

        if [ "$azure_type" = "blob" ]; then
          prompt container_name "Blob container name" ""
          prompt client_id "Managed Identity Client ID (for auth)" ""
          prompt resource_group "Resource group" ""
          prompt volume_handle "Volume handle (unique in cluster)" "${resource_group}-${storage_account}-${container_name}"
          pv_comment="# Azure Blob Storage"
          pv_entry="    - name: ${pv_name}
      capacity: 10Gi
      accessModes:
        - ReadWriteMany
      storageClassName: blob-fuse
      reclaimPolicy: Retain
      mountOptions:
        - -o allow_other
        - --file-cache-timeout-in-seconds=120
      csi:
        driver: blob.csi.azure.com
        volumeHandle: ${volume_handle}
        volumeAttributes:
          storageAccount: ${storage_account}
          containerName: ${container_name}
          clientID: ${client_id}
          resourcegroup: ${resource_group}
          # subscriptionid: <only if storage account is in a different subscription>
      pvc:
        claimName: ${claim_name}
      annotations:
        pv.kubernetes.io/provisioned-by: blob.csi.azure.com
        helm.sh/resource-policy: keep"
        else
          local share_name
          prompt share_name "File share name" ""
          prompt client_id "Managed Identity Client ID (for auth)" ""
          prompt resource_group "Resource group" ""
          prompt volume_handle "Volume handle (unique in cluster)" "${resource_group}#${storage_account}#${share_name}"
          pv_comment="# Azure File Share"
          pv_entry="    - name: ${pv_name}
      capacity: 10Gi
      accessModes:
        - ReadWriteMany
      storageClassName: azurefile-csi
      reclaimPolicy: Retain
      mountOptions:
        - -o allow_other
        - --file-cache-timeout-in-seconds=120
      csi:
        driver: file.csi.azure.com
        volumeHandle: \"${volume_handle}\"
        volumeAttributes:
          storageaccount: ${storage_account}
          shareName: ${share_name}
          clientID: ${client_id}
          resourcegroup: ${resource_group}
          # subscriptionid: <only if storage account is in a different subscription>
      pvc:
        claimName: ${claim_name}"
        fi
        ;;

      amazon)
        local efs_id
        prompt pv_name "PV name" "rpifileoutputdir"
        prompt efs_id "EFS filesystem ID" ""
        prompt claim_name "PVC claim name" "pvc-efs"
        pv_comment="# AWS EFS"
        pv_entry="    - name: ${pv_name}
      capacity: 10Gi
      accessModes:
        - ReadWriteMany
      storageClassName: efs-sc
      reclaimPolicy: Retain
      csi:
        driver: efs.csi.aws.com
        volumeHandle: ${efs_id}
      pvc:
        claimName: ${claim_name}"
        ;;

      google)
        local filestore_ip share_name
        prompt pv_name "PV name" "rpifileoutputdir"
        prompt filestore_ip "Filestore instance IP" ""
        prompt share_name "File share name" "rpi_data"
        prompt claim_name "PVC claim name" "pvc-filestore"
        pv_comment="# GCP Filestore"
        pv_entry="    - name: ${pv_name}
      capacity: 10Gi
      accessModes:
        - ReadWriteMany
      storageClassName: filestore-sc
      reclaimPolicy: Retain
      csi:
        driver: filestore.csi.storage.gke.io
        volumeHandle: \"modeInstance/${filestore_ip}/${share_name}\"
        volumeAttributes:
          ip: ${filestore_ip}
          volume: ${share_name}
      pvc:
        claimName: ${claim_name}"
        ;;
    esac

    if has_block "$file" "persistentVolumes"; then
      # Append new entry to existing persistentVolumes list
      python3 -c "
import sys
lines = open(sys.argv[1]).readlines()
comment = sys.argv[2]
entry = sys.argv[3]
# Find last '    - name:' line under persistentVolumes to locate end of list
last_entry_end = -1
in_pv = False
for i, l in enumerate(lines):
    if 'persistentVolumes:' in l and not l.strip().startswith('#'):
        in_pv = True
    elif in_pv:
        stripped = l.rstrip()
        # A top-level key or a new sibling key at 2-space indent ends the block
        if stripped and not stripped.startswith('#') and not stripped.startswith(' '):
            break
        if stripped and not stripped.startswith('#') and len(stripped) - len(stripped.lstrip()) <= 2 and ':' in stripped:
            break
        last_entry_end = i
# Insert after the last line of the existing list
insert_at = last_entry_end + 1
new_lines = '    ' + comment + '\n' + entry + '\n'
lines.insert(insert_at, new_lines)
open(sys.argv[1], 'w').writelines(lines)
" "$file" "$pv_comment" "$pv_entry"
    elif has_block "$file" "storage"; then
      # storage: exists but no persistentVolumes yet — append the section
      python3 -c "
import sys
lines = open(sys.argv[1]).readlines()
comment = sys.argv[2]
entry = sys.argv[3]
idx = next(i for i, l in enumerate(lines) if l.startswith('storage:'))
end = len(lines)
for j in range(idx + 1, len(lines)):
    if lines[j][0:1] not in (' ', '#', ''):
        end = j
        break
insert = '  persistentVolumes:\n    ' + comment + '\n' + entry + '\n'
lines.insert(end, insert)
open(sys.argv[1], 'w').writelines(lines)
" "$file" "$pv_comment" "$pv_entry"
    else
      # No storage: block at all — create from scratch
      append_block "$file" "$(printf 'storage:\n  persistentVolumes:\n    %s\n%s' "$pv_comment" "$pv_entry")" "Storage Configuration"
    fi
    echo "  ${ICON_CHECK} Added CSI storage (PV + PVC) to ${file}"
  fi
}

add_helm_copilot() {
  local file=$1
  if has_block "$file" "helmcopilot"; then
    echo "  ${ICON_WARN} ${YELLOW}helmcopilot already exists in ${file}${RESET}"; return 0
  fi
  append_block "$file" "$(cat <<'BLOCK'
helmcopilot:
  enabled: true
BLOCK
)" "Interaction Copilot (MCP Server)"
  echo "  ${ICON_CHECK} Added Interaction Copilot to ${file}"
  echo "  ${DIM}  AI-powered assistant for configuring and troubleshooting RPI.${RESET}"
  echo "  ${DIM}  Connect via: claude mcp add rpi-helm --transport http https://<helmcopilot-host>/mcp${RESET}"
}

add_data_warehouse() {
  local file=$1
  if grep -q "datawarehouse:" "$file" 2>/dev/null; then
    echo "  ${ICON_WARN} ${YELLOW}datawarehouse already exists in ${file}${RESET}"; return 0
  fi
  echo ""
  echo "  ${DIM}Connect RPI to an external data warehouse for audience output and analytics.${RESET}"
  echo ""
  local provider
  prompt_choice provider "Data warehouse provider" "snowflake|redshift|bigquery" "snowflake"

  case "$provider" in
    redshift)
      echo ""
      echo "  ${BOLD}Amazon Redshift${RESET}"
      local conn_name rs_server rs_database rs_username rs_password
      prompt conn_name "Connection name" "rsh-tenant1"
      prompt rs_server "Redshift cluster endpoint" ""
      prompt rs_database "Database name" ""
      prompt rs_username "Username" ""
      prompt_secret rs_password "Password"
      append_block "$file" "$(cat <<BLOCK
databases:
  datawarehouse:
    redshift:
      enabled: true
      connections:
        - name: ${conn_name}
          server: ${rs_server}
          port: 5439
          database: ${rs_database}
          username: ${rs_username}
          password: ${rs_password}
BLOCK
)" "Data Warehouse — Amazon Redshift"
      echo "  ${ICON_CHECK} Added Redshift data warehouse to ${file}"
      ;;

    snowflake)
      echo ""
      echo "  ${BOLD}Snowflake${RESET}"
      echo "  ${DIM}Uses JWT authentication. Create a ConfigMap with your RSA private key before deploying.${RESET}"
      local sf_configmap sf_keyname
      prompt sf_configmap "ConfigMap name (containing RSA key)" "snowflake-creds"
      prompt sf_keyname "Key file name in ConfigMap" "my-snowflake-rsakey.p8"
      append_block "$file" "$(cat <<BLOCK
databases:
  datawarehouse:
    snowflake:
      enabled: true
      credentialsType: snowflake_jwt
      ConfigMapName: ${sf_configmap}
      keyName: ${sf_keyname}
      ConfigMapFilePath: /app/snowflake-creds
BLOCK
)" "Data Warehouse — Snowflake"
      echo "  ${ICON_CHECK} Added Snowflake data warehouse to ${file}"
      echo "  ${DIM}  Ensure ConfigMap '${sf_configmap}' exists with key '${sf_keyname}' before deploying.${RESET}"
      ;;

    bigquery)
      echo ""
      echo "  ${BOLD}Google BigQuery${RESET}"
      echo "  ${DIM}Uses service account authentication. Create a ConfigMap with your service account JSON key.${RESET}"
      local bq_configmap bq_sa_email bq_name bq_project
      prompt bq_name "Connection name (also used as DSN)" "gbq-tenant1"
      prompt bq_configmap "ConfigMap name (containing SA key JSON)" "gbq-tenant1"
      prompt bq_sa_email "Service account email" ""
      prompt bq_project "Google Cloud project ID" ""
      append_block "$file" "$(cat <<BLOCK
databases:
  datawarehouse:
    bigquery:
      enabled: true
      connections:
        - name: ${bq_name}
          projectId: ${bq_project}
          sqlDialect: 1
          OAuthMechanism: 0
          credentialsType: serviceAccount
          serviceAccountEmail: ${bq_sa_email}
          configMapName: ${bq_configmap}
          keyName: ${bq_name}.json
          ConfigMapFilePath: /app/google-creds
          allowLargeResults: 0
          largeResultsDataSetId: _bqodbc_temp_tables
          largeResultsTempTableExpirationTime: "3600000"
BLOCK
)" "Data Warehouse — Google BigQuery"
      echo "  ${ICON_CHECK} Added BigQuery data warehouse to ${file}"
      echo "  ${DIM}  Ensure ConfigMap '${bq_configmap}' exists with key '${bq_name}.json' before deploying.${RESET}"
      ;;
  esac
}

add_extra_envs() {
  local file=$1
  if has_block "$file" "extraEnvs"; then
    echo "  ${ICON_WARN} ${YELLOW}extraEnvs already exists in ${file}${RESET}"; return 0
  fi
  echo ""
  echo "  ${DIM}Extra environment variables are injected into the execution service container.${RESET}"
  echo "  ${DIM}Each variable has an enabled flag — set to true to activate.${RESET}"
  echo ""

  local envs=""
  local any_enabled=false

  # LuxSci sandbox
  local yn; prompt_yesno yn "Enable LuxSci sandbox mode?" "n"
  envs="${envs}\n    - name: Plugins__LuxSci__IsSandboxMode\n      enabled: ${yn}\n      value: \"true\""
  [ "$yn" = "true" ] && any_enabled=true

  # SendGrid sandbox
  prompt_yesno yn "Enable SendGrid sandbox mode?" "n"
  envs="${envs}\n    - name: Plugins__SendGrid__EnableSandBoxMode\n      enabled: ${yn}\n      value: \"true\""
  [ "$yn" = "true" ] && any_enabled=true

  # Twilio disable SMS
  prompt_yesno yn "Disable Twilio SMS campaigns?" "n"
  envs="${envs}\n    - name: Plugins__Twilio__DisableSendSMSCampaign\n      enabled: ${yn}\n      value: \"true\""
  [ "$yn" = "true" ] && any_enabled=true

  # Locale
  prompt_yesno yn "Set UTF-8 locale (LC_ALL, LANG, LANGUAGE)?" "n"
  envs="${envs}\n    - name: LC_ALL\n      enabled: ${yn}\n      value: \"en_US.UTF-8\""
  envs="${envs}\n    - name: LANG\n      enabled: ${yn}\n      value: \"en_US.UTF-8\""
  envs="${envs}\n    - name: LANGUAGE\n      enabled: ${yn}\n      value: \"en_US.UTF-8\""
  [ "$yn" = "true" ] && any_enabled=true

  # mPulse debug variables
  prompt_yesno yn "Enable mPulse debug variables?" "n"
  envs="${envs}\n    - name: RPI_MPULSE_UPSERT_CONTACT_DEBUG\n      enabled: ${yn}\n      value: \"1\""
  envs="${envs}\n    - name: RPI_MPULSE_EVENT_UPLOAD_DEBUG\n      enabled: ${yn}\n      value: \"1\""
  envs="${envs}\n    - name: RPI_MPULSE_EVENT_UPLOAD_FAIL_DEBUG\n      enabled: ${yn}\n      value: \"0\""
  envs="${envs}\n    - name: RPI_MPULSE_EVENT_UPLOAD_SCENARIO\n      enabled: ${yn}\n      value: \"1,5,2,3,5,7\""
  envs="${envs}\n    - name: RPI_MPULSE_SAVE_MPULSE_EVENT_CONTENT_DEBUG\n      enabled: ${yn}\n      value: \"1\""
  envs="${envs}\n    - name: RPI_MPULSE_UPSERT_CONTACT_IMPORT_PATH_DEBUG\n      enabled: ${yn}\n      value: \"/rpifileoutputdir/mpulse-debug-path\""
  [ "$yn" = "true" ] && any_enabled=true

  append_block "$file" "$(echo -e "advanced:\n  executionservice:\n    extraEnvs:${envs}")" "Extra Environment Variables"
  echo "  ${ICON_CHECK} Added extraEnvs to ${file}"
  if [ "$any_enabled" = "true" ]; then
    echo "  ${DIM}  Variables set to enabled: true will be injected at deploy time.${RESET}"
  else
    echo "  ${DIM}  All variables are disabled. Edit the overrides to enable as needed.${RESET}"
  fi
}

add_advanced() {
  local file=$1
  if has_block "$file" "advanced"; then
    echo "  ${ICON_WARN} ${YELLOW}advanced already exists in ${file}${RESET}"; return 0
  fi
  append_block "$file" "$(cat <<'BLOCK'
advanced:
  # Override any internal default here. See docs/values-reference.yaml for all keys.
  # Example:
  # interactionapi:
  #   resources:
  #     requests:
  #       cpu: 500m
  #       memory: 1Gi
  #   livenessProbe:
  #     periodSeconds: 30
BLOCK
)" "Advanced Overrides"
  echo "  ${ICON_CHECK} Added advanced block to ${file}"
  echo "  ${DIM}  See docs/values-reference.yaml for all available keys.${RESET}"
}

show_feature_menu() {
  echo ""
  echo "  ${BOLD}Available features:${RESET}"
  echo ""
  echo "    ${CYAN}1${RESET})  database_upgrade  — Run schema migrations automatically after upgrades"
  echo "    ${CYAN}2${RESET})  queue_reader      — Process realtime queue events (forms, listeners, callbacks)"
  echo "    ${CYAN}3${RESET})  autoscaling       — Scale services based on CPU/memory with HPA or KEDA"
  echo "    ${CYAN}4${RESET})  custom_metrics    — Expose Prometheus /metrics endpoints for monitoring"
  echo "    ${CYAN}5${RESET})  service_mesh      — Enable Linkerd mTLS and traffic policies"
  echo "    ${CYAN}6${RESET})  smoke_tests       — Validate PVC mounts and CSI drivers post-deploy"
  echo "    ${CYAN}7${RESET})  entra_id          — Single sign-on via Microsoft Entra ID (Azure AD)"
  echo "    ${CYAN}8${RESET})  oidc              — Single sign-on via OpenID Connect (Keycloak, Okta, etc.)"
  echo "    ${CYAN}9${RESET})  smtp              — Send transactional emails from RPI workflows"
  echo "    ${CYAN}10${RESET}) redpoint_ai       — AI-powered content generation (OpenAI + Cognitive Search)"
  echo "    ${CYAN}11${RESET}) storage           — Persistent volumes for file-based processing and caching"
  echo "    ${CYAN}12${RESET}) helm_copilot      — AI assistant for chart configuration and troubleshooting"
  echo "    ${CYAN}13${RESET}) data_warehouse    — Connect to Snowflake, Redshift, or BigQuery"
  echo "    ${CYAN}14${RESET}) extra_envs        — Debug and plugin environment variables"
  echo "    ${CYAN}15${RESET}) advanced          — Override internal defaults (probes, security, logging)"
  echo ""
  local choice
  read -rp "  Enter feature number or name: " choice
  case "$choice" in
    1|database_upgrade)  ADD_FEATURE="database_upgrade" ;;
    2|queue_reader)      ADD_FEATURE="queue_reader" ;;
    3|autoscaling)       ADD_FEATURE="autoscaling" ;;
    4|custom_metrics)    ADD_FEATURE="custom_metrics" ;;
    5|service_mesh)      ADD_FEATURE="service_mesh" ;;
    6|smoke_tests)       ADD_FEATURE="smoke_tests" ;;
    7|entra_id)          ADD_FEATURE="entra_id" ;;
    8|oidc)              ADD_FEATURE="oidc" ;;
    9|smtp)              ADD_FEATURE="smtp" ;;
    10|redpoint_ai)      ADD_FEATURE="redpoint_ai" ;;
    11|storage)          ADD_FEATURE="storage" ;;
    12|helm_copilot)     ADD_FEATURE="helm_copilot" ;;
    13|data_warehouse)   ADD_FEATURE="data_warehouse" ;;
    14|extra_envs)       ADD_FEATURE="extra_envs" ;;
    15|advanced)         ADD_FEATURE="advanced" ;;
    *) echo "  ${RED}Unknown feature: ${choice}${RESET}"; exit 1 ;;
  esac
}

run_add_feature() {
  local file=$1 feature=$2
  case "$feature" in
    database_upgrade) add_database_upgrade "$file" ;;
    queue_reader)     add_queue_reader "$file" ;;
    autoscaling)      add_autoscaling "$file" ;;
    custom_metrics)   add_custom_metrics "$file" ;;
    service_mesh)     add_service_mesh "$file" ;;
    smoke_tests)      add_smoke_tests "$file" ;;
    entra_id)         add_entra_id "$file" ;;
    oidc)             add_oidc "$file" ;;
    smtp)             add_smtp "$file" ;;
    redpoint_ai)      add_redpoint_ai "$file" ;;
    storage)          add_storage "$file" ;;
    helm_copilot)     add_helm_copilot "$file" ;;
    data_warehouse)   add_data_warehouse "$file" ;;
    extra_envs)       add_extra_envs "$file" ;;
    advanced)         add_advanced "$file" ;;
    *) echo "  ${RED}Unknown feature: ${feature}${RESET}"; exit 1 ;;
  esac
}

# --- Handle --add mode ---
if [ "$ADD_MODE" = "true" ]; then
  echo ""
  echo "${CYAN}${BOLD}╔══════════════════════════════════════════════╗${RESET}"
  echo "${CYAN}${BOLD}║     ⚡ Redpoint Interaction CLI               ║${RESET}"
  echo "${CYAN}${BOLD}║        Add Feature to Overrides               ║${RESET}"
  echo "${CYAN}${BOLD}╚══════════════════════════════════════════════╝${RESET}"
  echo ""

  if [ ! -f "$OUTPUT_FILE" ]; then
    echo "  ${RED}Error: ${OUTPUT_FILE} not found.${RESET}"
    echo "  Run the CLI without -a first to generate your base overrides."
    exit 1
  fi

  if [ "$ADD_FEATURE" = "menu" ]; then
    show_feature_menu
  fi

  run_add_feature "$OUTPUT_FILE" "$ADD_FEATURE"
  echo ""
  exit 0
fi

# --- Full setup mode ---
echo ""
if [ "$FILE_MODE" = "true" ]; then
  echo "${CYAN}${BOLD}Redpoint Interaction CLI — File Mode${RESET}"
  echo "  Reading from: ${BOLD}${INPUT_FILE}${RESET}"
  echo ""
else
  echo "${CYAN}${BOLD}╔══════════════════════════════════════════════╗${RESET}"
  echo "${CYAN}${BOLD}║     ⚡ Redpoint Interaction CLI               ║${RESET}"
  echo "${CYAN}${BOLD}║        Deployment Generator for RPI           ║${RESET}"
  echo "${CYAN}${BOLD}╚══════════════════════════════════════════════╝${RESET}"
  echo ""
  echo "  This tool generates the files needed to deploy"
  echo "  Redpoint Interaction (RPI) on Kubernetes."
  echo ""
  echo "  ${ICON_FILE} overrides.yaml       — Helm values overrides"
  echo "  ${ICON_KEY} secrets.yaml         — Kubernetes Secret manifest"
  echo "  ${ICON_ROCKET} prereqs.sh           — Prerequisite kubectl commands"
  echo ""
fi

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
  if [ "$FILE_MODE" = "true" ]; then
    DB_PASS="${_CFG[DB_PASS]:-}"
  else
    read -rsp "  Database password: " DB_PASS; echo ""
  fi
  prompt DB_PULSE "Pulse database name" "Pulse"
  prompt DB_LOGGING "Pulse logging database name" "Pulse_Logging"
fi

# ============================================================
# 3b. Data Warehouse (optional, after operational DB)
# ============================================================
DW_ENABLED=false
if [ "$MODE" = "standard" ]; then
  section "Data Warehouse"
  echo "  ${DIM}Connect RPI to an external data warehouse for audience output and analytics.${RESET}"
  prompt_yesno DW_ENABLED "Configure a data warehouse (Snowflake, Redshift, BigQuery)?" "n"
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
RT_CACHE_BIGTABLE_PROJECT=""
RT_CACHE_BIGTABLE_INSTANCE=""
RT_QUEUE_PROVIDER=""
RT_QUEUE_CONNSTR=""
RT_EVENTHUB_NAME=""
RT_EVENTHUB_NAMESPACE=""
RT_PUBSUB_PROJECT=""

if [ "$REALTIME_ENABLED" = "true" ]; then
  echo ""
  echo "  ${DIM}Cache provider stores realtime decision data for low-latency lookups.${RESET}"
  if [ "$PLATFORM" = "azure" ]; then
    prompt_choice RT_CACHE_PROVIDER "Cache provider" "mongodb|azureredis|redis|inMemorySql|googlebigtable" "mongodb"
  elif [ "$PLATFORM" = "amazon" ]; then
    prompt_choice RT_CACHE_PROVIDER "Cache provider" "mongodb|redis|inMemorySql|googlebigtable" "mongodb"
  elif [ "$PLATFORM" = "google" ]; then
    prompt_choice RT_CACHE_PROVIDER "Cache provider" "mongodb|redis|googlebigtable|inMemorySql" "mongodb"
  else
    prompt_choice RT_CACHE_PROVIDER "Cache provider" "mongodb|redis|inMemorySql|googlebigtable" "mongodb"
  fi

  if [ "$RT_CACHE_PROVIDER" = "mongodb" ]; then
    prompt RT_CACHE_CONNSTR "MongoDB connection string" ""
  elif [ "$RT_CACHE_PROVIDER" = "redis" ] || [ "$RT_CACHE_PROVIDER" = "azureredis" ]; then
    prompt RT_CACHE_CONNSTR "Redis connection string" ""
  elif [ "$RT_CACHE_PROVIDER" = "inMemorySql" ]; then
    prompt RT_CACHE_CONNSTR "SQL Server in-memory cache connection string" ""
  elif [ "$RT_CACHE_PROVIDER" = "googlebigtable" ]; then
    prompt RT_CACHE_BIGTABLE_PROJECT "Google Bigtable project ID" ""
    prompt RT_CACHE_BIGTABLE_INSTANCE "Google Bigtable instance ID" ""
  fi

  echo ""
  echo "  ${DIM}Queue provider handles asynchronous messaging between RPI services.${RESET}"
  if [ "$PLATFORM" = "azure" ]; then
    prompt_choice RT_QUEUE_PROVIDER "Queue provider" "azureservicebus|rabbitmq|azureeventhubs" "azureservicebus"
  elif [ "$PLATFORM" = "amazon" ]; then
    prompt_choice RT_QUEUE_PROVIDER "Queue provider" "amazonsqs|rabbitmq" "amazonsqs"
  elif [ "$PLATFORM" = "google" ]; then
    prompt_choice RT_QUEUE_PROVIDER "Queue provider" "googlepubsub|rabbitmq" "googlepubsub"
  else
    prompt_choice RT_QUEUE_PROVIDER "Queue provider" "rabbitmq" "rabbitmq"
  fi

  if [ "$RT_QUEUE_PROVIDER" = "azureservicebus" ]; then
    prompt RT_QUEUE_CONNSTR "Azure Service Bus connection string" ""
  elif [ "$RT_QUEUE_PROVIDER" = "azureeventhubs" ]; then
    prompt RT_QUEUE_CONNSTR "Azure Event Hubs connection string" ""
    prompt RT_EVENTHUB_NAME "Event Hub name" "RPIQueueListener"
    prompt RT_EVENTHUB_NAMESPACE "Event Hubs namespace name" ""
  elif [ "$RT_QUEUE_PROVIDER" = "googlepubsub" ]; then
    prompt RT_PUBSUB_PROJECT "Google Pub/Sub project ID" ""
  fi
fi

# ============================================================
# Generate auto-generated passwords and tokens
# ============================================================
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
if [ "$FILE_MODE" = "true" ]; then
  echo "${CYAN}${BOLD}Generating files...${RESET}"
else
  printf "${CYAN}${BOLD}Generating files ${RESET}"
  for i in $(seq 1 30); do
    printf "${CYAN}▪${RESET}"
    sleep 1
  done
  echo ""
fi

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
  elif { [ "$RT_CACHE_PROVIDER" = "redis" ] || [ "$RT_CACHE_PROVIDER" = "azureredis" ]; } && [ -n "$RT_CACHE_CONNSTR" ]; then
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
  elif [ "$RT_QUEUE_PROVIDER" = "azureeventhubs" ] && [ -n "$RT_QUEUE_CONNSTR" ]; then
    cat >> "$SECRETS_FILE" << SECRETS_EH
  RealtimeAPI_EventHubs_ConnectionString: "${RT_QUEUE_CONNSTR}"
SECRETS_EH
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

# Storage is added on demand via: bash interactioncli.sh -a storage

# Realtime API (non-sensitive parts only)
if [ "$REALTIME_ENABLED" = "true" ]; then

  # Build cache provider-specific config
  CACHE_EXTRA=""
  case "$RT_CACHE_PROVIDER" in
    mongodb)
      CACHE_EXTRA="    mongodb:
      databaseName: RealtimeCacheDB
      collectionName: RealtimeCacheCollection"
      ;;
    redis)
      CACHE_EXTRA="    redis:
      type: internal"
      ;;
    googlebigtable)
      CACHE_EXTRA="    googlebigtable:
      projectId: \"${RT_CACHE_BIGTABLE_PROJECT}\"
      instanceId: \"${RT_CACHE_BIGTABLE_INSTANCE}\""
      ;;
  esac

  # Build queue provider-specific config
  QUEUE_EXTRA=""
  case "$RT_QUEUE_PROVIDER" in
    rabbitmq)
      QUEUE_EXTRA="    rabbitmq:
      type: internal"
      ;;
    azureeventhubs)
      QUEUE_EXTRA="    azureeventhubs:
      eventHubName: \"${RT_EVENTHUB_NAME}\"
      NamespaceName: \"${RT_EVENTHUB_NAMESPACE}\"
      PartitionIds: [\"0\"]"
      ;;
    googlepubsub)
      QUEUE_EXTRA="    googlepubsub:
      projectId: \"${RT_PUBSUB_PROJECT}\""
      ;;
  esac

  cat >> "$OUTPUT_FILE" << YAML

realtimeapi:
  enabled: true
  replicas: 1
  cacheProvider:
    enabled: true
    provider: ${RT_CACHE_PROVIDER}
${CACHE_EXTRA}
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
${QUEUE_EXTRA}
YAML
fi

# Pre-flight
cat >> "$OUTPUT_FILE" << YAML

preflight:
  enabled: true
  mode: test
YAML

# ============================================================
# Data Warehouse — configure if opted in during step 3b
# ============================================================
if [ "$DW_ENABLED" = "true" ]; then
  section "Configuring: Data Warehouse"
  add_data_warehouse "$OUTPUT_FILE"
fi

# ============================================================
# Optional features — prompt during initial setup
# ============================================================
FEATURES_LIST="database_upgrade queue_reader storage smtp redpoint_ai oidc entra_id autoscaling custom_metrics service_mesh smoke_tests helm_copilot extra_envs advanced"
SELECTED_FEATURES=""

if [ "$FILE_MODE" = "true" ]; then
  # Build feature list from input file
  section "Optional Features"
  for feat in $FEATURES_LIST; do
    if _feature_enabled "$feat"; then
      SELECTED_FEATURES="${SELECTED_FEATURES} ${feat}"
      echo "  ${ICON_CHECK} ${feat}"
    fi
  done
  [ -z "$SELECTED_FEATURES" ] && echo "  ${DIM}(none selected)${RESET}"
else
  section "Optional Features"
  echo ""
  echo "  Select features to include now. You can always add more later"
  echo "  with ${DIM}bash interactioncli.sh -a <feature>${RESET}"
  echo ""
  for feat in $FEATURES_LIST; do
    label=""
    case "$feat" in
      database_upgrade) label="Database Upgrade — run schema migrations automatically after upgrades" ;;
      queue_reader)     label="Queue Reader — process realtime queue events (forms, listeners, callbacks)" ;;
      storage)          label="Storage — persistent volumes for file-based processing and caching" ;;
      smtp)             label="SMTP — send transactional emails from RPI workflows" ;;
      redpoint_ai)      label="Redpoint AI — AI-powered content generation (OpenAI + Cognitive Search)" ;;
      oidc)             label="OIDC — single sign-on via OpenID Connect (Keycloak, Okta, etc.)" ;;
      entra_id)         label="Entra ID — single sign-on via Microsoft Entra ID (Azure AD)" ;;
      autoscaling)      label="Autoscaling — scale services based on CPU/memory with HPA or KEDA" ;;
      custom_metrics)   label="Custom Metrics — expose Prometheus /metrics endpoints for monitoring" ;;
      service_mesh)     label="Service Mesh — enable Linkerd mTLS and traffic policies" ;;
      smoke_tests)      label="Smoke Tests — validate PVC mounts and CSI drivers post-deploy" ;;
      helm_copilot)     label="Interaction Copilot — AI assistant for chart configuration and troubleshooting" ;;
      extra_envs)       label="Extra Envs — debug and plugin environment variables for execution service" ;;
      advanced)         label="Advanced Overrides — override internal defaults (probes, security, logging)" ;;
      *) label="$feat" ;;
    esac
    yn=""
    read -rp "  Add ${BOLD}${label}${RESET}? ${DIM}(y/n) [n]${RESET}: " yn
    if [ "${yn:-n}" = "y" ] || [ "${yn:-n}" = "Y" ]; then
      SELECTED_FEATURES="${SELECTED_FEATURES} ${feat}"
    fi
  done
fi

# Run each selected feature's add function against the generated overrides
for feat in $SELECTED_FEATURES; do
  echo ""
  section "Configuring: ${feat}"

  # In file mode, set context-specific _CFG entries for features that
  # share variable names (e.g., client_id used by both entra_id and oidc)
  if [ "$FILE_MODE" = "true" ]; then
    case "$feat" in
      entra_id)
        _CFG[client_id]=$(cfg '.features.entra_id.client_id' '')
        _CFG[tenant_id]=$(cfg '.features.entra_id.tenant_id' '')
        ;;
      oidc)
        _CFG[client_id]=$(cfg '.features.oidc.client_id' '')
        ;;
      queue_reader)
        _CFG[tenant_id]=$(cfg '.features.queue_reader.tenant_id' '')
        ;;
    esac
  fi

  case "$feat" in
    database_upgrade) add_database_upgrade "$OUTPUT_FILE" ;;
    queue_reader)     add_queue_reader "$OUTPUT_FILE" ;;
    storage)          add_storage "$OUTPUT_FILE" ;;
    smtp)             add_smtp "$OUTPUT_FILE" ;;
    redpoint_ai)      add_redpoint_ai "$OUTPUT_FILE" ;;
    oidc)             add_oidc "$OUTPUT_FILE" ;;
    entra_id)         add_entra_id "$OUTPUT_FILE" ;;
    autoscaling)      add_autoscaling "$OUTPUT_FILE" ;;
    custom_metrics)   add_custom_metrics "$OUTPUT_FILE" ;;
    service_mesh)     add_service_mesh "$OUTPUT_FILE" ;;
    smoke_tests)      add_smoke_tests "$OUTPUT_FILE" ;;
    helm_copilot)     add_helm_copilot "$OUTPUT_FILE" ;;
    extra_envs)       add_extra_envs "$OUTPUT_FILE" ;;
    advanced)         add_advanced "$OUTPUT_FILE" ;;
  esac
done

# Add hint for future feature additions
cat >> "$OUTPUT_FILE" << 'YAML'

# ---------------------------------------------------------------
# Add more features with the Interaction CLI:
#   bash deploy/cli/interactioncli.sh -a <feature>
#   bash deploy/cli/interactioncli.sh -a menu
#
# See docs/readme-configuration.md for details on each feature.
# ---------------------------------------------------------------
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
echo "  ${BOLD}Add features later:${RESET}"
echo "  ${DIM}bash deploy/cli/interactioncli.sh -a menu${RESET}"
echo ""
echo "  ${ICON_WARN}  ${YELLOW}${SECRETS_FILE} contains sensitive values.${RESET}"
echo "     ${YELLOW}Do NOT commit it to version control.${RESET}"

# Delete input file after successful generation (contains sensitive values)
if [ "$FILE_MODE" = "true" ] && [ -f "$INPUT_FILE" ]; then
  rm -f "$INPUT_FILE"
  echo ""
  echo "  ${ICON_CHECK} ${DIM}Deleted ${INPUT_FILE} (contained sensitive values)${RESET}"
fi
echo ""
echo "${DIM}──────────────────────────────────────────────${RESET}"
echo "  ${BOLD}Redpoint Global${RESET}"
echo "  ${DIM}https://www.redpointglobal.com${RESET}"
echo "  ${DIM}Support: support@redpointglobal.com${RESET}"
echo "  ${DIM}Docs:    https://docs.redpointglobal.com/rpi${RESET}"
echo "${DIM}──────────────────────────────────────────────${RESET}"
echo ""
