#!/usr/bin/env bash

kubectl rollout status deployment/openpension-client && kubectl rollout status deployment/openpension-server
