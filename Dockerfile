# Pulled Dec 11, 2024
FROM ghcr.io/astral-sh/uv:python3.12-bookworm@sha256:481869efca773b240d322b251050663d71b68f9086735f9b86a5a8b6cfb19f6e
RUN useradd -m -s /bin/bash hasadna
RUN mkdir /home/hasadna/app
WORKDIR /home/hasadna/app
COPY pyproject.toml uv.lock ./
RUN uv sync --no-install-project --frozen
COPY hasadna_k8s ./hasadna_k8s
RUN uv sync --frozen
ARG VERSION=docker-development
RUN echo "version = '$VERSION'" > hasadna_k8s/version.py
USER hasadna
ENTRYPOINT ["uv", "run", "hasadna-k8s"]
