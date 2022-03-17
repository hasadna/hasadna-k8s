# Open Bus

Open Bus project

## Install

First, deploy the Stride DB server, see below under "Stride DB" for details.

Connect to openbus production environment

```
export KUBECONFIG=/path/to/kamatera/kubeconfig
source switch_environment.sh openbus
```

Create namespace

```
kubectl create ns openbus
```

Create ssh tunnel secret

```
kubectl -n openbus create secret generic sshtunnel \
    --from-file=key=
```

Create siri requester secret

```
kubectl -n openbus create secret generic siri-requester \
    --from-literal=OPEN_BUS_MOT_KEY= \
    --from-literal=OPEN_BUS_SSH_TUNNEL_SERVER_IP= \
    --from-literal=OPEN_BUS_S3_ENDPOINT_URL= \
    --from-literal=OPEN_BUS_S3_ACCESS_KEY_ID= \
    --from-literal=OPEN_BUS_S3_SECRET_ACCESS_KEY= \
    --from-literal=OPEN_BUS_S3_BUCKET=
```

SSH to NFS server and create NFS path

```
mkdir -p /srv/default2/openbus/siri-requester
```

Create DB password secret, change the username/password/ip according to actual values:

```
kubectl -n openbus create secret generic db \
    --from-literal=SQLALCHEMY_URL=postgresql://postgres:password@172.16.0.16/postgres
```

SSH to NFS server and create NFS paths

```
mkdir -p /srv/default2/openbus/stride-db
```

Create Airflow secrets

```
OPEN_BUS_PIPELINES_AIRFLOW_ADMIN_PASSWORD=`python3 -c 'import secrets; print(secrets.token_hex(16))'`
kubectl -n openbus create secret generic airflow \
    --from-literal=OPEN_BUS_PIPELINES_AIRFLOW_ADMIN_PASSWORD=${OPEN_BUS_PIPELINES_AIRFLOW_ADMIN_PASSWORD}
```

Create Airflow DB password secret

```
AIRFLOW_DB_POSTGRES_PASSWORD=`python3 -c 'import secrets; print(secrets.token_hex(16))'`
kubectl -n openbus create secret generic airflow-db \
    --from-literal=POSTGRES_PASSWORD=${AIRFLOW_DB_POSTGRES_PASSWORD} \
    --from-literal=SQLALCHEMY_URL=postgresql://postgres:${AIRFLOW_DB_POSTGRES_PASSWORD}@airflow-db
```

SSH to NFS server and create NFS paths

```
mkdir -p /srv/default2/openbus/airflow-db
mkdir -p /srv/default2/openbus/airflow-home
```

Dry Run

```
./helm_upgrade_external_chart.sh openbus --install --debug --dry-run
```

Deploy

```
./helm_upgrade_external_chart.sh openbus --install
```


## Stride DB

The Stride DB is hosted on a dedicated server due to it's high load requirements.

### Deploy

Using [Kamatera Console](https://console.kamatera.com) create a new server:

* Service image: postgresql (latest on ubuntu 20.04)
* Type: B
* CPU: 6
* RAM: 32gb
* SSD: 1.5TB
* Network #1: WAN
* Network #2: LAN (`lan-82145-hasadna`)

The server root password is in hasadna's vault under `Projects/OBus/stride-db/server-root-password`

Upgrade to PostgreSQL 14:

```
apt update
wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | sudo apt-key add -
echo "deb http://apt.postgresql.org/pub/repos/apt/ $(lsb_release -cs)-pgdg main" | sudo tee /etc/apt/sources.list.d/postgresql-pgdg.list > /dev/null
apt update
apt remove postgresql-12
apt install postgresl-14
```

Edit `/etc/postgresql/14/main/postgresql.conf`:

* Set `listen_addresses = '*'`
* Set `port = 5432`

Edit `/etc/postgresql/14/main/pg_hba.conf`:

* Set ipv4 / ipv6 addresses to `0.0.0.0/0` and `::/0`

Allow access to port 5432

```
ufw allow 5432
```

Restart:

```
systemctl restart postgresql
```

Generate a password for the DB using the following snippet:

```
python3 -c 'import secrets; print(secrets.token_hex(16))'
```

Set the password/username in Hasadna's vault under `Projects/OBus/stride-db` / (`db-admin-password` / `db-admin-user`)

Change the postgres user password:

```
ALTER USER postgres WITH PASSWORD '*******';
```

Verify access to the DB from your local PC:

```
psql -h open-bus-stride-db.hasadna.org.il -U postgres
```

SSH to the db server

Download and unzip the last backup file:

```
wget https://open-bus-siri-requester.hasadna.org.il/stride_db_backup/stride_db.sql.gz
gunzip stride_db.sql.gz
mv stride_db.sql /
```

Restore from the backup:

```
sudo -u postgres psql -f /stride_db.sql
```

Get AWS secrets from `siri-requester` secret and set in file `/var/lib/postgresql/stride-backup.env`:

```
export AWS_ACCESS_KEY_ID=
export AWS_SECRET_ACCESS_KEY=
export BUCKET_NAME=
```

Create backup script in file `/var/lib/postgresql/stride-backup.sh`:

```
cd /var/lib/postgresql &&\
echo `date +"%Y-%m-%d %H:%M"` creating stride_db backup &&\
pg_dump -n public --no-privileges -f ./stride_db.sql &&\
du -h ./stride_db.sql &&\
echo `date +"%Y-%m-%d %H:%M"` gzipping stride_db backup &&\
gzip -kf ./stride_db.sql &&\
du -h ./stride_db.sql.gz &&\
. /var/lib/postgresql/stride-backup.env &&\
echo `date +"%Y-%m-%d %H:%M"` copying backup to S3 &&\
/usr/local/bin/aws s3 cp ./stride_db.sql.gz s3://${BUCKET_NAME}/stride_db.sql.gz &&\
echo `date +"%Y-%m-%d %H:%M"` Great Success!
```

Edit the postgres crontab:

```
EDITOR=nano crontab -u postgres -e
```

Add the following cronjob:

```
37 1 * * * bash /var/lib/postgresql/stride-backup.sh 2>&1 >> /var/lib/postgresql/stride-backup.log
```

### Enable DB Redash read-only user

Run the following on the stride DB (replace **** with real password):

```
CREATE ROLE stride_readonly;
GRANT CONNECT ON DATABASE postgres TO stride_readonly;
GRANT USAGE ON SCHEMA public TO stride_readonly;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO stride_readonly;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON TABLES TO stride_readonly;
CREATE USER redash WITH PASSWORD '*****';
GRANT stride_readonly TO redash;
```
