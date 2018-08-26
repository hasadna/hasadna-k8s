#!/usr/bin/env bash

if [ "${1}" == "loop" ]; then
    # can be used to wait track progress of changes
    # e.g.
    # ./kubectl.sh loop get pods
    while true; do
        kubectl "${@:2}"
        sleep 1
    done

elif [ "${1}" == "port-forward" ]; then
    # port-forward based on app label
    if [ "${3}" == "" ]; then
        PORT_FORWARD_DEFAULT_ARGS=""
        [ -e charts-external/${2}/default.sh ] && source charts-external/${2}/default.sh
        [ -z "${PORT_FORWARD_DEFAULT_ARGS}" ] && echo missing port-forward args && exit 1
        ARGS="${PORT_FORWARD_DEFAULT_ARGS}"
    else
        ARGS="${@:3}"
    fi
    kubectl port-forward $(./kubectl.sh get-pod-name "${2}") $ARGS


elif [ "${1}" == "get-pod-name" ]; then
    # get pod name based on app label
    kubectl get pods -l "app=${2}" -o 'jsonpath={.items[0].metadata.name}'

elif [ "${1}" == "exec" ]; then
    if [ "${3}" == "" ]; then
        EXEC_DEFAULT_ARGS=""
        [ -e charts-external/${2}/default.sh ] && source charts-external/${2}/default.sh
        [ -z "${EXEC_DEFAULT_ARGS}" ] && echo missing exec args && exit 1
        ARGS="${EXEC_DEFAULT_ARGS}"
    else
        ARGS="${@:3}"
    fi
    kubectl exec $(./kubectl.sh get-pod-name "${2}") $ARGS

elif [ "${1}" == "logs" ]; then
    if [ "${3}" == "" ]; then
        LOGS_DEFAULT_ARGS=""
        [ -e charts-external/${2}/default.sh ] && source charts-external/${2}/default.sh
        ARGS="${LOGS_DEFAULT_ARGS}"
    else
        ARGS="${@:3}"
    fi
    kubectl logs $(./kubectl.sh get-pod-name "${2}") $ARGS

fi
