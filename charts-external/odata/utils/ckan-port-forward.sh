#!/usr/bin/env bash

kubectl port-forward $(kubectl get pods -l app=ckan -o 'jsonpath={.items[0].metadata.name}') ${1:-5000}
