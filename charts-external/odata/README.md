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
charts-external/odata/update-ckan-configuration.sh
```

To run the CKAN pipelines server you will also need to provide a CKAN api key with sysadmin privileges.

Each user has an API key which is displayed in the user's profile page

```
kubectl create secret generic pipelines --from-literal=CKAN_API_KEY=***
```

Upload via email requires the following secret - after creating it you should re-run update-ckan-configuration.sh script

```
kubectl create secret generic env-vars-upload-via-email --from-literal=GMAIL_TOKEN=*** \
                                                        --from-literal=ALLOWED_SENDERS_RESOURCE_ID=***
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

For GKE environment - you can skip this step if you created from existing disk / snapshot

The backup is private, you should have permissions to the relevant google storage

```
charts-external/odata/utils/initiate_db_from_backup.sh gs://odata-k8s-backups/production/ckan-db-dump-2018-09-24.ckan.dump
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

Create new updated secret

```
charts-external/odata/update-ckan-configuration.sh
```

Update the values file etcCkanDefaultSecretName attribute to the new name

Deploy

You should delete old secrets once you are certain they won't be needed for rollback

```
charts-external/odata/delete-old-ckan-configurations.sh
```

## Backups

Backups are generated daily and uploaded to google storage

You can also run a backup manually:

```
./kubectl.sh exec db -c db -- bash /db-scripts/backup.sh &&\
./kubectl.sh logs db -c db-ops -f
```

## Blue/Green deployment

* Switch to environment with a namespace suffix
  ```source switch_environment.sh odata green```
* Create the namespace
  * ```kubectl create ns odata-green```
* Override values for the namespace suffix in `environments/odata/values.green.yaml`
  * Set empty strings for the persistent disk names - to prevent collision with existing persistent disks
* Create secrets and continue deployment normally (follow steps above)
* When new deployment is stable, create new persistent disks:
  * `gcloud compute disks create odata-green-db --size=20`
* Switch to current live environment:
  * `source switch_environment.sh odata`
* Take snapshot of data volume (which will be discarded but will speed up snapshot later):
  * ```gcloud compute disks snapshot $(eval echo `./read_env_yaml.sh odata nfsGcePersistentDiskName`)```
* Deploy without the ckan deployment (causing down-time):
  * `./helm_upgrade_external_chart.sh odata --install --debug --set ckanDeploymentEnabled=false`
* Take snapshot of data volume and create disk from it:
  * ```gcloud compute disks snapshot $(eval echo `./read_env_yaml.sh odata nfsGcePersistentDiskName`) --snapshot-names odata-before-green-nfs```
  * ```gcloud compute disks create odata-green-nfs --size=100 --source-snapshot=odata-before-green-nfs```
* Create and upload a DB backup:
```
kubectl exec -it $(kubectl get pods -l app=db -o 'jsonpath={.items[0].metadata.name}') -- \
    bash -c "BACKUP_DATABASE_NAME=ckan BACKUP_DATABASE_FILE=/ckan.dump bash /db-scripts/backup.sh" &&\
kubectl cp $(kubectl get pods -l app=db -o 'jsonpath={.items[0].metadata.name}'):/ckan.dump ./ckan.dump &&\
gsutil cp ./ckan.dump gs://odata-k8s-backups/production/ckan-before-green-`date +%Y%m%d`.dump
```
* Switch to the new environment
  * ```source switch_environment.sh odata green```
* Update relevant environment's `values.yaml` persistent disk names and db restore
  * ```ckanDbPersistentDiskName: odata-green-db```
  * ```nfsGcePersistentDiskName: odata-green-nfs```
  * ```nfsPersistentVolumeName: odata-green-nfs-gcepd```
* Enable db-ops, disable backup and enable restore from created backup:
```
  dbOps:
    enabled: true
#    backup: "gs://odata-k8s-backups/production/ckan-db-dump-"
    restore: "gs://odata-k8s-backups/production/ckan-before-green-20180925.dump"
```
* Deploy new environment
  * ```./helm_upgrade_external_chart.sh odata```
* update the load balancer backend target to the new namespace
  * Edit `environments/hasadna/values.yaml`
  * Set odata backend rule to `backendUrl: "http://ckan.odata-green:5000"`
* Deploy traefik
  * `source switch_environment.sh hasadna`
  * `./helm_upgrade_external_chart.sh traefik`
* update main environment's .env file (`environments/odata/.env`) to the new namespace
  * `K8S_NAMESPACE=odata-green`
* merge `values.green.yaml` with `values.yaml`
* update `charts-config.yaml` to point to the new namespace for the continuous deployment
* Enable DB backup
  * Edit `environments/odata/values.yaml`, under dbOps: disable restore and enable backup
  * `source switch_environment.sh odata`
  * `./helm_upgrade_external_chart.sh odata`
* Delete helm release of previous environment
  * helm delete --purge odata-odata-odata
* Delete persistent disks of previous environment
