# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

A single Docker image (`felipegouveiae/kubectl-aws-db-backup`) that bundles the AWS CLI v2, MySQL client (`mysqldump`), PostgreSQL client (`pg_dump`), MongoDB database tools (`mongodump`), `kubectl`, `bash`, and `zip`. There is no application code — the image is a toolbox. The actual backup logic lives in the `command:` blocks of the Kubernetes `CronJob` manifests under `samples/`, which run inside this image on a schedule: dump a database to `/tmp`, compress it, and upload to S3 via `aws s3api put-object`.

## Build & publish

`build.sh` builds and pushes the image and takes the image tag as its first argument. Prerequisites: Docker with `buildx`, and being logged in to Docker Hub with push access to `felipegouveiae/kubectl-aws-db-backup`.

```bash
./build.sh latest      # or ./build.sh v1.0, etc.
```

The script runs a single `docker buildx build --platform linux/amd64,linux/arm64 --push`, which builds both architectures and pushes them under one multi-arch `…:$TAG`. It uses a `docker-container` buildx builder named `multiarch` (created on first run), because the default `docker` driver can't push multi-platform images. Building the non-native arch relies on QEMU emulation (built into Docker Desktop).

If `docker` is missing or is really Podman (a `docker=podman` shell alias does not apply inside the script), it falls back to `podman build --platform ... --manifest docker.io/<image>:<tag>` + `podman manifest push --all`. The local name is fully qualified on purpose: a leftover plain image at `docker.io/...:<tag>` otherwise breaks `--manifest` with "image is not a manifest list".

## Architecture notes

- **Oracle Linux 9 (`oraclelinux:9-slim`, glibc) base**, chosen so `mysqldump` is Oracle's official MySQL client. The image used to be Alpine, but Alpine's `mysqldump` is MariaDB's, which segfaulted against a MySQL server on amd64 and lacked the `caching_sha2_password` plugin. Oracle doesn't build MySQL for musl, and its APT repo is amd64-only; the EL9 yum repo covers both arches. Tools come from vendor sources, configured in the Dockerfile's `vendors.repo` heredoc:
  - `mysql-community-client` 8.4 LTS from repo.mysql.com.
  - `postgresql17` + `postgresql16` from PGDG, installed under `/usr/pgsql-<N>/bin`. 17 is first on `$PATH`, since pg_dump is backward compatible and a 17.x server needs pg_dump ≥ 17. `/usr/libexec/postgresql{16,17}` are symlinks kept for the old Alpine-era paths. PGDG signs aarch64 RPMs with a separate key (`PGDG-RPM-GPG-KEY-AARCH64-RHEL`), so both keys are listed.
  - `mongodb-database-tools` from the MongoDB 8.0 repo.
  - AWS CLI v2 from Amazon's official installer zip.
  - `kubectl` from dl.k8s.io, checksum-verified and pinned by `ARG KUBECTL_VERSION`.
  - The per-arch downloads use `TARGETARCH`, which buildx and podman set per `--platform`.
- **Oracle `mysqldump` against a MariaDB server** needs `--column-statistics=0`; otherwise it fails with `Unknown table 'COLUMN_STATISTICS'`. The MySQL sample, which targets `mariadb-service`, passes it. `--set-gtid-purged=OFF` works against both.
- **Where behavior actually lives**: to change what gets backed up or how, edit the `samples/*.yaml` CronJob `command:` scripts, not the image. The image only needs rebuilding when a bundled tool (versions, adding a client) changes.
- **Configuration is injected at runtime** via `envFrom` (Kubernetes ConfigMaps/Secrets) — DB credentials, hostnames, S3 bucket/key. The Dockerfile bakes in no secrets or config.
- **`/tmp` sizing**: the MongoDB sample mounts an ephemeral volume at `/tmp` because dumps can exceed the container's default writable layer; keep this in mind when editing dump paths (both samples write to `/tmp`).
