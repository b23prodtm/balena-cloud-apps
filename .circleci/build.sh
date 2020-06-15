#!/usr/bin/env bash
work_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
usage=("" \
"Usage: $0" \
"    CircleCI needs a primary image with docker-in-docker backend." \
"    To build it use deployment/build.sh script to push to image registry and tag it:" \
"        deployment/images/build.sh secondary betothreeprod/cci-mariadb arm64v8-latest" \
"Then you can run composition process: sudo docker-compose up --build" \
"")
[ ! "$(command -v circleci)" ] && curl -fLSs https://circle.ci/cli | bash
# https://github.com/koalaman/shellcheck/wiki/SC2207
# shellcheck source=../deploy.sh
mapfile -t dock < <(find "${work_dir}/../deployment/images" -name "Dockerfile.x86_64")
[ "$#" -lt 1 ] && printf "Usage: %s <repository>" "$0" && exit 0
for d in "${dock[@]}"; do
  dir=$(dirname "$d")
  docker_build "$dir" "." "$1/$(basename "$dir")" "$(arch)"
done
sed -e "/custom_checkout:/s/\"\"/\"\/tmp\/_circleci_local_build_repo\"/g" "${work_dir}/config.yml" | circleci config process - > "${work_dir}/config-compat.yml"
circleci local execute -c "${work_dir}/config-compat.yml" || echo -e "${usage[0]}"
