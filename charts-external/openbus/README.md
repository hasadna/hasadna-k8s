# Open Bus

Open Bus project

## Install

Connect to openbus production environment

```
export KUBECONFIG=/path/to/kamatera/kubeconfig
source switch_environment.sh openbus
```

Create namespace

```
kubectl create ns openbus
```

Create ssh tunnel secret

```
kubectl -n openbus create secret generic sshtunnel \
    --from-file=key=
```

Create siri requester secret

```
kubectl -n openbus create secret generic siri-requester \
    --from-literal=OPEN_BUS_MOT_KEY= \
    --from-literal=OPEN_BUS_SSH_TUNNEL_SERVER_IP= \
    --from-literal=OPEN_BUS_S3_ENDPOINT_URL= \
    --from-literal=OPEN_BUS_S3_ACCESS_KEY_ID= \
    --from-literal=OPEN_BUS_S3_SECRET_ACCESS_KEY= \
    --from-literal=OPEN_BUS_S3_BUCKET=
```

SSH to NFS server and create NFS path

```
mkdir -p /srv/default2/openbus/siri-requester
```

Create DB password secret

```
POSTGRES_PASSWORD=`python3 -c 'import secrets; print(secrets.token_hex(16))'`
kubectl -n openbus create secret generic db \
    --from-literal=POSTGRES_PASSWORD=${POSTGRES_PASSWORD} \
    --from-literal=SQLALCHEMY_URL=postgresql://postgres:${POSTGRES_PASSWORD}@stride-db
```

SSH to NFS server and create NFS paths

```
mkdir -p /srv/default2/openbus/stride-db
```

Create Airflow secrets

```
OPEN_BUS_PIPELINES_AIRFLOW_ADMIN_PASSWORD=`python3 -c 'import secrets; print(secrets.token_hex(16))'`
kubectl -n openbus create secret generic airflow \
    --from-literal=OPEN_BUS_PIPELINES_AIRFLOW_ADMIN_PASSWORD=${OPEN_BUS_PIPELINES_AIRFLOW_ADMIN_PASSWORD}
```

Create Airflow DB password secret

```
AIRFLOW_DB_POSTGRES_PASSWORD=`python3 -c 'import secrets; print(secrets.token_hex(16))'`
kubectl -n openbus create secret generic airflow-db \
    --from-literal=POSTGRES_PASSWORD=${AIRFLOW_DB_POSTGRES_PASSWORD} \
    --from-literal=SQLALCHEMY_URL=postgresql://postgres:${AIRFLOW_DB_POSTGRES_PASSWORD}@airflow-db
```

SSH to NFS server and create NFS paths

```
mkdir -p /srv/default2/openbus/airflow-db
mkdir -p /srv/default2/openbus/airflow-home
```

Dry Run

```
./helm_upgrade_external_chart.sh openbus --install --debug --dry-run
```

Deploy

```
./helm_upgrade_external_chart.sh openbus --install
```

## Enable DB Redash read-only user

Run the following on the stride DB (replace **** with real password):

```
CREATE ROLE stride_readonly;
GRANT CONNECT ON DATABASE postgres TO stride_readonly;
GRANT USAGE ON SCHEMA public TO stride_readonly;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO stride_readonly;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON TABLES TO stride_readonly;
CREATE USER redash WITH PASSWORD '*****';
GRANT stride_readonly TO redash;
```
