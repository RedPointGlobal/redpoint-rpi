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
Common labels for a specific component.
Usage: {{ include "redpoint-rpi.componentLabels" (dict "root" . "name" "rpi-realtimeapi" "component" "api") }}
*/}}
{{- define "redpoint-rpi.componentLabels" -}}
helm.sh/chart: {{ include "redpoint-rpi.chart" .root }}
app.kubernetes.io/name: {{ .name }}
app.kubernetes.io/instance: {{ .root.Release.Name }}
app.kubernetes.io/version: {{ .root.Values.global.deployment.images.tag | quote }}
app.kubernetes.io/managed-by: {{ .root.Release.Service }}
app.kubernetes.io/part-of: rpi
app.kubernetes.io/component: {{ .component }}
{{- end }}

{{/*
Default security context for RPI services (.NET-based)
*/}}
{{- define "redpoint-rpi.securityContext" -}}
securityContext:
  runAsUser: {{ .Values.securityContext.runAsUser }}
  runAsGroup: {{ .Values.securityContext.runAsGroup }}
  fsGroup: {{ .Values.securityContext.fsGroup }}
  runAsNonRoot: {{ .Values.securityContext.runAsNonRoot }}
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
{{- if .root.Values.topologySpreadConstraints.enabled }}
topologySpreadConstraints:
  - maxSkew: {{ .root.Values.topologySpreadConstraints.maxSkew | default 1 }}
    topologyKey: {{ .root.Values.topologySpreadConstraints.topologyKey | default "topology.kubernetes.io/zone" }}
    whenUnsatisfiable: {{ .root.Values.topologySpreadConstraints.whenUnsatisfiable | default "ScheduleAnyway" }}
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
