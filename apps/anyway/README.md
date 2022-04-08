# Anyway

## Architecture

https://docs.google.com/presentation/d/1bXkcCgsXUr1FQA7hCZdb5_m7IXIiP1UixuOHuV88sfs/edit?usp=sharing

![](image.png)

## Connect to the cluster

### Using Minikube for local testing

* [Install and start a Minikube cluster](https://kubernetes.io/docs/tasks/tools/install-minikube/)
  * When you start the cluster add this argument to set the right Kubernetes version `--kubernetes-version v1.16.7`:
  * Also, recommended to limit resources for the cluster:  `--memory 2048 --cpus 2 --disk-size 15g`
* Make sure you are connected to your local minikube environment
  * `kubectl get nodes`
  * Should see a single `minikube` node
* Set namespace name in env var (will be used in later commands)
  * `NAMESPACE_NAME=anyway-minikube`
* Create the namespace
  * `kubectl create ns $NAMESPACE_NAME`

### Connecting to the production environment

Set the kubeconfig file to the hasadna kamatera kubeconfig

```
export KUBECONFIG=/path/to/kamatera/kubeconfig
```

Set namespace name

```
NAMESPACE_NAME=anyway
```

## Initial Deployment

* Create secrets
  * set env vars with the secret DB values
    * `POSTGRES_PASSWORD=`
    * `ANYWAY_PASSWORD=`
    * `DBRESTORE_AWS_ACCESS_KEY_ID=`
    * `DBRESTORE_AWS_SECRET_ACCESS_KEY=`
    * `DBDUMP_AWS_ACCESS_KEY_ID=`
    * `DBDUMP_AWS_SECRET_ACCESS_KEY=`
  * create the DB secrets:
    * `kubectl -n $NAMESPACE_NAME create secret generic anyway-db "--from-literal=DATABASE_URL=postgresql://anyway:${ANYWAY_PASSWORD}@db/anyway"`
    * `kubectl -n $NAMESPACE_NAME create secret generic db "--from-literal=DBRESTORE_SET_ANYWAY_PASSWORD=${ANYWAY_PASSWORD}" "--from-literal=POSTGRES_PASSWORD=${POSTGRES_PASSWORD}" "--from-literal=DBRESTORE_AWS_ACCESS_KEY_ID=${DBRESTORE_AWS_ACCESS_KEY_ID}" "--from-literal=DBRESTORE_AWS_SECRET_ACCESS_KEY=${DBRESTORE_AWS_SECRET_ACCESS_KEY}"`
    * `kubectl -n $NAMESPACE_NAME create secret generic db-backup "--from-literal=DBDUMP_AWS_ACCESS_KEY_ID=${DBDUMP_AWS_ACCESS_KEY_ID}" "--from-literal=DBDUMP_AWS_SECRET_ACCESS_KEY=${DBDUMP_AWS_SECRET_ACCESS_KEY}" "--from-literal=DBDUMP_PASSWORD=${POSTGRES_PASSWORD}"`
  * Create the anyway secret (see the anyway production docker-compose for available values, or leave it empty just for basic testing)
    * `kubectl -n $NAMESPACE_NAME create secret generic anyway`

## Deployment

* For local deployment on Minikue - use Helm to deploy this chart with the values file `values-minikube.yaml`
* For production deployment - Use ArgoCD, see [/docs/argocd.md](/docs/argocd.md) for details.

## Enable logging

Setup bindplane monitoring target with container logs filter `/var/log/containers/*anyway*.log`

Set the target values in a secret:

```
kubectl -n $NAMESPACE_NAME create secret generic bindplane-logs \
    --from-literal=COMPANY_ID= \
    --from-literal=SECRET_KEY= \
    --from-literal=TEMPLATE_ID=
```

Set enableLogs=true in the environment's values

## Creating a new environment based on existing environment

In this example - production environment will be copied to dev environment

* Copy the values file, e.g. copy from `values-anyway.yaml` to `values-anyway-dev.yaml`
* Modify the values as needed
* Create the namespace - `kubectl create ns anyway-dev`
* Using Rancher - clone the secrets from old to new environment (secrets: `anyway`, `anyway-db`, `db`)
* Deploy

## Enabling the Airflow server

Set the following values in `anyway` secret:

* `AIRFLOW_DB_POSTGRES_PASSWORD`: Generate a password (`python3 -c 'import secrets; print(secrets.token_hex(16))'`)
* `AIRFLOW_SQLALCHEMY_URL`: (replace AIRFLOW_DB_POSTGRES_PASSWORD with the password you generated) `postgresql://postgres:AIRFLOW_DB_POSTGRES_PASSWORD@airflow-db`
* `AIRFLOW_ADMIN_PASSWORD`: Generate a password (`python3 -c 'import secrets; print(secrets.token_hex(16))'`)

SSH to NFS server and create NFS paths

```
mkdir -p /srv/default2/anyway/airflow-db
mkdir -p /srv/default2/anyway/airflow-home
mkdir -p /srv/default2/anyway/etl-data
```

Enable airflow by setting `enableAirflow: true` in the relevant environment's values

Deploy

## Enable DB Redash read-only user

Start a shell on DB pod and run the following to start an sql session:

```
su postgres
psql anyway
```

Run the following to create the readonly user (replace **** with real password):

```
CREATE ROLE readonly;
GRANT CONNECT ON DATABASE anyway TO readonly;
GRANT USAGE ON SCHEMA public TO readonly;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO readonly;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON TABLES TO readonly;
CREATE USER redash WITH PASSWORD '*****';
GRANT readonly TO redash;
```

## Restore from backup

Production DB has a daily backup which can be used to populate a new environment's DB

Following steps are for restoring to dev environment:

* stop the dev DB by scaling the db deployment down to 0 replicas
* SSH to hasadna NFS server and clear the DB data directory (`/srv/default2/anyway-dev/db/dbdata`)
* Edit the environment values (e.g. `values-anyway-dev.yaml`) and set `dbRestoreFileName` to the current day's date.
* Deploy the anyway chart - this will cause DB to be recreated from the backup
* The restore can take a long time..
