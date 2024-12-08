#!/usr/bin/env bash
if [ -z "$1" ]; then
  echo "Missing argument issue number!"
else
  printf "New issue fixture %s ...\n" "$1"
  sleep 1
  if [ "$(git branch fix/issue-"$1" >> "$LOG")" ]; then
     printf "Branch created\n"
  fi
  printf "Jump on branch %s...\n" "fix/issue-$1"
  sleep 1
  if [ "$(git checkout fix/issue-"$1" >> "$LOG")" ]; then
     printf "Now fixing, add your files...\n"
  fi
fi
