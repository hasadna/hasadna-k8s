# Hasadna's Rancher

## Renewing certificates

Some Rancher certificates are expired after 1 year, to renew SSH to the rancher server and run the following:

```
docker exec -it rancher sh -c “rm /var/lib/rancher/k3s/server/tls/dynamic-cert.json”
docker exec -it rancher k3s kubectl --insecure-skip-tls-verify delete secret -n kube-system k3s-serving
docker restart rancher
```
