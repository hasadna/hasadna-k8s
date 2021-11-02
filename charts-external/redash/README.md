## Hasadna Redash

### Install

Create redash secret:

```
COOKIE_SECRET=$(pwgen -1s 32)
SECRET_KEY=$(pwgen -1s 32)
POSTGRES_PASSWORD=$(pwgen -1s 32)
REDASH_DATABASE_URL="postgresql://postgres:${POSTGRES_PASSWORD}@postgres/postgres"
kubectl create secret generic redash \
    --from-literal=PYTHONUNBUFFERED=0 \
    --from-literal=REDASH_LOG_LEVEL=INFO \
    --from-literal=REDASH_REDIS_URL=redis://redis:6379/0 \
    "--from-literal=POSTGRES_PASSWORD=${POSTGRES_PASSWORD}" \
    "--from-literal=REDASH_COOKIE_SECRET=${COOKIE_SECRET}" \
    "--from-literal=REDASH_SECRET_KEY=${SECRET_KEY}" \
    "--from-literal=REDASH_DATABASE_URL=postgresql://postgres:${POSTGRES_PASSWORD}@postgres/postgres"
```

Deploy with helm value `redashInitialize` set to `yes`

Check server logs to make sure create_db completed successfully.

Deploy without `redashInitialize` value
