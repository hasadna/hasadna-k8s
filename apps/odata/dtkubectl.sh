#!/usr/bin/env bash

get_pod_name() {
    ! kubectl get pods -l "app=${1}" -o 'jsonpath={.items[0].metadata.name}' \
        && echo > /dev/stderr && echo "Error: couldn't find pod matching label app=${1}" >/dev/stderr && return 1
    return 0
}

get_secrets_json() {
    kubectl get secret $1 -o json
}

get_secret_from_json() {
    VAL=`echo "${1}" | jq -r ".data.${2}"`
    if [ "${VAL}" != "" ] && [ "${VAL}" != "null" ]; then
        echo "${VAL}" | base64 -d
    fi
}

export_ckan_env_vars() {
    ENV_VARS_SECRET="${1}"
    EMAIL_ENV_VARS_SECRET="${2}"
    ( [ -z "${ENV_VARS_SECRET}" ] || [ -z "${EMAIL_ENV_VARS_SECRET}" ] ) && return 0
    ! SECRETS_JSON=`get_secrets_json $ENV_VARS_SECRET` \
        && echo could not find ckan env vars secret ENV_VARS_SECRET && return 0
    export CKAN_APP_INSTANCE_UUID=`get_secret_from_json "${SECRETS_JSON}" CKAN_APP_INSTANCE_UUID`
    export CKAN_BEAKER_SESSION_SECRET=`get_secret_from_json "${SECRETS_JSON}" CKAN_BEAKER_SESSION_SECRET`
    export POSTGRES_PASSWORD=`get_secret_from_json "${SECRETS_JSON}" POSTGRES_PASSWORD`
    export POSTGRES_USER=`get_secret_from_json "${SECRETS_JSON}" POSTGRES_USER`
    export DATASTORE_POSTGRES_PASSWORD=`get_secret_from_json "${SECRETS_JSON}" DATASTORE_POSTGRES_PASSWORD`
    export DATASTORE_POSTGRES_USER=`get_secret_from_json "${SECRETS_JSON}" DATASTORE_POSTGRES_USER`
    export DATASTORE_RO_USER=`get_secret_from_json "${SECRETS_JSON}" DATASTORE_RO_USER`
    export DATASTORE_RO_PASSWORD=`get_secret_from_json "${SECRETS_JSON}" DATASTORE_RO_PASSWORD`
    if EMAIL_SECRETS_JSON=`get_secrets_json $EMAIL_ENV_VARS_SECRET`; then
        export GMAIL_TOKEN="`get_secret_from_json "${EMAIL_SECRETS_JSON}" GMAIL_TOKEN`"
        export ALLOWED_SENDERS_RESOURCE_ID=`get_secret_from_json "${EMAIL_SECRETS_JSON}" ALLOWED_SENDERS_RESOURCE_ID`
    else
        echo WARNING: missing email env vars secret, upload via email feature will not work
        export GMAIL_TOKEN="--"
        export ALLOWED_SENDERS_RESOURCE_ID="--"
    fi

    ( [ -z "${CKAN_BEAKER_SESSION_SECRET}" ] || [ -z "${CKAN_APP_INSTANCE_UUID}" ] || [ -z "${POSTGRES_PASSWORD}" ] || \
      [ -z "${POSTGRES_USER}" ] ) && echo missing required ckan env vars && return 0

    return 0
}

if [ "${1}" == "loop" ]; then
    # can be used to wait track progress of changes
    # e.g.
    # ./kubectl.sh loop get pods
    while true; do
        kubectl "${@:2}"
        sleep 1
    done

elif [ "${1} ${2}" == "port-forward ckan-infra" ]; then
    ./kubectl.sh port-forward db 5432 &
    ./kubectl.sh port-forward solr 8983 &
    ./kubectl.sh port-forward redis 6379 &
    ./kubectl.sh port-forward datastore-db 5433:5432 &
    ./kubectl.sh port-forward datapusher 8800 &
    wait

elif [ "${1}" == "port-forward" ]; then
    # port-forward based on app label
    if [ "${3}" == "" ]; then
        PORT_FORWARD_DEFAULT_ARGS=""
        [ -e charts-external/${2}/default.sh ] && source charts-external/${2}/default.sh
        [ -z "${PORT_FORWARD_DEFAULT_ARGS}" ] && echo missing port-forward args && exit 1
        ARGS="${PORT_FORWARD_DEFAULT_ARGS}"
    else
        ARGS="${@:3}"
    fi
    ! POD_NAME=$(./kubectl.sh get-pod-name "${2}") && exit 1
    if [ "${2}" == "db" ] && [ "${3}" == "5432" ]; then
        ./kubectl.sh exec ckan cat /etc/ckan/production.ini | grep sqlalchemy.url
        ./kubectl.sh exec db env -c db | grep POSTGRES_PASSWORD
    elif [ "${2}" == "datastore-db" ] && [ "${3}" == "5432" ]; then
        ./kubectl.sh exec ckan cat /etc/ckan/production.ini | grep 'datastore.*_url'
        DB_ENV="$(./kubectl.sh exec datastore-db env -c db)"
        echo "${DB_ENV}" | grep POSTGRES_PASSWORD
        echo "${DB_ENV}" | grep DATASTORE_RO_PASSWORD
        echo "${DB_ENV}" | grep DATASTORE_RO_USER
    fi
    kubectl port-forward ${POD_NAME} $ARGS

elif [ "${1}" == "get-pod-name" ]; then
    # get pod name based on app label
    get_pod_name "${2}"

elif [ "${1}" == "exec" ]; then
    if [ "${3}" == "" ]; then
        EXEC_DEFAULT_ARGS=""
        [ -e charts-external/${2}/default.sh ] && source charts-external/${2}/default.sh
        [ -z "${EXEC_DEFAULT_ARGS}" ] && echo missing exec args && exit 1
        ARGS="${EXEC_DEFAULT_ARGS}"
    else
        ARGS="${@:3}"
    fi
    ! POD_NAME=$(./kubectl.sh get-pod-name "${2}") && exit 1
    kubectl exec "${POD_NAME}" $ARGS

elif [ "${1}" == "logs" ]; then
    if [ "${3}" == "" ]; then
        LOGS_DEFAULT_ARGS=""
        [ -e charts-external/${2}/default.sh ] && source charts-external/${2}/default.sh
        ARGS="${LOGS_DEFAULT_ARGS}"
    else
        ARGS="${@:3}"
    fi
    ! POD_NAME=$(./kubectl.sh get-pod-name "${2}") && exit 1
    kubectl logs "${POD_NAME}" $ARGS

elif [ "${1}" == "copy-ckan-conf" ]; then
    TARGET_DIR="${3:-/etc/ckan}"
    echo "Saving conf from ckan pod to ${TARGET_DIR} and replacing urls to point to localhost"
    read -p "Press <Enter> to continue"
    mkdir -p "${TARGET_DIR}" &&\
    ./kubectl.sh cp ckan etc/ckan/production.ini ${TARGET_DIR}/production.ini &&\
    ./kubectl.sh cp ckan etc/ckan/who.ini ${TARGET_DIR}/who.ini &&\
    sed -e 's/redis:6379/localhost:6379/g' -i ${TARGET_DIR}/production.ini &&\
    sed -e 's/solr:8983/localhost:8983/g' -i ${TARGET_DIR}/production.ini &&\
    sed -e 's/datapusher:8800/localhost:8800/g' -i ${TARGET_DIR}/production.ini &&\
    sed -e 's/db\/ckan/localhost\/ckan/g' -i ${TARGET_DIR}/production.ini
    sed -e 's/datastore-db\/datastore/localhost:5433\/datastore/g' -i ${TARGET_DIR}/production.ini
    [ "$?" != "0" ] && echo && echo ERROR: Failed to copy ckan conf
    echo
    echo Successfully copied ckan configuration to ${TARGET_DIR}

elif [ "${1}" == "cp" ]; then
    ! POD_NAME=$(./kubectl.sh get-pod-name "${2}") && exit 1
    kubectl cp ${POD_NAME}:${@:3}

elif [ "${1}" == "ckan-sysadmin" ]; then
    ! POD_NAME=$(./kubectl.sh get-pod-name ckan) && exit 1
    kubectl exec -it $POD_NAME -- ckan-paster --plugin=ckan sysadmin -c /etc/ckan/production.ini ${@:2}

elif [ "${1}" == "initialize-pipelines" ]; then
    USER="${2:-ckan-pipelines-sysadmin}"
    EMAIL="${3:-ckan-pipelines-sysadmin@ckan}"
    SECRET_NAME="${4:-ckan-pipelines}"
    echo "Initializing pipelines sysadmin user ${USER} email ${EMAIL} secret ${SECRET_NAME}"
    if ! kubectl get secret $SECRET_NAME; then
        PASSWORD=`python -c "import binascii,os;print(binascii.hexlify(os.urandom(12)))"`
        ! CREATE_SYSADMIN_OUTPUT=$(echo "y" | ./kubectl.sh ckan-sysadmin add $USER password=$PASSWORD email=$EMAIL 2>&1) \
            && echo "${CREATE_SYSADMIN_OUTPUT}" && echo failed to create sysadmin user && exit 1
        ! API_KEY=$(echo "${CREATE_SYSADMIN_OUTPUT}" \
                    | grep -oP "'apikey': u'\K[^']*") \
            && echo "${CREATE_SYSADMIN_OUTPUT}" \
            && echo failed to grep api key from create sysadmin response && exit 1
        [ "${API_KEY}" == "" ] && echo missing api key && exit 1
        ! kubectl create secret generic $SECRET_NAME --from-literal=apikey=$API_KEY \
                                                     --from-literal=password=$PASSWORD \
                                                     --from-literal=email=$EMAIL \
                                                     --from-literal=user=$USER \
            && echo failed to create pipelines secret && exit 1
        echo created pipelines secret && exit 0
    else
        echo pipelines secret already exists && exit 0
    fi

elif [ "${1}" == "initialize-ckan-env-vars" ]; then
    ENV_VARS_SECRET="${2:-ckan-env-vars}"
    if ! kubectl get secret $ENV_VARS_SECRET; then
        echo "Creating ckan env vars secret ${ENV_VARS_SECRET}"
        ! kubectl create secret generic $ENV_VARS_SECRET \
                  --from-literal=CKAN_APP_INSTANCE_UUID=`python -c "import uuid;print(uuid.uuid1())"` \
                  --from-literal=CKAN_BEAKER_SESSION_SECRET=`python -c "import binascii,os;print(binascii.hexlify(os.urandom(25)))"` \
                  --from-literal=POSTGRES_PASSWORD=`python -c "import binascii,os;print(binascii.hexlify(os.urandom(12)))"` \
                  --from-literal=POSTGRES_USER=ckan \
                  --from-literal=DATASTORE_POSTGRES_PASSWORD=`python -c "import binascii,os;print(binascii.hexlify(os.urandom(12)))"` \
                  --from-literal=DATASTORE_POSTGRES_USER=postgres \
                  --from-literal=DATASTORE_RO_USER=readonly \
                  --from-literal=DATASTORE_RO_PASSWORD=`python -c "import binascii,os;print(binascii.hexlify(os.urandom(12)))"` \
            && echo Failed to create ckan env vars secret && exit 1
        echo Created ckan env vars secret && exit 0
    else
        echo Ckan env vars secret already exists && exit 0
    fi

elif [ "${1}" == "initialize-ckan-secrets" ]; then
    ENV_VARS_SECRET="${2:-ckan-env-vars}"
    EMAIL_ENV_VARS_SECRET="${3:-ckan-upload-via-email-env-vars}"
    CKAN_SECRETS_SECRET="${4:-ckan-secrets}"
    if ! kubectl get secret "${CKAN_SECRETS_SECRET}"; then
        echo Creating ckan secrets secret $CKAN_SECRETES_SECRET from env vars secrets $ENV_VARS_SECRET $EMAIL_ENV_VARS_SECRET
        ! export_ckan_env_vars $ENV_VARS_SECRET $EMAIL_ENV_VARS_SECRET && exit 1
        TEMPFILE=`mktemp`
        echo "export BEAKER_SESSION_SECRET=${CKAN_BEAKER_SESSION_SECRET}
        export APP_INSTANCE_UUID=${CKAN_APP_INSTANCE_UUID}
        export SQLALCHEMY_URL=postgresql://${POSTGRES_USER}:${POSTGRES_PASSWORD}@db/ckan
        export CKAN_DATASTORE_WRITE_URL=postgresql://${DATASTORE_POSTGRES_USER}:${DATASTORE_POSTGRES_PASSWORD}@datastore-db/datastore
        export CKAN_DATASTORE_READ_URL=postgresql://${DATASTORE_RO_USER}:${DATASTORE_RO_PASSWORD}@datastore-db/datastore
        export SOLR_URL=http://solr:8983/solr/ckan
        export CKAN_REDIS_URL=redis://redis:6379/1
        export CKAN_DATAPUSHER_URL=
        export SMTP_SERVER=
        export SMTP_STARTTLS=
        export SMTP_USER=
        export SMTP_PASSWORD=
        export SMTP_MAIL_FROM=
        export ALLOWED_SENDERS_RESOURCE_ID=${ALLOWED_SENDERS_RESOURCE_ID}
        export GMAIL_TOKEN='$(echo $GMAIL_TOKEN)'" > $TEMPFILE
        kubectl create secret generic "${CKAN_SECRETS_SECRET}" --from-file=secrets.sh=$TEMPFILE
        CKAN_SECRET_RES="$?"
        rm $TEMPFILE
        [ "$CKAN_SECRET_RES" != "0" ] && echo failed to create ckan secrets secret && exit 1
        echo Great Success
        echo Created new ckan secrets secret: $CKAN_SECRETS_SECRET
        echo Please update the relevant values.yaml file with the new secret name
        exit 0
    else
        echo Ckan secrets secret $CKAN_SECRETES_SECRET already exists
        exit 0
    fi

elif [ "${1}" == "get-ckan-secrets" ]; then
    CKAN_SECRETS_SECRET="${2:-ckan-secrets}"
    OUTPUT_FILE="${3:-secrets.sh}"
    echo Getting ckan secrets from $CKAN_SECRETS_SECRET to $OUTPUT_FILE
    ! SECRETS_JSON=`get_secrets_json $CKAN_SECRETS_SECRET` \
        && echo could not find ckan secrets $CKAN_SECRETS_SECRET && exit 1
    ! get_secret_from_json "${SECRETS_JSON}" '"secrets.sh"' > $OUTPUT_FILE \
        && echo failed to parse secrets && exit 1
    echo Successfully copied secrets
    exit 0

elif [ "${1}" == "initialize-upload-via-email" ]; then
    export CREDENTIALS="${2}"
    [ "${CREDENTIALS}" == "" ] && echo missing CREDENTIALS && exit 1
    ALLOWED_SENDERS_RESOURCE_ID="${3}"
    ! [ -e "${CREDENTIALS}" ] && echo missing CREDENTIALS file $CREDENTIALS && exit 1
    if ! [ -e upload_via_email_requirements.txt ]; then
        ! wget -O upload_via_email_requirements.txt \
               https://raw.githubusercontent.com/OriHoch/ckanext-upload_via_email/v0.0.5/ckanext/upload_via_email/pipelines/requirements.txt \
            && echo Failed to download upload via email requirements && exit 1
    fi
    if ! [ -e upload_via_email_generate_ckan_config.py ]; then
        ! wget -O upload_via_email_generate_ckan_config.py \
               https://raw.githubusercontent.com/OriHoch/ckanext-upload_via_email/v0.0.5/bin/generate_ckan_config.py \
            && echo Failed to download upload via email generate ckan config script && exit 1
        ! sudo pip3 install -r upload_via_email_requirements.txt &&\
            echo Failed to install upload via email requirements && exit 1
    fi
    ! RES=`python3 upload_via_email_generate_ckan_config.py --noauth_local_webserver | tee /dev/stderr` \
        && echo Failed to generate upload via email ckan config && exit 1
    TEMPFILE=`mktemp`
    echo "${RES}" | tail -1 | cut -d" " -f 3- > $TEMPFILE
    [ "`cat $TEMPFILE`" == "" ] && echo Failed to generate gmail token && exit 1
    if [ "${ALLOWED_SENDERS_RESOURCE_ID}" != "" ]; then
        ALLOWED_SENDERS_PARAM="--from-literal=ALLOWED_SENDERS_RESOURCE_ID=${ALLOWED_SENDERS_RESOURCE_ID}"
    else
        ALLOWED_SENDERS_PARAM=""
    fi
    kubectl delete secret ckan-upload-via-email-env-vars
    kubectl create secret generic ckan-upload-via-email-env-vars --from-file=GMAIL_TOKEN=$TEMPFILE \
                                                                 $ALLOWED_SENDERS_PARAM
    RES="$?"
    rm $TEMPFILE
    [ "${RES}" != "0" ] && echo Failed to create upload via email env vars secret && exit 1
    echo Successfully created upload via email env vars secret
    exit 0

elif [ "${1}" == "initialize-backups" ]; then
    SERVICE_ACCOUNT_FILE="${2}"
    DB_PREFIX="${3}"
    DATASTORE_PREFIX="${4}"
    echo Creating DB backup secret
    kubectl delete secret ckan-db-backups >/dev/null 2>&1
    ! kubectl create secret generic ckan-db-backups --from-file=secret.json=$SERVICE_ACCOUNT_FILE \
        && echo Failed to create DB backups secret && exit 1
    echo Please update the following values in the environment values.yaml:
    echo
    echo "  datastore:"
    echo "    dbOps:"
    echo "      enabled: true"
    echo "      backup: ${DB_PREFIX}"
    echo
    echo "  dbOps:"
    echo "    enabled: true"
    echo "    backup: ${DATASTORE_PREFIX}"
    echo
    exit 0

fi
