apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ include "party.fullname" . }}
  labels:
    {{- include "party.labels" . | nindent 4 }}
spec:
  replicas: {{ .Values.replicaCount }}
  # single stateful RSVP store — never run two replicas (they'd clobber the
  # same JSON file). Recreate, not RollingUpdate, for the same reason.
  strategy:
    type: Recreate
  selector:
    matchLabels:
      {{- include "party.selectorLabels" . | nindent 6 }}
  template:
    metadata:
      labels:
        {{- include "party.selectorLabels" . | nindent 8 }}
    spec:
      # ----------------------------------------------------------------------
      # PUBLIC edge: run on the VPS node with hostNetwork so the container can
      # bind the node's public port 80 directly. Same mechanism as the
      # minecraft-proxy precedent (hostNetwork + hostPort on racknerd-vps).
      # Cloudflare terminates TLS for party.salad-playground.party and forwards
      # plain HTTP to our :80 — so no in-cluster ingress/LB is needed.
      #
      # Running as root inside the (isolated) container is required to bind :80
      # on Ubuntu 24.04 (ip_unprivileged_port_start=1024). See Dockerfile.
      # ----------------------------------------------------------------------
      hostNetwork: true
      dnsPolicy: ClusterFirstWithHostNet
      {{- with .Values.imagePullSecrets }}
      imagePullSecrets:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      affinity:
        nodeAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
            nodeSelectorTerms:
              - matchExpressions:
                  - key: kubernetes.io/hostname
                    operator: In
                    values:
                      - {{ .Values.node | quote }}
      containers:
        - name: party
          image: "{{ .Values.image.repository }}:{{ .Values.image.tag }}"
          imagePullPolicy: {{ .Values.image.pullPolicy }}
          ports:
            - name: http
              containerPort: {{ .Values.containerPort }}
              hostPort: {{ .Values.hostPort }}
              protocol: TCP
          env:
            - name: PARTY_PORT
              value: {{ .Values.containerPort | quote }}
            - name: PARTY_WEB
              value: /app/web
            - name: PARTY_DATA
              value: /data/rsvps.json
            - name: PARTY_OWNER_TOKEN
              valueFrom:
                secretKeyRef:
                  name: {{ include "party.fullname" . }}-owner
                  key: PARTY_OWNER_TOKEN
          readinessProbe:
            httpGet:
              path: /healthz
              port: http
            initialDelaySeconds: 2
            periodSeconds: 10
          livenessProbe:
            httpGet:
              path: /healthz
              port: http
            initialDelaySeconds: 5
            periodSeconds: 20
          resources:
            {{- toYaml .Values.resources | nindent 12 }}
          volumeMounts:
            - name: data
              mountPath: /data
      {{- with .Values.tolerations }}
      tolerations:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      volumes:
        - name: data
          persistentVolumeClaim:
            claimName: {{ include "party.fullname" . }}-data
      terminationGracePeriodSeconds: 10
