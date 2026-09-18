# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

A single Docker image (`felipegouveiae/kubectl-aws-db-backup`) that bundles the AWS CLI v2, MySQL client (`mysqldump`), PostgreSQL client (`pg_dump`), MongoDB database tools (`mongodump`), `kubectl`, `bash`, and `zip`. There is no application code — the image is a toolbox. The actual backup logic lives in the `command:` blocks of the Kubernetes `CronJob` manifests under `samples/`, which run inside this image on a schedule: dump a database to `/tmp`, compress it, and upload to S3 via `aws s3api put-object`.

## Build & publish

`build.sh` does everything (Docker Hub login + build + push) and takes the image tag as its first argument. Prerequisites: Docker with `buildx`, and Docker Hub push access to `felipegouveiae/kubectl-aws-db-backup`.

```bash
./build.sh latest      # or ./build.sh v1.0, etc.
```

The script builds a per-arch image with `docker buildx build --platform ...` for both `linux/arm64` and `linux/amd64`, tags them `…:$TAG-arm64` / `…:$TAG-amd64`, pushes both, then assembles and pushes a multi-arch `…:$TAG` manifest.

Note: `build.sh` still downloads `awscliv2.zip` into `linux/<arch>/`, but that is now **dead code** — the Alpine Dockerfile installs AWS CLI from `apk`, so nothing consumes the zip. It can be removed. Both `linux/` and `*.zip` are gitignored.

## Architecture notes

- **Single-stage Alpine Dockerfile**: everything is installed from Alpine's own repos in one `apk add`, for both amd64 and arm64 — no glibc-compat shim and no downloaded AWS CLI installer. This works because Alpine 3.21 packages `aws-cli` 2.x built for musl (the usual blocker for AWS CLI v2 on Alpine). `postgresql17-client` and `postgresql16-client` are both installed and coexist via Alpine's `postgresql-common`: the default `pg_dump` on `$PATH` is 17 (pg_dump is backward compatible, so a 17.x server needs pg_dump ≥ 17), and the 16 binary stays available at `/usr/libexec/postgresql16/pg_dump`. `mongodb-tools` provides the 100.x MongoDB Database Tools; `kubectl` and `mysql-client` come from the community repo. Versions track the pinned Alpine release (`FROM alpine:3.21`) — bump the base image to move them.
- **`mysqldump` is MariaDB's on Alpine**, not Oracle MySQL. It does **not** support the MySQL-only `--set-gtid-purged` flag used in `samples/kubernetes-mysql-job-sample.yaml` — that flag must be dropped when the sample runs against this image.
- **`bash` is explicitly installed** because the sample CronJobs invoke `/bin/bash`, which Alpine does not ship by default (it has busybox `sh`).
- **Where behavior actually lives**: to change what gets backed up or how, edit the `samples/*.yaml` CronJob `command:` scripts, not the image. The image only needs rebuilding when a bundled tool (versions, adding a client) changes.
- **Configuration is injected at runtime** via `envFrom` (Kubernetes ConfigMaps/Secrets) — DB credentials, hostnames, S3 bucket/key. The Dockerfile bakes in no secrets or config.
- **`/tmp` sizing**: the MongoDB sample mounts an ephemeral volume at `/tmp` because dumps can exceed the container's default writable layer; keep this in mind when editing dump paths (both samples write to `/tmp`).
