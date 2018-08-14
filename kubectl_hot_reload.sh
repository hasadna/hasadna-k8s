#!/usr/bin/env bash

COMMIT_MESSAGE="${1}"

[ "${COMMIT_MESSAGE}" == "" ] && echo warning: no commit message && exit 2

for CHART in `ls charts-external`; do
    if [ -f charts-external/$CHART/kubectl_hot_reload.sh ]; then
        charts-external/$CHART/kubectl_hot_reload.sh "${COMMIT_MESSAGE}"
        RES=$?
        [ "${RES}" == "0" ] && echo successful hot reload for chart $CHART \
            && exit 0
        [ "${RES}" == "1" ] && echo failed hot reload for chart $CHART \
            && exit 1
        [ "${RES}" != "2" ] && echo invalid hot reload exit code for chart $CHART: $RES \
            && exit 1
    fi
done

exit 2
