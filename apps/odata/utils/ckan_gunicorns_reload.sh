#!/usr/bin/env bash

RES=0

for POD_NAME in `kubectl get pods -l app=ckan -o 'jsonpath={.items[*].metadata.name}'`; do
    ! kubectl exec $POD_NAME -- kill -HUP 1 && echo failed to restart pod $POD_NAME && RES=1
done

[ "${RES}" != "0" ] && exit 1

echo Great Success
exit 0
