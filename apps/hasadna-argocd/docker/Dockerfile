ARG ARGOCD_VERSION=2.8.2
FROM quay.io/argoproj/argocd:v$ARGOCD_VERSION
USER root
ADD https://dl.google.com/dl/cloudsdk/channels/rapid/downloads/google-cloud-cli-linux-x86_64.tar.gz /opt/google-cloud-cli-linux-x86_64.tar.gz
RUN cd /opt &&\
    tar -xf google-cloud-cli-linux-x86_64.tar.gz &&\
    ./google-cloud-sdk/install.sh -q &&\
    /opt/google-cloud-sdk/bin/gcloud components install gke-gcloud-auth-plugin -q
USER argocd
