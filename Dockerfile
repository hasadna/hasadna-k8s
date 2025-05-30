# Pulled May 30, 2025
ARG BASE_IMAGE=python:3.12@sha256:12e60b9c62151e59de29ec7e1836c63080b382415f2b0083a8b7e27e3049dc83
ARG UV_VERSION=0.7.8
FROM $BASE_IMAGE AS builder
RUN curl -LsSf https://astral.sh/uv/${UV_VERSION}/install.sh | sh
WORKDIR /app
COPY pyproject.toml uv.lock ./
RUN ~/.local/bin/uv sync --no-install-project --frozen &&\
    ~/.local/bin/uv pip install --upgrade pip &&\
    chown -R 1000:1000 /app

FROM $BASE_IMAGE
RUN useradd -m -s /bin/bash hasadna
RUN mkdir /home/hasadna/app
WORKDIR /home/hasadna/app
COPY pyproject.toml ./
COPY --from=builder /app/.venv ./.venv
COPY hasadna_k8s ./hasadna_k8s
RUN .venv/bin/python -m pip install --no-cache-dir -e .
ARG VERSION=docker-development
RUN echo "version = '$VERSION'" > hasadna_k8s/version.py &&\
    echo ". /home/hasadna/app/.venv/bin/activate" > /home/hasadna/.bash_env &&\
    echo "PATH=\"/home/hasadna/app/.venv/bin:$PATH\"" >> /home/hasadna/.bash_env &&\
    echo ". /home/hasadna/.bash_env" >> /home/hasadna/.bashrc &&\
    echo "#!/bin/bash" >> entrypoint.sh &&\
    echo "exec hasadna-k8s \"\$@\"" >> entrypoint.sh &&\
    chmod +x entrypoint.sh
ENV BASH_ENV=/home/hasadna/.bash_env
USER hasadna
ENTRYPOINT ["/home/hasadna/app/entrypoint.sh"]
