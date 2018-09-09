#!/usr/bin/env bash

CURRENT_SECRET=$(eval echo `./read_env_yaml.sh odata etcCkanDefaultSecretName`)
OLD_SECRETS=$(kubectl get secrets | grep etc-ckan-default | grep -v '^'${CURRENT_SECRET}' ' | cut -d" " -f 1)

echo CURRENT_SECRET:
echo "${CURRENT_SECRET}"
echo
echo OLD_SECRETS:
echo "${OLD_SECRETS}"
echo
read -p "Press <Enter> to delete the old secrets"

kubectl delete secret $OLD_SECRETS
