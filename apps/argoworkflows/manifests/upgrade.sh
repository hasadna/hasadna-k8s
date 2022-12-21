#!/usr/bin/env bash

VERSION="${1}"

if [[ -z "${VERSION}" ]]; then
  echo "Usage: $0 <version>"
  exit 1
fi &&\
echo Upgrading ArgoWorkflows to "${VERSION}" &&\
URL="https://github.com/argoproj/argo-workflows/releases/download/${VERSION}/install.yaml" &&\
echo "# downloaded $(date +%Y-%m-%d) from:" > apps/argoworkflows/manifests/install.yaml &&\
echo "#   ${URL}" >> apps/argoworkflows/manifests/install.yaml &&\
curl -sL "${URL}" >> apps/argoworkflows/manifests/install.yaml &&\
echo OK
