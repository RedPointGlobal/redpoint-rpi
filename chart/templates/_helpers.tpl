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
Default security context for RPI services
*/}}
{{- define "redpoint-rpi.securityContext" -}}
securityContext:
  runAsUser: {{ (fromYaml (include "rpi.merged.securityContext" .)).runAsUser }}
  runAsGroup: {{ (fromYaml (include "rpi.merged.securityContext" .)).runAsGroup }}
  fsGroup: {{ (fromYaml (include "rpi.merged.securityContext" .)).fsGroup }}
  runAsNonRoot: {{ (fromYaml (include "rpi.merged.securityContext" .)).runAsNonRoot }}
  seccompProfile:
    type: RuntimeDefault
{{- end }}

{{/*
Default container security context for RPI services
*/}}
{{- define "redpoint-rpi.containerSecurityContext" -}}
securityContext:
  readOnlyRootFilesystem: {{ .readOnlyRootFilesystem | default true }}
  allowPrivilegeEscalation: false
  privileged: false
  capabilities:
    drop:
      - ALL
{{- end }}

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
{{- $redshift := $dw.redshift | default dict -}}
{{- $bigquery := $dw.bigquery | default dict -}}
{{- $databricks := $dw.databricks | default dict -}}

{{- $redshiftEnabled := $redshift.enabled | default false -}}
{{- $bigqueryEnabled := $bigquery.enabled | default false -}}
{{- $databricksEnabled := $databricks.enabled | default false -}}

{{- if or $redshiftEnabled $bigqueryEnabled $databricksEnabled -}}
true
{{- else -}}
false
{{- end -}}
{{- end }}

{{/* ============================================================
     MERGE HELPERS
     ============================================================
     Each helper merges: defaults + advanced overrides + user values.
     Usage in templates:
       {{- $cfg := fromYaml (include "rpi.merged.realtimeapi" .) -}}
     ============================================================ */}}

{{/* --- Component merge helpers --- */}}

{{- define "rpi.merged.realtimeapi" -}}
{{- $d := fromYaml (include "rpi.defaults.realtimeapi" .) -}}
{{- $a := ((.Values.advanced).realtimeapi) | default dict -}}
{{- $u := .Values.realtimeapi | default dict -}}
{{- toYaml (mustMergeOverwrite $d $u $a) -}}
{{- end -}}

{{- define "rpi.merged.callbackapi" -}}
{{- $d := fromYaml (include "rpi.defaults.callbackapi" .) -}}
{{- $a := ((.Values.advanced).callbackapi) | default dict -}}
{{- $u := .Values.callbackapi | default dict -}}
{{- toYaml (mustMergeOverwrite $d $u $a) -}}
{{- end -}}

{{- define "rpi.merged.executionservice" -}}
{{- $d := fromYaml (include "rpi.defaults.executionservice" .) -}}
{{- $a := ((.Values.advanced).executionservice) | default dict -}}
{{- $u := .Values.executionservice | default dict -}}
{{- toYaml (mustMergeOverwrite $d $u $a) -}}
{{- end -}}

{{- define "rpi.merged.interactionapi" -}}
{{- $d := fromYaml (include "rpi.defaults.interactionapi" .) -}}
{{- $a := ((.Values.advanced).interactionapi) | default dict -}}
{{- $u := .Values.interactionapi | default dict -}}
{{- toYaml (mustMergeOverwrite $d $u $a) -}}
{{- end -}}

{{- define "rpi.merged.integrationapi" -}}
{{- $d := fromYaml (include "rpi.defaults.integrationapi" .) -}}
{{- $a := ((.Values.advanced).integrationapi) | default dict -}}
{{- $u := .Values.integrationapi | default dict -}}
{{- toYaml (mustMergeOverwrite $d $u $a) -}}
{{- end -}}

{{- define "rpi.merged.nodemanager" -}}
{{- $d := fromYaml (include "rpi.defaults.nodemanager" .) -}}
{{- $a := ((.Values.advanced).nodemanager) | default dict -}}
{{- $u := .Values.nodemanager | default dict -}}
{{- toYaml (mustMergeOverwrite $d $u $a) -}}
{{- end -}}

{{- define "rpi.merged.deploymentapi" -}}
{{- $d := fromYaml (include "rpi.defaults.deploymentapi" .) -}}
{{- $a := ((.Values.advanced).deploymentapi) | default dict -}}
{{- $u := .Values.deploymentapi | default dict -}}
{{- toYaml (mustMergeOverwrite $d $u $a) -}}
{{- end -}}

{{- define "rpi.merged.queuereader" -}}
{{- $d := fromYaml (include "rpi.defaults.queuereader" .) -}}
{{- $a := ((.Values.advanced).queuereader) | default dict -}}
{{- $u := .Values.queuereader | default dict -}}
{{- toYaml (mustMergeOverwrite $d $u $a) -}}
{{- end -}}

{{- define "rpi.merged.rebrandly" -}}
{{- $d := fromYaml (include "rpi.defaults.rebrandly" .) -}}
{{- $a := ((.Values.advanced).rebrandly) | default dict -}}
{{- $u := .Values.rebrandly | default dict -}}
{{- toYaml (mustMergeOverwrite $d $u $a) -}}
{{- end -}}

{{- define "rpi.merged.authservice" -}}
{{- $d := fromYaml (include "rpi.defaults.authservice" .) -}}
{{- $a := ((.Values.advanced).authservice) | default dict -}}
{{- $u := .Values.authservice | default dict -}}
{{- toYaml (mustMergeOverwrite $d $u $a) -}}
{{- end -}}

{{- define "rpi.merged.keycloak" -}}
{{- $d := fromYaml (include "rpi.defaults.keycloak" .) -}}
{{- $a := ((.Values.advanced).keycloak) | default dict -}}
{{- $u := .Values.keycloak | default dict -}}
{{- toYaml (mustMergeOverwrite $d $u $a) -}}
{{- end -}}

{{- define "rpi.merged.initservice" -}}
{{- $d := fromYaml (include "rpi.defaults.initservice" .) -}}
{{- $a := ((.Values.advanced).initservice) | default dict -}}
{{- $u := .Values.initservice | default dict -}}
{{- toYaml (mustMergeOverwrite $d $u $a) -}}
{{- end -}}

{{- define "rpi.merged.messageq" -}}
{{- $d := fromYaml (include "rpi.defaults.messageq" .) -}}
{{- $a := ((.Values.advanced).messageq) | default dict -}}
{{- $u := .Values.messageq | default dict -}}
{{- toYaml (mustMergeOverwrite $d $u $a) -}}
{{- end -}}

{{- define "rpi.merged.maintenanceservice" -}}
{{- $d := fromYaml (include "rpi.defaults.maintenanceservice" .) -}}
{{- $a := ((.Values.advanced).maintenanceservice) | default dict -}}
{{- $u := .Values.maintenanceservice | default dict -}}
{{- toYaml (mustMergeOverwrite $d $u $a) -}}
{{- end -}}

{{- define "rpi.merged.servicesapi" -}}
{{- $d := fromYaml (include "rpi.defaults.servicesapi" .) -}}
{{- $a := ((.Values.advanced).servicesapi) | default dict -}}
{{- $u := .Values.servicesapi | default dict -}}
{{- toYaml (mustMergeOverwrite $d $u $a) -}}
{{- end -}}

{{- define "rpi.merged.socketio" -}}
{{- $d := fromYaml (include "rpi.defaults.socketio" .) -}}
{{- $a := ((.Values.advanced).socketio) | default dict -}}
{{- $u := .Values.socketio | default dict -}}
{{- toYaml (mustMergeOverwrite $d $u $a) -}}
{{- end -}}

{{- define "rpi.merged.uiservice" -}}
{{- $d := fromYaml (include "rpi.defaults.uiservice" .) -}}
{{- $a := ((.Values.advanced).uiservice) | default dict -}}
{{- $u := .Values.uiservice | default dict -}}
{{- toYaml (mustMergeOverwrite $d $u $a) -}}
{{- end -}}

{{- define "rpi.merged.cdpcache" -}}
{{- $d := fromYaml (include "rpi.defaults.cdpcache" .) -}}
{{- $a := ((.Values.advanced).cdpcache) | default dict -}}
{{- $u := .Values.cdpcache | default dict -}}
{{- toYaml (mustMergeOverwrite $d $u $a) -}}
{{- end -}}

{{/* --- Cross-cutting merge helpers --- */}}

{{- define "rpi.merged.securityContext" -}}
{{- $d := fromYaml (include "rpi.defaults.securityContext" .) -}}
{{- $a := ((.Values.advanced).securityContext) | default dict -}}
{{- $u := .Values.securityContext | default dict -}}
{{- toYaml (mustMergeOverwrite $d $u $a) -}}
{{- end -}}

{{- define "rpi.merged.livenessProbe" -}}
{{- $d := fromYaml (include "rpi.defaults.livenessProbe" .) -}}
{{- $a := ((.Values.advanced).livenessProbe) | default dict -}}
{{- $u := .Values.livenessProbe | default dict -}}
{{- toYaml (mustMergeOverwrite $d $u $a) -}}
{{- end -}}

{{- define "rpi.merged.readinessProbe" -}}
{{- $d := fromYaml (include "rpi.defaults.readinessProbe" .) -}}
{{- $a := ((.Values.advanced).readinessProbe) | default dict -}}
{{- $u := .Values.readinessProbe | default dict -}}
{{- toYaml (mustMergeOverwrite $d $u $a) -}}
{{- end -}}

{{- define "rpi.merged.startupProbe" -}}
{{- $d := fromYaml (include "rpi.defaults.startupProbe" .) -}}
{{- $a := ((.Values.advanced).startupProbe) | default dict -}}
{{- $u := .Values.startupProbe | default dict -}}
{{- toYaml (mustMergeOverwrite $d $u $a) -}}
{{- end -}}

{{- define "rpi.merged.topologySpreadConstraints" -}}
{{- $d := fromYaml (include "rpi.defaults.topologySpreadConstraints" .) -}}
{{- $a := ((.Values.advanced).topologySpreadConstraints) | default dict -}}
{{- $u := .Values.topologySpreadConstraints | default dict -}}
{{- toYaml (mustMergeOverwrite $d $u $a) -}}
{{- end -}}

{{- define "rpi.merged.ingress" -}}
{{- $d := fromYaml (include "rpi.defaults.ingress" .) -}}
{{- $a := ((.Values.advanced).ingress) | default dict -}}
{{- $u := .Values.ingress | default dict -}}
{{- toYaml (mustMergeOverwrite $d $u $a) -}}
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
{{- $a := ((.Values.advanced).diagnosticsMode) | default dict -}}
{{- $u := .Values.diagnosticsMode | default dict -}}
{{- toYaml (mustMergeOverwrite $d $u $a) -}}
{{- end -}}

{{- define "rpi.merged.networkPolicy" -}}
{{- $d := fromYaml (include "rpi.defaults.networkPolicy" .) -}}
{{- $a := ((.Values.advanced).networkPolicy) | default dict -}}
{{- $u := .Values.networkPolicy | default dict -}}
{{- toYaml (mustMergeOverwrite $d $u $a) -}}
{{- end -}}

{{- define "rpi.merged.postInstall" -}}
{{- $d := fromYaml (include "rpi.defaults.postInstall" .) -}}
{{- $a := ((.Values.advanced).postInstall) | default dict -}}
{{- $u := .Values.postInstall | default dict -}}
{{- toYaml (mustMergeOverwrite $d $u $a) -}}
{{- end -}}

{{- define "rpi.merged.databaseUpgrade" -}}
{{- $d := fromYaml (include "rpi.defaults.databaseUpgrade" .) -}}
{{- $a := ((.Values.advanced).databaseUpgrade) | default dict -}}
{{- $u := .Values.databaseUpgrade | default dict -}}
{{- toYaml (mustMergeOverwrite $d $u $a) -}}
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
Usage: {{ include "rpi.serviceAccountName" (dict "root" . "name" $name) }}
  - root: the top-level context (.)
  - name: the per-service SA name (e.g., "rpi-realtimeapi")
*/}}
{{- define "rpi.serviceAccountName" -}}
{{- if .root.Values.cloudIdentity.serviceAccount.create -}}
{{ .root.Values.cloudIdentity.serviceAccount.name | default "redpoint-rpi" }}
{{- else -}}
{{ .name }}
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