#!/usr/bin/env bash
ARC=(armhf x86_64 aarch64)

# Loop through the array and echo each value
for arch in "${ARC[@]}"; do
  printf "Updating templates, %s \n" "$arch"
  echo "0" | ./deploy.sh "$arch" 1 2> /dev/null > /dev/null	
done

git add docker-compose.yml
git commit -m "Updated Templates"
