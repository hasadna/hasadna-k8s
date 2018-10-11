FROM jupyter/minimal-notebook

USER root

RUN apt-get update -y &&\
    apt-get install -y \
        bash jq python-pip openssl curl git &&\
    pip install --upgrade pip && pip install python-dotenv pyyaml

RUN curl https://sdk.cloud.google.com | bash -s - --disable-prompts --install-dir=/gcloud
RUN bash -c "source /gcloud/google-cloud-sdk/completion.bash.inc &&\
             source /gcloud/google-cloud-sdk/path.bash.inc &&\
             gcloud components install kubectl --quiet"
RUN mkdir -p /usr/local/bin/before-notebook.d && echo '\
    source /gcloud/google-cloud-sdk/completion.bash.inc &&\
    source /gcloud/google-cloud-sdk/path.bash.inc &&\
    ( cd /home/$NB_USER/hasadna-k8s && bash apps_travis_script.sh install_helm ) \
    ' > /usr/local/bin/before-notebook.d/gcloud.sh
    
RUN curl https://raw.githubusercontent.com/kubernetes/helm/master/scripts/get > get_helm.sh &&\
    chmod 700 get_helm.sh &&\
    ./get_helm.sh --version v2.8.2 &&\
    helm version --client --short | grep "Client: v2.8.2+"
    
RUN ln -s `which python3` /usr/bin/python3 &&\
    python3 -m pip install bash_kernel &&\
    python3 -m bash_kernel.install
    
RUN pip install --upgrade python-dotenv[cli]

RUN pip2 install supervisor

ENV JUPYTER_ENABLE_LAB=1
