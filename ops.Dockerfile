FROM google/cloud-sdk:alpine

RUN apk --update --no-cache add bash jq py2-pip openssl curl git \
    && pip install --upgrade pip \
    && pip install python-dotenv[cli] pyyaml \
    && gcloud --quiet components install kubectl

RUN wget https://releases.rancher.com/cli2/v2.3.2/rancher-linux-amd64-v2.3.2.tar.gz &&\
    tar -xzvf rancher-linux-amd64-v2.3.2.tar.gz &&\
    mv ./rancher-v2.3.2/rancher /usr/local/bin/ &&\
    rm -rf ./rancher-v2.3.2 rancher-linux-amd64-v2.3.2.tar.gz

RUN apk --update --no-cache add sudo
COPY apps_travis_script.sh ./
RUN bash apps_travis_script.sh install_helm

RUN echo 'rancher login --token $RANCHER_TOKEN $RANCHER_ENDPOINT' >> ~/.bashrc
RUN echo 'rancher kubectl config view --raw | grep -v certificate-authority-data: > /.rancher.kubeconfig' >> ~/.bashrc
RUN echo '[ -f /k8s-ops/secret.json ] && gcloud auth activate-service-account --key-file=/k8s-ops/secret.json' >> ~/.bashrc
RUN echo '[ "${OPS_REPO_SLUG}" != "" ] && ! [ -d /ops ] && git clone --depth 1 --branch ${OPS_REPO_BRANCH:-master} https://github.com/${OPS_REPO_SLUG}.git /ops' >> ~/.bashrc
RUN echo '[ -d /ops ] && cd /ops' >> ~/.bashrc

ENTRYPOINT ["bash"]