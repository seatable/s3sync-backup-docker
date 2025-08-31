# Rclone S3 Backup Docker Container

This Docker container automates the synchronisation of S3-buckets at regular intervals with rclone. It offers:

- Simple setup
- Define backup schedules
- Fast synchronisation due to optimized rclone parameters
- Custom hook integration
- Healthcheck (via https://healthchecks.io/) or email notifications

## SeaTable and Seafile Specific Extension

This container is essentially a wrapper for the well-established backup software [rclone](https://rclone.org/), suitable for any use case.
My main motivation to build that, was to easily backup our own SeaTable and Seafile servers.

## How to use

Just provide the rclone configuration file and the source and target bucket. This backup container will take care of the rest.

### Commands

You can easily execute the rclone sync command in the Docker container with this command:

```bash
docker exec -it s3sync-backup backup
```

### Hooks

The Container supports the execution of the following custom hooks (if available at the container). Hooks are skipped if no scripts are found.

- /hooks/pre-backup.sh
- /hooks/post-backup.sh

### Logs

By default the container returns logs to stdout. You can get the log output of the container with `docker logs s3-backup -f`.

If `LOG_TYPE` is set to `file`, the container also writes a log file to `/var/log/rclone/backup.log` which is mounted as volume to `/opt/rclone/logs` in the host.

## Customize the Container

The container is set up by setting environment variables and volumes.

### Environment variables

| Name                | Description                                 | Example                                   | Default                          |
| ------------------- | ------------------------------------------- | ----------------------------------------- | -------------------------------- |
| `BACKUP_CRON`       | Execution schedule for the backup           | `15 3 * * *`                              | `15 3 * * *`                     |
| `LOG_LEVEL`         | Define log level                            | `DEBUG`, `INFO`, `WARNING` or `ERROR`.    | `INFO`                           |
| `LOG_TYPE`          | Define the log output type                  | `stdout` or `file`                        | `stdout`                         |
| `TZ`                | Timezone                                    | `Europe/Berlin`                           |                                  |
| `HEALTHCHECK_URL`   | healthcheck.io server check url             | `https://healthcheck.io/ping/a444061a`    |                                  |
| `MSMTP_ARGS`        | SMTP settings for mail notification         | `--host=x --port=587 ... cdb@seatable.io` |                                  |
| `ALLOWED_DEVIATION` | Allowed deviation of number of objects in % | `1`                                       | `1`                              |
| `B1_FROM`           | Bucket name mapping (Source)                | `rclone-remote:bucket-name`               |                                  |
| `B1_TO`             | Bucket name mapping (Backup)                | `rclone-remote:backup-name`               |                                  |
| `B2_FROM`           | Bucket name mapping (Source)                | `rclone-remote:bucket-name`               |                                  |
| `B2_TO`             | Bucket name mapping (Backup)                | `rclone-remote:backup-name`               |                                  |
| `B3_FROM`           | ... up to 6 bucket mappings are allowed     |                                           |                                  |
| `B3_TO`             |                                             |                                           |                                  |
| `USER_AGENT`        | Define the user agent used with curl        | `s3sync-backup-docker/<version>`          | `s3sync-backup-docker/<version>` |
| `NUM_CHECKERS`      | Define number of `--checkers` of rclone     | `64`                                      | `64`                             |
| `NUM_TRANSFERS`     | Define number of `--transfers` of rclone    | `16`                                      | `16`                             | 
| `STATS_INTERVAL`    | Define time between stats output            | `30m`                                     | `30m`                            |
| `BUFFER_SIZE`       | Define value of `--buffer-size` of rclone   | `16M`                                     | `0`                              |

### Mail notification

Mail notification is optional. If specified, the content of `/var/log/rclone/lastrun.log` is sent via mail after each backup using an external SMTP. To have maximum flexibility, you have to provide a msmtp configuration file with the mail/smtp parameters on your own. Have a look at the [msmtp manpage](https://wiki.debian.org/msmtp) for further information.

Here is an example of `MSMTP_ARGS`, to specify the recipient of the notification.

```bash
# example of MSMTP_ARGS
MSMTP_ARGS="recipient@example.com"
MSMTP_ARGS="-a default recipient@example.com"
```

Here is the example of `/opt/rclone/msmtprc.conf` to configure your external SMTP account.

```bash
defaults
auth           on
tls            on
tls_trust_file /etc/ssl/certs/ca-certificates.crt
logfile        /var/log/rclone/msmtp.log

account        brevo
host           smtp-relay.brevo.com
port           587
from           noreply@seatable.io
user           your-username
password       your-password

account default: brevo
```

## Example docker-compose

Get the latest version of the container from <https://hub.docker.com/repository/docker/seatable/s3sync-backup>.

```yaml
---
services:
  s3sync-backup:
    image: ${SEATABLE_S3SYNC_BACKUP_IMAGE:-seatable/s3sync-backup:latest}
    container_name: s3sync-backup
    restart: unless-stopped
    init: true
    volumes:
      - /opt/s3sync/rclone/rclone.conf:/root/.config/rclone/rclone.conf
      #- /opt/s3sync/hooks:/hooks:ro
      #- /opt/s3sync/logs:/var/log/rclone
      #- /opt/s3sync/msmtprc.conf:/root/.msmtprc:ro
    environment:
      - BACKUP_CRON=${BACKUP_CRON:-15 3 * * *} # Start backup always at 3:15 am.
      - LOG_LEVEL=${LOG_LEVEL:-INFO}
      - LOG_TYPE=${LOG_TYPE:-stdout}
      - TZ=${TIME_ZONE}
      - HEALTHCHECK_URL=${HEALTHCHECK_URL:-}
      - MSMTP_ARGS=${MSMTP_ARGS:-}
      - ALLOWED_DEVIATION=${ALLOWED_DEVIATION:-1}
      - B1_FROM=${B1_FROM}
      - B1_TO=${B1_TO}
      - B2_FROM=${B2_FROM:-}
      - B2_TO=${B2_TO:-}
      - B3_FROM=${B3_FROM:-}
      - B3_TO=${B3_TO:-}
      - B4_FROM=${B4_FROM:-}
      - B4_TO=${B4_TO:-}
      - B5_FROM=${B5_FROM:-}
      - B5_TO=${B5_TO:-}
      - B6_FROM=${B6_FROM:-}
      - B6_TO=${B6_TO:-}
```

### Creating an rclone.conf file

The simplest way to generate your `rclone.conf` file is by using the rclone configuration management command line. Follow these steps:

```
docker run -it --entrypoint=/bin/bash seatable/s3sync-backup:latest -i
rclone config
# Follow the prompts to create your rclone configuration.
# Once completed, display the contents of the configuration file:
cat /root/.config/rclone/rclone.conf
# copy the content of this configuration file to the host and mount it to the container.
```
