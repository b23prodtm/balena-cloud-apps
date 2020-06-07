#!/usr/bin/env bash
[ "$#" -eq 0 ] && echo "usage $0 \${BASH_SOURCE[0]} <args>" && exit 0
banner=("" "[$0] BASH ${BASH_SOURCE[0]}" ""); printf "%s\n" "${banner[@]}"

if [ -f /lib/lsb/init-functions ]; then
  # lsb-base package (not available in alpine linux)
  # shellcheck disable=SC1091
  . /lib/lsb/init-functions
else
  function log_daemon_msg() {
    printf "* %s\n" "$@"
  }
  function log_progress_msg() {
    printf "+ %s\n" "$@"
  }
  function log_warning_msg() {
    printf "! %s\n" "$@"
  }
  function log_failure_msg() {
    printf "[!] %s\n" "$@"
  }
  function log_success_msg() {
    printf "[*] %s\n" "$@"
  }
  function log_end_msg() {
    case "$1" in
      0)
        printf "[>]                            %s\n" "[OK]"
        ;;
      [1-9]+)
        printf "[x]                          %s\n" "[fail]"
        ;;
      *) printf "%s\n" "$@"
        ;;
    esac
  }
fi
# Dsiplay message with time and thread if logger debug Kit available
function slogger() {
  [ -f /dev/log ] && logger "$@" && return
  [ "$#" -gt 1 ] && shift
  log_daemon_msg "$@"
}
function new_log() {
  LOG="$(cd "${1:-"/tmp/log/$(basename "$0" .sh)"}" && pwd)/${2:-"$(date +%Y-%m-%d_%H:%M).log"}" && mkdir -p "$(dirname "$LOG")"
  touch "$LOG" && chmod 4766 "$LOG" # sticky bit
  printf "%s\n" "$LOG"
}
function check_log() {
  if [ "${DEBUG:-0}" = 0 ] && [[ $(wc -l "$LOG" | awk '{ print $1 }') -gt 0 ]]; then
    log_daemon_msg "Find the log file at $LOG and read more detailed information."
  fi
}
