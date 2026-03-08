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
while getopts "o:a:h" opt; do
  case $opt in
    o) OUTPUT_FILE="$OPTARG" ;;
    a) ADD_MODE=true; ADD_FEATURE="$OPTARG" ;;
    h)
      echo "Usage: $0 [-o output-file] [-a feature]"
      echo ""
      echo "  No flags       Full setup — generates overrides, secrets, and prereqs"
      echo "  -a <feature>   Add a feature to an existing overrides file"
      echo "  -a menu        Show interactive feature menu"
      echo "  -o <file>      Output file path (default: overrides.yaml)"
      echo ""
      echo "  Available features:"
      echo "    databaseUpgrade   Automatic database schema upgrades"
      echo "    queuereader       Queue Listener and Realtime queue processing"
      echo "    autoscaling       HPA or KEDA autoscaling for services"
      echo "    customMetrics     Prometheus /metrics endpoints"
      echo "    serviceMesh       Linkerd Server CRDs"
      echo "    smokeTests        PVC and CSI mount validation"
      echo "    entraID           Microsoft Entra ID (Azure AD) SSO"
      echo "    oidc              OpenID Connect (Keycloak, Okta, etc.)"
      echo "    smtp              Email delivery configuration"
      echo "    redpointAI        OpenAI and Azure Cognitive Search"
      echo "    storage           PVC and CSI storage volumes"
      echo "    advanced          Fine-tune internal defaults"
      echo ""
      echo "  Examples:"
      echo "    bash interactioncli.sh -a redpointAI"
      echo "    bash interactioncli.sh -a menu"
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

add_databaseUpgrade() {
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

add_queuereader() {
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
      echo "  ${ICON_WARN} ${YELLOW}Add QueueService_RedisCache_ConnectionString to your Kubernetes Secret.${RESET}"
    fi
    if [ "$queue_type" = "internal" ]; then
      echo "  ${ICON_WARN} ${YELLOW}Add QueueService_RabbitMQ_Password to your Kubernetes Secret.${RESET}"
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

add_customMetrics() {
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

add_serviceMesh() {
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

add_smokeTests() {
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

add_entraID() {
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
  if [ "$use_creds" = "true" ]; then
    echo "  ${ICON_WARN} ${YELLOW}Add SMTP_Password to your Kubernetes Secret.${RESET}"
  fi
}

add_redpointAI() {
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
  echo ""
  echo "  ${ICON_WARN} ${YELLOW}Add these keys to your Kubernetes Secret:${RESET}"
  echo "    ${DIM}RPI_NLP_API_KEY                  — OpenAI API key${RESET}"
  echo "    ${DIM}RPI_NLP_SEARCH_KEY               — Cognitive Search key${RESET}"
  echo "    ${DIM}RPI_NLP_MODEL_CONNECTION_STRING   — Blob storage connection string${RESET}"
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
  echo "    ${CYAN}1${RESET})  databaseUpgrade   — Automatic database schema upgrades"
  echo "    ${CYAN}2${RESET})  queuereader       — Queue Listener and Realtime queue processing"
  echo "    ${CYAN}3${RESET})  autoscaling       — HPA or KEDA autoscaling for services"
  echo "    ${CYAN}4${RESET})  customMetrics     — Prometheus /metrics endpoints"
  echo "    ${CYAN}5${RESET})  serviceMesh       — Linkerd Server CRDs"
  echo "    ${CYAN}6${RESET})  smokeTests        — PVC and CSI mount validation"
  echo "    ${CYAN}7${RESET})  entraID           — Microsoft Entra ID (Azure AD) SSO"
  echo "    ${CYAN}8${RESET})  oidc              — OpenID Connect (Keycloak, Okta, etc.)"
  echo "    ${CYAN}9${RESET})  smtp              — Email delivery configuration"
  echo "    ${CYAN}10${RESET}) redpointAI        — OpenAI and Azure Cognitive Search"
  echo "    ${CYAN}11${RESET}) storage           — PVC and CSI storage volumes"
  echo "    ${CYAN}12${RESET}) advanced          — Fine-tune internal defaults"
  echo ""
  local choice
  read -rp "  Enter feature number or name: " choice
  case "$choice" in
    1|databaseUpgrade)  ADD_FEATURE="databaseUpgrade" ;;
    2|queuereader)      ADD_FEATURE="queuereader" ;;
    3|autoscaling)      ADD_FEATURE="autoscaling" ;;
    4|customMetrics)    ADD_FEATURE="customMetrics" ;;
    5|serviceMesh)      ADD_FEATURE="serviceMesh" ;;
    6|smokeTests)       ADD_FEATURE="smokeTests" ;;
    7|entraID)          ADD_FEATURE="entraID" ;;
    8|oidc)             ADD_FEATURE="oidc" ;;
    9|smtp)             ADD_FEATURE="smtp" ;;
    10|redpointAI)      ADD_FEATURE="redpointAI" ;;
    11|storage)         ADD_FEATURE="storage" ;;
    12|advanced)        ADD_FEATURE="advanced" ;;
    *) echo "  ${RED}Unknown feature: ${choice}${RESET}"; exit 1 ;;
  esac
}

run_add_feature() {
  local file=$1 feature=$2
  case "$feature" in
    databaseUpgrade)  add_databaseUpgrade "$file" ;;
    queuereader)      add_queuereader "$file" ;;
    autoscaling)      add_autoscaling "$file" ;;
    customMetrics)    add_customMetrics "$file" ;;
    serviceMesh)      add_serviceMesh "$file" ;;
    smokeTests)       add_smokeTests "$file" ;;
    entraID)          add_entraID "$file" ;;
    oidc)             add_oidc "$file" ;;
    smtp)             add_smtp "$file" ;;
    redpointAI)       add_redpointAI "$file" ;;
    storage)          add_storage "$file" ;;
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

# Storage is added on demand via: bash interactioncli.sh -a storage

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

# ============================================================
# Optional features — prompt during initial setup
# ============================================================
section "Optional Features"
echo ""
echo "  Select features to include now. You can always add more later"
echo "  with ${DIM}bash interactioncli.sh -a <feature>${RESET}"
echo ""

FEATURES_LIST="databaseUpgrade queuereader storage smtp redpointAI oidc entraID autoscaling customMetrics serviceMesh smokeTests advanced"
SELECTED_FEATURES=""
for feat in $FEATURES_LIST; do
  local label
  case "$feat" in
    databaseUpgrade) label="Database Upgrade (automatic schema upgrades)" ;;
    queuereader)     label="Queue Reader (Realtime queue processing)" ;;
    storage)         label="Storage (PVC / CSI volumes)" ;;
    smtp)            label="SMTP (email delivery)" ;;
    redpointAI)      label="Redpoint AI (OpenAI + Cognitive Search)" ;;
    oidc)            label="OIDC (OpenID Connect SSO)" ;;
    entraID)         label="Microsoft Entra ID (Azure AD SSO)" ;;
    autoscaling)     label="Autoscaling (HPA / KEDA)" ;;
    customMetrics)   label="Custom Metrics (Prometheus endpoints)" ;;
    serviceMesh)     label="Service Mesh (Linkerd)" ;;
    smokeTests)      label="Smoke Tests (PVC / CSI validation)" ;;
    advanced)        label="Advanced Overrides (fine-tune internals)" ;;
    *) label="$feat" ;;
  esac
  local yn
  read -rp "  Add ${BOLD}${label}${RESET}? ${DIM}(y/n) [n]${RESET}: " yn
  if [ "${yn:-n}" = "y" ] || [ "${yn:-n}" = "Y" ]; then
    SELECTED_FEATURES="${SELECTED_FEATURES} ${feat}"
  fi
done

# Run each selected feature's add function against the generated overrides
for feat in $SELECTED_FEATURES; do
  echo ""
  section "Configuring: ${feat}"
  case "$feat" in
    databaseUpgrade) add_databaseUpgrade "$OUTPUT_FILE" ;;
    queuereader)     add_queuereader "$OUTPUT_FILE" ;;
    storage)         add_storage "$OUTPUT_FILE" ;;
    smtp)            add_smtp "$OUTPUT_FILE" ;;
    redpointAI)      add_redpointAI "$OUTPUT_FILE" ;;
    oidc)            add_oidc "$OUTPUT_FILE" ;;
    entraID)         add_entraID "$OUTPUT_FILE" ;;
    autoscaling)     add_autoscaling "$OUTPUT_FILE" ;;
    customMetrics)   add_customMetrics "$OUTPUT_FILE" ;;
    serviceMesh)     add_serviceMesh "$OUTPUT_FILE" ;;
    smokeTests)      add_smokeTests "$OUTPUT_FILE" ;;
    advanced)        add_advanced "$OUTPUT_FILE" ;;
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
echo ""
echo "${DIM}──────────────────────────────────────────────${RESET}"
echo "  ${BOLD}Redpoint Global${RESET}"
echo "  ${DIM}https://www.redpointglobal.com${RESET}"
echo "  ${DIM}Support: support@redpointglobal.com${RESET}"
echo "  ${DIM}Docs:    https://docs.redpointglobal.com/rpi${RESET}"
echo "${DIM}──────────────────────────────────────────────${RESET}"
echo ""
