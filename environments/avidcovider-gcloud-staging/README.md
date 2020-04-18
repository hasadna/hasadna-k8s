# avidcovider staging environment

staging environment is identical to prod environment except for the following changes:

* uses the same NFS server as prod but with different paths
* allows to change the COVID19-ISRAEL repository branch / commit to test changes

## Copy secrets from prod environment

```
source switch_environment.sh avidcovider-gcloud-staging &&\
mkdir -p environments/avidcovider-gcloud/.secrets &&\
kubectl -n avidcovider get secret pipelines-secrets --export -o yaml >environments/avidcovider-gcloud/.secrets/pipelines-secrets.yaml &&\
kubectl -n avidcovider get secret  pipelines-cdc-secrets-certs --export -o yaml >environments/avidcovider-gcloud/.secrets/pipelines-cdc-secrets-certs.yaml &&\
kubectl -n avidcovider get secret  pipelines-collector --export -o yaml >environments/avidcovider-gcloud/.secrets/pipelines-collector.yaml &&\
kubectl -n avidcovider get secret  pipelines-auth --export -o yaml >environments/avidcovider-gcloud/.secrets/pipelines-auth.yaml &&\
kubectl -n avidcovider-staging apply -f environments/avidcovider-gcloud/.secrets/pipelines-secrets.yaml &&\
kubectl -n avidcovider-staging apply -f environments/avidcovider-gcloud/.secrets/pipelines-cdc-secrets-certs.yaml &&\
kubectl -n avidcovider-staging apply -f environments/avidcovider-gcloud/.secrets/pipelines-collector.yaml &&\
kubectl -n avidcovider-staging apply -f environments/avidcovider-gcloud/.secrets/pipelines-auth.yaml &&\
rm -rf environments/avidcovider-gcloud/.secrets
```
