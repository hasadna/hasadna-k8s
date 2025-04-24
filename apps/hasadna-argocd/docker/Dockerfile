ARG ARGOCD_VERSION=2.8.2
ARG GCLOUD_VERSION=519.0.0

FROM google/cloud-sdk:$GCLOUD_VERSION as gcloud

FROM quay.io/argoproj/argocd:v$ARGOCD_VERSION
COPY --from=gcloud /usr/bin/gke-gcloud-auth-plugin /usr/bin/gke-gcloud-auth-plugin
