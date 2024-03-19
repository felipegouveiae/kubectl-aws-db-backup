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
    apt-get install -y -qq \
        apt-transport-https \
        ca-certificates \
        curl \
        gpg-agent && \
    curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.29/deb/Release.key | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg && \
    echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.29/deb/ /' | tee /etc/apt/sources.list.d/kubernetes.list && \
    apt-get update -qq  && \
    apt-get install -y -qq kubectl mysql-client zip

RUN apt-get install -y -qq jq && \    
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*
