# Vertical Pod Autoscaler

VPA Has to be deployed manually, we only use the recommender and do the scaling manually

## Deploy

Generate certs (should be done only once):

```
apps/vertical-pod-autoscaler/gencerts.sh
```

Deploy manually:

```
kubectl apply -k apps/vertical-pod-autoscaler
```

## Upgrade

Change version in download.sh and run:

```
apps/vertical-pod-autoscaler/download.sh
```
