{{- define "custom.namespace" -}}
  {{- if .Values.global.namespace }}
    {{- .Values.global.namespace }}
  {{- else }}
    {{- .Release.Namespace }}
  {{- end }}
{{- end }}

{{- define "custom.replicaCount" -}}
  {{- if .Values.global.replicaCount }}
    {{- .Values.global.replicaCount }}
  {{- else }}
    {{- .Values.replicaCount }}
  {{- end }}
{{- end }}