#!/bin/bash
set -euo pipefail

uv sync
uv pip install --requirement tests/requirements.txt

cd hasadna-mutating-webhook
go mod download
