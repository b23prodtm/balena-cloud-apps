#!/usr/bin/env bash
vendord="$(cd "$(dirname "${BASH_SOURCE[0]}")/../vendor/cni" && pwd)"
chkSet="x${DEBIAN_FRONTEND:-}"
DEBIAN_FRONTEND='noninteractive'
testd="$(cd "$(dirname "${BASH_SOURCE[0]}")/build" && pwd)"
# shellcheck source=../vendor/cni/init_functions.sh
. "$vendord/init_functions.sh" "$testd"
LOG=$(new_log "/tmp")
[ "$DEBUG" ] && LOG=$(new_log "/dev" "/stderr")
function test_deploy() {
  # shellcheck source=../vendor/cni/balena_deploy.sh
  . "$vendord/balena_deploy.sh" "$testd" "$@" >> "$LOG"
}
test_deploy "$(arch)" --nobuild --exit
results=("$?")
function test_docker() {
  # shellcheck source=../vendor/cni/docker_build.sh
  . "$vendord/docker_build.sh" "$testd/submodule" "$@" >> "$LOG"
}
test_docker -m . "betothreeprod/intel-nuc-dind" "$DKR_ARCH"
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
