cd /;
rm -f "${DB_BACKUP_FILE}" "${DB_BACKUP_FILE}.part"
echo "downloading from ${1} to ${DB_BACKUP_FILE}"
gcloud auth activate-service-account --key-file="${SECRET_SERVICE_KEY_FILE}" &&\
gsutil cp "${1}" "${DB_BACKUP_FILE}.part" &&\
mv "${DB_BACKUP_FILE}.part" "${DB_BACKUP_FILE}"
[ "$?" != "0" ] && echo failed to download backup && exit 1
while echo "Disable restore arg and restart db-ops"
do sleep 86400; done
