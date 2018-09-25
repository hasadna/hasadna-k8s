while ! su postgres -c "pg_isready"; do echo waiting for DB..; sleep 1; done
echo creating datastore db &&\
su postgres -c "createdb datastore -E utf-8" &&\
echo creating datastore readonly user &&\
su postgres -c "psql -c \"create role ${DATASTORE_RO_USER} with login password '${DATASTORE_RO_PASSWORD}';\"" &&\
echo setting datastore permissions &&\
bash /db-scripts/templater.sh /db-scripts/datastore-permissions.sql.template | su postgres -c "psql --set ON_ERROR_STOP=1"
[ "$?" != "0" ] && echo failed to set datastore permissions && exit 1
echo Great Success
exit 0
