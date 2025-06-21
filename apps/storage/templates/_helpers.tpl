{{- define "runner.volumes" }}
  - name: host-dev
    hostPath:
      path: /dev
  - name: host-modules
    hostPath:
      path: /lib/modules
{{- end }}
