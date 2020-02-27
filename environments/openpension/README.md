# openpension staging environment

## Install

* Switch to the openpension environment
  * `export KUBECONFIG=/path/to/kamatera/kubeconfig`
  * `source switch_environment.sh openpension`
* Make sure you are connected to the correct cluster
  * `kubectl get nodes`
* Create the openpension namespace
  * `kubectl create ns openpension`
* Install the helm client
  * `bash apps_travis_script.sh install_helm`
  * if you have problems, refer to helm docs - [helm client](https://docs.helm.sh/using_helm/#installing-the-helm-client)
* Create the DB secret
  * Create new:
    * `kubectl create secret generic -n openpension db --from-literal=POSTGRES_PASSWORD=*******`
  * Or, copy from previous environment:
    * connect to previous environment
    * `mkdir -p environments/openpension/.secrets`
    * `kubectl -n openpension get secret db --export -o yaml > environments/openpension/.secrets/db.yaml`
    * `kubectl -n openpension get secret mongodb-env --export -o yaml > environments/openpension/.secrets/mongodb-env.yaml`
    * `kubectl -n openpension get secret server --export -o yaml > environments/openpension/.secrets/server.yaml`
    * connect to new environment
    * `export KUBECONFIG=/path/to/kamatera/kubeconfig`
    * `source switch_environment.sh openpension`
    * `kubectl apply -f environments/openpension/.secrets/db.yaml`
    * `kubectl apply -f environments/openpension/.secrets/mongodb-env.yaml`
    * `kubectl apply -f environments/openpension/.secrets/server.yaml`
    * `rm -rf environments/openpension/.secrets`
* Create the NFS paths
  * ssh to the NFS server and run: `mkdir -p /srv/default2/openpension/staging-db /srv/default2/openpension/staging-mongodb`
* Set DNS (because we use let's encrypt for SSL, it should be set before initial deployment)
* Enable initialization and set persistent disk in values
  * Edit `environments/openpension/values.yaml` under `openpension:`
    * Set `initialize: true`
* Dry run and debug the openpension chart installation
  * `./helm_upgrade_external_chart.sh openpension --install --debug --dry-run`
* Install the openpension chart
  * `./helm_upgrade_external_chart.sh openpension --install`
* Check the openpension pod logs, verify it initialized correctly
* Disable initialization
  * Comment the line `initialize: true`
* Redeploy
  * `./helm_upgrade_external_chart.sh openpension`
