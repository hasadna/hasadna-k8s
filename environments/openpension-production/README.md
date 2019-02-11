# openpension production environment

<!-- TODO: This environment is continuously updated from hasadna/openpension master branch. -->

Infrastructure changes should be tested on the staging environment (`openpension` environment)

## Install

* Switch to the openpension-production environment
  * `source switch_environment.sh openpension-production`
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
  * `kubectl create secret generic -n openpension-production db --from-literal=POSTGRES_PASSWORD=*******`
* Create the persistent disk for the DB
  * `gcloud compute disks create --size=100GB --zone=europe-west1-b openpension-production-db`
* Enable initialization and set persistent disk in values
  * Edit `environments/openpension/values.yaml` under `openpension:`
  * Set `initialize: true`
  * Set `dbPersistentDiskName: openpension-production-db`
* Dry run and debug the openpension chart installation
  * `./helm_upgrade_external_chart.sh openpension --install --debug --dry-run`
* Install the openpension chart
  * `./helm_upgrade_external_chart.sh openpension --install`
* Check the openpension pod logs, verify it initialized correctly
* Disable initialization
  * Comment the line `initialize: true`
* Redeploy
  * `./helm_upgrade_external_chart.sh openpension`
* Test with port forward
  * `kubectl port-forward openpension_client_POD_NAME 8080`
  * http://localhost:8080/
* Deploy hasadna cluster load balancer to route to openpension-production
  * `source switch_environment.sh hasadna`
  * `./helm_upgrade_external_chart.sh traefik`
