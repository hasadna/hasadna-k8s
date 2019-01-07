# openpension minikube environment

Allows to test openpension kubernetes environment locally

## Install

* [Install Minikube](https://kubernetes.io/docs/tasks/tools/install-minikube/)
* Switch to the openpension-minikube environment
  * `source switch_environment.sh openpension-minikube`
* Make sure you are connected to your local minikube environment
  * `kubectl get nodes`
  * Should see a single `minikube` node
* Create the openpension-minikube namespace
  * `kubectl create ns openpension-minikube`
* Install the helm client
  * To make sure you get corret version you should use the script in this repo
  * `bash apps_travis_script.sh install_helm`
  * if you have problems, refer to helm docs - [helm client](https://docs.helm.sh/using_helm/#installing-the-helm-client)
* Install the helm server-side component on your minikube cluster
  * `helm init --history-max 2 --upgrade --wait`
* Verify helm installation
  * `helm version`
* Create DB secret
  * `kubectl create secret generic -n openpension-minikube db --from-literal=POSTGRES_PASSWORD=123456`
* Dry run and debug the openpension chart installation
  * `./helm_upgrade_external_chart.sh openpension --install --debug --dry-run`
* Install the openpension chart
  * `./helm_upgrade_external_chart.sh openpension --install`
* Port forward to the openpension client
  * `kubectl port-forward $(kubectl get pod -l "app=client" -o 'jsonpath={.items[0].metadata.name}') 8080:80`
  * site should be available at http://localhost:8080
* edit `environments/openpension-minikube/values.yaml`
  * comment the line `initialize: true` to prevent initialization from running on next upgrade
