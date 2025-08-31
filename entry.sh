#!/usr/bin/env bash
#
# Entry script of this docker container.
# - creates cronjobs for backup

source /bin/log.sh

# check for valid LOG_LEVEL
if ! [[ "$LOG_LEVEL" =~ ^(INFO|WARNING|DEBUG|ERROR)$ ]]; then
    LOG_LEVEL="ERROR";
    log "ERROR" "Invalid value for LOG_LEVEL found. Allowed values are INFO, WARNING, DEBUG or ERROR. Exiting"
    exit 1
fi

# check for mandatory input (rclone.conf, B1_FROM and B1_TO)
if [ ! -f "/root/.config/rclone/rclone.conf" ]; then
    log "ERROR" "No rclone configuration found at /root/.config/rclone/rclone.conf."
fi
[ -z "$B1_FROM" ] && { log "ERROR" "B1_FROM is not set. Exiting."; exit 1; }
[ -z "$B1_TO" ] && { log "ERROR" "B1_TO is not set. Exiting."; exit 1; }

log "INFO" "Starting the s3 sync backup container ..."

# make environment variables and path available to cron
env >> /etc/environment
export GOGC=20

# output environment variables (debug only)
log "DEBUG" "LIST OF ENVIRONMENT VARIABLES:"
log "DEBUG" "BACKUP_CRON: ${BACKUP_CRON}"
log "DEBUG" "LOG_LEVEL: ${LOG_LEVEL}"
log "DEBUG" "LOG_TYPE: ${LOG_TYPE}"
log "DEBUG" "MSMTP_ARGS: ${MSMTP_ARGS}"
log "DEBUG" "HEALTHCHECK_URL: ${HEALTHCHECK_URL}"
log "DEBUG" "ALLOWED_DEVIATION: ${ALLOWED_DEVIATION}"
log "DEBUG" "USER_AGENT: ${USER_AGENT}"
log "DEBUG" "B1_FROM: ${B1_FROM}"
log "DEBUG" "B1_TO: ${B1_TO}"
if [ -n "$B2_FROM" ]; then log "DEBUG" "B2_FROM: ${B2_FROM}"; fi
if [ -n "$B2_TO" ]; then log "DEBUG" "B2_TO: ${B2_TO}"; fi
if [ -n "$B3_FROM" ]; then log "DEBUG" "B3_FROM: ${B3_FROM}"; fi
if [ -n "$B3_TO" ]; then log "DEBUG" "B3_TO: ${B3_TO}"; fi
if [ -n "$B4_FROM" ]; then log "DEBUG" "B4_FROM: ${B4_FROM}"; fi
if [ -n "$B4_TO" ]; then log "DEBUG" "B4_TO: ${B4_TO}"; fi
if [ -n "$B5_FROM" ]; then log "DEBUG" "B5_FROM: ${B5_FROM}"; fi
if [ -n "$B5_TO" ]; then log "DEBUG" "B5_TO: ${B5_TO}"; fi
if [ -n "$B6_FROM" ]; then log "DEBUG" "B6_FROM: ${B6_FROM}"; fi
if [ -n "$B6_TO" ]; then log "DEBUG" "B6_TO: ${B6_TO}"; fi
log "DEBUG" "NUM_CHECKERS: ${NUM_CHECKERS}"
log "DEBUG" "NUM_TRANSFERS: ${NUM_TRANSFERS}"
log "DEBUG" "STATS_INTERVAL: ${STATS_INTERVAL}"


log "INFO" "Setup s3 sync backup cron job with cron expression BACKUP_CRON: ${BACKUP_CRON}"
echo "${BACKUP_CRON} root /usr/bin/flock -n /var/run/backup.lock /bin/backup >/proc/1/fd/1 2>/proc/1/fd/2" > /etc/crontab

echo '
# An empty line is required at the end of this file for a valid cron file.
' >> /etc/crontab

log "DEBUG" "start the cron daemon now."

log "INFO" "Container started successful. The cron daemon runs... Ready for s3 sync backup!"
exec "$@"
