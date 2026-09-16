#!/bin/bash
set -euo pipefail

if [ -f ~/.bash_aliases ]; then
    source ~/.bash_aliases
fi

TAG="${1:-}"

if [ -z "$TAG" ]; then
    echo "Usage: $0 <docker-tagname>" >&2
    echo "  e.g. $0 latest" >&2
    exit 1
fi

IMAGE=felipegouveiae/kubectl-aws-db-backup

mkdir -p linux/arm64
mkdir -p linux/amd64

if [ ! -e linux/arm64/awscliv2.zip ]; then
    curl https://awscli.amazonaws.com/awscli-exe-linux-aarch64.zip -o linux/arm64/awscliv2.zip
fi

if [ ! -e linux/amd64/awscliv2.zip ]; then
    curl https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip -o linux/amd64/awscliv2.zip
fi

docker buildx build --platform linux/arm64 --load -t kubectl-aws-db-backup:$TAG-arm64 .
docker buildx build --platform linux/amd64 --load -t kubectl-aws-db-backup:$TAG-amd64 .

docker tag kubectl-aws-db-backup:$TAG-arm64 $IMAGE:$TAG-arm64
docker tag kubectl-aws-db-backup:$TAG-amd64 $IMAGE:$TAG-amd64

docker push $IMAGE:$TAG-arm64
docker push $IMAGE:$TAG-amd64

docker manifest rm $IMAGE:$TAG || true

docker manifest create $IMAGE:$TAG \
    $IMAGE:$TAG-amd64 \
    $IMAGE:$TAG-arm64

docker manifest push $IMAGE:$TAG
