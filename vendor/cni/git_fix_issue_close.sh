#!/usr/bin/env bash
if [ -z "$1" ]; then
  echo "Missing argument issue number!"
else
  printf "Close fixture %s ...\n" "$1"
  sleep 1
  if [ "$(git checkout main > /dev/null)" ]; then
    echo "Switched to main"
  fi
  printf "Delete branch %s\n" "fix/issue-$1"
  sleep 1
  if [ "$(git branch -D fix/issue-"$1" > /dev/null)" ]; then
    echo "Branch was deleted !"
  fi
  printf "Pulling recent changes...\n"
  sleep 1
  if [ "$(git pull > /dev/null)" ]; then
    echo "Done."
  fi
fi
