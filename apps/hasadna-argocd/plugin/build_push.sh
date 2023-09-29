#!/usr/bin/env bash

TAG=$(git rev-parse HEAD)
docker build -t ghcr.io/hasadna/hasadna-k8s/hasadna-argocd-plugin:$TAG apps/hasadna-argocd/plugin/ &&\
docker push ghcr.io/hasadna/hasadna-k8s/hasadna-argocd-plugin:$TAG