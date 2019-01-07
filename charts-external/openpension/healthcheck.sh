#!/usr/bin/env bash

kubectl rollout status deployment/client && kubectl rollout status deployment/server
