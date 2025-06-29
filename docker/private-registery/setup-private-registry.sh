#!/usr/bin/env bash
set -euo pipefail

REGISTRY_PORT=5000
REGISTRY_NAME=registry
REGISTRY_VOLUME="$(pwd)/registry-data"

echo "==> [1/6] Starting private Docker registry..."
docker container run -d \
    -p "${REGISTRY_PORT}:5000" \
    --name "${REGISTRY_NAME}" \
    -v "${REGISTRY_VOLUME}:/var/lib/registry" \
    registry

echo "==> [2/6] Pulling and tagging 'hello-world' image..."
docker pull hello-world
docker tag hello-world "127.0.0.1:${REGISTRY_PORT}/hello-world"

echo "==> [3/6] Pushing image to private registry..."
docker push "127.0.0.1:${REGISTRY_PORT}/hello-world"

echo "==> [4/6] Removing local copies of the image..."
docker image remove hello-world || true
docker image remove "127.0.0.1:${REGISTRY_PORT}/hello-world" || true

echo "==> [5/6] Pulling image back from private registry..."
docker pull "127.0.0.1:${REGISTRY_PORT}/hello-world"

echo "==> [6/6] Completed successfully. Private registry is running on port ${REGISTRY_PORT}."
