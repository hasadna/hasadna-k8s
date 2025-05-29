FROM ghcr.io/hasadna/hasadna-k8s/validator:b4f34a177e4726b9e1adf318eb8f6dae6d418a91
ENV KOPIA_VERSION=0.20.1
ADD https://github.com/kopia/kopia/releases/download/v${KOPIA_VERSION}/kopia-${KOPIA_VERSION}-linux-x64.tar.gz .
USER root
RUN tar -xzvf kopia-${KOPIA_VERSION}-linux-x64.tar.gz &&\
    mv kopia-${KOPIA_VERSION}-linux-x64/kopia /usr/bin/ &&\
    chmod +x /usr/bin/kopia &&\
    rm -rf kopia-${KOPIA_VERSION}-linux-x64 kopia-${KOPIA_VERSION}-linux-x64.tar.gz
USER validator
