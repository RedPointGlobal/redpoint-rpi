{{/*
Expand the name of the chart.
*/}}
{{- define "redpoint-rpi.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "redpoint-rpi.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "redpoint-rpi.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "redpoint-rpi.labels" -}}
helm.sh/chart: {{ include "redpoint-rpi.chart" . }}
{{ include "redpoint-rpi.selectorLabels" . }}
app.kubernetes.io/version: {{ .Values.global.deployment.images.tag | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/part-of: rpi
{{- end }}

{{/*
Selector labels
*/}}
{{- define "redpoint-rpi.selectorLabels" -}}
app.kubernetes.io/name: {{ .name }}
app.kubernetes.io/instance: {{ .root.Release.Name }}
{{- end }}

{{/*
Common labels.
Usage:
{{ include "redpoint-rpi.componentLabels" (dict "root" . "component" "api") }}
*/}}
{{- define "redpoint-rpi.componentLabels" -}}
app.kubernetes.io/name: {{ .name | default (include "redpoint-rpi.fullname" .root) }}
app.kubernetes.io/instance: {{ .root.Release.Name }}
app.kubernetes.io/part-of: rpi
app.kubernetes.io/component: {{ .component }}
{{- end }}

{{/*
Common labels.
Usage:
{{ include "smartactivation.componentLabels" (dict "root" . "component" "api") }}
*/}}
{{- define "smartactivation.componentLabels" -}}
app.kubernetes.io/name: {{ .name | default (include "redpoint-rpi.fullname" .root) }}
app.kubernetes.io/instance: {{ .root.Release.Name }}
app.kubernetes.io/part-of: smartactivation
{{- end }}

{{/*
Pod-level security context.
Usage: {{- include "rpi.pod.securityContext" (dict "sc" $secCtx) | nindent 6 }}
Options: set "noFsGroup" true or "noSupplementalGroups" true for services that need a minimal context.
*/}}
{{- define "rpi.pod.securityContext" -}}
{{- $sc := .sc -}}
{{- if $sc.enabled -}}
securityContext:
  runAsUser: {{ $sc.runAsUser }}
  runAsGroup: {{ $sc.runAsGroup }}
  {{- if not .noFsGroup }}
  fsGroup: {{ $sc.fsGroup }}
  {{- end }}
  runAsNonRoot: {{ $sc.runAsNonRoot }}
  {{- if not .noSupplementalGroups }}
  {{- with $sc.supplementalGroups }}
  supplementalGroups:
    {{- toYaml . | nindent 4 }}
  {{- end }}
  {{- end }}
{{- end }}
{{- end -}}

{{/*
Container-level security context.
Usage: {{- include "rpi.container.securityContext" (dict "sc" $secCtx) | nindent 8 }}
*/}}
{{- define "rpi.container.securityContext" -}}
{{- $sc := .sc -}}
{{- if $sc.enabled -}}
securityContext:
  privileged: {{ $sc.privileged }}
  allowPrivilegeEscalation: {{ $sc.allowPrivilegeEscalation }}
  readOnlyRootFilesystem: {{ $sc.readOnlyRootFilesystem }}
  appArmorProfile:
    type: RuntimeDefault
  capabilities:
    drop:
    {{- range $sc.capabilities.drop }}
      - {{ . }}
    {{- end }}
{{- end }}
{{- end -}}

{{/*
Topology spread constraints
Usage: {{ include "redpoint-rpi.topologySpreadConstraints" (dict "name" "rpi-realtimeapi" "root" .) }}
*/}}
{{- define "redpoint-rpi.topologySpreadConstraints" -}}
{{- $tsc := fromYaml (include "rpi.merged.topologySpreadConstraints" .) -}}
{{- if $tsc.enabled }}
topologySpreadConstraints:
  - maxSkew: {{ $tsc.maxSkew | default 1 }}
    topologyKey: {{ $tsc.topologyKey | default "topology.kubernetes.io/zone" }}
    whenUnsatisfiable: {{ $tsc.whenUnsatisfiable | default "ScheduleAnyway" }}
    labelSelector:
      matchLabels:
        app.kubernetes.io/name: {{ .name }}
{{- end }}
{{- end }}

{{/*
PreStop lifecycle hook for graceful shutdown
*/}}
{{- define "redpoint-rpi.preStopHook" -}}
lifecycle:
  preStop:
    exec:
      command: ["/bin/sh", "-c", "sleep 10"]
{{- end }}

{{/*
Standard probe configuration
Usage: {{ include "redpoint-rpi.livenessProbe" (dict "probes" .Values.realtimeapi "path" "/health") }}
*/}}
{{- define "redpoint-rpi.livenessProbe" -}}
livenessProbe:
  httpGet:
    path: {{ .path | default "/health" }}
    port: 8080
  initialDelaySeconds: {{ .probes.livenessProbe.initialDelaySeconds }}
  periodSeconds: {{ .probes.livenessProbe.periodSeconds }}
  failureThreshold: {{ .probes.livenessProbe.failureThreshold }}
  timeoutSeconds: {{ .probes.livenessProbe.timeoutSeconds }}
{{- end }}

{{- define "redpoint-rpi.readinessProbe" -}}
readinessProbe:
  httpGet:
    path: {{ .path | default "/health/ready" }}
    port: 8080
  initialDelaySeconds: {{ .probes.readinessProbe.initialDelaySeconds }}
  periodSeconds: {{ .probes.readinessProbe.periodSeconds }}
  failureThreshold: {{ .probes.readinessProbe.failureThreshold }}
  timeoutSeconds: {{ .probes.readinessProbe.timeoutSeconds }}
{{- end }}

{{- define "redpoint-rpi.startupProbe" -}}
startupProbe:
  httpGet:
    path: {{ .path | default "/health" }}
    port: 8080
  initialDelaySeconds: {{ .probes.startupProbe.initialDelaySeconds }}
  failureThreshold: {{ .probes.startupProbe.failureThreshold }}
  periodSeconds: {{ .probes.startupProbe.periodSeconds }}
  timeoutSeconds: {{ .probes.startupProbe.timeoutSeconds }}
{{- end }}

{{/*
Image pull secrets
*/}}
{{- define "redpoint-rpi.imagePullSecrets" -}}
{{- if .Values.global.deployment.images.imagePullSecret.enabled }}
imagePullSecrets:
  - name: {{ .Values.global.deployment.images.imagePullSecret.name }}
{{- end }}
{{- end }}

{{/*
Node selector
*/}}
{{- define "redpoint-rpi.nodeSelector" -}}
{{- if .Values.nodeSelector.enabled }}
nodeSelector:
  {{ .Values.nodeSelector.key }}: {{ .Values.nodeSelector.value }}
{{- end }}
{{- end }}

{{/*
Tolerations
*/}}
{{- define "redpoint-rpi.tolerations" -}}
{{- if .Values.tolerations.enabled }}
tolerations:
  - effect: {{ .Values.tolerations.effect }}
    key: {{ .Values.tolerations.key }}
    operator: {{ .Values.tolerations.operator }}
    value: {{ .Values.tolerations.value }}
{{- end }}
{{- end }}

{{/* DatawarehouseProviders */}}
{{- define "redpoint.DatawarehouseProviders" -}}
{{- $dw := .Values.databases.datawarehouse | default dict -}}
{{- $bigquery := $dw.bigquery | default dict -}}

{{- if ($bigquery.enabled | default false) -}}
true
{{- else -}}
false
{{- end -}}
{{- end }}

{{/* ============================================================
     MERGE HELPERS
     ============================================================
     Each helper merges: defaults + user values (user wins).
     Usage in templates:
       {{- $cfg := fromYaml (include "rpi.merged.realtimeapi" .) -}}
     ============================================================ */}}

{{/* --- Component merge helpers ---
     Merge order: service defaults → global resources → per-service user values.
     Global .Values.resources sets a baseline for all services.
     Per-service overrides (e.g. .Values.interactionapi.resources) win.
*/}}

{{/* Apply global resources onto a service defaults dict */}}
{{- define "rpi.applyGlobalResources" -}}
{{- $d := index . 0 -}}
{{- $g := index . 1 -}}
{{- if $g -}}
{{- $_ := set $d "resources" (mustMergeOverwrite ($d.resources | default dict) $g) -}}
{{- end -}}
{{- toYaml $d -}}
{{- end -}}

{{- define "rpi.merged.realtimeapi" -}}
{{- $d := fromYaml (include "rpi.applyGlobalResources" (list (fromYaml (include "rpi.defaults.realtimeapi" .)) (.Values.resources | default dict))) -}}
{{- $u := .Values.realtimeapi | default dict -}}
{{- toYaml (mustMergeOverwrite $d $u) -}}
{{- end -}}

{{- define "rpi.merged.callbackapi" -}}
{{- $d := fromYaml (include "rpi.applyGlobalResources" (list (fromYaml (include "rpi.defaults.callbackapi" .)) (.Values.resources | default dict))) -}}
{{- $u := .Values.callbackapi | default dict -}}
{{- toYaml (mustMergeOverwrite $d $u) -}}
{{- end -}}

{{- define "rpi.merged.executionservice" -}}
{{- $d := fromYaml (include "rpi.applyGlobalResources" (list (fromYaml (include "rpi.defaults.executionservice" .)) (.Values.resources | default dict))) -}}
{{- $u := .Values.executionservice | default dict -}}
{{- toYaml (mustMergeOverwrite $d $u) -}}
{{- end -}}

{{- define "rpi.merged.interactionapi" -}}
{{- $d := fromYaml (include "rpi.applyGlobalResources" (list (fromYaml (include "rpi.defaults.interactionapi" .)) (.Values.resources | default dict))) -}}
{{- $u := .Values.interactionapi | default dict -}}
{{- toYaml (mustMergeOverwrite $d $u) -}}
{{- end -}}

{{- define "rpi.merged.integrationapi" -}}
{{- $d := fromYaml (include "rpi.applyGlobalResources" (list (fromYaml (include "rpi.defaults.integrationapi" .)) (.Values.resources | default dict))) -}}
{{- $u := .Values.integrationapi | default dict -}}
{{- toYaml (mustMergeOverwrite $d $u) -}}
{{- end -}}

{{- define "rpi.merged.nodemanager" -}}
{{- $d := fromYaml (include "rpi.applyGlobalResources" (list (fromYaml (include "rpi.defaults.nodemanager" .)) (.Values.resources | default dict))) -}}
{{- $u := .Values.nodemanager | default dict -}}
{{- toYaml (mustMergeOverwrite $d $u) -}}
{{- end -}}

{{- define "rpi.merged.deploymentapi" -}}
{{- $d := fromYaml (include "rpi.applyGlobalResources" (list (fromYaml (include "rpi.defaults.deploymentapi" .)) (.Values.resources | default dict))) -}}
{{- $u := .Values.deploymentapi | default dict -}}
{{- toYaml (mustMergeOverwrite $d $u) -}}
{{- end -}}

{{- define "rpi.merged.queuereader" -}}
{{- $d := fromYaml (include "rpi.applyGlobalResources" (list (fromYaml (include "rpi.defaults.queuereader" .)) (.Values.resources | default dict))) -}}
{{- $u := .Values.queuereader | default dict -}}
{{- toYaml (mustMergeOverwrite $d $u) -}}
{{- end -}}

{{- define "rpi.merged.rebrandly" -}}
{{- $d := fromYaml (include "rpi.applyGlobalResources" (list (fromYaml (include "rpi.defaults.rebrandly" .)) (.Values.resources | default dict))) -}}
{{- $u := .Values.rebrandly | default dict -}}
{{- toYaml (mustMergeOverwrite $d $u) -}}
{{- end -}}

{{- define "rpi.merged.authservice" -}}
{{- $d := fromYaml (include "rpi.applyGlobalResources" (list (fromYaml (include "rpi.defaults.authservice" .)) (.Values.resources | default dict))) -}}
{{- $u := .Values.authservice | default dict -}}
{{- toYaml (mustMergeOverwrite $d $u) -}}
{{- end -}}

{{- define "rpi.merged.keycloak" -}}
{{- $d := fromYaml (include "rpi.applyGlobalResources" (list (fromYaml (include "rpi.defaults.keycloak" .)) (.Values.resources | default dict))) -}}
{{- $u := .Values.keycloak | default dict -}}
{{- toYaml (mustMergeOverwrite $d $u) -}}
{{- end -}}

{{- define "rpi.merged.initservice" -}}
{{- $d := fromYaml (include "rpi.applyGlobalResources" (list (fromYaml (include "rpi.defaults.initservice" .)) (.Values.resources | default dict))) -}}
{{- $u := .Values.initservice | default dict -}}
{{- toYaml (mustMergeOverwrite $d $u) -}}
{{- end -}}

{{- define "rpi.merged.messageq" -}}
{{- $d := fromYaml (include "rpi.applyGlobalResources" (list (fromYaml (include "rpi.defaults.messageq" .)) (.Values.resources | default dict))) -}}
{{- $u := .Values.messageq | default dict -}}
{{- toYaml (mustMergeOverwrite $d $u) -}}
{{- end -}}

{{- define "rpi.merged.maintenanceservice" -}}
{{- $d := fromYaml (include "rpi.applyGlobalResources" (list (fromYaml (include "rpi.defaults.maintenanceservice" .)) (.Values.resources | default dict))) -}}
{{- $u := .Values.maintenanceservice | default dict -}}
{{- toYaml (mustMergeOverwrite $d $u) -}}
{{- end -}}

{{- define "rpi.merged.servicesapi" -}}
{{- $d := fromYaml (include "rpi.applyGlobalResources" (list (fromYaml (include "rpi.defaults.servicesapi" .)) (.Values.resources | default dict))) -}}
{{- $u := .Values.servicesapi | default dict -}}
{{- toYaml (mustMergeOverwrite $d $u) -}}
{{- end -}}

{{- define "rpi.merged.socketio" -}}
{{- $d := fromYaml (include "rpi.applyGlobalResources" (list (fromYaml (include "rpi.defaults.socketio" .)) (.Values.resources | default dict))) -}}
{{- $u := .Values.socketio | default dict -}}
{{- toYaml (mustMergeOverwrite $d $u) -}}
{{- end -}}

{{- define "rpi.merged.uiservice" -}}
{{- $d := fromYaml (include "rpi.applyGlobalResources" (list (fromYaml (include "rpi.defaults.uiservice" .)) (.Values.resources | default dict))) -}}
{{- $u := .Values.uiservice | default dict -}}
{{- toYaml (mustMergeOverwrite $d $u) -}}
{{- end -}}

{{- define "rpi.merged.cdpcache" -}}
{{- $d := fromYaml (include "rpi.applyGlobalResources" (list (fromYaml (include "rpi.defaults.cdpcache" .)) (.Values.resources | default dict))) -}}
{{- $u := .Values.cdpcache | default dict -}}
{{- toYaml (mustMergeOverwrite $d $u) -}}
{{- end -}}

{{/* --- Cross-cutting merge helpers --- */}}

{{- define "rpi.merged.securityContext" -}}
{{- $d := fromYaml (include "rpi.defaults.securityContext" .) -}}
{{- $u := .Values.securityContext | default dict -}}
{{- toYaml (mustMergeOverwrite $d $u) -}}
{{- end -}}

{{- define "rpi.merged.livenessProbe" -}}
{{- $d := fromYaml (include "rpi.defaults.livenessProbe" .) -}}
{{- $u := .Values.livenessProbe | default dict -}}
{{- toYaml (mustMergeOverwrite $d $u) -}}
{{- end -}}

{{- define "rpi.merged.readinessProbe" -}}
{{- $d := fromYaml (include "rpi.defaults.readinessProbe" .) -}}
{{- $u := .Values.readinessProbe | default dict -}}
{{- toYaml (mustMergeOverwrite $d $u) -}}
{{- end -}}

{{- define "rpi.merged.startupProbe" -}}
{{- $d := fromYaml (include "rpi.defaults.startupProbe" .) -}}
{{- $u := .Values.startupProbe | default dict -}}
{{- toYaml (mustMergeOverwrite $d $u) -}}
{{- end -}}

{{- define "rpi.merged.topologySpreadConstraints" -}}
{{- $d := fromYaml (include "rpi.defaults.topologySpreadConstraints" .) -}}
{{- $u := .Values.topologySpreadConstraints | default dict -}}
{{- toYaml (mustMergeOverwrite $d $u) -}}
{{- end -}}

{{- define "rpi.merged.ingress" -}}
{{- $d := fromYaml (include "rpi.defaults.ingress" .) -}}
{{- $u := .Values.ingress | default dict -}}
{{- toYaml (mustMergeOverwrite $d $u) -}}
{{- end -}}

{{/*
Resolve ingress annotations. If the user sets ingress.annotations, those
are used as-is (full replacement). Otherwise returns sensible defaults.
*/}}
{{- define "rpi.ingress.annotations" -}}
{{- if $ingCfg := fromYaml (include "rpi.merged.ingress" .) -}}
{{- if $ingCfg.annotations -}}
{{- toYaml $ingCfg.annotations -}}
{{- else -}}
nginx.ingress.kubernetes.io/proxy-body-size: 4096m
nginx.ingress.kubernetes.io/proxy-read-timeout: "3600"
nginx.ingress.kubernetes.io/proxy-send-timeout: "3600"
nginx.ingress.kubernetes.io/enable-access-log: "true"
nginx.ingress.kubernetes.io/ssl-redirect: "true"
nginx.ingress.kubernetes.io/force-ssl-redirect: "true"
{{- end -}}
{{- end -}}
{{- end -}}

{{- define "rpi.merged.diagnosticsMode" -}}
{{- $d := fromYaml (include "rpi.defaults.diagnosticsMode" .) -}}
{{- $u := .Values.diagnosticsMode | default dict -}}
{{- toYaml (mustMergeOverwrite $d $u) -}}
{{- end -}}

{{- define "rpi.merged.networkPolicy" -}}
{{- $d := fromYaml (include "rpi.defaults.networkPolicy" .) -}}
{{- $u := .Values.networkPolicy | default dict -}}
{{- toYaml (mustMergeOverwrite $d $u) -}}
{{- end -}}

{{- define "rpi.merged.postInstall" -}}
{{- $d := fromYaml (include "rpi.defaults.postInstall" .) -}}
{{- $u := .Values.postInstall | default dict -}}
{{- toYaml (mustMergeOverwrite $d $u) -}}
{{- end -}}

{{- define "rpi.merged.databaseUpgrade" -}}
{{- $d := fromYaml (include "rpi.defaults.databaseUpgrade" .) -}}
{{- $u := .Values.databaseUpgrade | default dict -}}
{{- toYaml (mustMergeOverwrite $d $u) -}}
{{- end -}}

{{/*
Resolve a host entry to an FQDN.
If the host value contains a dot, it is treated as a FQDN and returned as-is.
Otherwise it is treated as a subdomain and appended to the domain.
Usage: {{ include "rpi.ingress.fqdn" (dict "host" $ingCfg.hosts.callbackapi "domain" $ingCfg.domain) }}
*/}}
{{- define "rpi.ingress.fqdn" -}}
{{- if contains "." .host -}}
{{- .host -}}
{{- else -}}
{{- printf "%s.%s" .host .domain -}}
{{- end -}}
{{- end -}}

{{/* ============================================================
     CLOUD IDENTITY HELPERS
     ============================================================
     Shared helpers for pod-to-cloud authentication and secrets.
     Eliminates duplication across all deploy-*.yaml templates.
     ============================================================ */}}

{{/*
Validate that cloudIdentity is enabled when using sdk or csi secrets.
Call this once from any top-level template to catch misconfiguration early.
*/}}
{{- define "rpi.validateConfig" -}}
{{- if or (eq .Values.secretsManagement.provider "sdk") (eq .Values.secretsManagement.provider "csi") -}}
{{- if not .Values.cloudIdentity.enabled -}}
{{- fail "secretsManagement.provider 'sdk' and 'csi' require cloudIdentity.enabled=true (pods must authenticate to the cloud to access the vault)" -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{/*
Service mesh pod annotations.
When serviceMesh is enabled with Linkerd, merges default annotations with
any user overrides from serviceMesh.podAnnotations. User values win.
Usage: {{- include "rpi.serviceMesh.podAnnotations" . | nindent 8 }}
*/}}
{{- define "rpi.serviceMesh.podAnnotations" -}}
{{- if .Values.serviceMesh.enabled }}
{{- if eq (.Values.serviceMesh.provider | default "linkerd") "linkerd" }}
{{- $defaults := dict "linkerd.io/inject" "enabled" "config.linkerd.io/skip-outbound-ports" "443" "config.linkerd.io/proxy-outbound-connect-timeout" "240000ms" -}}
{{- $overrides := .Values.serviceMesh.podAnnotations | default dict -}}
{{- $merged := mustMergeOverwrite $defaults $overrides -}}
{{- toYaml $merged }}
{{- end }}
{{- end }}
{{- end }}

{{/*
ServiceAccount annotations for cloud identity.
Renders the appropriate annotation based on global.deployment.platform.
Usage: {{- include "rpi.cloudidentity.saAnnotations" . | nindent 4 }}
*/}}
{{- define "rpi.cloudidentity.saAnnotations" -}}
{{- if .Values.cloudIdentity.enabled -}}
{{- if eq .Values.global.deployment.platform "azure" }}
azure.workload.identity/client-id: {{ .Values.cloudIdentity.azure.managedIdentityClientId | quote }}
azure.workload.identity/tenant-id: {{ .Values.cloudIdentity.azure.tenantId | quote }}
{{- else if eq .Values.global.deployment.platform "google" }}
iam.gke.io/gcp-service-account: {{ .Values.cloudIdentity.google.serviceAccountEmail | quote }}
{{- else if eq .Values.global.deployment.platform "amazon" }}
{{- if not .Values.cloudIdentity.amazon.useAccessKeys }}
eks.amazonaws.com/role-arn: {{ .Values.cloudIdentity.amazon.roleArn | quote }}
{{- end }}
{{- end }}
{{- end }}
{{- end -}}

{{/*
Pod labels for cloud identity (Azure Workload Identity webhook).
Usage: {{- include "rpi.cloudidentity.podLabels" . | nindent 8 }}
*/}}
{{- define "rpi.cloudidentity.podLabels" -}}
{{- if .Values.cloudIdentity.enabled -}}
{{- if eq .Values.global.deployment.platform "azure" }}
azure.workload.identity/use: "true"
{{- end }}
{{- end }}
{{- end -}}

{{/*
Cloud identity env vars (IRSA for Amazon, Google credentials path).
Usage: {{- include "rpi.cloudidentity.envvars" . | nindent 10 }}
*/}}
{{- define "rpi.cloudidentity.envvars" -}}
{{- if .Values.cloudIdentity.enabled -}}
{{- if eq .Values.global.deployment.platform "amazon" }}
{{- if not .Values.cloudIdentity.amazon.useAccessKeys }}
- name: AWS_ROLE_ARN
  value: {{ .Values.cloudIdentity.amazon.roleArn | quote }}
- name: AWS_WEB_IDENTITY_TOKEN_FILE
  value: "/var/run/secrets/eks.amazonaws.com/serviceaccount/token"
- name: AWS_STS_REGIONAL_ENDPOINTS
  value: "regional"
- name: AWS_DEFAULT_REGION
  value: {{ .Values.cloudIdentity.amazon.region | quote }}
{{- end }}
{{- else if eq .Values.global.deployment.platform "google" }}
{{- if .Values.cloudIdentity.google.configMapName }}
- name: GOOGLE_APPLICATION_CREDENTIALS
  value: "{{ .Values.cloudIdentity.google.configMapFilePath }}/{{ .Values.cloudIdentity.google.keyName }}"
{{- end }}
{{- end }}
{{- end }}
{{- end -}}

{{/*
Amazon access key env vars (when using static keys instead of IRSA).
Usage: {{- include "rpi.cloudidentity.awsAccessKeyEnvvars" . | nindent 10 }}
*/}}
{{- define "rpi.cloudidentity.awsAccessKeyEnvvars" -}}
{{- if .Values.cloudIdentity.enabled -}}
{{- if eq .Values.global.deployment.platform "amazon" }}
{{- if .Values.cloudIdentity.amazon.useAccessKeys }}
- name: AWS_ACCESS_KEY_ID
  valueFrom:
    secretKeyRef:
      key: AWS_Access_Key_ID
      name: {{ include "rpi.secrets.secretName" . }}
- name: AWS_SECRET_ACCESS_KEY
  valueFrom:
    secretKeyRef:
      key: AWS_Secret_Access_Key
      name: {{ include "rpi.secrets.secretName" . }}
- name: AWS_REGION
  value: {{ .Values.cloudIdentity.amazon.region | quote }}
{{- end }}
{{- end }}
{{- end }}
{{- end -}}

{{/*
SDK vault env vars — only when secretsManagement.provider == "sdk".
Configures the app to read secrets from the cloud vault at runtime.
Usage: {{- include "rpi.secrets.sdk.envvars" . | nindent 10 }}
*/}}
{{- define "rpi.secrets.sdk.envvars" -}}
{{- if eq .Values.secretsManagement.provider "sdk" -}}
{{- if eq .Values.global.deployment.platform "azure" }}
- name: CloudIdentity__Azure__CredentialType
  value: "AzureIdentity"
- name: CloudIdentity__Azure__UseADTokenForDatabaseConnection
  value: {{ .Values.secretsManagement.sdk.azure.useADTokenForDatabaseConnection | quote }}
- name: KeyVault__Provider
  value: "Azure"
- name: KeyVault__UseForAppSettings
  value: "true"
- name: KeyVault__UseForConfigPasswords
  value: "true"
- name: KeyVault__AzureSettings__VaultURI
  value: {{ .Values.secretsManagement.sdk.azure.vaultUri | quote }}
- name: KeyVault__AzureSettings__AppSettingsVaultURI
  value: {{ .Values.secretsManagement.sdk.azure.vaultUri | quote }}
- name: KeyVault__AzureSettings__ConfigurationReloadIntervalSeconds
  value: {{ .Values.secretsManagement.sdk.azure.configurationReloadIntervalSeconds | quote }}
{{- else if eq .Values.global.deployment.platform "google" }}
- name: KeyVault__Provider
  value: "Google"
- name: KeyVault__UseForAppSettings
  value: "true"
- name: KeyVault__UseForConfigPasswords
  value: "true"
{{- else if eq .Values.global.deployment.platform "amazon" }}
- name: KeyVault__Provider
  value: "Amazon"
- name: KeyVault__UseForAppSettings
  value: "true"
- name: KeyVault__UseForConfigPasswords
  value: "true"
- name: KeyVault__AmazonSettings__AppSettingsTag
  value: {{ .Values.secretsManagement.sdk.amazon.secretTagKey | quote }}
{{- end }}
{{- end }}
{{- end -}}

{{/*
Resolve the K8s secret name — works for kubernetes and csi modes.
Usage: {{ include "rpi.secrets.secretName" . }}
*/}}
{{- define "rpi.secrets.secretName" -}}
{{- if eq .Values.secretsManagement.provider "csi" -}}
{{ .Values.secretsManagement.csi.secretName | default "redpoint-rpi-secrets" }}
{{- else -}}
{{ .Values.secretsManagement.kubernetes.secretName | default "redpoint-rpi-secrets" }}
{{- end -}}
{{- end -}}

{{/*
Resolve which ServiceAccount name a pod should use.
Usage: {{ include "rpi.serviceAccountName" (dict "root" . "name" $name "cfg" $cfg) }}
  - root: the top-level context (.)
  - name: the per-service SA name (e.g., "rpi-realtimeapi")
  - cfg:  the merged service config (optional)
Priority:
  1. Per-service override: cfg.serviceAccountName (if set)
  2. Mode=shared: uses the shared SA name
  3. Mode=per-service or both: uses the per-service SA name
*/}}
{{- define "rpi.serviceAccountName" -}}
{{- if and .cfg (hasKey .cfg "serviceAccountName") .cfg.serviceAccountName -}}
{{ .cfg.serviceAccountName }}
{{- else -}}
{{- $mode := .root.Values.cloudIdentity.serviceAccount.mode | default "per-service" -}}
{{- if eq $mode "shared" -}}
{{ .root.Values.cloudIdentity.serviceAccount.name | default "redpoint-rpi" }}
{{- else -}}
{{ .name }}
{{- end -}}
{{- end -}}
{{- end -}}

{{/*
Google ConfigMap volume mount (for services that need the SA JSON file).
Usage: {{- include "rpi.cloudidentity.googleVolumeMounts" . | nindent 10 }}
*/}}
{{- define "rpi.cloudidentity.googleVolumeMounts" -}}
{{- if .Values.cloudIdentity.enabled -}}
{{- if eq .Values.global.deployment.platform "google" }}
{{- if .Values.cloudIdentity.google.configMapName }}
- name: {{ .Values.cloudIdentity.google.configMapName }}
  mountPath: "{{ .Values.cloudIdentity.google.configMapFilePath }}/{{ .Values.cloudIdentity.google.keyName }}"
  subPath: {{ .Values.cloudIdentity.google.keyName | quote }}
{{- end }}
{{- end }}
{{- end }}
{{- end -}}

{{/*
Google ConfigMap volume definition.
Usage: {{- include "rpi.cloudidentity.googleVolumes" . | nindent 8 }}
*/}}
{{- define "rpi.cloudidentity.googleVolumes" -}}
{{- if .Values.cloudIdentity.enabled -}}
{{- if eq .Values.global.deployment.platform "google" }}
{{- if .Values.cloudIdentity.google.configMapName }}
- name: {{ .Values.cloudIdentity.google.configMapName | quote }}
  configMap:
    name: {{ .Values.cloudIdentity.google.configMapName | quote }}
{{- end }}
{{- end }}
{{- end }}
{{- end -}}

{{/*
Platform-specific database connection env var name.
Usage: {{- include "rpi.platform.dbProviderEnvvar" . | nindent 10 }}
*/}}
{{- define "rpi.platform.dbProviderEnvvar" -}}
{{- if eq .Values.global.deployment.platform "azure" }}
- name: RPI__CloudEnvironment
  value: "Azure"
{{- else if eq .Values.global.deployment.platform "amazon" }}
- name: RPI__CloudEnvironment
  value: "Amazon"
{{- else if eq .Values.global.deployment.platform "google" }}
- name: RPI__CloudEnvironment
  value: "Google"
{{- else }}
- name: RPI__CloudEnvironment
  value: "SelfHosted"
{{- end }}
{{- end -}}

{{/*
Resolve the container image for a service.
Uses a per-service override if set under global.deployment.images.overrides.<name>,
otherwise constructs {repository}/{name}:{tag}.
Usage: {{ include "rpi.image" (dict "root" . "name" $name) }}
*/}}
{{- define "rpi.image" -}}
{{- $overrides := .root.Values.global.deployment.images.overrides | default dict -}}
{{- if hasKey $overrides .name -}}
{{ index $overrides .name }}
{{- else -}}
{{ .root.Values.global.deployment.images.repository }}/{{ .name }}:{{ .root.Values.global.deployment.images.tag }}
{{- end -}}
{{- end -}}

{{/*
Pod anti-affinity block. Renders the full affinity: stanza.
Usage: {{- include "rpi.podAntiAffinity" (dict "root" . "name" $name) | nindent 6 }}
*/}}
{{- define "rpi.podAntiAffinity" -}}
{{- $aa := .root.Values.podAntiAffinity | default dict -}}
{{- $enabled := ternary $aa.enabled true (hasKey $aa "enabled") -}}
{{- if $enabled }}
affinity:
  podAntiAffinity:
    {{- if eq ($aa.type | default "preferred") "required" }}
    requiredDuringSchedulingIgnoredDuringExecution:
      - labelSelector:
          matchLabels:
            app.kubernetes.io/name: {{ .name }}
        topologyKey: {{ $aa.topologyKey | default "kubernetes.io/hostname" }}
    {{- else }}
    preferredDuringSchedulingIgnoredDuringExecution:
      - weight: {{ $aa.weight | default 100 }}
        podAffinityTerm:
          labelSelector:
            matchLabels:
              app.kubernetes.io/name: {{ .name }}
          topologyKey: {{ $aa.topologyKey | default "kubernetes.io/hostname" }}
    {{- end }}
{{- end }}
{{- end -}}

{{/*
Custom CA certificate volume mount.
Usage: {{- include "rpi.customCACerts.volumeMount" . | nindent 10 }}
*/}}
{{- define "rpi.customCACerts.volumeMount" -}}
{{- if and .Values.customCACerts .Values.customCACerts.enabled .Values.customCACerts.name }}
- name: custom-ca-certs
  mountPath: {{ .Values.customCACerts.mountPath | default "/usr/local/share/ca-certificates/custom" }}
  readOnly: true
{{- end }}
{{- end -}}

{{/*
Custom CA certificate volume definition.
Usage: {{- include "rpi.customCACerts.volume" . | nindent 8 }}
*/}}
{{- define "rpi.customCACerts.volume" -}}
{{- if and .Values.customCACerts .Values.customCACerts.enabled .Values.customCACerts.name }}
- name: custom-ca-certs
  {{- if eq (.Values.customCACerts.source | default "configMap") "secret" }}
  secret:
    secretName: {{ .Values.customCACerts.name }}
  {{- else }}
  configMap:
    name: {{ .Values.customCACerts.name }}
  {{- end }}
{{- end }}
{{- end -}}

{{/*
Custom CA certificate env var (SSL_CERT_FILE).
Usage: {{- include "rpi.customCACerts.envVar" . | nindent 8 }}
*/}}
{{- define "rpi.customCACerts.envVar" -}}
{{- if and .Values.customCACerts .Values.customCACerts.enabled .Values.customCACerts.certFile }}
- name: SSL_CERT_FILE
  value: "{{ .Values.customCACerts.mountPath | default "/usr/local/share/ca-certificates/custom" }}/{{ .Values.customCACerts.certFile }}"
{{- end }}
{{- end -}}

{{/*
Render merged annotations for a specific resource type.
Usage: {{- include "rpi.mergedAnnotations" (dict "root" . "type" "serviceAccount") }}
Merges commonAnnotations + type-specific overrides (serviceAccountAnnotations, serviceAnnotations).
*/}}
{{- define "rpi.mergedAnnotations" -}}
{{- $common := .root.Values.commonAnnotations | default dict -}}
{{- $extra := dict -}}
{{- if eq .type "serviceAccount" -}}
{{- $extra = .root.Values.serviceAccountAnnotations | default dict -}}
{{- else if eq .type "service" -}}
{{- $extra = .root.Values.serviceAnnotations | default dict -}}
{{- end -}}
{{- $merged := mustMergeOverwrite (dict) $common $extra -}}
{{- if $merged -}}
{{- toYaml $merged -}}
{{- end -}}
{{- end -}}