#!/usr/bin/env bash

usage() {
    echo "Usage: ./run_docker_ops.sh <ENVIRONMENT_NAME> [SCRIPT:bash] [OPS_DOCKER_IMAGE:orihoch/sk8s-ops] <OPS_REPO_SLUG> [OPS_REPO_BRANCH:master] [OPS_SECRET_JSON_FILE:./secret-k8s-ops.json] [DOCKER_RUN_PARAMS]"
}

ENVIRONMENT_NAME="${1}"
SCRIPT="${2}"
OPS_DOCKER_IMAGE="${3}"
OPS_REPO_SLUG="${4}"
OPS_REPO_BRANCH="${5}"
OPS_SECRET_JSON_FILE="${6}"
DOCKER_RUN_PARAMS="${7}"

echo "ENVIRONMENT_NAME=${ENVIRONMENT_NAME}"
echo "OPS_DOCKER_IMAGE=${OPS_DOCKER_IMAGE}"
echo "OPS_REPO_SLUG=${OPS_REPO_SLUG}"
echo "OPS_REPO_BRANCH=${OPS_REPO_BRANCH}"
echo "OPS_SECRET_JSON_FILE=${OPS_SECRET_JSON_FILE}"
echo "DOCKER_RUN_PARAMS=${DOCKER_RUN_PARAMS}"

[ -z "${ENVIRONMENT_NAME}" ] && usage && exit 1
[ -z "${OPS_REPO_SLUG}" ] && usage && exit 1

[ -z "${SCRIPT}" ] && SCRIPT="bash"
[ -z "${OPS_DOCKER_IMAGE}" ] && OPS_DOCKER_IMAGE="orihoch/hasadna-k8s-ops-kamatera@sha256:e87997ad5d4bdead53e15a7f1d1d017c39655a4e2ea4b5107b01a531825fe61b" \
                             && echo "OPS_DOCKER_IMAGE=${OPS_DOCKER_IMAGE}"
[ -z "${OPS_REPO_BRANCH}" ] && OPS_REPO_BRANCH="master" \
                            && echo "OPS_REPO_BRANCH=${OPS_REPO_BRANCH}"
[ -z "${OPS_SECRET_JSON_FILE}" ] && OPS_SECRET_JSON_FILE="secret-k8s-ops.json" \
                                 && echo "OPS_SECRET_JSON_FILE=${OPS_SECRET_JSON_FILE}"

[ ! -f "${OPS_SECRET_JSON_FILE}" ] && echo "Missing secret json file ${OPS_SECRET_JSON_FILE}" && exit 1

! docker run -it -v "`readlink -f "${OPS_SECRET_JSON_FILE}"`:/k8s-ops/secret.json" \
                 -e "OPS_REPO_SLUG=${OPS_REPO_SLUG}" \
                 -e "OPS_REPO_BRANCH=${OPS_REPO_BRANCH}" \
                 -e RANCHER_TOKEN=${RANCHER_TOKEN} -e RANCHER_ENDPOINT=${RANCHER_ENDPOINT} \
                 $DOCKER_RUN_PARAMS \
                 "${OPS_DOCKER_IMAGE}" \
                 -c "source ~/.bashrc && source switch_environment.sh ${ENVIRONMENT_NAME}; ${SCRIPT}" \
    && echo "failed to run SCRIPT" && exit 1

echo "Great Success!"
exit 0
