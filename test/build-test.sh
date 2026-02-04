#!/usr/bin/env bash
set -eu

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
vendord="$script_dir/../vendor/cni"
testd="$script_dir/build"

chkSet="x${DEBIAN_FRONTEND:-}"
[ "$chkSet" = 'x' ] && unset DEBIAN_FRONTEND || DEBIAN_FRONTEND=${chkSet:1}

# shellcheck disable=SC1090
. "$vendord/init_functions.sh"

function test_deploy() {
  # x86_64
  args=( "$testd" --no-ssh "3" --nobuild --exit )
  # shellcheck disable=SC1090
  bash -c "$vendord/balena_deploy.sh ${args[*]}" || true
  grep -q "intel-nuc" < "$testd/submodule/Dockerfile.x86_64"
}
function test_deploy_2() {
  # aarch64
  args=( "$testd" "arm64" --nobuild --exit )
  # shellcheck disable=SC1090
  bash -c "$vendord/balena_deploy.sh ${args[*]}" || true
  grep -q "generic-aarch64" < "$testd/submodule/Dockerfile.aarch64"
}
function test_deploy_3() {
  # armhf
  args=( "$testd" "1" --nobuild --exit )
  # shellcheck disable=SC1090
  bash -c "$vendord/balena_deploy.sh ${args[*]}" || true
  grep -q "raspberrypi3" < "$testd/submodule/Dockerfile.armhf"
}
function test_docker_3() {
  args=( "${testd}/submodule" "betothreeprod/raspberrypi3:latest" "armhf" )
  # shellcheck disable=SC1090
  bash -c "$vendord/docker_build.sh ${args[*]}" || true
  docker image ls -q "${args[2]}*"
}
function test_docker() {
  args=( "${testd}/deployment/images/dind-php7" "betothreeprod/dind-php7:latest" "armhf")
  # shellcheck disable=SC1090
  bash -c "$vendord/docker_build.sh ${args[*]}" || true
  docker image ls -q "${args[2]}*"
}
function test_git_fix() {
  args=( "https://github.com/b23prodtm/balena-cloud-apps.git" "balena-cloud-apps" "1" )
  cd "$testd" && \
  git clone "${args[0]}"
  cd "${args[1]}" && \
  # shellcheck disable=SC1090,SC2015 \
  bash -c "$vendord/git_fix_issue.sh ${args[2]}" || true
}
function test_git_fix_close() {
  test_git_fix
  args=( "1" "master" )
  # shellcheck disable=SC1090
  bash -c "$vendord/git_fix_issue_close.sh ${args[*]}" || true
  cd "$testd" && rm -Rf balena-cloud-apps
}
function test_update() {
  args=( "$testd" )
  # shellcheck disable=SC1090
  bash -c "$vendord/update_templates.sh ${args[*]}" || true
}

test_deploy
results=( "$?" )
test_deploy_2
results+=( "$?" )
test_deploy_3
results+=( "$?" )
test_docker
results+=( "$?" )
test_docker_3
results+=( "$?" )
test_git_fix
results+=( "$?" )
test_git_fix_close
results+=( "$?" )
test_update
results+=( "$?" )

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
