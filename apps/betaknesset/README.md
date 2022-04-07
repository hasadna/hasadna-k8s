# BetaKnesset

## Access Elasticsearch / Kibana

Get the password

```
kubectl -n betaknesset get secret betaknesset-elasticsearch-es-elastic-user -o go-template='{{.data.elastic | base64decode}}'
```

Login to Kibana at https://betaknesset-kibana.hasadna.org.il with username `elastic`

Access elasticsearch using https://elastic:PASSWORD@betaknesset-elasticsearch.hasadna.org.il
