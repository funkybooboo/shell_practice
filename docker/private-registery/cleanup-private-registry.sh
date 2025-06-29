#!/usr/bin/env bash
set -euo pipefail

REGISTRY_NAME=registry
REGISTRY_PORT=5000
REGISTRY_IMAGE="registry"
REGISTRY_VOLUME="$(pwd)/registry-data"

echo "==> [1/3] Stopping and removing the registry container..."
docker container stop "${REGISTRY_NAME}" || true
docker container rm "${REGISTRY_NAME}" || true

echo "==> [2/3] Deleting Docker images from local system..."
docker image remove "127.0.0.1:${REGISTRY_PORT}/hello-world" || true
docker image remove hello-world || true
docker image remove "${REGISTRY_IMAGE}" || true

echo "==> [3/3] Removing bind mount data with elevated privileges..."
if [ -d "${REGISTRY_VOLUME}" ]; then
    sudo rm -rf "${REGISTRY_VOLUME}"
    echo "✓ Successfully deleted ${REGISTRY_VOLUME}"
else
    echo "✓ No data directory to remove at ${REGISTRY_VOLUME}"
fi

echo "==> Cleanup complete."
