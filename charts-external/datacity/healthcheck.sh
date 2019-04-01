#!/usr/bin/env bash

kubectl rollout status deployment/frontend && kubectl rollout status deployment/backend
