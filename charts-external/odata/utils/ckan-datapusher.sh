#!/usr/bin/env bash

PARAMS="$@"

[ "${PARAMS}" == "" ] && PARAMS="--help"

kubectl exec -it $(kubectl get pods -l app=ckan -o 'jsonpath={.items[0].metadata.name}') \
    -- ckan-paster --plugin=ckan datapusher -c /etc/ckan/production.ini $PARAMS
