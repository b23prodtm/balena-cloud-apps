#!/usr/bin/env bash

if [ "$#" -gt 0 ]; then
  dir="$1"
else
  dir="."
fi

ARC=(armhf x86_64 aarch64)

# Loop through the array and echo each value
for arch in "${ARC[@]}"; do
  printf "Updating templates, %s \n" "$arch"
  echo "0" | balena_deploy "$dir" "$arch" 1 0 0 2> /dev/null > /dev/null	
done

git add "$dir"/docker-compose.yml
git commit -m "Updated Templates"
