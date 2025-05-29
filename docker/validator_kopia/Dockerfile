FROM ghcr.io/hasadna/hasadna-k8s/validator:d5c0418f45e25098963800fc58aaef23229d6fdd
ENV KOPIA_VERSION=0.20.1
ADD https://github.com/kopia/kopia/releases/download/v${KOPIA_VERSION}/kopia-${KOPIA_VERSION}-linux-x64.tar.gz .
USER root
RUN tar -xzvf kopia-${KOPIA_VERSION}-linux-x64.tar.gz &&\
    mv kopia-${KOPIA_VERSION}-linux-x64/kopia /usr/bin/ &&\
    chmod +x /usr/bin/kopia &&\
    rm -rf kopia-${KOPIA_VERSION}-linux-x64 kopia-${KOPIA_VERSION}-linux-x64.tar.gz &&\
    chown validator:validator validate.sh
USER validator
