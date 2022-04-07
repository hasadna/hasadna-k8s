# Elasticsearch

Providing Elasticsearch instances using ECK

## Deploy the operator

The operator and CRDs should be deployed manually:

```
kubectl apply -k apps/elasticsearch/operator
```

## Deploy instances

Instances should be deployed as part of other apps, using the ECK CRDs

see an example in apps/betaknesset

Refer to ECK documentation for details - https://www.elastic.co/guide/en/cloud-on-k8s/current/index.html
