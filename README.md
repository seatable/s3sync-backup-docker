# Rclone S3 Backup Docker Container

This Docker container automates S3 bucket synchronization using rclone at scheduled intervals. It focuses on simple setup, flexible scheduling, optimized performance, hook integration, and optional health monitoring.

## Features

- Simple configuration via environment variables
- Flexible backup schedules using cron
- Optimized rclone parameters for large S3 buckets
- Custom pre/post backup hooks
- Optional health monitoring via healthchecks.io

## SeaTable/Seafile Focus

The container is a thin wrapper around the well-established backup tool [rclone](https://rclone.org/) and can be used for any S3-to-S3 backup scenario.
It was primarily built to reliably back up SeaTable and Seafile instances with very large, flat S3 buckets.

## Operation Modes

This container supports two modes:

- **Cron mode** (`RUN_MODE=cron`): Runs `rclone sync` automatically to `S3SYNC_BACKUP_CRON` schedule.
- **Manual mode** (`RUN_MODE=sleep`): The container stays idle until you trigger a sync manually:

```bash
docker exec -it s3sync sync.sh
```

## Configuration overview

The container requires:

- An `rclone.conf` with credentials and remotes for source and target
- Environment variables for schedules, bucket mappings, and rclone tuning

### Creating `rclone.conf`

The easiest way is to use the interactive `rclone` configuration inside the image:

```bash
docker run -it --entrypoint=/bin/bash seatable/s3sync-backup:latest -i
rclone config
# Follow the prompts to create your rclone configuration
cat /root/.config/rclone/rclone.conf
# Copy the output to the host and save it as rclone.conf
```

For sure you could also create your rclone.conf manually. Your `rclone.conf` should like something like this - just an example.

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

Mount it into the container:

```bash
volumes:
  - /opt/s3sync/rclone/rclone.conf:/root/.config/rclone/rclone.conf:ro
```

### Environment variables

The container is configured entirely via environment variables.

#### Core settings

| Name                 | Description                       | Example                                | Default      |
| -------------------- | --------------------------------- | -------------------------------------- | ------------ |
| `S3SYNC_BACKUP_CRON` | Cron schedule                     | `15 3 * * *`                           | `15 3 * * *` |
| `S3SYNC_RUN_MODE`    | Cron schedule or manual execution | `cron` or `sleep`                      | `cron`       |
| `S3SYNC_LOG_LEVEL`   | Define log level                  | `DEBUG`, `INFO`, `WARNING` or `ERROR`. | `INFO`       |
| `TIME_ZONE`          | Timezone                          | `Europe/Berlin`                        |              |

#### Bucket mappings

Up to 6 source/target pairs are supported.

| Name      | Description                             | Example                     | Default |
| --------- | --------------------------------------- | --------------------------- | ------- |
| `B1_FROM` | Bucket name mapping (Source)            | `rclone-remote:bucket-name` |         |
| `B1_TO`   | Bucket name mapping (Backup)            | `rclone-remote:backup-name` |         |
| `B2_FROM` | Bucket name mapping (Source)            | `rclone-remote:bucket-name` |         |
| `B2_TO`   | Bucket name mapping (Backup)            | `rclone-remote:backup-name` |         |
| `B3_FROM` | ... up to 6 bucket mappings are allowed |                             |         |
| `B3_TO`   |                                         |                             |         |

#### S3SYNC-specific options

| Name                       | Description                                  | Example                                | Default |
| -------------------------- | -------------------------------------------- | -------------------------------------- | ------- |
| `S3SYNC_ALLOWED_DEVIATION` | Allowed deviation of object count in percent | `1`                                    | `1`     |
| `S3SYNC_SKIP_SIZE_CHECK`   | Skip post-sync size check                    | `false`                                | `false` |
| `S3SYNC_SHARDED_SYNC`      | Enable sharded sync per library              | `false`                                | `false` |
| `S3SYNC_HEALTHCHECK_URL`   | healthchecks.io ping URL                     | `https://healthcheck.io/ping/a444061a` |         |

#### rclone tuning

| Name                        | Description             | Example                              | Default   |
| --------------------------- | ----------------------- | ------------------------------------ | --------- |
| `RCLONE_LOG_LEVEL`          | rclone log level        | `DEBUG`, `INFO`, `NOTICE` or `ERROR` | `INFO`    |
| `RCLONE_STATS_LOG_LEVEL`    | rclone stats log level  | `DEBUG`, `INFO`, `NOTICE` or `ERROR` | `INFO`    |
| `RCLONE_STATS`              | Stats interval          | `180s`                               | `60s`     |
| `RCLONE_STATS_ONE_LINE`     | One-line stats output   | `true` or `false`                    | `true`    |
| `RCLONE_CHECKSUM`           | Use checksum comparison | `true` or `false`                    | `true`    |
| `RCLONE_FAST_LIST`          | Enable `--fast-list`    | `true` or `false`                    | `true`    |
| `RCLONE_TRANSFERS`          | `--transfers`           | `16`                                 | `16`      |
| `RCLONE_CHECKERS`           | `--checkers`            | `64`                                 | `64`      |
| `RCLONE_BUFFER_SIZE`        | `--buffer-size`         | `16M`                                | `8M`      |
| `RCLONE_SKIP_LINKS`         | `--skip-links`          | `true`                               | `true`    |
| `RCLONE_S3_NO_CHECK_BUCKET` | `--s3-no-check-bucket`  | `true`                               | `true`    |
| `RCLONE_USE_MMAP`           | `--use-mmap`            | `true`                               | `true`    |
| `RCLONE_MODIFY_WINDOW`      | `--modify-window`       | `1ns`                                | `1s`      |
| `RCLONE_TPSLIMIT`           | `--tpslimit`            | `0`                                  | `0`       |
| `RCLONE_TPSLIMIT_BURST`     | `--tpslimit-burst`      | `3`                                  | `1`       |
| `RCLONE_LIST_CUTOFF`        | `--list-cutoff`         | `10000`                              | `1000000` |
| `RCLONE_S3_NO_HEAD`         | `--s3-no-head`          | `true`                               | `true`    |

### Hooks

If present, the following optional scripts are executed inside the container:

- /hooks/pre-backup.sh
- /hooks/post-backup.sh

If no script is mounted, the corresponding hook is skipped.

### Logs

By default, all logs go to stdout.
You can retrieve them via:

```bash
docker logs s3sync -f
# or
docker compose logs -f
```

Log verbosity is controlled by:

- `S3SYNC_LOG_LEVEL` – container logic
- `RCLONE_LOG_LEVEL` – rclone operations
- `RCLONE_STATS_LOG_LEVEL` – rclone progress stats

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
      # schedule and mode
      - BACKUP_CRON=${S3SYNC_BACKUP_CRON:-15 3 * * *} # Start s3sync always at 3:15 am.
      - RUN_MODE=${S3SYNC_RUN_MODE:-cron}
      - LOG_LEVEL=${S3SYNC_LOG_LEVEL:-NOTICE}
      - TZ=${TIME_ZONE:?Variable is not set or empty}

      # buckets to sync
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

      # size check, sharded sync, healthcheck
      - ALLOWED_DEVIATION=${S3SYNC_ALLOWED_DEVIATION:-1}
      - SKIP_SIZE_CHECK=${S3SYNC_SKIP_SIZE_CHECK:-false}
      - SHARDED_SYNC=${S3SYNC_SHARDED_SYNC:-false}
      - HEALTHCHECK_URL=${S3SYNC_HEALTHCHECK_URL:-}

      # rclone parameters
      - RCLONE_LOG_LEVEL=${RCLONE_LOG_LEVEL:-NOTICE}
      - RCLONE_STATS_LOG_LEVEL=${RCLONE_STATS_LOG_LEVEL:-NOTICE}
      - RCLONE_STATS=${RCLONE_STATS:-60s}
      - RCLONE_STATS_ONE_LINE=${RCLONE_STATS_ONE_LINE:-true}
      - RCLONE_CHECKSUM=${RCLONE_CHECKSUM:-true}
      - RCLONE_FAST_LIST=${RCLONE_FAST_LIST:-true}
      - RCLONE_TRANSFERS=${RCLONE_TRANSFERS:-16}
      - RCLONE_CHECKERS=${RCLONE_CHECKERS:-64}
      - RCLONE_BUFFER_SIZE=${RCLONE_BUFFER_SIZE:-8M}
      - RCLONE_SKIP_LINKS=${RCLONE_SKIP_LINKS:-true}
      - RCLONE_S3_NO_CHECK_BUCKET=${RCLONE_S3_NO_CHECK_BUCKET:-true}
      - RCLONE_USE_MMAP=${RCLONE_USE_MMAP:-true}
      - RCLONE_MODIFY_WINDOW=${RCLONE_MODIFY_WINDOW:-1s}
      - RCLONE_TPSLIMIT=${RCLONE_TPSLIMIT:-0}
      - RCLONE_TPSLIMIT_BURST=${RCLONE_TPSLIMIT_BURST:-1}
      - RCLONE_LIST_CUTOFF=${RCLONE_LIST_CUTOFF:-1000000}
      - RCLONE_S3_NO_HEAD=${RCLONE_S3_NO_HEAD:-true}
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

## Sync comparision mode

`rclone sync` can decide which objects to sync using three comparison modes:

| Mode          | Description                                                                     |
| ------------- | ------------------------------------------------------------------------------- |
| **Size-only** | Compares file sizes only. Very fast but unsafe if different data has same size. |
| **Modtime**   | Compares size and modification time. This is the rclone default.                |
| **Checksum**  | Compares cryptographic hashes (for example MD5 or SHA1), plus size.             |

Using **size-only** is strongly discouraged unless you fully understand the risk of false positives.

### Speed characteristics

In many general scenarios the typical ranking is:

- **size-only** > **modtime** > **checksum**

However, for SeaTable and Seafile with very large buckets and millions of small objects, the following pattern is common:

- **size-only**: fastest, but not recommended for safety reasons
- **checksum**: roughly 20% slower than size-only, but still efficient when the backend exposes checksums in listings
- **modtime**: slowest, as it often triggers additional API calls (for example HEAD per object) to read timestamps accurately

## Full vs sharded sync

Large SeaTable/Seafile buckets with a flat hierarchy can cause high memory usage when `rclone` indexes all objects in one pass.

With `S3SYNC_SHARDED_SYNC=true`, the container retrieves library IDs and synchronizes each library separately:

- instead of a `single source-bucket -> target-bucket` sync
- it runs `source-bucket/library-id -> target-bucket/library-id` in a loop

## Performance tuning

- If `docker stats` shows rapidly increasing RAM or you see **out of memory** events in `dmesg`, lower `RCLONE_LIST_CUTOFF` from `1000000` to something like `10000`.
- If your provider returns `429 Too Many Requests`, reduce `RCLONE_TPSLIMIT` and increase `RCLONE_TPSLIMIT_BURST` gradually until you stay below rate limits.
