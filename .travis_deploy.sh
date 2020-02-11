#!/usr/bin/env bash

echo "${TRAVIS_COMMIT_MESSAGE}" | grep -- --no-deploy && echo skipping deployment && exit 0

openssl aes-256-cbc -K $encrypted_ff5d1c5705e0_key -iv $encrypted_ff5d1c5705e0_iv -in environments/hasadna/k8s-ops.json.enc -out secret-k8s-ops.json -d

K8S_ENVIRONMENT_NAME="hasadna"
OPS_REPO_SLUG="hasadna/hasadna-k8s"
OPS_REPO_BRANCH="${TRAVIS_BRANCH}"
./run_docker_ops.sh "${K8S_ENVIRONMENT_NAME}" '
    ./kubectl_hot_reload.sh "'"${TRAVIS_COMMIT_MESSAGE}"'"
    HOT_RELOAD_RES=$?
    [ "${HOT_RELOAD_RES}" == "1" ] && echo hot reload failed && exit 1
    [ "${HOT_RELOAD_RES}" == "0" ] && echo hot reload success && exit 0
    [ "${HOT_RELOAD_RES}" != "2" ] && echo invalid hot reload exit code $HOT_RELOAD_RES && exit 1
    ./kubectl_patch_charts.py "'"${TRAVIS_COMMIT_MESSAGE}"'" --dry-run
    PATCH_RES=$?
    [ "${PATCH_RES}" == "1" ] && echo patches dry run failed && exit 1
    if [ "${PATCH_RES}" == "0" ]; then
        echo performing patches
        ! ./kubectl_patch_charts.py "'"${TRAVIS_COMMIT_MESSAGE}"'" && echo failed patches && exit 1
        echo patches successful
        exit 0
    fi
    [ "${PATCH_RES}" != "2" ] && echo invalid patches exit code $PATCH_RES && exit 1
    echo nothing to do...
    exit 0
' "orihoch/hasadna-k8s-ops-kamatera@sha256:e87997ad5d4bdead53e15a7f1d1d017c39655a4e2ea4b5107b01a531825fe61b" "${OPS_REPO_SLUG}" "${OPS_REPO_BRANCH}" "secret-k8s-ops.json"
if [ "$?" == "0" ]; then
    echo travis deployment success
    exit 0
else
    echo travis deployment failed
    exit 1
fi
