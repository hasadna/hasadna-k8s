{{- define "server.container" }}
name: server
image: {{ .Values.serverImage | quote }}
resources:
  requests:
    cpu: "500m"
    memory: "1Gi"
  limits:
    cpu: "1"
    memory: "2Gi"
envFrom:
  - secretRef:
      name: meirim-server-env
env:
  - name: SERVER_DATABASE_HOST
    value: "meirim-mariadb"
{{- end }}
