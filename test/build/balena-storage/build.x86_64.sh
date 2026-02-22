#!/usr/bin/env bash
set -eu
TOPDIR="$(cd "$(dirname \
"$(dirname "${BASH_SOURCE[0]}")")" && pwd)"
ln -s "${TOPDIR}/x86_64.env" x86_64.env
balena_deploy "${TOPDIR}" x86_64 3 0
docker buildx bake -f "${TOPDIR}/docker-bake.hcl" balena-storage \
  --set "*.platform=linux/amd64" --push
