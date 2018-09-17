#!/usr/bin/env bash

RES=0

echo "Linting all charts"
for CHART_NAME in `ls charts-external`; do
    LINT_ENVIRONMENTS=$(eval echo `./read_yaml.py charts-config.yaml $CHART_NAME lint-environments 2>/dev/null`)
    if [ "${LINT_ENVIRONMENTS}" != "" ]; then
        for LINT_ENVIRONMENT in $LINT_ENVIRONMENTS; do
            echo LINT_ENVIRONMENT=$LINT_ENVIRONMENT
            ! ./helm_lint_external_chart.sh $CHART_NAME $LINT_ENVIRONMENT && RES=1
        done
    else
        helm lint charts-external/$CHART_NAME 2>/dev/null | grep 'ERROR' | grep -v 'Chart.yaml: version is required'
        if [ "$?" == "0" ]; then
            echo "${CHART_NAME}: failed lint"
            RES=1
        else
            echo "${CHART_NAME}: OK"
        fi
    fi

done

exit $RES
