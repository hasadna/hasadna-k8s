# Hasadna environment

For cluster-wide stuff

### Installing Heptio Ark - persistent volumes backup

Create a GCS bucket to hold backups

```
gsutil mb -p hasadna-general -c regional -l europe-west1 gs://hasadna-k8s-backups
```

Create a service account for Ark server

```
gcloud --project=hasadna-general iam service-accounts create hasadna-k8s-heptio-ark \
    --display-name "Hasadna K8S Heptio Ark service account"
```

Give permissions to the service account

```
ROLE_PERMISSIONS=(
     compute.disks.get
     compute.disks.create
     compute.disks.createSnapshot
     compute.snapshots.get
     compute.snapshots.create
     compute.snapshots.useReadOnly
     compute.snapshots.delete
     compute.projects.get
)
gcloud iam roles create heptio_ark.server \
     --project hasadna-general \
     --title "Heptio Ark Server" \
     --permissions "$(IFS=","; echo "${ROLE_PERMISSIONS[*]}")" &&\
 gcloud projects add-iam-policy-binding hasadna-general \
     --member serviceAccount:hasadna-k8s-heptio-ark@hasadna-general.iam.gserviceaccount.com \
     --role projects/hasadna-general/roles/heptio_ark.server &&\
gsutil iam ch serviceAccount:hasadna-k8s-heptio-ark@hasadna-general.iam.gserviceaccount.com:objectAdmin gs://hasadna-k8s-backups
```

Make sure you are connected to the relevant environment

```
source switch_environment.sh hasadna
```

Create service account and secret

```
TEMPFILE=`mktemp` &&\
gcloud iam service-accounts keys create $TEMPFILE \
     --iam-account hasadna-k8s-heptio-ark@hasadna-general.iam.gserviceaccount.com &&\
kubectl create secret generic cloud-credentials --namespace heptio-ark --from-file cloud=$TEMPFILE &&\
rm $TEMPFILE
```

Install Heptio Ark prerequisites

```
kubectl apply -f environments/hasadna/manifests/00-prereqs.yaml
```

Deploy Heptio Ark server to the cluster

```
kubectl apply -f environments/hasadna/manifests/00-ark-config.yaml
kubectl apply -f environments/hasadna/manifests/10-deployment.yaml
```

Install Ark client

```
wget https://github.com/heptio/ark/releases/download/v0.9.4/ark-v0.9.4-linux-amd64.tar.gz
tar -xvzf ark-v0.9.4-linux-amd64.tar.gz
sudo mv ark /usr/local/bin/
sudo mv ark-restic-restore-helper /usr/local/bin
rm ark-v0.9.4-linux-amd64.tar.gz
```

Schedule daily cluster-wide backup with retention of 30 days

```
ark schedule create cluster-daily --schedule '0 13 * * *' --ttl 720h0m0s
```
