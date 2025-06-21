{{- define "runner.volumes" }}
- name: host-dev
  hostPath:
    path: /dev
- name: host-modules
  hostPath:
    path: /lib/modules
{{- end }}

{{- define "runner.podSpec" }}
image: ghcr.io/hasadna/hasadna-k8s/hasadna-k8s:latest
imagePullPolicy: Always
env:
  - name: KOPIA_CHECK_FOR_UPDATES
    value: "false"
  - name: KOPIA_PASSWORD
    valueFrom:
      secretKeyRef:
        name: kopia
        key: password
  - name: KOPIA_S3_BUCKET
    valueFrom:
      secretKeyRef:
        name: kopia
        key: bucket_name
  - name: KOPIA_S3_REGION
    valueFrom:
      secretKeyRef:
        name: kopia
        key: bucket_region
  - name: AWS_ACCESS_KEY_ID
    valueFrom:
      secretKeyRef:
        name: kopia
        key: aws_access_key_id
  - name: AWS_SECRET_ACCESS_KEY
    valueFrom:
      secretKeyRef:
        name: kopia
        key: aws_secret_access_key
  - name: ROOK_CEPH_USERNAME
    valueFrom:
      secretKeyRef:
        name: rook-ceph-mon
        key: ceph-username
  - name: ROOK_CEPH_KEYRING
    valueFrom:
      secretKeyRef:
        name: rook-ceph-mon
        key: ceph-secret
volumeMounts:
  - name: host-dev
    mountPath: /dev
  - name: host-modules
    mountPath: /lib/modules
securityContext:
  privileged: true
  runAsUser: 0
command: [bash]
{{- end }}