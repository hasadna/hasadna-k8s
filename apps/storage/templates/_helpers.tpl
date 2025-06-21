{{- define "runner.volumes" }}
- name: host-dev
  hostPath:
    path: /dev
- name: host-modules
  hostPath:
    path: /lib/modules
{{- end }}

{{- define "runner.container" }}
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
command: [bash]
{{- end }}

{{- define "runner.workflowTemplateScriptSource" }}
source: |
  set -euo pipefail
  (
    mkdir -p /etc/ceph
    echo "[global]
  mon_host = rook-ceph-mon-a:6789,rook-ceph-mon-b:6789,rook-ceph-mon-c:6789

  [client.admin]
  keyring = /etc/ceph/keyring" > /etc/ceph/ceph.conf
    echo "[${ROOK_CEPH_USERNAME}]
  key = ${ROOK_CEPH_KEYRING}" > /etc/ceph/keyring
    kopia repository connect s3 --bucket=$KOPIA_S3_BUCKET --region=$KOPIA_S3_REGION
  ) 2>&1 | tee /tmp/log.txt
  cat <<'EOF' > /tmp/exec_script.sh
  {{ "{{inputs.parameters.exec_script}}" }}
  EOF
  chmod +x /tmp/exec_script.sh
  /tmp/exec_script.sh 2>&1 | tee /tmp/log.txt
  echo "Execution completed successfully" 2>&1 | tee /tmp/log.txt
{{- end }}
