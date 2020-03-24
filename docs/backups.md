# Backups

Backups are handled using Restic and run periodically from the Jenkins server

Make sure you are using Restic version 0.9

```
restic version | grep 'restic 0.9.'
```

Install Restic by downloading the binary and placing in PATH: https://github.com/restic/restic/releases

All backups require the following env vars, shared between all backups:

```
export RESTIC_PASSWORD=
export AWS_ACCESS_KEY_ID=
export AWS_SECRET_ACCESS_KEY=
```

In addition, each backup has a dedicated `RESTIC_REPO`:

`export RESTIC_REPO=s3:s3.amazonaws.com/BUCKET_NAME/BACKUP_TYPE`

where BACKUP_TYPE can be one of:

* Rancher and Jenkins: `rancher`
* Storage: `storage`
* Etcd: `etcd`

Before first backup, each repo was initialized with the following command: `restic -r $RESTIC_REPO init`

## Periodic backup jobs

Jobs are scheduled on the Jenkins server

### Rancher and Jenkins backups

* name: `backup-rancher`
* discard old builds: keep 10 days
* `BACKUP_DIRECTORIES=/var/lib/rancher /srv/default`
* `RESTIC_REPO=`
* restrict where project can run: `docker` (this is the server that runs rancher and hosts the jenkins storage)
* build periodically: `H * * * *`
* use secret text or files: `RESTIC_BACKUP_VARS`
* execute shell:
```
#!/usr/bin/env bash

eval "${RESTIC_BACKUP_VARS}"
! restic version | grep 'restic 0.9.' && exit 1
restic -r $RESTIC_REPO backup $BACKUP_DIRECTORIES
```

### Storage backups

* name: `hasadna-backup-storage`
* discard old builds: keep 10 days
* `BACKUP_DIRECTORIES=/mnt/sdb3/srv/default /srv/default2`
* `RESTIC_REPO=`
* build periodically: `H 0 * * *`
* use secret text or files: `RESTIC_BACKUP_VARS`
* execute shell on remote node using ssh - run on the NFS server
```
#!/usr/bin/env bash

RESTIC="restic"

! $RESTIC version | grep 'restic 0.9.' && exit 1

ALL_RET=0

exec_cmd() {
      CMD="${1}"
      echo $CMD
      $CMD
      RET=$?
      if [ "${RET}" != "0" ]; then
        ALL_RET=$RET
        echo ERROR
        echo command failed, exit code: $RET
      fi
}

backup_subdir() {
    echo
    echo
    echo backing up $1
    exec_cmd "$RESTIC -r $RESTIC_REPO backup $1"
}

eval "${RESTIC_BACKUP_VARS}"
for BACKUP_DIRECTORY in $BACKUP_DIRECTORIES; do
  for SUBDIR in `ls $BACKUP_DIRECTORY`; do
    backup_subdir "$BACKUP_DIRECTORY/$SUBDIR"
  done
done

exit $ALL_RET
```

### etcd backups

* name: `hasadna-backup-etcd`
* discard old builds: keep 10 days
* `RESTIC_REPO=`
* build periodically: `H * * * *`
* use secret text: `RESTIC_BACKUP_VARS`
* use secret text: `RANCHER_GLOBAL_ADMIN_LOGIN`
* execute shell:
```
#!/usr/bin/env bash

wget -q https://releases.rancher.com/cli2/v2.3.2/rancher-linux-amd64-v2.3.2.tar.gz
tar -xzf rancher-linux-amd64-v2.3.2.tar.gz
chmod +x rancher-v2.3.2/rancher
export PATH=`pwd`/rancher-v2.3.2:$PATH
$RANCHER_GLOBAL_ADMIN_LOGIN --context c-vrqxr:p-g6m98
ETCD_NODE=`rancher nodes | grep master | cut -d" " -f1 | head -n1`
echo getting backup from node $ETCD_NODE
rancher ssh $ETCD_NODE -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no "
  eval \"${RESTIC_BACKUP_VARS}\"
  curl -L https://github.com/restic/restic/releases/download/v0.9.6/restic_0.9.6_linux_amd64.bz2 | bunzip2 > restic &&\
  chmod +x restic && ./restic version &&\
  docker exec etcd etcdctl snapshot save /etcd-snapshot &&\
  docker cp etcd:/etcd-snapshot ./etcd-snapshot &&\
  ./restic -r $RESTIC_REPO backup ./etcd-snapshot
"
```
