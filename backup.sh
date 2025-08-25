#!/usr/bin/env bash
#
# Backup script to sync s3 buckets from one remote target to another (execute manually or by CHECK_CRON schedule)

source /bin/log.sh

mkdir -p /var/log/rclone
lastLogfile="/var/log/rclone/lastrun.log"
start=`date +%s`

healthcheck() {
    suffix=$1
    if [ -n "$HEALTHCHECK_URL" ]; then
        log "INFO" "Reporting healthcheck $suffix ..."
        [[ ${1} == "/start" ]] && m="" || m=$(cat ${lastLogfile} | tail -n 300)
        curl -fSsL --retry 3 -X POST \
            --user-agent ${USER_AGENT} \
            --data-raw "$m" "${HEALTHCHECK_URL}${suffix}"
        if [ $? != 0 ]; then
            log "ERROR" "HEALTHCHECK_URL seems to be wrong..."
            exit 1
        fi
    else
        log "DEBUG" "No HEALTHCHECK_URL provided. Skipping healthcheck."
    fi
}

function compare_size(){
    c1=`echo ${1} | jq .count`
    c2=`echo ${2} | jq .count`
    c2dev=$(( ${c2} * (100+${ALLOWED_DEVIATION}) / 100 ))
    b1=`echo ${1} | jq .bytes`
    b2=`echo ${2} | jq .bytes`
    b2dev=$(( ${b2} * (100+${ALLOWED_DEVIATION}) / 100 ))

    if [[ $c1 -gt $c2dev || $b1 -gt $b2dev ]]; then
        status="ERROR"
    else
        status="OK"
    fi
    echo "$1 vs $2 = $status" >> $lastLogfile
    log "INFO" "$1 vs. $2 = $status"
}

# /hooks/pre-backup.sh
if [ -f "/hooks/pre-backup.sh" ]; then
    log "INFO" "Starting pre-backup script"
    /hooks/pre-backup.sh
    if [ $? -ne 0 ]; then
        log "ERROR" "pre-backup.sh was not successful."
        exit 1
    fi
else
    log "DEBUG" "Pre-backup script not found"
fi

log "INFO" "Starting S3 Sync Backup"
echo "Starting S3 Sync Backup at $(date +"%Y-%m-%d %H:%M:%S")" > $lastLogfile
echo "--" >> $lastLogfile

log "DEBUG" "Healthcheck start"
healthcheck /start

SYNC_PARAMS="--config /root/.config/rclone/rclone.conf --stats 30m --stats-one-line --stats-log-level NOTICE --transfers=16 --checkers=16 --skip-links --s3-no-check-bucket --log-file="${lastLogfile}" --log-level=NOTICE --fast-list"
SIZE_PARAMS="--config /root/.config/rclone/rclone.conf --stats 30m --stats-one-line --stats-log-level NOTICE --transfers=16 --checkers=16 --skip-links --s3-no-check-bucket --log-file=/dev/null     --log-level=NOTICE --fast-list --json"

# Define the maximum number of buckets you expect
MAX_BUCKETS=6

for ((i=1; i<=MAX_BUCKETS; i++)); do
  FROM_VAR="B${i}_FROM"
  TO_VAR="B${i}_TO"

  if [[ -n ${!FROM_VAR} ]] && [[ -n ${!TO_VAR} ]]; then
    echo "Sync Bucket $i:" >> $lastLogfile
    log "INFO" "Sync Bucket $i:"
    /bin/rclone sync ${!FROM_VAR} ${!TO_VAR} ${SYNC_PARAMS}
    json1=`/bin/rclone size ${!FROM_VAR} ${SIZE_PARAMS}`
    json2=`/bin/rclone size ${!TO_VAR} ${SIZE_PARAMS}`

    if [[ -z "$json1" ]] || ! echo "$json1" | jq . >/dev/null 2>&1 || ! echo "$json1" | jq 'has("count")' | grep -q true; then
        log "ERROR" "Bucket configuration for B${i}_FROM seems to be wrong"
    fi
    if [[ -z "$json2" ]] || ! echo "$json2" | jq . >/dev/null 2>&1 || ! echo "$json2" | jq 'has("count")' | grep -q true; then
        log "ERROR" "Bucket configuration for B${i}_TO seems to be wrong"
    fi
    log "DEBUG" "Result of rclone size for B${i}_FROM: $json1"
    log "DEBUG" "Result of rclone size for B${i}_TO: $json2"

    compare_size $json1 $json2
  fi
done

hits=$(cat ${lastLogfile} | grep "ERROR" | wc -l)
if [[ $hits -eq 0 ]]; then
  statusCode=0 # success
else
  statusCode=1 # failure
fi

end=`date +%s`
log "INFO" "Finished S3 Sync Backup after $((end-start)) seconds"
echo "--" >> $lastLogfile
echo "Finished S3 Sync Backup at $(date +"%Y-%m-%d %H:%M:%S") after $((end-start)) seconds" >> $lastLogfile

if [[ $statusCode == 0 ]]; then
    log "INFO" "S3 Sync Backup Successful"
    healthcheck /0
else
    log "ERROR" "S3 Sync Backup Failed with Status ${statusCode}"
    healthcheck /fail
fi

if [ -n "${MSMTP_ARGS}" ]; then
    log "INFO" "Executing mail command"
    echo -e "Subject: S3Sync-Backup \n\n$(cat ${lastLogfile})" | msmtp ${MSMTP_ARGS}
    ms=$?
    if [[ $ms == 0 ]]; then
        log "INFO" "Mail notification successfully sent."
    else
        log "ERROR" "Sending mail notification FAILED."
    fi
else
    log "DEBUG" "MSMTP_ARGS not defined. Therefore no mail notification."
fi

# /hooks/post-backup.sh
if [ -f "/hooks/post-backup.sh" ]; then
    log "INFO" "Starting post-backup script"
    /hooks/post-backup.sh $statusCode
    if [ $? -ne 0 ]; then
        log "ERROR" "post-backup.sh was not successful."
        exit 1
    fi
else
    log "DEBUG" "Post-backup script not found"
fi

