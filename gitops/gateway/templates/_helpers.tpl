{{/*
Chart name used in labels/selectors.
*/}}
{{- define "gateway.name" -}}
{{- .Chart.Name -}}
{{- end -}}

{{/*
Fully qualified app name — "gateway" plus the release name, unless the
release name is itself already "gateway".
*/}}
{{- define "gateway.fullname" -}}
{{- if eq .Release.Name (include "gateway.name" .) -}}
{{- .Release.Name -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name (include "gateway.name" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}

{{/*
Common labels applied to every object this chart creates.
*/}}
{{- define "gateway.labels" -}}
app: gateway
app.kubernetes.io/name: {{ include "gateway.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
helm.sh/chart: {{ printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" }}
{{- end -}}

{{/*
Selector labels — must stay stable across releases (these are what the
Service, and the gateway-policy NetworkPolicy's pod_selector, match on).
*/}}
{{- define "gateway.selectorLabels" -}}
app: gateway
app.kubernetes.io/name: {{ include "gateway.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}
