# openpension staging environment

This environment is continuously updated from hasadna/openpension dev branch.

It can also be used to test infrastructure changes.

## Install

* Switch to the openpension environment
  * `source switch_environment.sh openpension`
* Make sure you are connected to the correct cluster
  * `kubectl get nodes`
* Create the openpension namespace
  * `kubectl create ns openpension`
* Install the helm client
  * To make sure you get corret version you should use the script in this repo
  * `bash apps_travis_script.sh install_helm`
  * if you have problems, refer to helm docs - [helm client](https://docs.helm.sh/using_helm/#installing-the-helm-client)
* Verify helm installation
  * `helm version`
* Create the DB secret
  * `kubectl create secret generic -n openpension db --from-literal=POSTGRES_PASSWORD=*******`
* Create the persistent disk for the DB
  * `gcloud compute disks create --size=100GB --zone=europe-west1-b openpension-db`
* Enable initialization and set persistent disk in values
  * Edit `environments/openpension/values.yaml` under `openpension:`
  * Set `initialize: true`
  * Set `dbPersistentDiskName: openpension-db`
* Dry run and debug the openpension chart installation
  * `./helm_upgrade_external_chart.sh openpension --install --debug --dry-run`
* Install the openpension chart
  * `./helm_upgrade_external_chart.sh openpension --install`
* Check the openpension pod logs, verify it initialized correctly
* Disable initialization
  * Comment the line `initialize: true`
* Redeploy
  * `./helm_upgrade_external_chart.sh openpension`
* Deploy hasadna cluster load balancer to route to openpension
  * `source switch_environment.sh hasadna`
  * `./helm_upgrade_external_chart.sh traefik`
