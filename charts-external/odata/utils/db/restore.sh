rm -rf /var/lib/postgresql/data/*;
docker-entrypoint.sh postgres &
while ! su postgres -c "pg_isready"; do
    echo waiting for DB to accept connections...
    sleep 1
done
while ! [ -e "${BACKUP_DATABASE_FILE}" ]; do
    echo waiting for backup file "${BACKUP_DATABASE_FILE}"
    sleep 1
done
su postgres -c "psql -c 'create database ckan;'" &&\
su postgres -c "pg_restore --exit-on-error -d ${BACKUP_DATABASE_NAME} ${BACKUP_DATABASE_FILE}" > /dev/null
[ "$?" != "0" ] && echo failed to restore from backup && exit 1
echo Successfully restored from backup, continuing to serve the DB
wait
