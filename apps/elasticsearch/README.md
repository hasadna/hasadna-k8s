# Elasticsearch

Providing Elasticsearch instances using ECK

## Deploy the operator

The operator and CRDs should be deployed manually:

```
kubectl apply -k apps/elasticsearch/operator
```

## Upgrading the operator

Make changes in the download.sh script and then run it to download the relevant manifests:

```
apps/elasticsearch/operator/download.sh
``` 

## Deploy instances

Instances should be deployed as part of other apps, using the ECK CRDs

see an example in apps/betaknesset

Refer to ECK documentation for details - https://www.elastic.co/guide/en/cloud-on-k8s/current/index.html
