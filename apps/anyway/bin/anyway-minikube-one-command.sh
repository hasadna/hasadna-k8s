source switch_environment.sh anyway-minikube && \
kubectl create ns anyway-minikube && \
bash apps_travis_script.sh install_helm && \
helm init --history-max 2 --upgrade --wait && \
kubectl create secret generic -n anyway-minikube db --from-literal=POSTGRES_PASSWORD=123456 && \
kubectl create secret generic -n anyway-minikube anyway --from-literal=ANYWAY-PASSWORD=123456 --from-literal=anyway_password=123456 --from-literal=FACEBOOK_KEY=123456 --from-literal=FACEBOOK_SECRET=123456 --from-literal=GOOGLE_LOGIN_CLIENT_ID=123456 --from-literal=GOOGLE_LOGIN_CLIENT_SECRET=123456 --from-literal=MAILUSER=123456 --from-literal=MAILPASS=123456 --from-literal=newrelic_key=123456 && \
./helm_upgrade_external_chart.sh anyway --install --debug --dry-run && \
./helm_upgrade_external_chart.sh anyway --install 
