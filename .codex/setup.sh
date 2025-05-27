#!/bin/bash
set -euo pipefail

# Install the project’s Python dependencies.
uv sync

# Install additional packages required by the tests.
uv pip install --requirement tests/requirements.txt

# Pre-download Go modules so `go test` works offline.
cd haadna-mutating-webhook
go mod download
