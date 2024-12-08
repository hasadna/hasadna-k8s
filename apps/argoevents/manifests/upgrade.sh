#!/usr/bin/env bash

VERSION="${1}"

if [[ -z "${VERSION}" ]]; then
  echo "Usage: $0 <version>"
  exit 1
fi &&\
echo Upgrading ArgoEvents to "${VERSION}" &&\
URL="https://raw.githubusercontent.com/argoproj/argo-events/${VERSION}/manifests/install.yaml" &&\
echo "# downloaded $(date +%Y-%m-%d) from:" > apps/argoevents/manifests/install.yaml &&\
echo "#   ${URL}" >> apps/argoevents/manifests/install.yaml &&\
curl -sL "${URL}" >> apps/argoevents/manifests/install.yaml &&\
echo OK
