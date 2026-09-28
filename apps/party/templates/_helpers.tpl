{{- define "party.fullname" -}}
{{- if .Values.fullnameOverride }}
{{ .Values.fullnameOverride }}
{{- else }}
{{- .Release.Name }}
{{- end }}
{{- end }}
{{- define "party.labels" -}}
app.kubernetes.io/name: party
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/part-of: home-lab
{{- end }}
{{- define "party.selectorLabels" -}}
app.kubernetes.io/name: party
app.kubernetes.io/instance: {{ .Release.Name }}
app: party
{{- end }}
