{{- define "screening.name" -}}
{{- .Chart.Name -}}
{{- end -}}

{{- define "screening.fullname" -}}
{{- if eq .Release.Name (include "screening.name" .) -}}
{{- .Release.Name -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name (include "screening.name" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}

{{- define "screening.labels" -}}
app: screening
app.kubernetes.io/name: {{ include "screening.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
helm.sh/chart: {{ printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" }}
{{- end -}}

{{/*
Matches the screening-policy NetworkPolicy's pod_selector exactly —
keep this label unconditional, never derived from the release name.
*/}}
{{- define "screening.selectorLabels" -}}
app: screening
app.kubernetes.io/name: {{ include "screening.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}
