#!/usr/bin/env bash

get_env_var_secret() {
    VAL=`kubectl get secret ${2:-env-vars} -o json | jq -r ".data.${1}"`
    if [ "${VAL}" != "" ] && [ "${VAL}" != "null" ]; then
        echo "${VAL}" | base64 -d
    fi
}

get_env_var_email_secret() {
    kubectl get secret env-vars-upload-via-email -o json | jq -r ".data.${1}" | base64 -d
}

if ! kubectl get secret ${2:-env-vars}; then
    [ -z "${CKAN_BEAKER_SESSION_SECRET}" ] && echo "Generating CKAN_BEAKER_SESSION_SECRET" &&\
        export CKAN_BEAKER_SESSION_SECRET=`python -c "import binascii,os;print(binascii.hexlify(os.urandom(25)))"`
    [ -z "${CKAN_APP_INSTANCE_UUID}" ] && echo "Generating CKAN_APP_INSTANCE_UUID" &&\
        export CKAN_APP_INSTANCE_UUID=`python -c "import uuid;print(uuid.uuid1())"`
    [ -z "${POSTGRES_PASSWORD}" ] && echo "Generating POSTGRES_PASSWORD" &&\
        export POSTGRES_PASSWORD=`python -c "import binascii,os;print(binascii.hexlify(os.urandom(12)))"`
    [ -z "${POSTGRES_USER}" ] && export POSTGRES_USER=postgres
    kubectl create secret generic ${2:-env-vars} --from-literal=CKAN_APP_INSTANCE_UUID=$CKAN_APP_INSTANCE_UUID \
                                                 --from-literal=CKAN_BEAKER_SESSION_SECRET=$CKAN_BEAKER_SESSION_SECRET \
                                                 --from-literal=POSTGRES_PASSWORD=$POSTGRES_PASSWORD \
                                                 --from-literal=POSTGRES_USER=$POSTGRES_USER
    ETC_CKAN_DEFAULT_SECRET_NAME="${1:-ckan-default}"
    CKAN_SECRETS_DEFAULT_SECRET_NAME="${1:-ckan-default}-secrets"
else
    [ -z "${1}" ] \
        && echo "Current secret = $(eval echo `./read_env_yaml.sh odata etcCkanDefaultSecretName`)" \
        && echo To update existing secret pass the new secret name as argument && exit 1
    ETC_CKAN_DEFAULT_SECRET_NAME="${1}"
    CKAN_SECRETS_DEFAULT_SECRET_NAME="${1}-secrets"
    export CKAN_APP_INSTANCE_UUID=`get_env_var_secret CKAN_APP_INSTANCE_UUID`
    export CKAN_BEAKER_SESSION_SECRET=`get_env_var_secret CKAN_BEAKER_SESSION_SECRET`
    export POSTGRES_PASSWORD=`get_env_var_secret POSTGRES_PASSWORD`
    POSTGRES_USER=`get_env_var_secret POSTGRES_USER`
    export POSTGRES_USER="${POSTGRES_UESR:-postgres}"
fi

if ! kubectl get secret env-vars-upload-via-email; then
    echo WARNING: No env-vars-upload-via-email secret
    echo Upload via email feature will not work
    export GMAIL_TOKEN="--"
    export ALLOWED_SENDERS_RESOURCE_ID="--"
else
    export GMAIL_TOKEN=`get_env_var_email_secret GMAIL_TOKEN`
    export ALLOWED_SENDERS_RESOURCE_ID=`get_env_var_email_secret ALLOWED_SENDERS_RESOURCE_ID`
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


TEMPFILE=`mktemp`
echo "export BEAKER_SESSION_SECRET=${CKAN_BEAKER_SESSION_SECRET}
export APP_INSTANCE_UUID=${CKAN_APP_INSTANCE_UUID}
export SQLALCHEMY_URL=postgresql://${POSTGRES_USER}:${POSTGRES_PASSWORD}@db/ckan
export CKAN_DATASTORE_WRITE_URL=
export CKAN_DATASTORE_READ_URL=
export SOLR_URL=http://solr:8983/solr/ckan
export CKAN_REDIS_URL=redis://redis:6379/1
export CKAN_DATAPUSHER_URL=
export SMTP_SERVER=
export SMTP_STARTTLS=
export SMTP_USER=
export SMTP_PASSWORD=
export SMTP_MAIL_FROM=" > $TEMPFILE
kubectl create secret generic "${CKAN_SECRETS_DEFAULT_SECRET_NAME}" --from-file=secrets.sh=$TEMPFILE
CKAN_SECRET_RES="$?"
rm $TEMPFILE
[ "$CKAN_SECRET_RES" != "0" ] && echo failed to create secrets.sh secret && exit 1

echo Great Success
echo env-vars secret: ${2:-env-vars}
echo config secret: ${CKAN_SECRETS_DEFAULT_SECRET_NAME}
echo Please update the relevant values.yaml with the secret names
exit 0
