# anyway minikube environment

Allows to test anyway kubernetes environment locally

## Install

* [Install Minikube](https://kubernetes.io/docs/tasks/tools/install-minikube/)
* Switch to the anyway-minikube environment
  * `source switch_environment.sh anyway-minikube`
* Make sure you are connected to your local minikube environment
  * `kubectl get nodes`
  * Should see a single `minikube` node
* Create the anyway-minikube namespace
  * `kubectl create ns anyway-minikube`
* Install the helm client
  * To make sure you get corret version you should use the script in this repo
  * `bash apps_travis_script.sh install_helm`
  * if you have problems, refer to helm docs - [helm client](https://docs.helm.sh/using_helm/#installing-the-helm-client)
* Install the helm server-side component on your minikube cluster
  * `helm init --history-max 2 --upgrade --wait`
* Verify helm installation
  * `helm version`
* Create DB secret
  * `kubectl create secret generic -n anyway-minikube db --from-literal=POSTGRES_PASSWORD=123456`
* Create the Anyway secrets
  *  .e.g. `kubectl create secret generic -n anyway anyway --from-literal=ANYWAY-PASSWORD=*******`
  * repeate for all those secret: anyway_password, FACEBOOK_KEY , FACEBOOK_SECRET , GOOGLE_LOGIN_CLIENT_ID , GOOGLE_LOGIN_CLIENT_SECRET, GOOGLE_LOGIN_CLIENT_PASS, MAILUSER , MAILPASS , newrelic_key  
* Dry run and debug the anyway chart installation
  * `./helm_upgrade_external_chart.sh anyway --install --debug --dry-run`
* Install the anyway chart
  * `./helm_upgrade_external_chart.sh anyway --install`
* Port forward to the anyway pod to access with the browser
  * `kubectl port-forward $(kubectl get pod -l "app=anyway" -o 'jsonpath={.items[0].metadata.name}') 8000`
  * site should be available at http://localhost:8000
* edit `environments/anyway-minikube/values.yaml`
  * comment the line `initialize: true` to prevent initialization from running on next upgrade
