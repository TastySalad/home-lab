apiVersion: v1
kind: Secret
metadata:
  name: {{ include "party.fullname" . }}-owner
  labels:
    {{- include "party.labels" . | nindent 4 }}
type: Opaque
stringData:
  PARTY_OWNER_TOKEN: {{ .Values.ownerToken | quote }}
