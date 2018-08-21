# Hasadna K8S Monitoring

Monitoring is based on Prometheus, it's deployed directly using kubectl from the `monitoring/manifests` directory.

## Updating the manifests

```
TEMPDIR=`mktemp -d`
curl -L https://github.com/coreos/prometheus-operator/archive/master.zip > $TEMPDIR/prom.zip
rm -rf environments/monitoring/manifests/* &&\
unzip -j \
      $TEMPDIR/prom.zip \
      'prometheus-operator-master/contrib/kube-prometheus/manifests/*' \
      -d environments/monitoring/manifests
```

Patch for GKE (see https://github.com/coreos/prometheus-operator/blob/master/contrib/kube-prometheus/docs/GKE-cadvisor-support.md)

```
sed -i -e 's/https/http/g' \
environments/monitoring/manifests/prometheus-serviceMonitorKubelet.yaml
```

## Installing the manifests

```
source switch_environment.sh monitoring
```

First, you might need to give yourself cluster-role-binding

```
kubectl create clusterrolebinding your-name-cluster-admin-binding \
                                  --clusterrole=cluster-admin \
                                  --user=<EMAIL_OR_GOOGLE_SERVICE_ACCOUNT_ID>
```

Now you can create the manifests

```
kubectl create -f environments/monitoring/manifests/
```
