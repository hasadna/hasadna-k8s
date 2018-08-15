# anyway production environment

This environment is continuously updated from hasadna/anyway master branch.

Infrastructure changes should be tested on the staging environment (`anyway` environment)

## Install

* Switch to the anyway-production environment
  * `source switch_environment.sh anyway-production`
* Make sure you are connected to the correct cluster
  * `kubectl get nodes`
* Create the anyway namespace
  * `kubectl create ns anyway`
* Install the helm client
  * To make sure you get corret version you should use the script in this repo
  * `bash apps_travis_script.sh install_helm`
  * if you have problems, refer to helm docs - [helm client](https://docs.helm.sh/using_helm/#installing-the-helm-client)
* Verify helm installation
  * `helm version`
* Create the DB secret
  * `kubectl create secret generic -n anyway-production db --from-literal=POSTGRES_PASSWORD=*******`
* Create the persistent disk for the DB
  * `gcloud compute disks create --size=100GB --zone=europe-west1-b anyway-production-db`
* Enable initialization and set persistent disk in values
  * Edit `environments/anyway/values.yaml` under `anyway:`
  * Set `initialize: true`
  * Set `dbPersistentDiskName: anyway-production-db`
* Dry run and debug the anyway chart installation
  * `./helm_upgrade_external_chart.sh anyway --install --debug --dry-run`
* Install the anyway chart
  * `./helm_upgrade_external_chart.sh anyway --install`
* Check the anyway pod logs, verify it initialized correctly
* Disable initialization
  * Comment the line `initialize: true`
* Redeploy
  * `./helm_upgrade_external_chart.sh anyway`
* Test with port forward
  * `kubectl port-forward ANYWAY_POD_NAME 8000`
  * http://localhost:8000/
* Deploy hasadna cluster load balancer to route to anyway-production
  * `source switch_environment.sh hasadna`
  * `./helm_upgrade_external_chart.sh traefik`
