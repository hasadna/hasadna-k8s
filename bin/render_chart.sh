#!/usr/bin/env bash

CHART_PATH="${1}"
CHART_NAME="${2}"
HELM_ARGS="${3}"
APPLY="${4}"

render() {
  apps/hasadna-argocd/argocd-hasadna-plugin.py init $CHART_PATH &&\
  apps/hasadna-argocd/argocd-hasadna-plugin.py generate $CHART_PATH $CHART_NAME $HELM_ARGS
}

if [ "${APPLY}" == "--apply" ]; then
  render | kubectl apply -f -
elif [ "${APPLY}" == "--dry-run" ]; then
  render | kubectl apply --dry-run=server -f -
else
  render
fi
