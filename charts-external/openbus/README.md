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

Dry Run

```
./helm_upgrade_external_chart.sh openbus --install --debug --dry-run
```

Deploy

```
./helm_upgrade_external_chart.sh openbus --install
```
