#!/usr/bin/env bash
dir="."
usage=( "usage $0" "[-d <project_root>]" )

if [ "$#" -gt 0 ]; then
  while true; do
    case $1 in
      -d)
        dir="$2"
        break;;
      *)
        printf "%s\n" "${usage[@]}"
        exit 0;;
    esac
  done
fi

ARC=(armhf x86_64 aarch64)

# Loop through the array and echo each value
for arch in "${ARC[@]}"; do
  printf "Updating templates, %s \n" "$arch"
  echo "0" | balena_deploy "$dir" "$arch" 1 0 0 2> /dev/null > /dev/null	
done

git add "$dir"/docker-compose.yml
git commit -m "Updated Templates"
