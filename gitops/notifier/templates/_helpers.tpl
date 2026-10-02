{{- define "notifier.name" -}}
{{- .Chart.Name -}}
{{- end -}}

{{- define "notifier.fullname" -}}
{{- if eq .Release.Name (include "notifier.name" .) -}}
{{- .Release.Name -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name (include "notifier.name" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}

{{- define "notifier.labels" -}}
app: notifier
app.kubernetes.io/name: {{ include "notifier.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
helm.sh/chart: {{ printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" }}
{{- end -}}

{{/*
Matches the notifier-policy NetworkPolicy's pod_selector exactly — keep
this label unconditional, never derived from the release name.
*/}}
{{- define "notifier.selectorLabels" -}}
app: notifier
app.kubernetes.io/name: {{ include "notifier.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}
