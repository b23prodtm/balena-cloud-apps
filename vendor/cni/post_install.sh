#!/usr/bin/env bash
chmod -R +w .
npm init --yes
npm link balena-cloud
cp node_modules/balena-cloud/test/build/*.env .
read -r -a BALENA_PROJECTS < <(find . -name "Dockerfile*" | awk -F"/Dockerfile" '{ print $1 }' | uniq | xargs)
printf "Found %s BALENA_PROJECTS(" "${#BALENA_PROJECTS}"
printf "%s " "${BALENA_PROJECTS[@]}"
printf " )\n"
sed -i.old -E -e "s#(BALENA_PROJECTS)=(.*))#\\1=\(${BALENA_PROJECTS[*]}\) \#\\2#" common.env
cat common.env
printf "Ready to <( balena_deploy . \n"
