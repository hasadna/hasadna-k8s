# Odata (ckan) chart

## Installation

### Setup

#### Minikube environment for local development

* [Install Minikube](https://kubernetes.io/docs/tasks/tools/install-minikube/)
* Switch to the odata-minikube environment
  * `source switch_environment.sh odata-minikube`
* Make sure you are connected to your local minikube environment
  * `kubectl get nodes`
  * Should see a single `minikube` node
* Create the odata-minikube namespace
  * `kubectl create ns odata-minikube`
* Install the helm client
  * To make sure you get corret version you should use the script in this repo
  * `bash apps_travis_script.sh install_helm`
  * if you have problems, refer to helm docs - [helm client](https://docs.helm.sh/using_helm/#installing-the-helm-client)
* Install the helm server-side component on your minikube cluster
  * `helm init --history-max 2 --upgrade --wait`
* Verify helm installation
  * `helm version`

#### Production environment on hasadna cluster

* Switch to the odata environment
  * `source switch_environment.sh odata`
* Make sure you are connected to the correct cluster
  * `kubectl get nodes`
* Create the odata namespace
  * `kubectl create ns odata`
* Install the helm client
  * To make sure you get corret version you should use the script in this repo
  * `bash apps_travis_script.sh install_helm`
  * if you have problems, refer to helm docs - [helm client](https://docs.helm.sh/using_helm/#installing-the-helm-client)
* Verify helm installation
  * `helm version`

### Create Secrets

```
export POSTGRES_PASSWORD=123456
export CKAN_BEAKER_SESSION_SECRET=`python -c "import binascii,os;print(binascii.hexlify(os.urandom(25)))"`
export CKAN_APP_INSTANCE_UUID=`python -c "import uuid;print(uuid.uuid1())"`
kubectl create secret generic env-vars --from-literal=CKAN_APP_INSTANCE_UUID=$CKAN_APP_INSTANCE_UUID \
                                       --from-literal=CKAN_BEAKER_SESSION_SECRET=$CKAN_BEAKER_SESSION_SECRET \
                                       --from-literal=POSTGRES_PASSWORD=$POSTGRES_PASSWORD
export CKAN_SQLALCHEMY_URL="postgresql://postgres:${POSTGRES_PASSWORD}@db/ckan"
export CKAN_SITE_URL="https://www.odata.org.il/"
export CKAN_SOLR_URL="http://solr:8983/solr/"
export CKAN_REDIS_URL="redis://redis:6379/0"
export CKAN_STORAGE_PATH="/var/lib/ckan/data"
export CKAN_MAX_RESOURCE_SIZE="500"
export CKAN_DEBUG=false
export COMMENT="-- This file contains secrets, do not commit / expose publicly! --"
TEMP_DIR=`mktemp -d`
./templater.sh charts-external/odata/who.ini.template > $TEMP_DIR/who.ini
./templater.sh charts-external/odata/development.ini.template > $TEMP_DIR/development.ini
kubectl create secret generic etc-ckan-default --from-file $TEMP_DIR/
rm -rf $TEMP_DIR
```

### Copy Google disk snapshots

Skip this step for Minikube environment

For the production environment on Google cloud you can copy existing disk snapshots to restore from backup

Create snapshots

```
gcloud compute disks snapshot gke-data4dappl-092038f-pvc-95731349-9b0d-11e7-855b-42010a80019d \
  --snapshot-names="odata-db" \
  --project=hasadna-odata --zone=us-central1-a
gcloud compute disks snapshot gke-data4dappl-092038f-pvc-9bd4aae7-9a25-11e7-855b-42010a80019d \
  --snapshot-names="odata-ckan-data" \
  --project=hasadna-odata --zone=us-central1-a
```

Create disks from the snapshots

```
gcloud compute disks create odata-db \
  --source-snapshot=$(gcloud compute snapshots describe odata-db --project=hasadna-odata --format json | jq -r .selfLink) \
  --project=hasadna-general --zone=europe-west1-b
gcloud compute disks create odata-ckan-data \
  --source-snapshot=$(gcloud compute snapshots describe odata-ckan-data --project=hasadna-odata --format json | jq -r .selfLink) \
  --project=hasadna-general --zone=europe-west1-b
```

Update the relevant values: `ckanDataPersistentDiskName` / `ckanDbPersistentDiskName`

### Deploy infrastructure components

```
./helm_upgrade_external_chart.sh odata --install --debug --set ckanDeploymentEnabled=false
```

Check that all the pods started

### Initiate the DB from backup

For minikube environment you must restore the DB from backup

For GKE environment - you can skip this step, if you created from existing disk / snapshot

The backup is private, you should have permissions to the relevant google storage

```
charts-external/odata/utils/initiate_db_from_backup.sh gs://odata-k8s-backups/production/ckan-db-dump-2018-08-06.gz
```

### Deploy all the remaining components

```
./helm_upgrade_external_chart.sh odata --debug
```

## Common Tasks

### Access the ckan web app directly

```
charts-external/odata/utils/ckan-port-forward.sh
```

Ckan will be available at http://localhost:5000/

### Create an admin user

```
charts-external/odata/utils/ckan-sysadmin.sh add minikube-admin email=minikube-admin@odata.org.il
```

### Rebuild the search index

```
charts-external/odata/utils/ckan-search-index.sh rebuild
```

### Initiate the data from backup

You should have permissions to the relevant google storage and enough local free disk space

```
charts-external/odata/utils/initiate_data_from_backup.sh gs://odata-k8s-backups/production/ckan-data-2018-08-13.tar.bz2
```

## Updating ckan configuration

Edit `charts-external/odata/development.ini.template` - make the required changes

Extract the required secrets from env-vars secret

```
export CKAN_APP_INSTANCE_UUID=`kubectl get secret env-vars -o json | jq -r .data.CKAN_APP_INSTANCE_UUID | base64 -d`
export CKAN_BEAKER_SESSION_SECRET=`kubectl get secret env-vars -o json | jq -r .data.CKAN_BEAKER_SESSION_SECRET | base64 -d`
export POSTGRES_PASSWORD=`kubectl get secret env-vars -o json | jq -r .data.POSTGRES_PASSWORD | base64 -d`
```

Proceed with create secrets procedure from initial installation but use a different name e.g. etc-ckan-default-2

Update the values file etcCkanDefaultSecretName attribute to the new name

Deploy

## Backups

Backups are generated daily and uploaded to google storage

You can also run a backup manually:

```
./kubectl.sh exec db -c db -- bash /db-scripts/backup.sh &&\
./kubectl.sh logs db -c db-ops -f
```
