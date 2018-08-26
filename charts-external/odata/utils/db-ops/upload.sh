cd /;
! [ -e ${DB_BACKUP_FILE} ] && exit 0
[ -e ${DB_BACKUP_FILE}_upload_lastmod ] &&\
[ "$(cat ${DB_BACKUP_FILE}_upload_lastmod)" == "$(stat -c %y ${DB_BACKUP_FILE})" ] &&\
exit 0;
BACKUP_TARGET="${BACKUP_TARGET_PREFIX}$(date +%Y-%m-%d)${BACKUP_TARGET_SUFFIX}"
echo "Uploading to ${BACKUP_TARGET}"
gcloud auth activate-service-account --key-file="${SECRET_SERVICE_KEY_FILE}" &&\
gsutil cp ${DB_BACKUP_FILE} "${BACKUP_TARGET}" &&\
echo "$(stat -c %y ${DB_BACKUP_FILE})" | tee ${DB_BACKUP_FILE}_upload_lastmod
