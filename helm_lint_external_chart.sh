#!/usr/bin/env bash

CHART_NAME="${1}"
LINT_ENVIRONMENT="${2}"

( [ -z "${CHART_NAME}" ] || [ -z "${LINT_ENVIRONMENT}" ] ) \
    && echo "usage:" && echo "./helm_lint_external_chart.sh <EXTERNAL_CHART_NAME> <LINT_ENVIRONMENT>" && exit 1

EXTERNAL_CHARTS_DIRECTORY="charts-external"
CHART_DIRECTORY="${EXTERNAL_CHARTS_DIRECTORY}/${CHART_NAME}"

[ ! -e "${CHART_DIRECTORY}" ] && echo "CHART_DIRECTORY does not exist" && exit 1

TEMPDIR=`mktemp -d`
echo '{}' > "${TEMPDIR}/values.yaml"

for VALUES_FILE in values.yaml values.auto-updated.yaml environments/${LINT_ENVIRONMENT}/values.yaml environments/${LINT_ENVIRONMENT}/values.auto-updated.yaml
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

CMD="helm lint -f ${TEMPDIR}/values.yaml ${CHART_DIRECTORY} ${@:3}"
if $CMD 2>/dev/null | grep 'ERROR' | grep -v 'Chart.yaml: version is required'; then
    echo "CHART_DIRECTORY=${CHART_DIRECTORY}"
    echo "LINT_ENVIRONMENT=${LINT_ENVIRONMENT}"
    echo "${VALUES}"
    echo "${CMD}"
    echo "${CHART_NAME}: failed lint"
    exit 1
else
    rm -rf $TEMPDIR
    echo "${CHART_NAME}: OK"
    exit 0
fi
