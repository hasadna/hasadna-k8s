#!/usr/bin/env bash

COMMIT_MESSAGE="${1}"

export KUBECONFIG=/.rancher.kubeconfig

if echo "${COMMIT_MESSAGE}" | grep 'automatic update of odata-ckan' >/dev/null 2>&1; then

    # echo odata ckan hot reload is disabled - it causes some problems
    exit 2

    echo hot reloading odata ckan
    CKAN_PODS=`kubectl -n odata get pods -l app=ckan -o 'jsonpath={.items[*].metadata.name}'`
    echo CKAN_PODS: $CKAN_PODS
    for CKAN_POD in $CKAN_PODS; do
        echo hot reloading ckan pod $CKAN_POD
        kubectl -n odata exec $CKAN_POD /entrypoint.sh update-ckanext
        [ "$?" != "0" ] && exit 1
    done
    echo all ckan pods reloaded successfuly
    exit 0
fi

exit 2
