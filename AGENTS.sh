#!/usr/bin/env bash

# script to setup environment for AI agents

set -euo pipefail

uv sync
uv pip install -r tests/requirements.txt

cd hasadna-mutating-webhook
go mod download -json
cd ..
