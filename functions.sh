get_pod_name() {
    local NAMESPACE=$1
    local POD_PREFIX=$2
    kubectl get pods -n $NAMESPACE | grep '^'$POD_PREFIX | cut -d " " -f 1
}

get_pod_node_name() {
    local NAMESPACE=$1
    local POD_PREFIX=$2
    kubectl get -n $NAMESPACE pod `get_pod_name $NAMESPACE $POD_PREFIX` -o yaml | grep nodeName: | cut -d " " -f 4
}

get_pod_uid() {
    local NAMESPACE=$1
    local POD_PREFIX=$2
    kubectl get -n $NAMESPACE pod `get_pod_name $NAMESPACE $POD_PREFIX` -o yaml | grep '^  uid' | cut -d " " -f 4
}

mount_nfs_and_rsync() {
    local NODE_NAME=$1
    local NFS_IP=$2
    local SOURCE_DIR=$3
    local TARGET_DIR=$4
    local NFS_TARGET_DIR=$5
    echo mounting NFS and rsyncing &&\
    echo NODE_NAME=$NODE_NAME &&\
    echo NFS_IP=$NFS_IP &&\
    echo SOURCE_DIR=$SOURCE_DIR &&\
    echo TARGET_DIR=$TARGET_DIR &&\
    echo NFS_TARGET_DIR=$NFS_TARGET_DIR &&\
    gcloud compute ssh $NODE_NAME -- toolbox bash -c '"apt-get update && apt-get install -y nfs-common rsync && mkdir -p '$TARGET_DIR'"' &&\
    gcloud compute ssh $NODE_NAME -- toolbox bash -c '"mount -t nfs '$NFS_IP':'$NFS_TARGET_DIR' '$TARGET_DIR' && rsync --progress -az '$SOURCE_DIR'/ '$TARGET_DIR'/"'
}
