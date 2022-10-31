#!/usr/bin/env bash
if [ -z "$1" ]; then echo "Usage: $0 <v0.0.0>"; exit; fi
git tag -d "$1"
git tag "$1"
git push --tags || while true; do
  read -rp "git push --tags -f(orce) ? [y/n]" force
  case $force in
    Y|y) git push --tags -f; break;;
    N|n) break;;
    *);;
  esac
  sleep 1
done
