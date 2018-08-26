#!/usr/bin/env bash

[ "${1}" == "" ] && echo please provide unique tag for the docker images && exit 1

docker build -t orihoch/hasadna-k8s-odata-db:${1} charts-external/odata/utils/db &&\
docker build -t orihoch/hasadna-k8s-odata-db-ops:${1} charts-external/odata/utils/db-ops/ &&\
docker push orihoch/hasadna-k8s-odata-db-ops:${1} &&\
docker push orihoch/hasadna-k8s-odata-db:${1}

echo "Built and pushed the following images:"
echo orihoch/hasadna-k8s-odata-db-ops:${1}
echo orihoch/hasadna-k8s-odata-db:${1}
