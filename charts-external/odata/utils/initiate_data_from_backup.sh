#!/usr/bin/env bash

GS_URL=$1

[ "${GS_URL}" == "" ] && echo "usage: charts-external/odata/utils/initiate_data_from_backup.sh <GS_URL>"

TEMPDIR=`mktemp -d`
gsutil cp $GS_URL $TEMPDIR/data-dump.tar.bz2 &&\
kubectl cp $TEMPDIR/data-dump.tar.bz2 \
           $(kubectl get pods -l app=ckan -o 'jsonpath={.items[0].metadata.name}'):/var/lib/ckan/ &&\
kubectl exec -it $(kubectl get pods -l app=ckan -o 'jsonpath={.items[0].metadata.name}') \
    -- bash -c "cd /var/lib/ckan && tar -xjvf data-dump.tar.bz2 && rm data-dump.tar.bz2"
RES=$?
rm -rf $TEMPDIR

[ "${RES}" != "0" ] && echo Failed to initialize data && exit 1

echo Great Success
exit 0
