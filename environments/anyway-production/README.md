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

  ## How to import full DB ( persistent volume) for Kubernetes environment
* edit file `environments/anyway/values.yaml`
 * change value `disbaledDeployment: false --> disbaledDeployment: true`
* Run DB pod only
  * `source switch_environment.sh anyway`
  * `kubectl create ns anyway`
  * `bash apps_travis_script.sh install_helm`
  * `helm init --history-max 2 --upgrade --wait`
  * `kubectl create secret generic -n anyway db --from-literal=POSTGRES_PASSWORD=******`
  * `./helm_upgrade_external_chart.sh anyway --install --debug --dry-run`
  * `./helm_upgrade_external_chart.sh anyway --install`

* restore DB to DB pod
  * `kubectl cp ../truncated_dump db-56c45ffdb5-kjj5w:/tmp`
  * `kubectl exec db-9bc6bf964-tz82r psql -- -U anyway -f /tmp/truncated_dump`
* edit file `environments/anyway-minikube/values.yaml`
* change value `disbaledDeployment: true --> disbaledDeployment: false`
* deploy anyway pod
  * `kubectl create secret generic -n anyway anyway --from-literal=ANYWAY-PASSWORD=****** --from-literal=anyway_password=****** --from-literal=FACEBOOK_KEY=****** --from-literal=FACEBOOK_SECRET=****** --from-literal=GOOGLE_LOGIN_CLIENT_ID=****** --from-literal=GOOGLE_LOGIN_CLIENT_SECRET=****** --from-literal=MAILUSER=****** --from-literal=MAILPASS=****** --from-literal=newrelic_key=******`

   * `./helm_upgrade_external_chart.sh anyway`
* port forward
  * `kubectl port-forward $(kubectl get pod -l "app=anyway" -o 'jsonpath={.items[0].metadata.name}') 8000`
