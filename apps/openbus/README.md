# Open Bus

Open Bus project

## Install

First, deploy the Stride DB server, see below under "Stride DB" for details.

Connect to cluster

```
export KUBECONFIG=/path/to/kamatera/kubeconfig
```

Create namespace

```
kubectl create ns openbus
```

SSH to NFS server and create NFS path

```
mkdir -p /srv/default2/openbus/siri-requester
```

SSH to NFS server and create NFS paths

```
mkdir -p /srv/default2/openbus/stride-db
```

Generate airflow password, set in secrets (see `values-hasadna.yaml` for secrets definitions)

```
OPEN_BUS_PIPELINES_AIRFLOW_ADMIN_PASSWORD=`python3 -c 'import secrets; print(secrets.token_hex(16))'`
```

Generate Airflow DB password secret:
```
AIRFLOW_DB_POSTGRES_PASSWORD=`python3 -c 'import secrets; print(secrets.token_hex(16))'`
```

SSH to NFS server and create NFS paths

```
mkdir -p /srv/default2/openbus/airflow-db
mkdir -p /srv/default2/openbus/airflow-home
```

Sync the app in [ArgoCD](/docs/argocd.md)


## Stride DB

The Stride DB is hosted on a dedicated server due to it's high load requirements.

It is managed in repo hasadna-iac under `modules/openbus`

See docs/monitoring.md Prometheus additional scrape configs, add 2 jobs:
* openbus-stride-db-server: 172.16.0.16:9796
* openbus-stride-db-postgres: 172.16.0.16:9797

The nfs node appears in grafana dashboard `Rancher / Node`

You can add a postgresql dashboard to Grafana: https://grafana.com/grafana/dashboards/9628


### Enable DB Redash read-only user

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

## Update MOT Node Allowed IPs

Some operations have to run from allowed IPs on MOT. The following command updates the node labels according to the
latest requested allowed IPs:

```
python3 apps/openbus/bin/update_node_allowed_ips.py
```

If you need to request or change the allowed IPs, edit that file and set the `ALLOWED_IPS` constant.
