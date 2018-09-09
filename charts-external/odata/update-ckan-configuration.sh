#!/usr/bin/env bash

get_env_var_secret() {
    kubectl get secret env-vars -o json | jq -r ".data.${1}" | base64 -d
}

if ! kubectl get secret env-vars; then
    [ -z "${CKAN_BEAKER_SESSION_SECRET}" ] && echo "Generating CKAN_BEAKER_SESSION_SECRET" &&\
        export CKAN_BEAKER_SESSION_SECRET=`python -c "import binascii,os;print(binascii.hexlify(os.urandom(25)))"`
    [ -z "${CKAN_APP_INSTANCE_UUID}" ] && echo "Generating CKAN_APP_INSTANCE_UUID" &&\
        export CKAN_APP_INSTANCE_UUID=`python -c "import uuid;print(uuid.uuid1())"`
    [ -z "${POSTGRES_PASSWORD}" ] && echo "Generating POSTGRES_PASSWORD" &&\
        export POSTGRES_PASSWORD=`python -c "import binascii,os;print(binascii.hexlify(os.urandom(12)))"`
    kubectl create secret generic env-vars --from-literal=CKAN_APP_INSTANCE_UUID=$CKAN_APP_INSTANCE_UUID \
                                           --from-literal=CKAN_BEAKER_SESSION_SECRET=$CKAN_BEAKER_SESSION_SECRET \
                                           --from-literal=POSTGRES_PASSWORD=$POSTGRES_PASSWORD
    ETC_CKAN_DEFAULT_SECRET_NAME="etc-ckan-default"
else
    [ -z "${1}" ] \
        && echo "Current secret = $(eval echo `./read_env_yaml.sh odata etcCkanDefaultSecretName`)" \
        && echo To update existing secret pass the new secret name as argument && exit 1
    ETC_CKAN_DEFAULT_SECRET_NAME="${1}"
    export CKAN_APP_INSTANCE_UUID=`get_env_var_secret CKAN_APP_INSTANCE_UUID`
    export CKAN_BEAKER_SESSION_SECRET=`get_env_var_secret CKAN_BEAKER_SESSION_SECRET`
    export POSTGRES_PASSWORD=`get_env_var_secret POSTGRES_PASSWORD`
fi

( [ -z "${CKAN_BEAKER_SESSION_SECRET}" ] || [ -z "${CKAN_APP_INSTANCE_UUID}" ] || [ -z "${POSTGRES_PASSWORD}" ] )\
    && echo missing env vars && exit 1

export CKAN_SQLALCHEMY_URL="postgresql://postgres:${POSTGRES_PASSWORD}@db/ckan"
if [ "${K8S_ENVIRONMENT_NAME}" == "odata-minikube" ]; then
    export CKAN_SITE_URL="http://localhost:5000/"
    echo Configuring CKAN_SITE_URL for local development on $CKAN_SITE_URL
else
    export CKAN_SITE_URL="https://www.odata.org.il/"
fi
export CKAN_SOLR_URL="http://solr:8983/solr/ckan"
export CKAN_REDIS_URL="redis://redis:6379/0"
export CKAN_STORAGE_PATH="/var/lib/ckan/data"
export CKAN_MAX_RESOURCE_SIZE="500"
export CKAN_DEBUG=false
export COMMENT="-- This file contains secrets, do not commit / expose publicly! --"
TEMP_DIR=`mktemp -d`
./templater.sh charts-external/odata/who.ini.template > $TEMP_DIR/who.ini
./templater.sh charts-external/odata/development.ini.template > $TEMP_DIR/development.ini
kubectl create secret generic "${ETC_CKAN_DEFAULT_SECRET_NAME}" --from-file $TEMP_DIR/
rm -rf $TEMP_DIR

echo Great Success
echo Created new secret: ${ETC_CKAN_DEFAULT_SECRET_NAME}
echo Please update the relevant values.yaml with the new secret name
exit 0
