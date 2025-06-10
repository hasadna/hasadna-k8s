# Pulled May 30, 2025
ARG BASE_IMAGE=python:3.12@sha256:12e60b9c62151e59de29ec7e1836c63080b382415f2b0083a8b7e27e3049dc83
FROM $BASE_IMAGE AS builder
ARG KUBECTL_VERSION=v1.20.15
ADD https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl /usr/local/bin/kubectl
ARG UV_VERSION=0.7.8
ADD https://astral.sh/uv/${UV_VERSION}/install.sh uv_install.sh
RUN sh uv_install.sh &&\
    chmod +x /usr/local/bin/kubectl
WORKDIR /app
COPY pyproject.toml uv.lock ./
RUN ~/.local/bin/uv sync --no-install-project --frozen &&\
    ~/.local/bin/uv pip install --upgrade pip &&\
    chown -R 1000:1000 /app

FROM $BASE_IMAGE
ARG CEPH_VERSION=19.2.2
ARG CEPH_RELEASE=squid
RUN apt update && apt install -y rsync git gnupg2 curl ca-certificates lsb-release &&\
    curl -fsSL https://download.ceph.com/keys/release.asc | gpg --dearmor -o /usr/share/keyrings/ceph.gpg &&\
    echo "deb [signed-by=/usr/share/keyrings/ceph.gpg] https://download.ceph.com/debian-${CEPH_RELEASE}/ $(lsb_release -sc) main" > /etc/apt/sources.list.d/ceph.list &&\
    apt update &&\
    apt install -y ceph-common=${CEPH_VERSION}-1* rbd-nbd=${CEPH_VERSION}-1* ceph-fuse=${CEPH_VERSION}-1* &&\
    rm -rf /var/lib/apt/lists/*
COPY --from=builder /usr/local/bin/kubectl /usr/local/bin/kubectl
ARG KOPIA_VERSION=0.20.1
ADD https://github.com/kopia/kopia/releases/download/v${KOPIA_VERSION}/kopia-${KOPIA_VERSION}-linux-x64.tar.gz /tmp/kopia.tar.gz
RUN cd /tmp &&\
    tar -xzvf kopia.tar.gz &&\
    mv kopia-${KOPIA_VERSION}-linux-x64/kopia /usr/local/bin/ &&\
    chmod +x /usr/local/bin/kopia &&\
    rm -rf kopia-${KOPIA_VERSION}-linux-x64 kopia.tar.gz
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
