#!/bin/bash

mkdir -p linux/arm64
mkdir -p linux/amd64

if [ ! -e linux/arm64/awscliv2.zip ]; then
    curl https://awscli.amazonaws.com/awscli-exe-linux-aarch64.zip -o linux/arm64/awscliv2.zip
fi

if [ ! -e linux/amd64/awscliv2.zip ]; then
    curl https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip -o linux/amd64/awscliv2.zip
fi

docker buildx build --platform linux/arm64 --load -t kubectl-aws-db-backup:arm64 .
docker buildx build --platform linux/amd64 --load -t kubectl-aws-db-backup:amd64 .

docker tag kubectl-aws-db-backup:arm64 felipegouveiae/kubectl-aws-db-backup:arm64
docker tag kubectl-aws-db-backup:amd64 felipegouveiae/kubectl-aws-db-backup:amd64

docker push -a felipegouveiae/kubectl-aws-db-backup

docker manifest rm felipegouveiae/kubectl-aws-db-backup:latest

docker manifest create felipegouveiae/kubectl-aws-db-backup:latest \
    felipegouveiae/kubectl-aws-db-backup:amd64 \
    felipegouveiae/kubectl-aws-db-backup:arm64

docker manifest push felipegouveiae/kubectl-aws-db-backup:latest
