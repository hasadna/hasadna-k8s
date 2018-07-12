#!/usr/bin/env bash

echo "${TRAVIS_COMMIT_MESSAGE}" | grep -- --no-deploy && echo skipping deployment && exit 0

openssl aes-256-cbc -K $encrypted_ff5d1c5705e0_key -iv $encrypted_ff5d1c5705e0_iv -in environments/hasadna/k8s-ops.json.enc -out secret-k8s-ops.json -d

K8S_ENVIRONMENT_NAME="hasadna"
OPS_REPO_SLUG="hasadna/hasadna-k8s"
OPS_REPO_BRANCH="${TRAVIS_BRANCH}"
./run_docker_ops.sh "${K8S_ENVIRONMENT_NAME}" '
    RES=0;
    curl -L https://raw.githubusercontent.com/hasadna/hasadna-k8s/master/apps_travis_script.sh | bash /dev/stdin install_helm;
    ./kubectl_patch_charts.py "'"${TRAVIS_COMMIT_MESSAGE}"'" --dry-run
    PATCH_RES=$?
    if [ "${PATCH_RES}" != "2" ]; then
        echo detected patches based on commit message
        if [ "${PATCH_RES}" == "0" ]; then
            ! ./kubectl_patch_charts.py "'"${TRAVIS_COMMIT_MESSAGE}"'" && echo failed patches && RES=1
        else
            echo patches dry run failed && RES=1
        fi
    fi
    exit $RES
' "orihoch/sk8s-ops" "${OPS_REPO_SLUG}" "${OPS_REPO_BRANCH}" "secret-k8s-ops.json"
if [ "$?" == "0" ]; then
    echo travis deployment success
    exit 0
else
    echo travis deployment failed
    exit 1
fi
