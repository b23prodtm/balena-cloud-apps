#!/usr/bin/env bash
set -u
[ "$#" -eq 0 ] && echo "usage $0 <work_dir> <args>" && exit 0
[ -f "$1" ] && set -- "$(cd "$(dirname "$1")" && pwd)" "${@:2}"
workd="$(cd "$1" && pwd)"; shift
banner=("" "[$0] BASH ${BASH_SOURCE[0]}" "$workd" "$*"); printf "%s\n" "${banner[@]}"
usage=("" \
"Usage: $0 [options] <work_sub_dir> <container_name> [DKR_ARCH]" \
"                    <-f, --force> <-e> <-m, --make-space>" \
"" \
"                    Base balenalib/raspberrypi3 images may be" \
"                    built from a Mac or PC without any specific" \
"                    cross-build backend, just set DKR_ARCH to ARM32" \
"                    or ARM64." \
"" \
"          work_sub_dir:    Path relative to $0" \
"          container_name:  Set to username/container to push to" \
"                           Docker.io, e.g. myself/cakephp2-image x86_64" \
"          DKR_ARCH:        1|arm32*|armv7l|armhf   ARMv7 OS" \
"                           2|arm64*|aarch64        ARMv8 OS" \
"                           3|amd64|x86_64          All X86 64 bits" \
"                                                   OS (Mac or PC)" \
"          -f,--force:      Set docker daemon restart flag on" \
"          -e:              Reset docker machine environment variables" \
"          -m,--make-space: Remove exited containers to free some disk space" \
"          TAG:             Set as environment variable IMG_TAG" \
"                           File <DKR_ARCH>.env" \
"More about docker tag:" \
"       docker tag <repository/image:tag> <new_repository/new_image:tag>" \
"")
[ "$#" -lt 3 ] && printf "%s\n" "${usage[@]}" && exit 0
while [[ "$#" -gt 0 ]]; do case $1 in
  -[fF]*|--force)
    docker-machine restart default;;
  -[eE]*)
    eval "$(docker-machine env)";;
  -[mM]*|--make-space)
    docker rm "$(docker ps -q -a -f 'status=exited')" 2> /dev/null \
    || docker volume rm "$(docker volume ls -qf dangling=true)" 2> /dev/null || true
    ;;
  -[hH]*|--help)
    printf "%s\n" "${usage[@]}"
    exit 0;;
  *)
    DIR="$1"
    NAME=$(echo "$2" | cut -d: -f1)
    DKR_ARCH="$3"
    shift 2
    ;;
esac; shift; done
# shellcheck disable=SC1090
. "${workd}/.env" && . "${workd}/common.env"
docker build -f "$workd/$DIR/Dockerfile.${DKR_ARCH}" -t "$NAME:$IMG_TAG" "$workd/$DIR"
container=$(echo "$NAME" | cut -d/ -f2-)
docker run --rm -itd --name "$container" "$NAME:$IMG_TAG" &
sleep 2
docker stop "$container"
docker login docker.io -u "${DOCKER_USER:-}" -p "${DOCKER_PASS:-}"
docker push "$NAME:$IMG_TAG"
docker tag "$NAME:$IMG_TAG" "$NAME:$IMG_TAG-${DKR_ARCH}"
docker push "$NAME:$IMG_TAG-${DKR_ARCH}"
