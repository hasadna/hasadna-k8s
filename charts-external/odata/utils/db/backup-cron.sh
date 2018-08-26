echo "Setting up backup cron: ${BACKUP_CRONLINE}" &&\
mkdir -p /db-backup-crontabs &&\
echo "${BACKUP_CRONLINE} bash /db-scripts/backup.sh" > /db-backup-crontabs/root
[ "$?" != "0" ] && echo failed to initialize db backup cron && exit 1
exec crond -f -L /dev/stdout -c /db-backup-crontabs
