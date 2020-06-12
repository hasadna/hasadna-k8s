# Cluster logging

**this method is deprecated** see ../logging.md for the currently used logging method

Switch to the logging environment

```
export KUBECONFIG=/path/to/kamatera/kubeconfig
source switch_environment.sh logging
```

Deploy the elasticsearch operator

```
kubectl apply -f https://download.elastic.co/downloads/eck/1.0.0/all-in-one.yaml
```

Create the logging elasticsearch instance

```
kubectl apply -f environments/logging/manifests/cluster-logs-elasticsearch.yaml
```

Wait for ready status

```
kubectl get elasticsearch
```

Create an ingress

```
kubectl apply -f environments/logging/manifests/cluster-logs-elasticsearch-ingress.yaml
```

Get the Elasticsearch username/password from secret `cluster-logs-es-elastic-user`

Access Elasticsearch at the ingress host

Deploy Kibana

```
kubectl apply -f environments/logging/manifests/cluster-logs-kibana.yaml
```

Wait for health green

```
kubectl get kibana
```

Deploy the Kibana ingress

```
kubectl apply -f environments/logging/manifests/cluster-logs-kibana-ingress.yaml
```

Access Kibana at the ingress host with the Elasticsearch username / password

Enable logging in Rancher per project / namespace

* endpoint: `https://elasticsearch-ingress-host:443`
* Change index name prefix to `hasadna` for all namespaces
* Make sure Elasticsearch is not included in the logs
* Check the log size generated from each namespace, and disable logs if elasticsearch consumes too much RAM

Create a Jenkins job to delete old indices:

* parameter: `RETENTION_DAYS=4`
* build periodically: daily
* secret text: `ELASTICSEARCH_URL=`
* Execute shell:

```
#!/usr/bin/env python3

import requests, os, datetime

to_delete = set()
not_delete = set()
index_names = requests.get('{}/_all'.format(os.environ['ELASTICSEARCH_URL'])).json().keys()
for index_name in index_names:
  if not index_name.startswith('hasadna'): continue
  index_date = datetime.date(*map(int,index_name.split('-')[1:]))
  if index_date + datetime.timedelta(days=int(os.environ['RETENTION_DAYS'])) < datetime.datetime.now().date():
    to_delete.add(index_name)
  else:
    not_delete.add(index_name + '(%s)'%index_date)

print("\n\nindex names NOT to delete: " + str(not_delete))
print("\nindex names to delete: " + str(to_delete))
if len(to_delete) > 0:
  print("\n\ndeleting indices\n\n")
  assert requests.delete('{}/{}?ignore_unavailable=true'.format(os.environ['ELASTICSEARCH_URL'],','.join(to_delete))).status_code == 200
else:
  print("\n\nnot deleting indices\n\n")

print(list(requests.get('{}/_all'.format(os.environ['ELASTICSEARCH_URL'])).json().keys()))

print('Great Success!')
```

## Uninstall

Disable logging in Rancher for all projects

Delete the elasticsearch and kibana instances

```
kubectl -n default delete kibana cluster-logs-kibana
kubectl -n default delete elasticsearch cluster-logs
```

Delete the operator

```
kubectl -n elastic-system delete statefulset elastic-operator
```

Delete ingresses

```
kubectl -n default delete ingress cluster-logs cluster-logs-kibana
```