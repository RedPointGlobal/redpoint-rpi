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
helm.sh/chart: {{ include "redpoint-rpi.chart" .root }}
app.kubernetes.io/name: {{ .name | default (include "redpoint-rpi.fullname" .root) }}
app.kubernetes.io/instance: {{ .root.Release.Name }}
app.kubernetes.io/managed-by: {{ .root.Release.Service }}
app.kubernetes.io/part-of: rpi
app.kubernetes.io/component: {{ .component }}
{{- end }}

{{/*
Common labels.
Usage:
{{ include "smartactivation.componentLabels" (dict "root" . "component" "api") }}
*/}}
{{- define "smartactivation.componentLabels" -}}
helm.sh/chart: {{ include "redpoint-rpi.chart" .root }}
app.kubernetes.io/name: {{ .name | default (include "redpoint-rpi.fullname" .root) }}
app.kubernetes.io/instance: {{ .root.Release.Name }}
app.kubernetes.io/managed-by: {{ .root.Release.Service }}
app.kubernetes.io/part-of: smartactivation
app.kubernetes.io/component: {{ .component }}
{{- end }}

{{/*
Default security context for RPI services (.NET-based)
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
{{- if .root(fromYaml (include "rpi.merged.topologySpreadConstraints" .)).enabled }}
topologySpreadConstraints:
  - maxSkew: {{ .root(fromYaml (include "rpi.merged.topologySpreadConstraints" .)).maxSkew | default 1 }}
    topologyKey: {{ .root(fromYaml (include "rpi.merged.topologySpreadConstraints" .)).topologyKey | default "topology.kubernetes.io/zone" }}
    whenUnsatisfiable: {{ .root(fromYaml (include "rpi.merged.topologySpreadConstraints" .)).whenUnsatisfiable | default "ScheduleAnyway" }}
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
{{- toYaml (mustMergeOverwrite $d $a $u) -}}
{{- end -}}

{{- define "rpi.merged.callbackapi" -}}
{{- $d := fromYaml (include "rpi.defaults.callbackapi" .) -}}
{{- $a := ((.Values.advanced).callbackapi) | default dict -}}
{{- $u := .Values.callbackapi | default dict -}}
{{- toYaml (mustMergeOverwrite $d $a $u) -}}
{{- end -}}

{{- define "rpi.merged.executionservice" -}}
{{- $d := fromYaml (include "rpi.defaults.executionservice" .) -}}
{{- $a := ((.Values.advanced).executionservice) | default dict -}}
{{- $u := .Values.executionservice | default dict -}}
{{- toYaml (mustMergeOverwrite $d $a $u) -}}
{{- end -}}

{{- define "rpi.merged.interactionapi" -}}
{{- $d := fromYaml (include "rpi.defaults.interactionapi" .) -}}
{{- $a := ((.Values.advanced).interactionapi) | default dict -}}
{{- $u := .Values.interactionapi | default dict -}}
{{- toYaml (mustMergeOverwrite $d $a $u) -}}
{{- end -}}

{{- define "rpi.merged.integrationapi" -}}
{{- $d := fromYaml (include "rpi.defaults.integrationapi" .) -}}
{{- $a := ((.Values.advanced).integrationapi) | default dict -}}
{{- $u := .Values.integrationapi | default dict -}}
{{- toYaml (mustMergeOverwrite $d $a $u) -}}
{{- end -}}

{{- define "rpi.merged.nodemanager" -}}
{{- $d := fromYaml (include "rpi.defaults.nodemanager" .) -}}
{{- $a := ((.Values.advanced).nodemanager) | default dict -}}
{{- $u := .Values.nodemanager | default dict -}}
{{- toYaml (mustMergeOverwrite $d $a $u) -}}
{{- end -}}

{{- define "rpi.merged.deploymentapi" -}}
{{- $d := fromYaml (include "rpi.defaults.deploymentapi" .) -}}
{{- $a := ((.Values.advanced).deploymentapi) | default dict -}}
{{- $u := .Values.deploymentapi | default dict -}}
{{- toYaml (mustMergeOverwrite $d $a $u) -}}
{{- end -}}

{{- define "rpi.merged.queuereader" -}}
{{- $d := fromYaml (include "rpi.defaults.queuereader" .) -}}
{{- $a := ((.Values.advanced).queuereader) | default dict -}}
{{- $u := .Values.queuereader | default dict -}}
{{- toYaml (mustMergeOverwrite $d $a $u) -}}
{{- end -}}

{{- define "rpi.merged.rebrandly" -}}
{{- $d := fromYaml (include "rpi.defaults.rebrandly" .) -}}
{{- $a := ((.Values.advanced).rebrandly) | default dict -}}
{{- $u := .Values.rebrandly | default dict -}}
{{- toYaml (mustMergeOverwrite $d $a $u) -}}
{{- end -}}

{{- define "rpi.merged.authservice" -}}
{{- $d := fromYaml (include "rpi.defaults.authservice" .) -}}
{{- $a := ((.Values.advanced).authservice) | default dict -}}
{{- $u := .Values.authservice | default dict -}}
{{- toYaml (mustMergeOverwrite $d $a $u) -}}
{{- end -}}

{{- define "rpi.merged.keycloak" -}}
{{- $d := fromYaml (include "rpi.defaults.keycloak" .) -}}
{{- $a := ((.Values.advanced).keycloak) | default dict -}}
{{- $u := .Values.keycloak | default dict -}}
{{- toYaml (mustMergeOverwrite $d $a $u) -}}
{{- end -}}

{{- define "rpi.merged.initservice" -}}
{{- $d := fromYaml (include "rpi.defaults.initservice" .) -}}
{{- $a := ((.Values.advanced).initservice) | default dict -}}
{{- $u := .Values.initservice | default dict -}}
{{- toYaml (mustMergeOverwrite $d $a $u) -}}
{{- end -}}

{{- define "rpi.merged.messageq" -}}
{{- $d := fromYaml (include "rpi.defaults.messageq" .) -}}
{{- $a := ((.Values.advanced).messageq) | default dict -}}
{{- $u := .Values.messageq | default dict -}}
{{- toYaml (mustMergeOverwrite $d $a $u) -}}
{{- end -}}

{{- define "rpi.merged.maintenanceservice" -}}
{{- $d := fromYaml (include "rpi.defaults.maintenanceservice" .) -}}
{{- $a := ((.Values.advanced).maintenanceservice) | default dict -}}
{{- $u := .Values.maintenanceservice | default dict -}}
{{- toYaml (mustMergeOverwrite $d $a $u) -}}
{{- end -}}

{{- define "rpi.merged.servicesapi" -}}
{{- $d := fromYaml (include "rpi.defaults.servicesapi" .) -}}
{{- $a := ((.Values.advanced).servicesapi) | default dict -}}
{{- $u := .Values.servicesapi | default dict -}}
{{- toYaml (mustMergeOverwrite $d $a $u) -}}
{{- end -}}

{{- define "rpi.merged.socketio" -}}
{{- $d := fromYaml (include "rpi.defaults.socketio" .) -}}
{{- $a := ((.Values.advanced).socketio) | default dict -}}
{{- $u := .Values.socketio | default dict -}}
{{- toYaml (mustMergeOverwrite $d $a $u) -}}
{{- end -}}

{{- define "rpi.merged.uiservice" -}}
{{- $d := fromYaml (include "rpi.defaults.uiservice" .) -}}
{{- $a := ((.Values.advanced).uiservice) | default dict -}}
{{- $u := .Values.uiservice | default dict -}}
{{- toYaml (mustMergeOverwrite $d $a $u) -}}
{{- end -}}

{{- define "rpi.merged.cdpcache" -}}
{{- $d := fromYaml (include "rpi.defaults.cdpcache" .) -}}
{{- $a := ((.Values.advanced).cdpcache) | default dict -}}
{{- $u := .Values.cdpcache | default dict -}}
{{- toYaml (mustMergeOverwrite $d $a $u) -}}
{{- end -}}

{{/* --- Cross-cutting merge helpers --- */}}

{{- define "rpi.merged.securityContext" -}}
{{- $d := fromYaml (include "rpi.defaults.securityContext" .) -}}
{{- $a := ((.Values.advanced).securityContext) | default dict -}}
{{- $u := .Values.securityContext | default dict -}}
{{- toYaml (mustMergeOverwrite $d $a $u) -}}
{{- end -}}

{{- define "rpi.merged.livenessProbe" -}}
{{- $d := fromYaml (include "rpi.defaults.livenessProbe" .) -}}
{{- $a := ((.Values.advanced).livenessProbe) | default dict -}}
{{- $u := .Values.livenessProbe | default dict -}}
{{- toYaml (mustMergeOverwrite $d $a $u) -}}
{{- end -}}

{{- define "rpi.merged.readinessProbe" -}}
{{- $d := fromYaml (include "rpi.defaults.readinessProbe" .) -}}
{{- $a := ((.Values.advanced).readinessProbe) | default dict -}}
{{- $u := .Values.readinessProbe | default dict -}}
{{- toYaml (mustMergeOverwrite $d $a $u) -}}
{{- end -}}

{{- define "rpi.merged.startupProbe" -}}
{{- $d := fromYaml (include "rpi.defaults.startupProbe" .) -}}
{{- $a := ((.Values.advanced).startupProbe) | default dict -}}
{{- $u := .Values.startupProbe | default dict -}}
{{- toYaml (mustMergeOverwrite $d $a $u) -}}
{{- end -}}

{{- define "rpi.merged.topologySpreadConstraints" -}}
{{- $d := fromYaml (include "rpi.defaults.topologySpreadConstraints" .) -}}
{{- $a := ((.Values.advanced).topologySpreadConstraints) | default dict -}}
{{- $u := .Values.topologySpreadConstraints | default dict -}}
{{- toYaml (mustMergeOverwrite $d $a $u) -}}
{{- end -}}

{{- define "rpi.merged.ingress" -}}
{{- $d := fromYaml (include "rpi.defaults.ingress" .) -}}
{{- $a := ((.Values.advanced).ingress) | default dict -}}
{{- $u := .Values.ingress | default dict -}}
{{- toYaml (mustMergeOverwrite $d $a $u) -}}
{{- end -}}

{{- define "rpi.merged.diagnosticsMode" -}}
{{- $d := fromYaml (include "rpi.defaults.diagnosticsMode" .) -}}
{{- $a := ((.Values.advanced).diagnosticsMode) | default dict -}}
{{- $u := .Values.diagnosticsMode | default dict -}}
{{- toYaml (mustMergeOverwrite $d $a $u) -}}
{{- end -}}

{{- define "rpi.merged.networkPolicy" -}}
{{- $d := fromYaml (include "rpi.defaults.networkPolicy" .) -}}
{{- $a := ((.Values.advanced).networkPolicy) | default dict -}}
{{- $u := .Values.networkPolicy | default dict -}}
{{- toYaml (mustMergeOverwrite $d $a $u) -}}
{{- end -}}