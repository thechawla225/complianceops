{{- define "transaction.name" -}}
{{- .Chart.Name -}}
{{- end -}}

{{- define "transaction.fullname" -}}
{{- if eq .Release.Name (include "transaction.name" .) -}}
{{- .Release.Name -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name (include "transaction.name" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}

{{- define "transaction.labels" -}}
app: transaction
app.kubernetes.io/name: {{ include "transaction.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
helm.sh/chart: {{ printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" }}
{{- end -}}

{{/*
Matches the transaction-policy NetworkPolicy's pod_selector exactly —
keep this label unconditional, never derived from the release name.
*/}}
{{- define "transaction.selectorLabels" -}}
app: transaction
app.kubernetes.io/name: {{ include "transaction.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}
