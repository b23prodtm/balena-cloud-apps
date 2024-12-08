#!/usr/bin/env bash
if [ -z "$1" ]; then
  echo "Missing argument issue number!"
else
  printf "Close fixture %s ...\n" "$1"
  sleep 1
  if [ "$(git checkout "$2" >> "$LOG")" ]; then
    echo "Switched to $2"
  fi
  printf "Delete branch %s\n" "fix/issue-$1"
  sleep 1
  if [ "$(git branch -D fix/issue-"$1" >> "$LOG")" ]; then
    echo "Branch was deleted !"
  fi
  printf "Pulling recent changes...\n"
  sleep 1
  if [ "$(git pull >> "$LOG")" ]; then
    echo "Done."
  fi
fi
