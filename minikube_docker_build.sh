#!/usr/bin/env bash

minikube mount `pwd`:/hasadna-k8s &
sleep 2
echo 'cd /hasadna-k8s/charts-external/anyway/docker/postgres-postgis/; docker build  -t db .; exit' | minikube ssh &&\
kill %1 && sleep 1
[ "${?}" != "0" ] && echo failed to build the docker image inside minikube && exit 1
echo db-backup docker image was built successfully inside minikube
exit 0
 