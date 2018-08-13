#!/usr/bin/env bash

GS_URL=$1

[ "${GS_URL}" == "" ] && echo "usage: charts-external/odata/utils/initiate_db_from_backup.sh <GS_URL>"

TEMPDIR=`mktemp -d`
gsutil cp $GS_URL $TEMPDIR/db-dump.gz &&\
gunzip $TEMPDIR/db-dump.gz &&\
echo CREATE DATABASE ckan | kubectl exec -i $(kubectl get pods -l app=db -o 'jsonpath={.items[0].metadata.name}') \
                              -- su postgres -c psql &&\
cat $TEMPDIR/db-dump | kubectl exec -i $(kubectl get pods -l app=db -o 'jsonpath={.items[0].metadata.name}') \
                         -- su postgres -c "psql ckan"
RES=$?
rm -rf $TEMPDIR

[ "${RES}" != "0" ] && echo Failed to initialize db && exit 1

echo Great Success
exit 0
