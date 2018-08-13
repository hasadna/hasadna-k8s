# odata minikube environment

Allows to test odata kubernetes environment locally

## Install

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

## Create secrets

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
mkdir -p $TEMP_DIR/etc-ckan-default
./templater.sh charts-external/odata/who.ini.template > $TEMP_DIR/who.ini
./templater.sh charts-external/odata/development.ini.template > $TEMP_DIR/development.ini
kubectl create secret generic etc-ckan-default --from-file $TEMP_DIR/
rm -rf $TEMP_DIR
```

## Deploy infrastructure components

```
./helm_upgrade_external_chart.sh odata --install --debug --set ckanDeploymentEnabled=false
```

## Initiate the DB from backup

The backup is private, you should have permissions to the relevant google storage

```
charts-external/odata/utils/initiate_db_from_backup.sh gs://odata-k8s-backups/production/ckan-db-dump-2018-08-06.gz
```

## Deploy all the components

```
./helm_upgrade_external_chart.sh odata --debug
```

### Post deployment tasks

#### Access the ckan web app

```
charts-external/odata/utils/ckan-port-forward.sh
```

Ckan will be available at http://localhost:5000/

#### Create an admin user

```
charts-external/odata/utils/ckan-sysadmin.sh add minikube-admin email=minikube-admin@odata.org.il
```

#### Initiate the data from backup

You should have permissions to the relevant google storage and enough local free disk space

```
charts-external/odata/utils/initiate_data_from_backup.sh gs://odata-k8s-backups/production/ckan-data-2018-08-13.tar.bz2
```

#### Rebuild the search index

```
charts-external/odata/utils/ckan-search-index.sh rebuild
```
