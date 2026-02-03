#!/usr/bin/env bash
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
vendord="$script_dir/../vendor/cni"
testd="$script_dir/build"
chkSet="x${DEBIAN_FRONTEND:-}"
DEBIAN_FRONTEND='noninteractive'
# shellcheck disable=SC1090
. "$vendord/init_functions.sh" "$testd"
function test_deploy() {
  # x86_64
  args=( --no-ssh "3" --nobuild --exit )
  # shellcheck disable=SC1090
  . "$vendord/balena_deploy.sh" "$testd" "${args[@]}" >> "$LOG"
  grep -q "intel-nuc" < "$testd/submodule/Dockerfile.x86_64"
}
function test_deploy_2() {
  # aarch64
  args=( "2" --nobuild --exit )
  # shellcheck disable=SC1090
  . "$vendord/balena_deploy.sh" "$testd" "${args[@]}" >> "$LOG"
  grep -q "generic-aarch64" < "$testd/submodule/Dockerfile.aarch64"
}
function test_deploy_3() {
  # armhf
  args=( "1" --nobuild --exit )
  # shellcheck disable=SC1090
  . "$vendord/balena_deploy.sh" "$testd" "${args[@]}" >> "$LOG"
  grep -q "raspberrypi3" < "$testd/submodule/Dockerfile.armhf"
}
function test_docker_3() {
  args=( "${testd}/submodule" -m . "betothreeprod/raspberrypi3" "$BALENA_ARCH" )
  # shellcheck disable=SC1090
  . "$vendord/docker_build.sh" "${args[@]}" >> "$LOG"
  docker image ls -q "${args[3]}*"
}
function test_docker() {
  args=( "${testd}/deployment/images/dind-php7" -m . "betothreeprod/dind-php7" "$BALENA_ARCH" )
  # shellcheck disable=SC1090
  . "$vendord/docker_build.sh" "${args[@]}" >> "$LOG"
  docker image ls -q "${args[3]}*"
}
function test_git_fix() {
  args=( "https://github.com/b23prodtm/balena-cloud-apps.git" "balena-cloud-apps" "1" )
  git clone "${args[0]}" && cd "${args[1]}" || return
  # shellcheck disable=SC1090
  . "$vendord/git_fix_issue.sh" "${args[2]}" >> "$LOG"
}
function test_git_fix_close() {
  test_git_fix
  args=( "1" "master" )
  # shellcheck disable=SC1090
  . "$vendord/git_fix_issue_close.sh" "${args[@]}" >> "$LOG"
}
function test_update() {
  args=( "-d" "$testd" )
  # shellcheck disable=SC1090
  . "$vendord/update_templates.sh" "${args[@]}" >> "$LOG"
}
test_deploy
results=( "$?" )
test_docker
results+=( "$?" )
test_deploy_2
results+=( "$?" )
test_deploy_3
results+=( "$?" )
test_docker_3
results+=( "$?" )
test_git_fix
results+=( "$?" )
test_git_fix_close
results+=( "$?" )
test_update
results+=( "$?" )
[ "$chkSet" = 'x' ] && unset DEBIAN_FRONTEND || DEBIAN_FRONTEND=${chkSet:2}

for r in "${!results[@]}"; do
    (( n=r+1 ))
    rt="${results[$r]}"
    if [ "$(( rt&1 ))" -gt 0 ]; then
      log_failure_msg "test n°$n FAIL"
      exit "${results[$r]}"
    else
      log_success_msg "test n°$n PASS"
    fi
done
