#!/usr/bin/env bash


## Running this will use install an helm chart from helm repository (e.g, prometheus)

source connect.sh
CHART_NAME="${1}"

[ -z "${CHART_NAME}" ] && echo "usage:" && echo "./helm_upgrade_repo_chart.sh <CHART_NAME>" && exit 1

RELEASE_NAME="${K8S_ENVIRONMENT_NAME}"
echo "RELEASE_NAME=${RELEASE_NAME}"

TEMPDIR=`mktemp -d`
echo '{}' > "${TEMPDIR}/values.yaml"

for VALUES_FILE in values.yaml values.auto-updated.yaml environments/${K8S_ENVIRONMENT_NAME}/values.yaml environments/${K8S_ENVIRONMENT_NAME}/values.auto-updated.yaml
do
    if [ -f "${VALUES_FILE}" ]; then
        GLOBAL_VALUES=`./read_yaml.py "${VALUES_FILE}" global 2>/dev/null`
        ! [ -z "${GLOBAL_VALUES}" ] \
            && ./update_yaml.py '{"global":'${GLOBAL_VALUES}'}' "${TEMPDIR}/values.yaml"
        RELEASE_VALUES=`./read_yaml.py "${VALUES_FILE}" "${CHART_NAME}" 2>/dev/null`
        ! [ -z "${RELEASE_VALUES}" ] \
            && ./update_yaml.py "${RELEASE_VALUES}" "${TEMPDIR}/values.yaml"
    fi
#    cat "${TEMPDIR}/values.yaml"
done

VALUES=`cat "${TEMPDIR}/values.yaml"`

CMD="helm upgrade -f ${TEMPDIR}/values.yaml ${RELEASE_NAME} ${CHART_NAME} ${@:2}"
if ! $CMD; then
    echo
    echo "${TEMPDIR}/values.yaml"
    echo "${VALUES}"
    echo
    echo "CMD"
    echo "${CMD}"
    echo
    echo "helm install failed"
    
else
    rm -rf $TEMPDIR
    echo "Great Success!"
  
fi

