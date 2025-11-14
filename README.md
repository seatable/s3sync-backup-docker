# Rclone S3 Backup Docker Container

This Docker container automates the synchronisation of S3-buckets at regular intervals with rclone. It offers:

- Simple setup
- Define backup schedules
- Fast synchronisation due to optimized rclone parameters
- Custom hook integration
- Healthcheck (via https://healthchecks.io/)

## SeaTable and Seafile Specific Extension

This container is essentially a wrapper for the well-established backup software [rclone](https://rclone.org/), suitable for any use case.
My main motivation to build that, was to easily backup our own SeaTable and Seafile servers.

## Two operation types

This container could be used in two different modes. The default one is the cron mode (`RUN_MODE=cron`). You specify the cron schedule and the container will execute the rclone s3 sync everytime at schedule.
The second mode is the single execution. The container simply waits for you to start the sync with the following command:

```bash
docker exec -it s3sync sync.sh
```

## How to configure

This container requires a rclone.conf with login credentials for source and target bucket. rclone itself is configured via environment variables. More details in the next sections.

### Creating an rclone.conf file

The simplest way to generate your `rclone.conf` file is by using the rclone configuration management command line. Follow these steps to generate the file.

```
docker run -it --entrypoint=/bin/bash seatable/s3sync-backup:latest -i
rclone config
# Follow the prompts to create your rclone configuration.
# Once completed, display the contents of the configuration file:
cat /root/.config/rclone/rclone.conf
# copy the content of this configuration file to the host and safe it as `rclone.conf`.
```

For sure you could also create your rclone.conf manually. Your rclone.conf should like something like this - just an example.

```sh
[source]
type = s3
provider = Other
access_key_id = ...
secret_access_key = ...
region = 
endpoint = sos-de-fra-1.exo.io
acl = private

[target, e.g. hetzner]
type = s3
provider = Other
access_key_id = ...
secret_access_key = ...
region = nbg1
endpoint = nbg1.your-objectstorage.com
acl = private
```

It will automatically mounted in the container.

### Environment variables

The container is set up by setting environment variables and volumes.

| Name                | Description                                 | Example                                   | Default                          |
| ------------------- | ------------------------------------------- | ----------------------------------------- | -------------------------------- |
| `BACKUP_CRON`       | Execution schedule for the backup           | `15 3 * * *`                              | `15 3 * * *`                     |
| `RUN_MODE`          | ... | `cron` or `sleep` | `cron`                                                                               |
| `TZ`                | Timezone                                    | `Europe/Berlin`                           |                                  |
| `LOG_LEVEL`         | Define log level                            | `DEBUG`, `INFO`, `WARNING` or `ERROR`.    | `INFO`                           |
| `ALLOWED_DEVIATION` | Allowed deviation of number of objects in % | `1`                                       | `1`                              |
| `B1_FROM`           | Bucket name mapping (Source)                | `rclone-remote:bucket-name`               |                                  |
| `B1_TO`             | Bucket name mapping (Backup)                | `rclone-remote:backup-name`               |                                  |
| `B2_FROM`           | Bucket name mapping (Source)                | `rclone-remote:bucket-name`               |                                  |
| `B2_TO`             | Bucket name mapping (Backup)                | `rclone-remote:backup-name`               |                                  |
| `B3_FROM`           | ... up to 6 bucket mappings are allowed     |                                           |                                  |
| `B3_TO`             |                                             |                                           |                                  |
| `HEALTHCHECK_URL`   | healthcheck.io server check url             | `https://healthcheck.io/ping/a444061a`    |                                  |
| `RCLONE_LOG_LEVEL` | How verbose rclone is | `DEBUG`, `INFO`, `NOTICE` or `DEBUG` | `INFO` |
| ... | | | 
| `RCLONE_NUM_CHECKERS`      | Define number of `--checkers` of rclone     | `64`                                      | `8`                             |
| `RCLONE_NUM_TRANSFERS`     | Define number of `--transfers` of rclone    | `16`                                      | `4`                             | 
| `RLCONE_STATS`    | Define time between stats output            | `60s` or `2m`                                     | `60s`                            |
| `RCLONE_BUFFER_SIZE`       | Define value of `--buffer-size` of rclone   | `16M`                                     | `0`                              |

### Hooks

The Container supports the execution of the following custom hooks (if available at the container). Hooks are skipped if no scripts are found.

- /hooks/pre-backup.sh
- /hooks/post-backup.sh

### Logs

By default the container returns logs to stdout. You can get the log output of the container with `docker logs s3sync -f` or `docker compose logs -f`.

## Example docker-compose

Get the latest version of the container from <https://hub.docker.com/repository/docker/seatable/s3sync-backup>.

```yaml
---
services:
  s3sync:
    image: ${SEATABLE_S3SYNC_BACKUP_IMAGE:-seatable/s3sync-backup:latest}
    container_name: s3sync
    restart: unless-stopped
    volumes:
      - /opt/s3sync/rclone/rclone.conf:/root/.config/rclone/rclone.conf
      #- /opt/s3sync/hooks:/hooks:ro
    environment:
      - BACKUP_CRON=${BACKUP_CRON:-15 3 * * *} # Start s3sync always at 3:15 am.
      - RUN_MODE=${RUN_MODE:-cron}
      - TZ=${TIME_ZONE}
      - LOG_LEVEL=${LOG_LEVEL:-INFO}
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
      - HEALTHCHECK_URL=${HEALTHCHECK_URL}
      - RCLONE_LOG_LEVEL=${RCLONE_LOG_LEVEL:-NOTICE}
      - RCLONE_STATS_LOG_LEVEL=${RCLONE_STATS_LOG_LEVEL:-NOTICE}
      - RCLONE_STATS=${RCLONE_STATS:-60s}
      - RCLONE_STATS_ONE_LINE=${RCLONE_STATS_ONE_LINE:-true}
      - RCLONE_TRANSFERS=${RCLONE_TRANSFERS:-8}
      - RCLONE_CHECKERS=${RCLONE_CHECKERS:-8}
      - RCLONE_BUFFER_SIZE=${RCLONE_BUFFER_SIZE:-8M}
      - RCLONE_SKIP_LINKS=${RCLONE_SKIP_LINKS:-true}
      - RCLONE_S3_NO_CHECK_BUCKET=${RCLONE_S3_NO_CHECK_BUCKET:-true}
      - RCLONE_USE_MMAP=${RCLONE_USE_MMAP:-true}
      - RCLONE_MODIFY_WINDOW=${RCLONE_MODIFY_WINDOW:-1ns}
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "3"
    deploy:
      resources:
        limits:
          memory: 2G
        reservations:
          memory: 1G
```

## Out of memory issue

## Performance tweaking

1. Increase Number of checkers and transfers will speed up the synchronisation. Probably out of 

