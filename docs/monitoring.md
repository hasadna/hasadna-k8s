# cluster monitoring

monitoring is based on Rancher (2.6) monitoring

## Install

Cluster explorer > hasadna > cluster tools > Monitoring > Install

* version: 100.1.2+up19.0.3
* Prometheus - enable persistent storage
  * Size: `50Gi`
  * Storage class name: `nfs-client`
* Grafana - enable persistent storage
  * same as prometheus

## Grafana

Access Grafana from the Rancher UI

Sign-in to make changes with username `admin`, password from vault `Projects/k8s/grafana-admin`

## Prometheus additional scrape configs

Cluster explorer > hasadna > cluster tools > monitoring > update

Edit as yaml and add scrape configs, for example:

```
  prometheusSpec:
    additionalScrapeConfigs:
    - job_name: myjob
      metrics_path: /metrics
      static_configs:
        - targets:
          - <IP>:<PORT>
```