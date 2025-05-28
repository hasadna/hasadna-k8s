#!/usr/bin/env bash

# script to setup environment for AI agents

set -euo pipefail

uv sync
uv pip install -r tests/requirements.txt

cd hasadna-mutating-webhook
go mod download -json
cd ..

wget https://releases.hashicorp.com/terraform/1.12.1/terraform_1.12.1_linux_amd64.zip
unzip terraform_1.12.1_linux_amd64.zip -d /usr/local/bin
rm terraform_1.12.1_linux_amd64.zip
chmod +x /usr/local/bin/terraform

wget https://releases.hashicorp.com/vault/1.19.4/vault_1.19.4_linux_amd64.zip
unzip vault_1.19.4_linux_amd64.zip -d /usr/local/bin
rm vault_1.19.4_linux_amd64.zip
chmod +x /usr/local/bin/vault

touch .AGENTS.sh.completed
