# Oracle Linux 9 base — glibc. Oracle only publishes the official MySQL client
# (mysqldump) for glibc distros, and only its EL9 yum repo covers both amd64
# and arm64 (the MySQL APT repo is amd64-only), so this is the same base the
# official `mysql` image uses. Every tool comes from its vendor's own repo or
# release, for both linux/amd64 and linux/arm64.
FROM oraclelinux:9-slim

# Set automatically by buildx/podman for each --platform (amd64 | arm64).
ARG TARGETARCH
ARG KUBECTL_VERSION=v1.31.14

# Vendor yum repos: MySQL 8.4 LTS, PostgreSQL 16 + 17 (PGDG), MongoDB tools.
# PGDG signs aarch64 packages with a separate key, so both keys are listed.
RUN cat > /etc/yum.repos.d/vendors.repo <<'EOF'
[mysql84-community]
name=MySQL 8.4 LTS Community
baseurl=https://repo.mysql.com/yum/mysql-8.4-community/el/9/$basearch/
gpgcheck=1
gpgkey=https://repo.mysql.com/RPM-GPG-KEY-mysql-2023

[pgdg17]
name=PostgreSQL 17
baseurl=https://download.postgresql.org/pub/repos/yum/17/redhat/rhel-9-$basearch
gpgcheck=1
gpgkey=https://download.postgresql.org/pub/repos/yum/keys/PGDG-RPM-GPG-KEY-RHEL https://download.postgresql.org/pub/repos/yum/keys/PGDG-RPM-GPG-KEY-AARCH64-RHEL

[pgdg16]
name=PostgreSQL 16
baseurl=https://download.postgresql.org/pub/repos/yum/16/redhat/rhel-9-$basearch
gpgcheck=1
gpgkey=https://download.postgresql.org/pub/repos/yum/keys/PGDG-RPM-GPG-KEY-RHEL https://download.postgresql.org/pub/repos/yum/keys/PGDG-RPM-GPG-KEY-AARCH64-RHEL

[mongodb-org-8.0]
name=MongoDB 8.0
baseurl=https://repo.mongodb.org/yum/redhat/9/mongodb-org/8.0/$basearch/
gpgcheck=1
gpgkey=https://pgp.mongodb.com/server-8.0.asc
EOF

RUN microdnf install -y --nodocs --setopt=install_weak_deps=0 \
        mysql-community-client \
        postgresql17 \
        postgresql16 \
        mongodb-database-tools \
        bash \
        zip \
        unzip \
        tar \
        gzip \
        ca-certificates \
    && microdnf clean all \
    && rm -rf /var/cache/yum /var/cache/dnf

# AWS CLI v2 — official installer (bundles its own Python).
RUN case "$TARGETARCH" in amd64) a=x86_64 ;; arm64) a=aarch64 ;; *) echo "unsupported arch $TARGETARCH" >&2; exit 1 ;; esac \
    && curl -fsSL "https://awscli.amazonaws.com/awscli-exe-linux-$a.zip" -o /tmp/awscliv2.zip \
    && unzip -q /tmp/awscliv2.zip -d /tmp \
    && /tmp/aws/install \
    && rm -rf /tmp/aws /tmp/awscliv2.zip

# kubectl — official release binary, checksum-verified.
RUN curl -fsSL "https://dl.k8s.io/release/$KUBECTL_VERSION/bin/linux/$TARGETARCH/kubectl" -o /usr/local/bin/kubectl \
    && echo "$(curl -fsSL "https://dl.k8s.io/release/$KUBECTL_VERSION/bin/linux/$TARGETARCH/kubectl.sha256")  /usr/local/bin/kubectl" | sha256sum -c - \
    && chmod +x /usr/local/bin/kubectl

# PGDG installs each major under /usr/pgsql-<N>/bin. Put 17 first on $PATH so
# plain `pg_dump` is 17, and keep the old Alpine-era paths working.
RUN mkdir -p /usr/libexec \
    && ln -s /usr/pgsql-17/bin /usr/libexec/postgresql17 \
    && ln -s /usr/pgsql-16/bin /usr/libexec/postgresql16
ENV PATH=/usr/pgsql-17/bin:$PATH

CMD ["/bin/bash"]

# Notes on the bundled tools:
#   mysql-community-client 8.4 LTS — Oracle's mysql + mysqldump (supports
#                                    --set-gtid-purged, caching_sha2_password)
#   postgresql17 / 16             — pg_dump 17 (default) and 16
#   mongodb-database-tools 100.x  — mongodump
#   aws-cli v2                    — official installer
#   kubectl                       — $KUBECTL_VERSION, official binary
#
# POSTGRES VERSIONS: the default `pg_dump` on $PATH is 17 (dumps 17.x, 16.x and
# older servers — pg_dump is backward compatible, so a 17.x server needs
# pg_dump >= 17). To force a specific major, call the versioned binary:
#     /usr/pgsql-17/bin/pg_dump   (== /usr/libexec/postgresql17/pg_dump == `pg_dump`)
#     /usr/pgsql-16/bin/pg_dump   (== /usr/libexec/postgresql16/pg_dump)
#
# MARIADB SERVERS: Oracle's mysqldump 8.4 can dump MariaDB, but MySQL-only
# options (e.g. --set-gtid-purged) are ignored/unsupported by MariaDB servers;
# add --column-statistics=0 if a MariaDB server rejects the COLUMN_STATISTICS query.
