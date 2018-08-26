cd /;
rm -f "${BACKUP_DATABASE_FILE}" "${BACKUP_DATABASE_FILE}.part"
su postgres -c "pg_dump --format=custom -d ${BACKUP_DATABASE_NAME}" > "${BACKUP_DATABASE_FILE}.part" &&\
mv "${BACKUP_DATABASE_FILE}.part" "${BACKUP_DATABASE_FILE}"
