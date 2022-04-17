#!/usr/bin/env bash

GS_URL=$1

[ "${GS_URL}" == "" ] && echo "usage: charts-external/odata/utils/initiate_db_from_backup.sh <GS_URL>"

TEMPDIR=`mktemp -d`

RES=0

if echo CREATE DATABASE ckan | kubectl exec -i $(kubectl get pods -l app=db -o 'jsonpath={.items[0].metadata.name}') \
                                            -- su postgres -c psql; then
    if [ "${GS_URL:(-5)}" == ".dump" ]; then
        if gsutil cp $GS_URL $TEMPDIR/db-dump; then
            ! cat $TEMPDIR/db-dump | kubectl exec -i $(kubectl get pods -l app=db -o 'jsonpath={.items[0].metadata.name}') \
                                                  -- su postgres -c 'pg_restore --exit-on-error -d ckan >/dev/null' \
                && echo Failed to restore from $GS_URL && RES=1
        else
            echo failed to copy from $GS_URL && RES=1
        fi
    else
        if gsutil cp $GS_URL $TEMPDIR/db-dump.gz && gunzip $TEMPDIR/db-dump.gz; then
            ! cat $TEMPDIR/db-dump | kubectl exec -i $(kubectl get pods -l app=db -o 'jsonpath={.items[0].metadata.name}') \
                                                  -- su postgres -c "psql ckan" \
                && echo Failed to restore from $GS_URL && RES=1
        else
            echo failed to copy and extract from $GS_URL && RES=1
        fi
    fi
else
    echo Failed to create database && RES=1
fi

rm -rf $TEMPDIR

[ "${RES}" != "0" ] && exit 1

echo Great Success
exit 0
