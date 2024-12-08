#!/usr/bin/env bash
if [ -z "$1" ]; then
  echo "Missing argument issue number!"
else
  printf "New issue fixture %s ...\n" "$1"
  sleep 1
  if [ "$(git branch fix/issue-"$1" > /dev/null)" ]; then
     echo "Branch created"
  fi
  printf "Jump on branch %s...\n" "fix/issue-$1"
  sleep 1
  if [ "$(git checkout fix/issue-"$1" > /dev/null)" ]; then
     echo "Now fixing, add your files..."
  fi
fi
