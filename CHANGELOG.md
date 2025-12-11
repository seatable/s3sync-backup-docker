# Changelog

## v2.1.0 (11.12.2025)

- new env variable `SHARDED_SYNC` for huge buckets with millions of objects

## v2.0.1 (21.11.2025)

- install tzdata in docker container
- new env variable `SKIP_SIZE_CHECK`
- fix container tagging "pre"

## v2.0.0 (13.11.2025)

- complete rewrite
- switch to RCLONE environment variables
- improved logging
- removed email notification

## v1.1.3 (29.10.2025)

- fix typo `NUM_TRANSFERS`

## v1.1.2 (31.08.2025)

- update rclone version from 1.69.0 to 1.71.0
- add go garbage collector
- support parameter `BUFFER_SIZE`

## v1.1.0 (25.08.2025)

- remove `--size-only`
- support parameters for `CHECKERS`, `TRANSFERS` and `STATS_INTERVAL`

## v1.0.1 (04.02.2025)

- minor fix

## v1.0.0 (04.02.2025)

Initial release
