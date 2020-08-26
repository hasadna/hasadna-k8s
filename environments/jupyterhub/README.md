# JupyterHub environment

## Create cluster

```
gcloud --project=hasadna-general container clusters create \
  --machine-type n1-standard-2 \
  --num-nodes 2 \
  --zone europe-west1-b \
  --cluster-version latest \
  jupyterhub
```

Give your account administrative permissions

```
source switch_environment.sh jupyterhub
kubectl create clusterrolebinding cluster-admin-binding \
  --clusterrole=cluster-admin \
  --user=<GOOGLE-EMAIL-ACCOUNT>
```

Create User's node pool

```
gcloud --project=hasadna-general beta container node-pools create user-pool \
  --machine-type n1-standard-2 \
  --num-nodes 0 \
  --enable-autoscaling \
  --min-nodes 0 \
  --max-nodes 3 \
  --node-labels hub.jupyter.org/node-purpose=user \
  --node-taints hub.jupyter.org_dedicated=user:NoSchedule \
  --zone europe-west1-b \
  --cluster jupyterhub
```

## Install JupyterHub

Install Helm3

```
bash apps_travis_script.sh install_helm
```

Create secret-config.yaml

```
echo 'proxy:
  secretToken: "'`openssl rand -hex 32`'"
' > environments/jupyterhub/secret-config.yaml
```

Install JupyterHub

```
helm repo add jupyterhub https://jupyterhub.github.io/helm-chart/ &&\
helm repo update &&\
helm upgrade --install jupyterhub jupyterhub/jupyterhub \
  --namespace default  \
  --version=0.9.0-beta.4 \
  --values environments/jupyterhub/secret-config.yaml
```

Wait for hub and proxy pods to be `Running`

```
kubectl get pods
```

Get the load balancer external IP

```
kubectl get service proxy-public
```

Access JupyterHub at the IP, login with any username/password

Delete the secret-config.yaml

```
rm environments/jupyterhub/secret-config.yaml
```

## Manage users

Add/remove user names as keys to `admin-users` configmap for admins or to `whitelist-users` configmap for users

Run the upgrade as specified below

## Upgrading

```
helm repo add jupyterhub https://jupyterhub.github.io/helm-chart/ &&\
helm repo update
```

```
echo 'proxy:
  secretToken: "'`kubectl get secret hub-secret -o json | jq -r '.data["proxy.token"]' | base64 -d`'"

auth:
  type: github
  github:
    clientId: "'`kubectl get secret github -o json | jq -r .data.clientid | base64 -d`'"
    clientSecret: "'`kubectl get secret github -o json | jq -r .data.secret | base64 -d`'"
    callbackUrl: "http://jupyterhub-test.odata.org.il/hub/oauth_callback"
  admin:
    access: true
    users:
'"$(python3 -c "import json, subprocess; print('\n'.join(['      - '+key for key in json.loads(subprocess.check_output('kubectl get configmap admin-users -o json', shell=True))['data'].keys()]))")"'
  whitelist:
    users:
'"$(python3 -c "import json, subprocess; print('\n'.join(['      - '+key for key in json.loads(subprocess.check_output('kubectl get configmap whitelist-users -o json', shell=True))['data'].keys()]))")"'
' > environments/jupyterhub/secret-config.yaml &&\
helm upgrade jupyterhub jupyterhub/jupyterhub \
  --namespace default  \
  --version=0.9.0-beta.4 \
  --values environments/jupyterhub/secret-config.yaml \
  --values environments/jupyterhub/config.yaml &&\
rm environments/jupyterhub/secret-config.yaml
```

Make sure the secret-config.yaml file is deleted

```
rm environments/jupyterhub/secret-config.yaml
```
