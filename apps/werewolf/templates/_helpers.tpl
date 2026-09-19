{{- define "werewolf.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "werewolf.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $name := default .Chart.Name .Values.nameOverride -}}
{{- if contains $name .Release.Name -}}
{{- .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{- define "werewolf.labels" -}}
helm.sh/chart: {{ include "werewolf.name" . }}-{{ .Chart.Version }}
{{ include "werewolf.selectorLabels" . }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end -}}

{{- define "werewolf.selectorLabels" -}}
app.kubernetes.io/name: {{ include "werewolf.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app: werewolf
{{- end -}}

{{- define "werewolf.serviceAccountName" -}}
default
{{- end -}}
