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
PLATFORMS=linux/amd64,linux/arm64

# NO_CACHE=1 ./build.sh <tag> rebuilds from scratch: re-pulls the base image and
# re-runs apk add, so the bundled tools pick up the latest Alpine packages.
BUILD_FLAGS=()
if [ "${NO_CACHE:-}" = "1" ]; then
    BUILD_FLAGS=(--no-cache --pull)
fi

# Prefer real Docker; fall back to Podman (aliases like docker=podman are not
# expanded inside scripts, so detect it explicitly).
if command -v docker >/dev/null 2>&1 && ! docker --version 2>/dev/null | grep -qi podman; then
    BUILDER=multiarch

    # The default "docker" buildx driver can't build/push multi-platform images,
    # so use (and create on first run) a docker-container builder.
    if ! docker buildx inspect "$BUILDER" >/dev/null 2>&1; then
        docker buildx create --name "$BUILDER" --driver docker-container
    fi

    # Builds both architectures and pushes them under a single multi-arch tag.
    docker buildx build \
        --builder "$BUILDER" \
        --platform "$PLATFORMS" \
        ${BUILD_FLAGS[@]+"${BUILD_FLAGS[@]}"} \
        -t "$IMAGE:$TAG" \
        --push \
        .

    docker buildx imagetools inspect "$IMAGE:$TAG"
elif command -v podman >/dev/null 2>&1; then
    # Podman builds each platform into a local manifest list, then pushes it
    # together with every per-arch image. Use the fully qualified name so a
    # stale docker.io/... image doesn't shadow the manifest list.
    LOCAL="docker.io/$IMAGE:$TAG"
    podman manifest rm "$LOCAL" >/dev/null 2>&1 || true
    podman rmi "$LOCAL" >/dev/null 2>&1 || true

    podman build --platform "$PLATFORMS" ${BUILD_FLAGS[@]+"${BUILD_FLAGS[@]}"} --manifest "$LOCAL" .
    podman manifest push --all "$LOCAL" "docker://$IMAGE:$TAG"

    podman manifest inspect "$LOCAL"
else
    echo "Neither docker nor podman found on PATH" >&2
    exit 1
fi
