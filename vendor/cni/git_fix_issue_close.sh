#!/usr/bin/env bash
if [ -z "$1" ]; then
  echo "Missing argument issue number!"
else
  # shellcheck source=init_functions.sh
  . "$(command -v init_functions)" "${BASH_SOURCE[0]:-0}"
  [ "${DEBUG:-0}" != 0 ] && log_daemon_msg "passed args $*"

  LOG=${LOG:-"$(new_log "." "$(basename "$project_root").log")"}
  
  printf "Close fixture %s ...\n" "$1"
  sleep 1
  if [ "$(git checkout "$2" >> "$LOG")" ]; then
    printf "Switched to %s\n" "$2"
  fi
  printf "Delete branch %s\n" "fix/issue-$1"
  sleep 1
  if [ "$(git branch -D fix/issue-"$1" >> "$LOG")" ]; then
    printf "Branch was deleted !\n"
  fi
  printf "Pulling recent changes...\n"
  sleep 1
  if [ "$(git pull >> "$LOG")" ]; then
    printf "Done.\n"
  fi
fi
