#!/usr/bin/env bash
chmod -R +w .
npm init --yes
npm link balena-cloud
cp node_modules/balena-cloud/test/build/*.env .
read -r -a BALENA_PROJECTS < <(find . -name "Dockerfile*" | awk -F"Dockerfile" '{ print $1 }' | uniq | xargs)
sed -i.old -E -e "s/(BALENA_PROJECTS)=\((.*)\)/\\1=\(${BALENA_PROJECTS[*]}\) #\\2/" common.env
cat common.env "$(arch).env"
balena_deploy .
