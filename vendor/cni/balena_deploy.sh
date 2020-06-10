#!/usr/bin/env bash
set -u
[ "$#" -eq 0 ] && echo "usage $0 <project_root|\${BASH_SOURCE[0]}> <args>" && exit 0
[ -f "$1" ] && set -- "$(cd "$(dirname "$1")" && pwd)" "${@:2}"
project_root="$(cd "$1" && pwd)"; shift
banner=("" "[$0] BASH ${BASH_SOURCE[0]}" "$project_root" ""); printf "%s\n" "${banner[@]}"

# shellcheck source=init_functions.sh
. "$(command -v init_functions)" "${BASH_SOURCE[0]}"
[ "${DEBUG:-0}" != 0 ] && log_daemon_msg "passed args $*"

LOG=${LOG:-"$(new_log "." "$(basename "$project_root").log")"}
usage=("" \
"Usage ${BASH_SOURCE[0]}  [1|2|3|<arch>] [1,--local|2,--balena|3,--nobuild|4,--docker|5,--push] [0,--exit]" \
"                         1|arm32*|armv7l|armhf   ARMv7 OS" \
"                         2|arm64*|aarch64        ARMv8 OS" \
"                         3|amd64|x86_64          All X86 64 bits OS (Mac or PC)" \
"" \
"                         1,--local               Pushing to local network Balena machine" \
"                                                 and continuous build, issue command" \
"                                                 balena login to authenticate." \
"                         2,--balena              Pushing to Balena Cloud Servers and" \
"                                                 continuous build, issue command" \
"                                                 balena login to authenticate." \
"                         3,--nobuild             Don't run any build process, format only" \
"                                                 the architecture templates. (prompt)" \
"                         4,--docker              Build a the docker images on localhost" \
"                                                 machine. Docker CE must be installed." \
"                                                 Balena Library enables ARM Cross-Build." \
"                         5,--push                Push latest changes to Github." \
"                         0,--exit                Quit script (non interactive)." \
"" \
"Set BALENA_PROJECTS=(./dir_one ./dir_two ./dir_three) in common.env file." \
"Set BALENA_PROJECTS_FLAGS=(VAR_ONE VAR_TWO)" \
"")
arch=${1:-''}
saved=("${@:2}")
while true; do
  case $arch in
    1|arm32*|armv7l|armhf)
      arch="armhf"
      break;;
    2|arm64*|aarch64)
      arch="aarch64"
      break;;
    3|amd64|x86_64|i386)
      arch="x86_64"
      break;;
    *)
      printf "%s\n" "${usage[@]}"
      if [ "${DEBIAN_FRONTEND:-}" = 'noninteractive' ]; then
        arch=$(grep "DKR_ARCH" < "$project_root/.env"| cut -d= -f2)
      else
        read -rp "Set docker machine architecture ARM32, ARM64 bits or X86-64 (choose 1, 2 or 3) ? " arch
      fi
      ;;
  esac
  log_progress_msg "Architecture $arch was selected"
done
DKR_ARCH=${arch}
[ ! -f "$project_root/${DKR_ARCH}.env" ] && log_failure_msg "Missing arch file ${DKR_ARCH}.env" && exit 1
ln -vsf "$project_root/${DKR_ARCH}.env" "$project_root/.env" >> "$LOG"
# shellcheck disable=SC1090
. "$project_root/.env" && . "$project_root/common.env"
### ADD HERE ANY ENVIRONMENT VARIABLE TO DEPLOYMENTS
flags=()
if [ -n "$BALENA_PROJECTS_FLAGS" ]; then
  log_daemon_msg "Found ${#BALENA_PROJECTS_FLAGS[@]} flags set BALENA_PROJECTS_FLAGS" >> "$LOG"
  flags=("${BALENA_PROJECTS_FLAGS[@]}")
fi
function setArch() {
  while [ "$#" -gt 1 ]; do
    cat /dev/null > "$1.sed"
    sed=("s/%%BALENA_MACHINE_NAME%%/${BALENA_MACHINE_NAME}/g" \
    "s/(Dockerfile\.)[^\.]*/\\1${DKR_ARCH}/g" \
    "s/%%BALENA_ARCH%%/${DKR_ARCH}/g" \
    "s/(DKR_ARCH[=:-]+)[^\$ }]+/\\1${DKR_ARCH}/g" )
    printf "%s\n" "${sed[@]}" >> "$1.sed"
    for flag in "${flags[@]}"; do
      flag_val=$(eval "echo \${$flag}")
      echo "s/(${flag}[=:-]+)[^\$ }]+/\\1${flag_val}/g" >> "$1.sed"
    done
    sed -E -f "$1.sed" "$1" > "$2"
  shift 2; done
}
### ADD HERE ANY SUBMODULE DOCKER IMAGE / SERVICE TO DEPLOYMENTS
projects=(".")
if [ "${#BALENA_PROJECTS[@]}" -gt 0 ]; then
  log_daemon_msg "Found ${#BALENA_PROJECTS[@]} projects set BALENA_PROJECTS"  >> "$LOG"
  projects=("${BALENA_PROJECTS[@]}")
fi
### ADD HERE ANY DEPLOYMENT DEPENDENCIES COMMAND LINES
DEPLOY_DEPS=(\
"${PRIMARY_HUB:-'PRIMARY_HUB'} ${DKR_ARCH}" \
"${SECONDARY_HUB:-'SECONDARY_HUB'} ${DKR_ARCH}" \
)
function deploy_deps() {
  for d in "${DEPLOY_DEPS[@]}"; do
    if printf "%s" "$d" | grep -q "_HUB"; then
      :
    else
      docker_build "${project_root}" deployment/images/primary "$d" >> "$LOG" 2>&1 || true;
    fi
  done
}
### ADD HERE ### A MARKER STARTS... ### A MARKER ENDS
function setMARKERS(){
  # shellcheck disable=SC2089
  export MARK_BEGIN="RUN [^a-z]*cross-build-start[^a-z]*"
  # shellcheck disable=SC2089
  export MARK_END="RUN [^a-z]*cross-build-end[^a-z]*"
  export ARM_BEGIN="### ARM BEGIN"
  export ARM_END="### ARM END"
}
### ------------------------------
# Disable blocks to Cross-Build ARM on x86_64 (-c) and ARM only (-a)
# Default: -a -c (Disable Cross-Build)
function comment() {
  [ "$#" -eq 0 ] && log_failure_msg "missing file input" && exit 0
  file=$1
  [ "$#" -eq 1 ] && comment "$file" -a -c && return
  cat /dev/null > "$file.sed"
  while [ "$#" -gt 1 ]; do case $2 in
    -a*|--arm)
      echo "/${ARM_BEGIN}/,/${ARM_END}/s/^[# ]*(.*)/# \\1/g" >> "$file.sed"
      ;;
    -c*|--cross)
      sed=("s/[# ]*(${MARK_BEGIN})/# \\1/g" \
      "s/[# ]*(${MARK_END})/# \\1/g")
      printf "%s\n" "${sed[@]}" >> "$file.sed"
      ;;
  esac; shift; done;
  sed -i.x.old -E -f "$file.sed" "$file" >> "$LOG"
}
### ------------------------------
# Enable blocks to Cross-Build ARM on x86_64 (-c) and ARM only (-a)
# Default: -a -c (Enable Cross-Build ARM only on x86_64)
function uncomment() {
  [ "$#" -eq 0 ] && log_failure_msg "missing file input" && exit 0
  file=$1
  [ "$#" -eq 1 ] && uncomment "$file" -a -c && return
  cat /dev/null > "$file.sed"
  while [ "$#" -gt 1 ]; do case $2 in
    -a*|--arm)
      echo "/${ARM_BEGIN}/,/${ARM_END}/s/^(# )+(.*)/\\2/g" >> "$file.sed"
      ;;
    -c*|--cross)
      sed=("s/(# )+(${MARK_BEGIN})/\\2/g" \
      "s/(# )+(${MARK_END})/\\2/g")
      printf "%s\n" "${sed[@]}" >> "$file.sed"
      ;;
  esac; shift; done;
  sed -i.x.old -E -f "$file.sed" "$file"
}
setMARKERS
function cross_build_start() {
  crossbuild=1
  if [ "$#" -gt 0 ]; then case $1 in
      -[d]*)
        log_progress_msg "$MARK_END" >> "$LOG"
        crossbuild=0
        ;;
      *)
        log_failure_msg "Wrong usage: ${FUNCNAME[0]} $1" >&2
        exit 3;;
    esac;
  else
    log_progress_msg "$MARK_BEGIN" >> "$LOG"
  fi
  for d in "${projects[@]}"; do
    [ "$(cd "$d" && pwd)" != "$(pwd)" ] && ln -vsf "$project_root/${DKR_ARCH}.env" "$project_root/$d/.env" >> "$LOG"
    [ "$(cd "$d" && pwd)" != "$(pwd)" ] && ln -vsf "$project_root/common.env" "$project_root/$d/common.env" >> "$LOG"
    setArch "$project_root/$d/Dockerfile.template" "$project_root/$d/Dockerfile.${DKR_ARCH}"
    if [ -z $crossbuild ]; then
      if [ "$arch" != "x86_64" ]; then
        comment "$project_root/$d/Dockerfile.${DKR_ARCH}" -c
        uncomment "$project_root/$d/Dockerfile.${DKR_ARCH}" -a
        uncomment "$project_root/docker-compose.${DKR_ARCH}" -a
      else
        comment "$project_root/$d/Dockerfile.${DKR_ARCH}"
        comment "$project_root/docker-compose.${DKR_ARCH}"
      fi
    else
      if [ "$arch" != "x86_64" ]; then
        uncomment "$project_root/docker-compose.${DKR_ARCH}"
        uncomment "$project_root/$d/Dockerfile.${DKR_ARCH}"
      else
        comment "$project_root/docker-compose.${DKR_ARCH}"
        comment "$project_root/$d/Dockerfile.${DKR_ARCH}"
      fi
    fi
    [ "$d" != '.' ] && cd "$project_root/$d" && git_commit "${DKR_ARCH} pushed ${d}"
    cd "$project_root" || return
  done
  git_commit "${DKR_ARCH} pushed"
}
function git_commit() {
  if ! git config user.email > /dev/null; then
      githubuserid=${MAINTAINER:-'add-MAINTAINER-email-to-environment@github.com'}
      git config --local user.email "$githubuserid"
      git config --local user.name "$(echo "$githubuserid "| cut -d@ -f1)"
    fi
    git commit -a -m "${1:-"Add commit message"}" >> "$LOG" 2>&1 || true
}
function native_compose_file_set() {
  if [ "$#" -gt 0 ]; then
    case $1 in
      -[d]*)
        cp -vf "$project_root/docker-compose.yml.old" "$project_root/docker-compose.yml"
        ;;
      *)
        cp -vf "$project_root/docker-compose.yml" "$project_root/docker-compose.yml.old"
        setArch "$project_root/docker-compose.yml" "$project_root/docker-compose.${DKR_ARCH}"
        cp -vf "$project_root/docker-compose.$1" "$project_root/docker-compose.yml"
        ;;
    esac
  else
    native_compose_file_set "${DKR_ARCH}"
  fi
}
function balena_push() {
  apps=("$#")
  i=0
  [ "$#" -gt 0 ] && for a in "$@"; do apps+=("$a"); done
  for a in "${!apps[@]}"; do
    [ "$a" = 0 ] && continue
    printf "[%s]: %s " "$a" "${apps[$a]}"
  done
  log_daemon_msg "Found ${apps[0]} apps."
  read -rp "Where do you want to push [1-${apps[0]}] ? " i
  log_daemon_msg "${apps[$i]} was selected"
  bash -c "balena push ${apps[$i]}"
}
set -- "${saved[@]}"
while true; do
  # SSH-ADD to Agent (PID)
  eval "$(ssh-agent)"
  ssh-add ~/.ssh/*id_rsa >> "$LOG" 2>&1 || true
  next=${target:-${1:-}}
  # store target
  log_daemon_msg "$0 $arch $next" >> "$LOG"
  unset target
  case $next in
    1|--local)
      slogger -st docker "Allow cross-build"
      cross_build_start
      deploy_deps
      native_compose_file_set
      if command -v balena; then
        # shellcheck disable=SC2046
        balena_push $(balena scan | awk '/address:/{print $2}') || true
      else
        log_failure_msg "Please install Balena Cloud to run this script."
      fi
      native_compose_file_set -d
      ;;
    4|--docker)
      slogger -st docker "Allow cross-build"
      cross_build_start
      deploy_deps
      file=docker-compose.${DKR_ARCH}
      if [ -f "$file" ]; then
        bash -c "docker-compose -f $file --host ${DOCKER_HOST:-''} build"  >> "$LOG"
      else
        bash -c "docker build -f Dockerfile.${DKR_ARCH} . && docker ps"  >> "$LOG"
      fi
      ;;
    2|--balena)
      slogger -st docker "Deny cross-build"
      cross_build_start -d
      deploy_deps
      native_compose_file_set
      if command -v balena > /dev/null; then
        # shellcheck disable=SC2046
        balena_push $(balena apps | awk '{if (NR>1) print $2}') || true
      else
        log_warning_msg "Balena Cloud not installed. Using git push."
        git push -uf balena || true
      fi
      native_compose_file_set -d
      ;;
    3|--nobuild)
      slogger -st docker "Allow cross-build" >> "$LOG"
      cross_build_start
      ;;
    5|--push)
      git push --recurse-submodules=on-demand
      ;;
    0|--exit)
      log_daemon_msg "deploy's exiting..." >> "$LOG"
      break;;
    *)
      if [ "${DEBIAN_FRONTEND:-}" = 'noninteractive' ]; then
        # try last target
        target=$(grep "$0 $arch" < "$LOG" | tail -1 | cut -d' ' -f3)
      else
        read -rp "What target docker's going to use (0:exit, 1:local-balena, 2:balena, 3:nobuild, 4:docker, 5:push) ?" target
      fi
      ;;
  esac; shift
done
check_log "$LOG"
