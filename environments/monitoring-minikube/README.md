# Hasadna K8S Monitoring

Prometheus base monitoring for your minikube environment.
Main difference is non persistance

## Deploying updated charts from helm repository
* [Install Minikube](https://kubernetes.io/docs/tasks/tools/install-minikube/)
* Switch to the monitoring environment
 * `source switch_environment.sh monitoring-minikube`
* Make sure you are connected to your local minikube environment
  * `kubectl get nodes`
  * Should see a single `minikube` node
* Create the monitoring namespace
  * `kubectl create ns monitoring`
* Install the helm client
  * To make sure you get corret version you should use the script in this repo
  * `bash apps_travis_script.sh install_helm`
  * if you have problems, refer to helm docs - [helm client](https://docs.helm.sh/using_helm/#installing-the-helm-client)
* Install the helm server-side component on your minikube cluster
  * `helm init --history-max 2 --upgrade --wait`
* Verify helm installation
  * `helm version`

* Dry run and debug deployment
 * `source helm_upgrade_repo_chart.sh stable/prometheus-operator prometheus --install --force --dry-run --debug`
* If successful install it
 * `source helm_upgrade_repo_chart.sh stable/prometheus-operator prometheus --install --force`

## Entering your prometheus deployment
* Run the following commands to make prometheus available from your computer
    ``` 
    export POD_NAME=$(kubectl get pods --namespace monitoring -l "app=prometheus,component=server" -o jsonpath="{.items[0].metadata.name}") 
    kubectl --namespace monitoring port-forward $POD_NAME 9090 
    ```
* Browse http://localhost:9090 to enter prometheus GUI