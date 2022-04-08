#!/usr/bin/env bash

if [ "${1}" == "--install" ]; then
    echo Installing and initializing the infrastructure
    ./helm_upgrade_external_chart.sh odata --install \
                   --set db.initialize=true --set datastore.initialize=true --set nfsInitialize=true \
                   --set dbOps.enabled=false --set datastore.dbOps.enabled=false \
                   --set datastore.datapusherEnabled=false --set pipelines.enabled=false \
                   --set solrInitialize=true --set minimalPlugins=true \
                   --set replicas=1 ${@:2}

elif [ "${1}" == "--restore" ]; then
    SERVICE_ACCOUNT_FILE="${2}"
    DB_BACKUP_GS_URL="${3}"
    DATASTORE_DB_BACKUP_GS_URL="${4}"
    echo Creating DB restore secret
    kubectl delete secret ckan-db-restore >/dev/null 2>&1
    ! kubectl create secret generic ckan-db-restore --from-file=secret.json=$SERVICE_ACCOUNT_FILE \
        && echo Failed to create DB restore secret && exit 1
    if [ -z "${DATASTORE_DB_BACKUP_GS_URL}" ]; then
        DATASTORE_ARGS="--set datastore.dbOps.enabled=false --set datastore.initialize=true"
    else
        DATASTORE_ARGS="--set datastore.dbOps.enabled=true --set datastore.dbOps.restore=${DATASTORE_DB_BACKUP_GS_URL} --set datastore.dbOps.backup="
    fi
    ./helm_upgrade_external_chart.sh odata --install \
                --set dbOps.enabled=true --set "dbOps.restore=${DB_BACKUP_GS_URL}" --set "dbOps.backup=" \
                --set dbOps.secretName=ckan-db-restore \
                ${DATASTORE_ARGS} \
                --set datastore.datapusherEnabled=false --set pipelines.enabled=false \
                --set solrInitialize=true --set ckanSolrRebuild=true \
                --set ckanJobsEnabled=false \
                --set replicas=1 ${@:5}

elif [ "${1}" == "--install-gke" ]; then
    echo Installing and initializing on Google Kubernetes Engine
    echo Please verify you are connected to the correct cluster and namespace
    cat environments/${K8S_ENVIRONMENT_NAME}/.env
    echo K8S_ENVIRONMENT_LABEL=${K8S_ENVIRONMENT_LABEL}
    ! kubectl config get-contexts `kubectl config current-context` && exit 1
    read -p "Press <Enter> to continue..."

    echo Creating namespace $K8S_NAMESPACE
    ! kubectl get ns $K8S_NAMESPACE && kubectl create ns $K8S_NAMESPACE

    echo Setting up storage
    NFS_SOURCE_SNAPSHOT=$(eval echo `./read_env_yaml.sh odataInstallGke nfsSourceSnapshot`)
    NFS_SIZE=$(eval echo `./read_env_yaml.sh odataInstallGke nfsSize`)
    DB_SIZE=$(eval echo `./read_env_yaml.sh odataInstallGke dbSize`)
    DATASTORE_SIZE=$(eval echo `./read_env_yaml.sh odataInstallGke datastoreSize`)
    if [ "${NFS_SOURCE_SNAPSHOT}" != "" ]; then
        SOURCE_SNAPSHOT_PARAM="--source-snapshot=${NFS_SOURCE_SNAPSHOT}"
    else
        SOURCE_SNAPSHOT_PARAM=""
    fi
    ! gcloud --project=${CLOUDSDK_CORE_PROJECT} compute disks create \
             "${K8S_ENVIRONMENT_NAME}-${K8S_ENVIRONMENT_LABEL}-nfs" \
             --size=${NFS_SIZE} --zone=${CLOUDSDK_COMPUTE_ZONE} \
             $SOURCE_SNAPSHOT_PARAMS \
        && echo Failed to create nfs persistent disk && exit 1
    ! gcloud --project=${CLOUDSDK_CORE_PROJECT} compute disks create \
             "${K8S_ENVIRONMENT_NAME}-${K8S_ENVIRONMENT_LABEL}-datastore" \
             --size=${DATASTORE_SIZE} --zone=${CLOUDSDK_COMPUTE_ZONE} \
        && echo Failed to create datastore disk && exit 1
    ! gcloud --project=${CLOUDSDK_CORE_PROJECT} compute disks create \
             "${K8S_ENVIRONMENT_NAME}-${K8S_ENVIRONMENT_LABEL}-db" \
              --size=${DB_SIZE} --zone=${CLOUDSDK_COMPUTE_ZONE} \
        && echo Failed to create db disk && exit 1
    echo 'apiVersion: v1
kind: PersistentVolume
metadata:
  # must be unique for the entire cluster
  name: odata-'${K8S_ENVIRONMENT_LABEL}'-nfs-gcepd
spec:
  storageClassName: ""
  capacity:
    storage: 100G
  accessModes:
    - ReadWriteOnce
  gcePersistentDisk:
    pdName: odata-'${K8S_ENVIRONMENT_LABEL}'-nfs
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: odata-'${K8S_ENVIRONMENT_LABEL}'-nfs-gcepd
spec:
  storageClassName: ""
  volumeName: odata-'${K8S_ENVIRONMENT_LABEL}'-nfs-gcepd
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 100G' > environments/${K8S_ENVIRONMENT_NAME}/nfs-pvc-${K8S_ENVIRONMENT_LABEL}.yaml
    echo 'apiVersion: apps/v1beta1
kind: Deployment
metadata:
  name: nfs
spec:
  replicas: 1
  revisionHistoryLimit: 5
  strategy:
    type: Recreate
  template:
    metadata:
      labels:
        app: nfs
    spec:
      containers:
      - name: nfs
        image: k8s.gcr.io/volume-nfs:0.8
        resources: {"requests": {"cpu": "150m", "memory": "200Mi"}, "limits": {"cpu": "150m", "memory": "200Mi"}}
        ports:
          - name: nfs
            containerPort: 2049
          - name: mountd
            containerPort: 20048
          - name: rpcbind
            containerPort: 111
        securityContext:
          privileged: true
        volumeMounts:
          - mountPath: /exports
            name: exports
      volumes:
        - name: exports
          persistentVolumeClaim:
            claimName: odata-'${K8S_ENVIRONMENT_LABEL}'-nfs-gcepd' > environments/${K8S_ENVIRONMENT_NAME}/nfs-deployment-${K8S_ENVIRONMENT_LABEL}.yaml

    echo Deploying data storage server
    kubectl create -f charts-external/odata/manifests/nfs-service.yaml &&\
    kubectl create -f environments/${K8S_ENVIRONMENT_NAME}/nfs-pvc-${K8S_ENVIRONMENT_LABEL}.yaml &&\
    kubectl create -f environments/${K8S_ENVIRONMENT_NAME}/nfs-deployment-${K8S_ENVIRONMENT_LABEL}.yaml
    [ "$?" != "0" ] && echo Failed to deploy data storage server && exit 1

    echo Great Success
    exit 0

elif [ "${1}" == "--install-kamatera" ]; then
    echo Installing and initializing on Kamatera
    echo Please verify you are connected to the correct cluster and namespace
    cat environments/${K8S_ENVIRONMENT_NAME}/.env
    echo K8S_ENVIRONMENT_LABEL=${K8S_ENVIRONMENT_LABEL}
    ! kubectl config get-contexts `kubectl config current-context` && exit 1
    ! kubectl get nodes && exit 1
    read -p "Press <Enter> to continue..."

    echo Creating namespace $K8S_NAMESPACE
    ! kubectl get ns $K8S_NAMESPACE && kubectl create ns $K8S_NAMESPACE

    echo Great Success
    exit 0

elif [ "${1}" == "--install-minikube" ]; then
    if [ "${2}" != "-y" ]; then
        echo Please verify you are connected to the correct cluster and namespace
        cat environments/${K8S_ENVIRONMENT_NAME}/.env
        ! kubectl config get-contexts `kubectl config current-context` && exit 1
        read -p "Press <Enter> to continue..."
    fi

    echo Installing and initializing Minikube environment
    ! minikube status \
        && ! minikube start --kubernetes-version v1.9.7 \
                            --memory 2048 --cpus 2 --disk-size 15g \
            && echo failed to start minikube && exit 1

    echo Creating namespace $K8S_NAMESPACE
    ! kubectl get ns $K8S_NAMESPACE && while ! kubectl create ns $K8S_NAMESPACE; do echo .; sleep 2; done
    ! bash apps_travis_script.sh install_helm && echo failed to install helm client && exit 1
    ! helm init --history-max 2 --upgrade --wait && echo failed to install helm server && exit 1
    helm version
    [ "${2}" != "-y" ] && sudo mkdir -p /var/odata-minikube-storage
    ! kubectl apply -f charts-external/odata/manifests/ckan-kubectl-rbac.yaml && echo failed to create rbac && exit 1
    echo Great Success
    exit 0

else
    ./helm_upgrade_external_chart.sh odata $@

fi
