#!/bin/sh
set -eu

# -----------------------------------------
# Rootless-friendly multi-arch build script
# POSIX sh + docker buildx
# -----------------------------------------

usage() {
    echo "Usage: $0 <dir> <image[:tag]> <BALENA_ARCH> [options]" >&2
    echo "Options:" >&2
    echo "  -p, --push        Push image after build" >&2
    echo "  -l, --load        Load image locally (single-arch only)" >&2
    echo "  -n, --dry-run     Show commands only" >&2
    exit 1
}

# -----------------------------------------
# BALENA_ARCH → docker platform
# -----------------------------------------
map_platform() {
    case "$1" in
        amd64|x86_64)
            echo "linux/amd64"
            ;;
        arm64|aarch64)
            echo "linux/arm64"
            ;;
        armv7hf|armv7|armhf)
            echo "linux/arm/v7"
            ;;
        armv6|rpi)
            echo "linux/arm/v6"
            ;;
        *)
            echo "Unknown BALENA_ARCH: $1" >&2
            exit 1
            ;;
    esac
}

# -----------------------------------------
# Args
# -----------------------------------------
[ $# -lt 3 ] && usage

DIR=$1
IMAGE=$2
BALENA_ARCH=$3
shift 3

PLATFORM=$(map_platform "$BALENA_ARCH")

PUSH=0
LOAD=0
DRYRUN=0

while [ $# -gt 0 ]; do
    case "$1" in
        -p|--push) PUSH=1 ;;
        -l|--load) LOAD=1 ;;
        -n|--dry-run) DRYRUN=1 ;;
        *) echo "Unknown option: $1" >&2; exit 1 ;;
    esac
    shift
done

# -----------------------------------------
# Image name + tag
# -----------------------------------------
NAME=$(echo "$IMAGE" | cut -d: -f1)
TAG=$(echo "$IMAGE" | cut -s -d: -f2)
[ -z "$TAG" ] && TAG="latest"

# -----------------------------------------
# Ensure buildx builder
# -----------------------------------------
BUILDER="rootless-multiarch"

if ! docker buildx inspect "$BUILDER" >/dev/null 2>&1; then
    docker buildx create --name "$BUILDER" --use >/dev/null
else
    docker buildx use "$BUILDER" >/dev/null
fi

# -----------------------------------------
# Build command
# -----------------------------------------
BUILD_CMD="docker buildx build \
  --builder $BUILDER \
  --platform $PLATFORM \
  -t $NAME:$TAG \
  $DIR"

if [ "$PUSH" -eq 1 ]; then
    BUILD_CMD="$BUILD_CMD --push"
fi

if [ "$LOAD" -eq 1 ]; then
    BUILD_CMD="$BUILD_CMD --load"
fi

echo "==> Building $NAME:$TAG for $BALENA_ARCH ($PLATFORM)"
echo "$BUILD_CMD"

if [ "$DRYRUN" -eq 0 ]; then
    sh -c "$BUILD_CMD"
fi

echo "Done."
