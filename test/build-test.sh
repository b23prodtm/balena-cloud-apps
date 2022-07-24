#!/usr/bin/env bash
vendord="$(cd "$(dirname "${BASH_SOURCE[0]}")/../vendor/cni" && pwd)"
chkSet="x${DEBIAN_FRONTEND:-}"
DEBIAN_FRONTEND='noninteractive'
testd="$(cd "$(dirname "${BASH_SOURCE[0]}")/build" && pwd)"
# shellcheck disable=SC1090
. "$vendord/init_functions.sh" "$testd"
LOG=$(new_log "/tmp")
[ "$DEBUG" ] && LOG=$(new_log "/dev" "/stderr")
function test_deploy() {
  # x86_64
  args=("3" --nobuild --exit)
  # shellcheck disable=SC1090
  . "$vendord/balena_deploy.sh" "$testd" "${args[@]}" >> "$LOG"
  grep -q "intel-nuc" < "$testd/submodule/Dockerfile.x86_64"
}
function test_deploy_2() {
  # aarch64
  args=("2" --nobuild --exit)
  # shellcheck disable=SC1090
  . "$vendord/balena_deploy.sh" "$testd" "${args[@]}" >> "$LOG"
  grep -q "generic-aarch64" < "$testd/submodule/Dockerfile.aarch64"
}
function test_deploy_3() {
  # armhf
  args=("1" --nobuild --exit)
  # shellcheck disable=SC1090
  . "$vendord/balena_deploy.sh" "$testd" "${args[@]}" >> "$LOG"
  grep -q "raspberrypi3" < "$testd/submodule/Dockerfile.armhf"
}
function test_docker_3() {
  args=("${testd}/submodule" -m . "betothreeprod/raspberrypi3" "$DKR_ARCH")
  # shellcheck disable=SC1090
  . "$vendord/docker_build.sh" "${args[@]}" >> "$LOG"
  docker image ls -q "${args[3]}*"
}
function test_docker() {
  args=("${testd}/deployment/images/dind-php7" -m . "betothreeprod/dind-php7" "$DKR_ARCH")
  # shellcheck disable=SC1090
  . "$vendord/docker_build.sh" "${args[@]}" >> "$LOG"
  docker image ls -q "${args[3]}*"
}
test_deploy
results=("$?")
test_docker
results+=("$?")
test_deploy_2
results+=("$?")
test_deploy_3
results+=("$?")
test_docker_3
results+=("$?")
[ "$chkSet" = 'x' ] && unset DEBIAN_FRONTEND || DEBIAN_FRONTEND=${chkSet:2}
check_log "$LOG"

for r in "${!results[@]}"; do
    if [ "${results[$r]}" -gt 0 ]; then
      cat "$LOG"
      log_failure_msg "test n°$r FAIL"
      exit "${results[$r]}"
    else
      log_success_msg "test n°$r PASS"
    fi
done
