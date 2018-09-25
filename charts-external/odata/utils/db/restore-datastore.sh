rm -rf /var/lib/postgresql/data/*;
docker-entrypoint.sh postgres &
while ! su postgres -c "pg_isready"; do echo waiting for DB..; sleep 1; done
echo creating datastore db &&\
su postgres -c "createdb datastore -E utf-8" &&\
echo creating datastore readonly user &&\
su postgres -c "psql -c \"create role ${DATASTORE_RO_USER} with login password '${DATASTORE_RO_PASSWORD}';\""
[ "$?" != "0" ] && echo failed to set datastore permissions && exit 1
! su postgres -c "pg_restore --exit-on-error -d ${BACKUP_DATABASE_NAME} ${BACKUP_DATABASE_FILE}" > /dev/null \
    && echo failed to restore from backup && exit 1
echo Successfully restored datastore from backup, continuing to serve the datastore DB
wait
