#!/usr/bin/env bash

# load environment variables to this script
source /etc/envvars

# set USER_AGENT
USER_AGENT="s3sync-backup-docker/2.0.1"

LOG_FILE=/tmp/lastrun.log
start=`date +%s`
echo "" > ${LOG_FILE}

log() {
  local level=$1
  shift

  # Log-Level-Mapping auf Prioritäten (niedriger Wert = höhere Priorität)
  case "$level" in
    ERROR) levelnum=1 ;;
    NOTICE) levelnum=2 ;;
    INFO) levelnum=3 ;;
    DEBUG) levelnum=4 ;;
    *) levelnum=5 ;; # unbekanntes Level, sehr niedrig priorisiert
  esac

  # Gleiche Nummern-Zuweisung für LOG_LEVEL
  case "$LOG_LEVEL" in
    ERROR) loglevelnum=1 ;;
    NOTICE) loglevelnum=2 ;;
    INFO) loglevelnum=3 ;;
    DEBUG) loglevelnum=4 ;;
    *) loglevelnum=5 ;;
  esac

  if [ "$levelnum" -le "$loglevelnum" ]; then
    echo "[$level] $*"
    echo "[$level] $*" >> ${LOG_FILE}
  fi
}

healthcheck() {
    suffix=$1
    if [ -n "${HEALTHCHECK_URL}" ]; then
        log INFO "Reporting healthcheck $suffix ..."
        m=""
        if [[ ${1} != "/start" ]]; then
          m=$(tail -n 300 "${LOG_FILE}" 2>/dev/null)
        fi
        curl -fSsL -o /dev/null --show-error --retry 3 -X POST \
            --user-agent ${USER_AGENT} \
            --data-raw "${m}" "${HEALTHCHECK_URL}${suffix}"
        if [ $? != 0 ]; then
            log ERROR "HEALTHCHECK_URL seems to be wrong..."
            exit 1
        fi
    else
        log DEBUG "No HEALTHCHECK_URL provided. Skipping healthcheck."
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
    log INFO "$1 vs. $2 = $status"
}

# /hooks/pre-backup.sh
if [ -f "/hooks/pre-backup.sh" ]; then
    log INFO "Starting pre-backup script"
    /hooks/pre-backup.sh
    if [ $? -ne 0 ]; then
        log ERROR "pre-backup.sh was not successful."
        exit 1
    fi
else
    log DEBUG "Pre-backup script not found"
fi

log NOTICE "s3sync job started at $(date +"%Y-%m-%d %H:%M:%S")."

log DEBUG "Healthcheck start"
healthcheck /start

# Define the maximum number of buckets you expect
MAX_BUCKETS=6

for ((i=1; i<=MAX_BUCKETS; i++)); do
    FROM_VAR="B${i}_FROM"
    TO_VAR="B${i}_TO"

    if [[ -n ${!FROM_VAR} ]] && [[ -n ${!TO_VAR} ]]; then

        # Sync the buckets (bucket sync = bs)
        log INFO ""
        log INFO "Sync the bucket (${!FROM_VAR} -> ${!TO_VAR})"
        log DEBUG "Sync command is: rclone sync ${!FROM_VAR} ${!TO_VAR}"
        start_bs=`date +%s`
        rclone sync ${!FROM_VAR} ${!TO_VAR} 2>&1
        end_bs=`date +%s`
        log "INFO" "Sync finished after $((end_bs-start_bs)) seconds."

        # Check bucket size (check size = cs)
        if [ "${SKIP_SIZE_CHECK,,}" != "true" ]; then
            log INFO "Get the bucket size"
            start_sc=`date +%s`
            json1=`rclone size ${!FROM_VAR} --json`
            json2=`rclone size ${!TO_VAR} --json`
            end_sc=`date +%s`
            log "INFO" "Get the bucket size finished after $((end_sc-start_sc)) seconds."
        fi

        if [[ -z "$json1" ]] || ! echo "$json1" | jq . >/dev/null 2>&1 || ! echo "$json1" | jq 'has("count")' | grep -q true; then
            log ERROR "Bucket configuration for B${i}_FROM seems to be wrong"
        fi
        if [[ -z "$json2" ]] || ! echo "$json2" | jq . >/dev/null 2>&1 || ! echo "$json2" | jq 'has("count")' | grep -q true; then
            log ERROR "Bucket configuration for B${i}_TO seems to be wrong"
        fi
        log DEBUG "Result of rclone size for B${i}_FROM: $json1"
        log DEBUG "Result of rclone size for B${i}_TO: $json2"

        compare_size $json1 $json2
    fi
done

hits=$(cat ${LOG_FILE} | grep "ERROR" | wc -l)
if [[ $hits -eq 0 ]]; then
  statusCode=0 # success
else
  statusCode=1 # failure
fi

end=`date +%s`

log NOTICE "s3sync job finished at $(date +"%Y-%m-%d %H:%M:%S") after $((end-start)) seconds."

if [[ $statusCode == 0 ]]; then
    log INFO "S3 Sync Backup Successful"
    healthcheck /0
else
    log ERROR "S3 Sync Backup Failed with Status ${statusCode}"
    healthcheck /fail
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
