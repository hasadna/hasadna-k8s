{{- define "server.container" }}
name: server
image: ghcr.io/hasadna/meirim/meirim-server:2d6981b429b7d950483d393bc3cc5e7e609d80b5
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
