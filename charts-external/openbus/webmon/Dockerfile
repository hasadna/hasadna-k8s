FROM ghcr.io/orihoch/uumpa-ci-toolbox/uci:bf4246c687ff98fca7a2cc7c237521eea7bbfb15
RUN curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip" &&\
    unzip awscliv2.zip && rm awscliv2.zip &&\
    ./aws/install && aws --version
COPY config.yaml stride-db-backup.py /opt/webmon/
ENTRYPOINT ["uci", "webmon", "start-multi", "8901", "/opt/webmon/config.yaml"]