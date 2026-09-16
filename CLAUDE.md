# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

A single Docker image (`felipegouveiae/kubectl-aws-db-backup`) that bundles the AWS CLI v2, MySQL client (`mysqldump`), PostgreSQL client (`pg_dump`), MongoDB 6 database tools (`mongodump`), `kubectl`, and `zip`. There is no application code — the image is a toolbox. The actual backup logic lives in the `command:` blocks of the Kubernetes `CronJob` manifests under `samples/`, which run inside this image on a schedule: dump a database to `/tmp`, compress it, and upload to S3 via `aws s3api put-object`.

## Build & publish

`build.sh` does everything (build + push). Prerequisites: Docker with `buildx`, and Docker Hub push access to `felipegouveiae/kubectl-aws-db-backup`.

```bash
./build.sh
```

The script:
1. Downloads the AWS CLI installers for both `linux/arm64` (aarch64) and `linux/amd64` (x86_64) into `linux/<arch>/awscliv2.zip` (skipped if already present — delete them to force a re-download).
2. Builds a per-arch image with `docker buildx build --platform ...`.
3. Tags, pushes both arches, then assembles and pushes a multi-arch `:latest` manifest.

The Dockerfile expects the AWS CLI zip at `$TARGETPLATFORM/awscliv2.zip` (e.g. `linux/amd64/awscliv2.zip`), which is why `build.sh` lays the files out under `linux/`. Both `linux/` and `*.zip` are gitignored.

## Architecture notes

- **Multi-stage Dockerfile**: the first stage unzips the AWS CLI installer; the final `ubuntu:22.04` stage installs it plus the DB clients and kubectl. MongoDB tools are pinned to `MONGO_VERSION 6.0.14` and installed from MongoDB's `6.0` apt repo; kubectl comes from the Kubernetes `v1.29` stable apt repo; the PostgreSQL client is `postgresql-client-16` from the official PGDG apt repo (not Ubuntu's default `postgresql-client`, which is older). `pg_dump` must be at least the server version, so bump this when you need to back up a newer server.
- **Where behavior actually lives**: to change what gets backed up or how, edit the `samples/*.yaml` CronJob `command:` scripts, not the image. The image only needs rebuilding when a bundled tool (versions, adding a client) changes.
- **Configuration is injected at runtime** via `envFrom` (Kubernetes ConfigMaps/Secrets) — DB credentials, hostnames, S3 bucket/key. The Dockerfile bakes in no secrets or config.
- **`/tmp` sizing**: the MongoDB sample mounts an ephemeral volume at `/tmp` because dumps can exceed the container's default writable layer; keep this in mind when editing dump paths (both samples write to `/tmp`).
