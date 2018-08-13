#!/usr/bin/env bash

PARAMS="$@"

[ "${PARAMS}" == "" ] && PARAMS="--help"

kubectl exec -it $(kubectl get pods -l app=ckan -o 'jsonpath={.items[0].metadata.name}') \
    -- bash -c "../../bin/paster sysadmin -c /etc/ckan/default/development.ini $PARAMS"
