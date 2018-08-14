#!/usr/bin/env bash

COMMIT_MESSAGE="${1}"

if echo "${COMMIT_MESSAGE}" | grep 'automatic update of odata-ckan' >/dev/null 2>&1; then
    echo hot reloading odata ckan
    CKAN_POD=`kubectl -n odata get pods -l app=ckan -o 'jsonpath={.items[0].metadata.name}'` &&\
    kubectl -n odata exec $CKAN_POD /entrypoint.sh update-ckanext
    [ "$?" != "0" ] && exit 1
    exit 0
fi

exit 2
