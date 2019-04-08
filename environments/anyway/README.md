# anyway staging environment

This environment is continuously updated from hasadna/anyway dev branch.

It can also be used to test infrastructure changes.

## Install

* Switch to the anyway environment
  * `source switch_environment.sh anyway`
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
  * `kubectl create secret generic -n anyway db --from-literal=POSTGRES_PASSWORD=*******`
* Create the Anyway secrets
  *  .e.g. `kubectl create secret generic -n anyway anyway --from-literal=ANYWAY-PASSWORD=*******`
  * repeate for all those secret: anyway_password, FACEBOOK_KEY , FACEBOOK_SECRET , GOOGLE_LOGIN_CLIENT_ID , GOOGLE_LOGIN_CLIENT_SECRET, GOOGLE_LOGIN_CLIENT_PASS, MAILUSER , MAILPASS , newrelic_key
     
* Create the persistent disk for the DB
  * `gcloud compute disks create --size=100GB --zone=europe-west1-b anyway-db`
* Enable initialization and set persistent disk in values
  * Edit `environments/anyway/values.yaml` under `anyway:`
  * Set `initialize: true`
  * Set `dbPersistentDiskName: anyway-db`
* Dry run and debug the anyway chart installation
  * `./helm_upgrade_external_chart.sh anyway --install --debug --dry-run`
* Install the anyway chart
  * `./helm_upgrade_external_chart.sh anyway --install`
* Check the anyway pod logs, verify it initialized correctly
* Disable initialization
  * Comment the line `initialize: true`
* Redeploy
  * `./helm_upgrade_external_chart.sh anyway`
* Deploy hasadna cluster load balancer to route to anyway
  * `source switch_environment.sh hasadna`
  * `./helm_upgrade_external_chart.sh traefik`
