FROM quay.io/argoproj/argocd:v2.3.3
USER root
RUN apt update && apt install -y python3 python3-pip
RUN pip install kubernetes==23.6.0
USER 999
