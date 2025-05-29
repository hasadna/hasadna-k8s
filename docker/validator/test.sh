#!/usr/bin/env bash

set -euo pipefail

docker build -t hasadna-k8s-validator docker/validator
docker run -d --name hasadna-k8s-validator -it --entrypoint sh hasadna-k8s-validator -c "
echo 'echo ERROR
false' > validate.sh &&\
cd web && exec httpd -f
"
if docker exec hasadna-k8s-validator wget -SO - localhost; then
  echo expected validator to fail
  echo TEST FAILURE
  exit 1
fi
docker rm -f hasadna-k8s-validator
docker run -d --name hasadna-k8s-validator -it --entrypoint sh hasadna-k8s-validator -c "
echo 'echo Great Success' > validate.sh &&\
cd web && exec httpd -f
"
if ! docker exec hasadna-k8s-validator wget -SO - localhost; then
  echo expected validator to succeed
  echo TEST FAILURE
  exit 1
fi
docker rm -f hasadna-k8s-validator

echo TESTS Success
