# kube-prometheus-stack

Chart is taken from:\
https://github.com/prometheus-community/helm-charts/tree/main/charts/kube-prometheus-stack

The currently running Prometheus stack is based on `rancher-monitoring-prometheus:v2.28.1`.\
Latest Prometheus version is `2.53.1`.

Upgrade guide:\
https://github.com/prometheus-community/helm-charts/blob/main/charts/kube-prometheus-stack/README.md

Compatibility Matrix:\
https://github.com/prometheus-operator/kube-prometheus/tree/main#compatibility

Compatibility matrix says the latest `kube-prometheus-stack` is officially supported from Kubernetes 1.27, upgrade guide says it should work for 1.19+.
