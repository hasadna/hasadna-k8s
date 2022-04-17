#!/usr/bin/env bash

./kubectl.sh exec pipelines pip install jupyter jupyterlab ipython &&\
exec kubectl exec -it $(./kubectl.sh get-pod-name pipelines) -- \
    jupyter lab --ip 0.0.0.0 --port 8888 --no-browser --allow-root --custom-display-url http://localhost:8888
