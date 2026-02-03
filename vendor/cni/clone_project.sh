#!/usr/bin/env bash

[ "$#" = 0 ] && printf "Usage: %s <up-directory-path>\n" "$0" && exit 0
PACKAGE_DIR="$1"

[ ! -d "$PACKAGE_DIR/deployment" ] && "Directory not found $PACKAGE_DIR/deployment!\n" && exit 1
printf "Extracting the Balena Cloud project files in %s...\n" "$(pwd)/deployment"
sleep 1
cp -Rv "$PACKAGE_DIR"/deployment .

cp -v "$PACKAGE_DIR"/*.env .

printf "Templating Docker and Compositing files...\n"
sleep 1
cp -v docker-compose.yml docker-compose.template
cp -v Dockerfile Dockerfile.template

printf "Copying deploy.sh file...\n"
sleep 1
cp -v "$PACKAGE_DIR"/deploy.sh .

printf "Processing files done.\n"

printf "Installing dependency balena-cloud-apps must be installed in version 19 !!\n"
sleep 1
if [[ "$(command -v npm)" > /dev/null ]]; then
  npm link balena-cloud-apps && npm update
else
  printf "NPMJS node not found,\n"
  sleep 1
  nvm install 19
fi

printf "You're ready to use balena-cloud-apps on this project, run ./deploy.sh !\n"
