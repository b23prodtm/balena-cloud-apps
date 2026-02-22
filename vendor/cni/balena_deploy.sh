#!/usr/bin/env bash
# shellcheck shell=bash

set -Eeuo pipefail

#######################################
# Global defaults & configuration
#######################################

SCRIPT_NAME=${0##*/}
DRY_RUN=0
USE_SSH=1
LOG=""
PROJECT_ROOT=""
ARCH=""
BALENA_ARCH=""
DEBIAN_FRONTEND=${DEBIAN_FRONTEND:-""}

#######################################
# Logging helpers (assumed from init_functions)
#######################################
# These are placeholders in case init_functions does not define them.
# If init_functions provides them, those will override these.

log_daemon_msg()   { printf '[INFO] %s\n' "$*"; }
log_progress_msg() { printf '[..] %s\n' "$*"; }
log_failure_msg()  { printf '[FAIL] %s\n' "$*"; }
log_warning_msg()  { printf '[WARN] %s\n' "$*"; }
slogger()          { printf '[LOG] %s\n' "$*"; }
check_log()        { :; }

#######################################
# Utility: run a command (honor DRY_RUN)
#######################################
run_cmd() {
  if [ "$DRY_RUN" -eq 1 ]; then
    printf '[DRY-RUN] %s\n' "$*"
  else
    # shellcheck disable=SC2086
    "$@"
  fi
}

#######################################
# Usage
#######################################
print_usage() {
  cat <<EOF
Usage: ${SCRIPT_NAME} <project_root|${BASH_SOURCE[0]}> [options] [target]

Options:
  --dry-run        Do not execute commands, only print them.
  --no-ssh         Do not start ssh-agent or add keys.
  -h, --help       Show this help and exit.

Targets:
  1, --local       Local Balena machine (balena push to scanned device).
  2, --balena      Balena Cloud (balena fleet push or git push balena).
  3, --nobuild     Only generate templates, no build.
  4, --docker      Docker or docker-compose build.
  5, --push        git push --recurse-submodules=on-demand.
  6, --build-deps  Build deployment images dependencies.
  0, --exit        Quit script.

Architecture:
  1, arm32*, armv7l, armhf   -> ARMv7 (armhf)
  2, arm64*, aarch64         -> ARMv8 (aarch64)
  3, amd64, x86_64, i386     -> x86_64

Environment:
  BALENA_PROJECTS        Array of project directories (e.g. ./dir_one ./dir_two).
  BALENA_PROJECTS_FLAGS  Array of variable names to substitute in templates.

EOF
}

#######################################
# Parse CLI arguments
#######################################
parse_args() {
  local positional=()

  while [ "$#" -gt 0 ]; do
    case $1 in
      --dry-run)
        DRY_RUN=1
        ;;
      --no-ssh)
        USE_SSH=0
        ;;
      -h|--help)
        print_usage
        exit 0
        ;;
      --)
        shift
        while [ "$#" -gt 0 ]; do
          positional+=("$1")
          shift
        done
        break
        ;;
      -*)
        log_failure_msg "Unknown option: $1"
        print_usage
        exit 1
        ;;
      *)
        positional+=("$1")
        ;;
    esac
    shift || true
  done

  if [ "${#positional[@]}" -eq 0 ]; then
    print_usage
    exit 1
  fi

  # First positional is project_root or a file inside it
  local first=${positional[0]}
  if [ -f "$first" ]; then
    PROJECT_ROOT=$(cd "$(dirname "$first")" && pwd)
  else
    PROJECT_ROOT=$(cd "$first" && pwd)
  fi

  # Remaining are passed as targets/extra args
  # shellcheck disable=SC2206
  set -- "${positional[@]:1}"
  echo "$PROJECT_ROOT"
  printf '%s\n' "$@"
}

#######################################
# Initialize environment & logging
#######################################
init_environment() {
  local project_root=$1
  shift
  local -a rest_args=("$@")

  PROJECT_ROOT=$project_root

  # Banner
  local banner=(
    ""
    "[$SCRIPT_NAME] BASH ${BASH_SOURCE[0]}"
    "$PROJECT_ROOT"
    ""
  )
  printf "%s\n" "${banner[@]}"

  # shellcheck source=init_functions.sh
  # init_functions is expected to define logging helpers and new_log
  . "$(command -v init_functions)" "${BASH_SOURCE[0]}"

  LOG=${LOG:-"$(new_log "." "$(basename "$PROJECT_ROOT").log")"}

  # Restore args for main loop
  # shellcheck disable=SC2124
  ARGS_REST="${rest_args[*]}"
}

#######################################
# Select architecture
#######################################
select_arch() {
  local arch_input=${1:-""}
  local usage=(
    ""
    "Usage ${BASH_SOURCE[0]}  [1|2|3|<arch>] [target]"
    "  1|arm32*|armv7l|armhf   ARMv7 OS"
    "  2|arm64*|aarch64        ARMv8 OS"
    "  3|amd64|x86_64|i386     All X86 64 bits OS (Mac or PC)"
    ""
  )

  ARCH=$arch_input

  while true; do
    case $ARCH in
      1|arm32*|armv7l|armhf)
        BALENA_ARCH="armhf"
        ;;
      2|arm64*|aarch64)
        BALENA_ARCH="aarch64"
        ;;
      3|amd64|x86_64|i386)
        BALENA_ARCH="x86_64"
        ;;
      *)
        printf "%s\n" "${usage[@]}"
        if [ "${DEBIAN_FRONTEND:-}" = "noninteractive" ]; then
          if [ -f "$PROJECT_ROOT/.env" ]; then
            BALENA_ARCH=$(grep "BALENA_ARCH" < "$PROJECT_ROOT/.env" | cut -d= -f2 || true)
          fi
        else
          read -rp "Set docker machine architecture (1:ARM32, 2:ARM64, 3:X86-64) ? " ARCH
          continue
        fi
        ;;
    esac
    log_progress_msg "Architecture ${BALENA_ARCH:-unknown} was selected"
    break
  done

  if [ -z "${BALENA_ARCH:-}" ]; then
    log_failure_msg "Unable to determine BALENA_ARCH"
    exit 1
  fi

  if [ ! -f "$PROJECT_ROOT/${BALENA_ARCH}.env" ]; then
    log_failure_msg "Missing arch file ${BALENA_ARCH}.env"
    exit 1
  fi

  run_cmd ln -vsf "$PROJECT_ROOT/${BALENA_ARCH}.env" "$PROJECT_ROOT/.env" >>"$LOG" 2>&1
  # shellcheck disable=SC1090
  . "$PROJECT_ROOT/.env"
  # shellcheck disable=SC1090
  . "$PROJECT_ROOT/common.env"
}

#######################################
# Collect flags from BALENA_PROJECTS_FLAGS
#######################################
get_flags_array() {
  # shellcheck disable=SC2178
  local -n _out=$1
  _out=()
  # shellcheck disable=SC2154
  if [ "${#BALENA_PROJETS_FLAGS[@]:-0}" -gt 0 ]; then
    log_daemon_msg "Found ${#BALENA_PROJECTS_FLAGS[@]} flags in BALENA_PROJECTS_FLAGS" >>"$LOG"
    # shellcheck disable=SC2154,SC2034
    _out=("${BALENA_PROJECTS_FLAGS[@]}")
  fi
}

#######################################
# Collect projects from BALENA_PROJECTS
#######################################
get_projects_array() {
  # shellcheck disable=SC2178
  local -n _out=$1
  _out=(".")
  # shellcheck disable=SC2154
  if [ "${#BALENA_PROJECTS[@]:-0}" -gt 0 ]; then
    log_daemon_msg "Found ${#BALENA_PROJECTS[@]} projects in BALENA_PROJECTS" >>"$LOG"
    # shellcheck disable=SC2154,SC2034
    _out=("${BALENA_PROJECTS[@]}")
  fi
}

#######################################
# Template substitution for arch & flags
#######################################
set_arch_in_files() {
  local -a flags=()
  get_flags_array flags

  while [ "$#" -gt 1 ]; do
    local src=$1
    local dst=$2
    shift 2

    : >"${src}.sed"

    local sed_rules=(
      "s/%%BALENA_MACHINE_NAME%%/${BALENA_MACHINE_NAME}/g"
      "s/(Dockerfile\.)[^\.]*/\\1${BALENA_ARCH}/g"
      "s/%%BALENA_ARCH%%/${BALENA_ARCH}/g"
      "s/(BALENA_ARCH[=:-]+)[^\$ }]+/\\1${BALENA_ARCH}/g"
    )

    printf "%s\n" "${sed_rules[@]}" >>"${src}.sed"

    local flag
    for flag in "${flags[@]}"; do
      # shellcheck disable=SC2086,SC2154
      local flag_val
      flag_val=$(eval "printf '%s' \"\${$flag}\"")
      local frules=(
        "s#(${flag}[=:-]+)[^\$ }]+#\\1${flag_val}#g"
        "s#%%${flag}%%#${flag_val}#g"
      )
      printf "%s\n" "${frules[@]}" >>"${src}.sed"
    done

    run_cmd sed -E -f "${src}.sed" "$src" >"$dst"
  done
}

#######################################
# Marker setup
#######################################
set_markers() {
  export MARK_BEGIN="RUN [^a-z]*cross-build-start[^a-z]*"
  export MARK_END="RUN [^a-z]*cross-build-end[^a-z]*"
  export BALENA_BEGIN="### BALENA BEGIN"
  export BALENA_END="### BALENA END"
  export BUILDKIT_BEGIN="### BUILDKIT BEGIN"
  export BUILDKIT_END="### BUILDKIT END"
}

#######################################
# Comment blocks (disable)
#######################################
comment_blocks() {
  if [ "$#" -eq 0 ]; then
    log_failure_msg "comment_blocks: missing file input"
    exit 1
  fi
  local file=$1
  if [ "$#" -eq 1 ]; then
    comment_blocks "$file" -b -c -k
    return
  fi

  : >"${file}.sed"
  while [ "$#" -gt 1 ]; do
    case $2 in
      -k|--buildkit)
        printf "%s\n" "/${BUILDKIT_BEGIN}/,/${BUILDKIT_END}/s/^[# ]*(.*)/# \\1/g" >>"${file}.sed"
        local sed_rules=(
          "s/[# ]*(${MOUNT_BEGIN})/# \\1/g"
          "s/[# ]*(${MOUNT_END})/# \\1/g"
        )
        printf "%s\n" "${sed_rules[@]}" >>"${file}.sed"
        ;;
      -b|--balena)
        printf "%s\n" "/${BALENA_BEGIN}/,/${BALENA_END}/s/^[# ]*(.*)/# \\1/g" >>"${file}.sed"
        ;;
      -c|--cross)
        local sed_rules=(
          "s/[# ]*(${MARK_BEGIN})/# \\1/g"
          "s/[# ]*(${MARK_END})/# \\1/g"
        )
        printf "%s\n" "${sed_rules[@]}" >>"${file}.sed"
        ;;
    esac
    shift
  done

  run_cmd sed -i.x.old -E -f "${file}.sed" "$file" >>"$LOG" 2>&1
}

#######################################
# Uncomment blocks (enable)
#######################################
uncomment_blocks() {
  if [ "$#" -eq 0 ]; then
    log_failure_msg "uncomment_blocks: missing file input"
    exit 1
  fi
  local file=$1
  if [ "$#" -eq 1 ]; then
    uncomment_blocks "$file" -b -c -k
    return
  fi

  : >"${file}.sed"
  while [ "$#" -gt 1 ]; do
    case $2 in
      -k|--buildkit)
        printf "%s\n" "/${BUILDKIT_BEGIN}/,/${BUILDKIT_END}/s/^(# )+(.*)/\\2/g" >>"${file}.sed"
        local sed_rules=(
          "s/(# )+(${MOUNT_BEGIN})/\\2/g"
          "s/(# )+(${MOUNT_END})/\\2/g"
        )
        printf "%s\n" "${sed_rules[@]}" >>"${file}.sed"
        ;;
      -b|--balena)
        printf "%s\n" "/${BALENA_BEGIN}/,/${BALENA_END}/s/^(# )+(.*)/\\2/g" >>"${file}.sed"
        ;;
      -c|--cross)
        local sed_rules=(
          "s/(# )+(${MARK_BEGIN})/\\2/g"
          "s/(# )+(${MARK_END})/\\2/g"
        )
        printf "%s\n" "${sed_rules[@]}" >>"${file}.sed"
        ;;
    esac
    shift
  done

  run_cmd sed -i.x.old -E -f "${file}.sed" "$file"
}

#######################################
# Cross-build start / end
#######################################
cross_build_start() {
  local crossbuild=1
  if [ "$#" -gt 0 ]; then
    case $1 in
      -d*)
        log_progress_msg "Disabled Cross-build" >>"$LOG"
        crossbuild=0
        ;;
      *)
        log_failure_msg "Wrong usage: cross_build_start $1"
        exit 3
        ;;
    esac
  else
    log_progress_msg "Enabled Cross-build" >>"$LOG"
  fi

  local -a projects=()
  get_projects_array projects

  local d
  for d in "${projects[@]}"; do

    if [ "$crossbuild" -eq 0 ]; then
      comment_blocks "$PROJECT_ROOT/$d/Dockerfile.${BALENA_ARCH}" -c -k
      comment_blocks "$PROJECT_ROOT/docker-compose.${BALENA_ARCH}" -c -k
      uncomment_blocks "$PROJECT_ROOT/$d/Dockerfile.${BALENA_ARCH}" -b
      uncomment_blocks "$PROJECT_ROOT/docker-compose.${BALENA_ARCH}" -b
    else
      uncomment_blocks "$PROJECT_ROOT/docker-compose.${BALENA_ARCH}" -c -k
      uncomment_blocks "$PROJECT_ROOT/$d/Dockerfile.${BALENA_ARCH}" -c -k
      comment_blocks "$PROJECT_ROOT/docker-compose.${BALENA_ARCH}" -b
      comment_blocks "$PROJECT_ROOT/$d/Dockerfile.${BALENA_ARCH}" -b
    fi

    if [ "$(cd "$PROJECT_ROOT/$d" && pwd)" != "$(pwd)" ]; then
      (
        cd "$PROJECT_ROOT/$d"
        git_commit "${BALENA_ARCH} pushed ${d}"
      )
    fi
  done

  git_commit "${BALENA_ARCH} pushed"
}

#######################################
# Git commit helper
#######################################
git_commit() {
  local msg=${1:-"Add commit message"}
  if ! git config user.email >/dev/null 2>&1; then
    local githubuserid=${MAINTAINER:-'add-MAINTAINER-email-to-environment@github.com'}
    git config --local user.email "$githubuserid"
    git config --local user.name "${githubuserid%@*}"
  fi
  run_cmd git commit -a -m "$msg" >>"$LOG" 2>&1 || true
}

#######################################
# Native docker-compose file selection
#######################################
native_compose_file_set() {
  local arch=${1:-""}
  if [ -z "$arch" ]; then
    native_compose_file_set "$BALENA_ARCH"
    return
  fi
  set_arch_in_files "$PROJECT_ROOT/docker-compose.template" "$PROJECT_ROOT/docker-compose.$arch"
  run_cmd cp -vf "$PROJECT_ROOT/docker-compose.$arch" "$PROJECT_ROOT/docker-compose.yml"

  run_cmd ln -vsf "$PROJECT_ROOT/${BALENA_ARCH}.env" "$PROJECT_ROOT/$d/.env" >>"$LOG" 2>&1
  if [ "$(cd "$PROJECT_ROOT/$d" && pwd)" != "$(pwd)" ]; then
    run_cmd ln -vsf "$PROJECT_ROOT/common.env" "$PROJECT_ROOT/$d/common.env" >>"$LOG" 2>&1
  fi

  set_arch_in_files "$PROJECT_ROOT/$d/Dockerfile.template" "$PROJECT_ROOT/$d/Dockerfile.${BALENA_ARCH}"
  set_arch_in_files "$PROJECT_ROOT/$d/build.template" "$PROJECT_ROOT/$d/build.${BALENA_ARCH}.sh"
}

#######################################
# Balena push selection
#######################################
balena_push_select() {
  local -a apps=()
  local i

  if [ "$#" -gt 0 ]; then
    apps=("$@")
  fi

  if [ "${#apps[@]}" -eq 0 ]; then
    log_warning_msg "No apps provided to balena_push_select"
    return 0
  fi

  printf "Available apps:\n"
  for i in "${!apps[@]}"; do
    printf "[%s]: %s\n" "$((i+1))" "${apps[$i]}"
  done
  log_daemon_msg "Found ${#apps[@]} apps."

  local choice
  read -rp "Where do you want to push [1-${#apps[@]}] ? " choice
  if ! [[ "$choice" =~ ^[0-9]+$ ]] || [ "$choice" -lt 1 ] || [ "$choice" -gt "${#apps[@]}" ]; then
    log_warning_msg "Invalid selection."
    return 1
  fi

  local idx=$((choice-1))
  log_daemon_msg "${apps[$idx]} was selected"
  run_cmd balena push "${apps[$idx]}"
}

#######################################
# Deployment dependencies
#######################################
deploy_deps() {
  local -a dock=()
  mapfile -t dock < <(find "${PROJECT_ROOT}/deployment/images" -name "Dockerfile.${BALENA_ARCH}" 2>/dev/null || true)
  local d dir
  for d in "${dock[@]}"; do
    dir=$(dirname "$d")
    # shellcheck disable=SC2154
    run_cmd docker_build "$dir" "." "$DOCKER_USER/$(basename "$dir")" "${BALENA_ARCH}"
  done
}

#######################################
# SSH agent setup
#######################################
setup_ssh_agent() {
  if [ "$USE_SSH" -ne 1 ]; then
    return
  fi

  if ! pgrep -u "$USER" ssh-agent >/dev/null 2>&1; then
    eval "$(ssh-agent -s)" >/dev/null 2>&1
  fi

  # Add keys, ignore failures
  # shellcheck disable=SC2086
  for pkey in "$HOME"/.ssh/*id_rsa; do
    ssh-add "$pkey" >> "$LOG" 2>&1
  done
  for pkey in "$HOME"/.ssh/*id_ed25519; do
    ssh-add "$pkey" >>"$LOG" 2>&1
  done
}

#######################################
# Target selection (interactive / non-interactive)
#######################################
select_target() {
  local current_arch=$1
  local next=${2:-""}

  if [ -n "$next" ]; then
    printf '%s\n' "$next"
    return
  fi

  if [ "${DEBIAN_FRONTEND:-}" = "noninteractive" ]; then
    local last
    last=$(grep "$SCRIPT_NAME $current_arch" <"$LOG" | tail -n 1 | awk '{print $3}' || true)
    if [ -z "$last" ]; then
      log_warning_msg "No previous target found in non-interactive mode."
      printf '0\n'
    else
      printf '%s\n' "$last"
    fi
  else
    local target
    read -rp "Select target (0:exit, 1:local, 2:balena, 3:nobuild, 4:build, 5:push, 6:build deps) ? " target
    printf '%s\n' "$target"
  fi
}

#######################################
# Run a single target
#######################################
run_target() {
  local target=$1
  log_daemon_msg "$SCRIPT_NAME $ARCH $target" >>"$LOG"

  case $target in
    1|--local)
      slogger -st docker "Allow cross-build (buildx)"
      native_compose_file_set
      cross_build_start
      if command -v balena >/dev/null 2>&1; then
        # shellcheck disable=SC2046
        local devices
        devices=$(balena scan | awk '/address:/{print $2}')
        # shellcheck disable=SC2206
        local arr=($devices)
        balena_push_select "${arr[@]}" || true
      else
        log_failure_msg "Please install Balena Cloud to run this script."
      fi
      ;;
    4|--docker)
      slogger -st docker "Allow cross-build (buildx)"
      native_compose_file_set
      cross_build_start
      run_cmd ./build.${BALENA_ARCH}.sh
      ;;
    2|--balena)
      slogger -st docker "Disable cross-build (buildx off)"
      native_compose_file_set
      cross_build_start -d
      native_compose_file_set
      if command -v balena >/dev/null 2>&1; then
        local fleets
        fleets=$(balena fleet list | awk 'NR>1{print $2}')
        # shellcheck disable=SC2206
        local arr=($fleets)
        balena_push_select "${arr[@]}" || true
      else
        log_warning_msg "Balena Cloud not installed. Using git push."
        run_cmd git push -uf balena || true
      fi
      ;;
    3|--nobuild)
      slogger -st docker "Allow cross-build (buildx)"
      native_compose_file_set
      cross_build_start
      ;;
    5|--push)
      run_cmd git push --recurse-submodules=on-demand
      ;;
    6|--build-deps)
      slogger -st docker "Allow cross-build (buildx)"
      native_compose_file_set
      cross_build_start
      deploy_deps
      ;;
    0|--exit)
      log_daemon_msg "deploy's exiting..." >>"$LOG"
      return 0
      ;;
    *)
      log_warning_msg "Unknown target: $target"
      ;;
  esac

  return 0
}

#######################################
# Main loop
#######################################
main_loop() {
  local max_iter=20
  local iter=0

  # Restore remaining args
  # shellcheck disable=SC2206
  local args=($ARGS_REST)

  while true; do
    if [ "${DEBIAN_FRONTEND:-}" = "noninteractive" ]; then
      iter=$((iter + 1))
      if [ "$iter" -ge "$max_iter" ]; then
        log_failure_msg "Loop protection triggered: exiting after $iter iterations"
        break
      fi
    fi

    setup_ssh_agent

    local next_arg=""
    if [ "${#args[@]}" -gt 0 ]; then
      next_arg=${args[0]}
    fi

    local target
    target=$(select_target "$ARCH" "$next_arg")
    if [ -z "$target" ]; then
      log_warning_msg "Empty target, exiting."
      break
    fi

    if ! run_target "$target"; then
      break
    fi

    if [ "${#args[@]}" -gt 0 ]; then
      args=("${args[@]:1}")
    fi
  done

  check_log "$LOG"
}

#######################################
# main()
#######################################
main() {
  # Parse args → project_root + rest
  local project_root
  local rest
  project_root=$(parse_args "$@")
  # parse_args prints project_root then rest lines
  # First line is project_root, remaining lines are args
  rest=$(printf '%s\n' "$project_root" | tail -n +2 || true)
  project_root=$(printf '%s\n' "$project_root" | head -n 1)

  init_environment "$project_root" "$rest"

  # First of remaining args is arch (if any)
  # shellcheck disable=SC2206
  local rest_array=($ARGS_REST)
  if [ "${#rest_array[@]}" -gt 0 ]; then
    ARCH=${rest_array[0]}
    ARGS_REST="${rest_array[*]:1}"
  else
    ARCH=""
    ARGS_REST=""
  fi

  set_markers
  select_arch "$ARCH"
  main_loop
}

main "$@"
