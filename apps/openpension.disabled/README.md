# OpenPension

## Initialize a new environment

Create namespace

```
kubectl create ns openpension
```

Create DB secret

```
kubectl -n openpension create secret generic db \
    --from-literal=MYSQL_ROOT_PASSWORD=
```

