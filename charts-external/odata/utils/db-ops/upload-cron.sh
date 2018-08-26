echo Setting up upload cron
mkdir -p /db-upload-crontabs &&\
echo '* * * * * bash /db-scripts/upload.sh' > /db-upload-crontabs/root
[ "$?" != "0" ] && echo failed to initialize db upload cron && exit 1
exec crond -f -L /dev/stdout -c /db-upload-crontabs
