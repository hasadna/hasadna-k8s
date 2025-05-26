#!/usr/bin/env bash

! which vault >/dev/null && echo missing vault binary && exit 1
! which jq >/dev/null && echo missing jq binary && exit 1
[ "${VAULT_ADDR}" == "" ] && echo missing VAULT_ADDR env var && exit 1
[ "${VAULT_TOKEN}" == "" ] && echo missing VAULT_TOKEN env var && exit 1
! vault read kv/data/Projects/k8s/argocd && echo invalid vault addr or token && exit 1

DATA="$(vault read kv/data/Projects/k8s/argocd -format=json | jq .data.data)" &&\
GITHUB_CLIENT_ID="$(echo "${DATA}" | jq -r .rke2_github_client_id)" &&\
GITHUB_CLIENT_SECRET="$(echo "${DATA}" | jq -r .rke2_github_client_secret)" &&\
cp -f apps/hasadna-argocd/manifests/patch-argocd-cm.yaml.template apps/hasadna-argocd/manifests/patch-argocd-cm.yaml &&\
sed -i "s/__dex.config.connectors.github.clientID__/${GITHUB_CLIENT_ID}/" apps/hasadna-argocd/manifests/patch-argocd-cm.yaml &&\
sed -i "s/__dex.config.connectors.github.clientSecret__/${GITHUB_CLIENT_SECRET}/" apps/hasadna-argocd/manifests/patch-argocd-cm.yaml &&\
DATA="$(vault read kv/data/Projects/iac/outputs/hasadna_argocd -format=json | jq .data.data)" &&\
GITHUB_WEBHOOK_SECRET="$(echo "${DATA}" | jq -r .github_webhook_secret)" &&\
cp -f apps/hasadna-argocd/manifests/github-secret.yaml.template apps/hasadna-argocd/manifests/github-secret.yaml &&\
sed -i "s/__github_webhook_secret__/${GITHUB_WEBHOOK_SECRET}/" apps/hasadna-argocd/manifests/github-secret.yaml &&\
echo OK
