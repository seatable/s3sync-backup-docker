#!/bin/bash

# check for mandatory input (rclone.conf, B1_FROM and B1_TO)
if [ ! -f "/root/.config/rclone/rclone.conf" ]; then
    echo "[ERROR] No rclone configuration found at /root/.config/rclone/rclone.conf."
fi
[ -z "$B1_FROM" ] && { echo "[ERROR] B1_FROM is not set. Exiting."; exit 1; }
[ -z "$B1_TO" ] && { echo "[ERROR] B1_TO is not set. Exiting."; exit 1; }

# check for valid LOG_LEVEL
if ! [[ "$LOG_LEVEL" =~ ^(DEBUG|INFO|NOTICE|ERROR)$ ]]; then
    echo "[ERROR] Invalid value for LOG_LEVEL found. Allowed values are DEBUG, INFO, NOTICE or ERROR. Exiting."
    exit 1
fi

# Output on start
echo "Container was started at $(date) and is now ready."
echo ""
echo "# These environment variables were set:"
env | sort
echo ""
echo "# How to use:"
echo "either start a standalone sync or use ofelia for cronjob."
echo "Read more on https://github.com/seatable/."
echo ""
rclone version


# cron or infinite loop to keep container alive
if [ "$RUN_MODE" = "cron" ]; then

    echo "Setup s3 sync backup cron job with cron expression BACKUP_CRON: ${BACKUP_CRON}"
    echo "${BACKUP_CRON} root /usr/bin/flock -n /var/run/sync.lock /bin/sync.sh >/proc/1/fd/1 2>/proc/1/fd/2" > /etc/crontab

    echo '
# An empty line is required at the end of this file for a valid cron file.
' >> /etc/crontab

    printenv | sed 's/^/export /' > /etc/envvars
    sed -i -e '/^export PWD=/d' -e '/^export SHLVL=/d' -e '/^export BACKUP_CRON=/d' /etc/envvars
    exec crond -f
else
    echo "No Cron. The container sleeps forever."
    exec sleep infinity
fi
