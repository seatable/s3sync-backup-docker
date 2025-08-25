# Function to log messages
# $LOG_LEVEL is the requested log level of the container, defined by the user in the ENV_VARIABLES
# $LEVEL is the level of the log message.

# set default values for all other environment variables
export BACKUP_CRON=${BACKUP_CRON:="15 3 * * *"}
export LOG_LEVEL=${LOG_LEVEL:="INFO"}
export LOG_TYPE=${LOG_TYPE:="stdout"}
export ALLOWED_DEVIATION=${ALLOWED_DEVIATION:="1"}
export USER_AGENT=${USER_AGENT:="s3sync-backup-docker/1.0.3"}

log() {
    local LEVEL="$1"
    local MESSAGE="$2"
    local TIMESTAMP=$(date +"%Y-%m-%d %H:%M:%S")
    local LOG_FILE="/var/log/rclone/backup.log"

    # always output to stdout depending of the LEVEL of the message.
    case $LEVEL in
        "DEBUG")
            [[ "$LOG_LEVEL" == "DEBUG" ]] && echo -e "[$TIMESTAMP] [DEBUG] $MESSAGE" >&2
            ;;
        "INFO")
            [[ "$LOG_LEVEL" == "INFO" || "$LOG_LEVEL" == "DEBUG" ]] && echo -e "[$TIMESTAMP] [INFO] $MESSAGE" >&2
            ;;
        "WARNING")
            [[ "$LOG_LEVEL" == "WARNING"  || "$LOG_LEVEL" == "INFO" || "$LOG_LEVEL" == "DEBUG" ]] && echo -e "[$TIMESTAMP] [INFO] $MESSAGE" >&2
            ;;
        "ERROR")
            [[ "$LOG_LEVEL" == "ERROR" || "$LOG_LEVEL" == "WARNING"  || "$LOG_LEVEL" == "INFO" || "$LOG_LEVEL" == "DEBUG" ]] && echo -e "[$TIMESTAMP] [ERROR] $MESSAGE" >&2
            ;;
    esac

    # IF 
    if [[ $LOG_TYPE == "file" ]]; then
        case $LEVEL in
            "DEBUG")
                [[ "$LOG_LEVEL" == "DEBUG" ]] && echo -e "[$TIMESTAMP] [DEBUG] $MESSAGE" >> $LOG_FILE
                ;;
            "INFO")
                [[ "$LOG_LEVEL" == "INFO" || "$LOG_LEVEL" == "DEBUG" ]] && echo -e "[$TIMESTAMP] [INFO] $MESSAGE" >> $LOG_FILE
                ;;
            "WARNING")
                [[ "$LOG_LEVEL" == "WARNING"  || "$LOG_LEVEL" == "INFO" || "$LOG_LEVEL" == "DEBUG" ]] && echo -e "[$TIMESTAMP] [INFO] $MESSAGE" >> $LOG_FILE
                ;;
            "ERROR")
                [[ "$LOG_LEVEL" == "ERROR" || "$LOG_LEVEL" == "WARNING"  || "$LOG_LEVEL" == "INFO" || "$LOG_LEVEL" == "DEBUG" ]] && echo -e "[$TIMESTAMP] [ERROR] $MESSAGE" >> $LOG_FILE
                ;;
        esac
    fi
}
