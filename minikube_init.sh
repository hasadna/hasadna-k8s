#!/bin/bash

set -x

function clean_exit(){
    local error_code="$?"
    local spawned=$(jobs -p)
    if [ -n "$spawned" ]; then
        sudo kill $(jobs -p)
    fi
    return $error_code
}

trap "clean_exit" EXIT

# Switch off SE-Linux
#setenforce 0


echo "Install VirtualBox it's required  for minikube"
sudo apt install virtualbox

echo "install google cloud"
CLOUD_SDK_VERSION=212.0.0
echo "PATH=~/google-cloud-sdk/bin:$PATH">> ~/.bashrc
export PATH=~/google-cloud-sdk/bin:$PATH
sudo apt install curl  \
        python \
        py-crcmod \
        bash \
        libc6-compat \
        openssh-client \
        git python-pip \
    && curl -O https://dl.google.com/dl/cloudsdk/channels/rapid/downloads/google-cloud-sdk-${CLOUD_SDK_VERSION}-linux-x86_64.tar.gz && \
    tar xzf google-cloud-sdk-${CLOUD_SDK_VERSION}-linux-x86_64.tar.gz && \
    rm google-cloud-sdk-${CLOUD_SDK_VERSION}-linux-x86_64.tar.gz && \
    ln -s /lib /lib64 && \
    gcloud config set core/disable_usage_reporting true && \
    gcloud config set component_manager/disable_update_check true && \
    gcloud config set metrics/environment github_docker_image && \
    gcloud --version

    sudo  pip install kubernetes
    sudo pip install pick python-dotenv pip install python-dotenv[cli]
    sudo pip install PyYAML

# Install docker if needed
path_to_executable=$(which docker)
if [ -x "$path_to_executable" ] ; then
    echo "Found Docker installation"
else
    curl -sSL https://get.docker.io | sudo bash
fi
docker --version

# Get the latest stable version of kubernetes
export K8S_VERSION=$(curl -sS https://storage.googleapis.com/kubernetes-release/release/stable.txt)
echo "K8S_VERSION : ${K8S_VERSION}"

echo "Starting docker service"
sudo systemctl enable docker.service
sudo systemctl start docker.service --ignore-dependencies
echo "Checking docker service"
sudo docker ps

echo "Download Kubernetes CLI"
wget -O kubectl "http://storage.googleapis.com/kubernetes-release/release/${K8S_VERSION}/bin/linux/amd64/kubectl"
sudo chmod +x kubectl
sudo mv kubectl /usr/local/bin/

echo "Download minikube from minikube project"
curl -Lo minikube "https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64"
sudo chmod +x minikube && sudo mv minikube /usr/local/bin/

echo "Starting minikube"
sudo nohup minikube start  > minikube.log 2>&1 &

echo "Waiting for minikube 4 minutesto start..."
if ! timeout 240 sh -c "while ! curl -ks http://192.168.99.100:30000 >/dev/null; do sleep 1; done"; then
    sudo cat minikube.log
    exit  $LINENO "minikube did not start"
fi


source <(kubectl completion bash) # setup autocomplete in bash into the current shell, bash-completion package should be installed first.
echo "source <(kubectl completion bash)" >> ~/.bashrc # add autocomplete permanently to your bash shell.


echo "Dump Kubernetes Objects..."
kubectl get componentstatuses
kubectl get configmaps
kubectl get daemonsets
kubectl get deployments
kubectl get events
kubectl get endpoints
kubectl get horizontalpodautoscalers
kubectl get ingress
kubectl get jobs
kubectl get limitranges
kubectl get nodes
kubectl get namespaces
kubectl get pods
kubectl get persistentvolumes
kubectl get persistentvolumeclaims
kubectl get quota
kubectl get resourcequotas
kubectl get replicasets
kubectl get replicationcontrollers
kubectl get secrets
kubectl get serviceaccounts
kubectl get services


echo "install Visual Studio Code"
sudo apt update && sudo apt install software-properties-common apt-transport-https wget
echo "import the Microsoft GPG key"
wget -q https://packages.microsoft.com/keys/microsoft.asc -O- | sudo apt-key add -
echo "enable the Visual Studio Code repository"
sudo add-apt-repository "deb [arch=amd64] https://packages.microsoft.com/repos/vscode stable main"
echo "install the latest version of Visual Studio Code"
sudo apt install code
echo "Running tests..."
set -x -e
# Yield execution to venv command
$*
