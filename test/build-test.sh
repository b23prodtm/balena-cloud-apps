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
  args=("armhf" --nobuild --exit)
  # shellcheck disable=SC1090
  . "$vendord/balena_deploy.sh" "$testd" "${args[@]}" >> "$LOG"
  grep -q "raspberrypi3" < "$testd/docker-compose.armhf"
}
test_deploy
results=("$?")
function test_docker() {
  args=("${testd}/submodule" -m . "betothreeprod/raspberrypi3" "$DKR_ARCH")
  # shellcheck disable=SC1090
  . "$vendord/docker_build.sh" "${args[@]}" >> "$LOG"
  docker image rm "${args[3]}"
}
test_docker
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
