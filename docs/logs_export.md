# Logs Export

Download [LogCLI](https://github.com/grafana/loki/releases) with version matching the Loki version running on the cluster - 
Check the image tag of the Loki pods.

Start a port-forward to the Loki service:

```bash
kubectl port-forward -n logging svc/logging-loki-gateway 8080:80
```

Keep it open and in another terminal window, run LogCLI to export logs:

```bash
export LOKI_ADDR=http://localhost:8080
logcli query '{namespace="kube-system"}' --limit=5 --since=24h --output=jsonl
```