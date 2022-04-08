#!/usr/bin/env bash

VERSION="0.9.2"
MANIFESTS="admission-controller-deployment.yaml recommender-deployment.yaml vpa-rbac.yaml vpa-v1-crd.yaml"

for MANIFEST in $MANIFESTS ; do
  wget -O apps/vertical-pod-autoscaler/$MANIFEST https://raw.githubusercontent.com/kubernetes/autoscaler/vertical-pod-autoscaler-$VERSION/vertical-pod-autoscaler/deploy/$MANIFEST
done