#!/usr/bin/env bash

wget -O apps/elasticsearch/operator/crds.yaml https://download.elastic.co/downloads/eck/2.1.0/crds.yaml &&\
wget -O apps/elasticsearch/operator/operator.yaml https://download.elastic.co/downloads/eck/2.1.0/operator.yaml
