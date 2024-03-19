FROM  ubuntu:22.04 as aws-cli-source

WORKDIR /opt/

ARG TARGETPLATFORM

COPY $TARGETPLATFORM/awscliv2.zip .

RUN apt-get update -qq && \
    apt-get install -y -qq unzip && \
    unzip awscliv2.zip 

FROM  ubuntu:22.04

COPY --from=aws-cli-source /opt/aws/ ./aws/

RUN ./aws/install

RUN apt-get update -qq && \
    apt-get install -y --no-install-recommends \
    apt-transport-https \
    ca-certificates \
    curl \
    gpg-agent \
    gnupg \
    wget \
    mysql-client \
    zip

# installing kubectl
RUN curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.29/deb/Release.key | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg && \
    echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.29/deb/ /' | tee /etc/apt/sources.list.d/kubernetes.list && \
    apt-get update -qq  && \
    apt-get install -y -qq kubectl

# Installing Mongo Toools (mongodump - https://github.com/mongodb/mongo/tree/25225db95574916fecab3af75b184409f8713aef
RUN set -eux; \
    \
    savedAptMark="$(apt-mark showmanual)"; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
    gnupg \
    wget \
    ; \
    rm -rf /var/lib/apt/lists/*; \
    \
    # download/install MongoDB PGP keys
    export GNUPGHOME="$(mktemp -d)"; \
    wget -O KEYS 'https://pgp.mongodb.com/server-6.0.asc'; \
    gpg --batch --import KEYS; \
    mkdir -p /etc/apt/keyrings; \
    gpg --batch --export --armor '39BD841E4BE5FB195A65400E6A26B1AE64C3C388' > /etc/apt/keyrings/mongodb.asc; \
    gpgconf --kill all; \
    rm -rf "$GNUPGHOME" KEYS; \
    \
    apt-mark auto '.*' > /dev/null; \
    apt-mark manual $savedAptMark > /dev/null; \
    apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false; 

ARG MONGO_PACKAGE=mongodb-org
ARG MONGO_REPO=repo.mongodb.org

ENV MONGO_PACKAGE=${MONGO_PACKAGE} MONGO_REPO=${MONGO_REPO}
ENV MONGO_VERSION 6.0.14
ENV MONGO_MAJOR 6.0

RUN set -x \
    && echo "deb [ signed-by=/etc/apt/keyrings/mongodb.asc ] http://$MONGO_REPO/apt/ubuntu jammy/${MONGO_PACKAGE%-unstable}/$MONGO_MAJOR multiverse" | tee "/etc/apt/sources.list.d/${MONGO_PACKAGE%-unstable}.list" \
    && export DEBIAN_FRONTEND=noninteractive \
    && apt-get update \
    && apt-get install -y \
    ${MONGO_PACKAGE}-tools=$MONGO_VERSION \
    ${MONGO_PACKAGE}-shell=$MONGO_VERSION \
    && rm -rf /var/lib/apt/lists/* \
    && rm -rf /var/lib/mongodb
