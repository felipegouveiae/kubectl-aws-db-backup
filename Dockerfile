# Alpine base — musl libc. Every tool below is installed straight from Alpine's
# repos (both linux/amd64 and linux/arm64), so there is no glibc-compat shim and
# no downloaded AWS CLI installer. apk auto-selects the right arch per build.
FROM alpine:3.20

RUN apk add --no-cache \
    aws-cli \
    mysql-client \
    postgresql16-client \
    mongodb-tools \
    kubectl \
    zip \
    curl \
    bash \
    ca-certificates

# Notes on the bundled tools (Alpine 3.20 versions):
#   aws-cli            2.x   — AWS CLI v2, built for musl (no glibc needed)
#   mysql-client             — provides mysqldump (MariaDB's implementation, see caveat below)
#   postgresql16-client 16.x — provides pg_dump 16
#   mongodb-tools       100.x — provides mongodump (MongoDB Database Tools)
#   kubectl            1.30.x
#   bash                     — the sample CronJobs invoke /bin/bash, absent by default on Alpine
#
# CAVEAT: on Alpine, mysqldump is MariaDB's, which does NOT support the MySQL-only
# `--set-gtid-purged` flag used in samples/kubernetes-mysql-job-sample.yaml.
# Drop that flag when running against MariaDB.
