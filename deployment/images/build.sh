#!/usr/bin/env bash
### Paste Here latest File Revisions
REV=https://raw.githubusercontent.com/b23prodtm/vagrant-shell-scripts/b23prodtm-patch/vendor/cni/docker_build.sh
if [ -f "$(dirname "${BASH_SOURCE[0]}")/docker_build.sh" ]; then
  ln -vsf "$(dirname "${BASH_SOURCE[0]}")/docker_build.sh" /usr/local/bin/docker_build
else
  curl -SL -o /usr/local/bin/docker_build $REV
fi
sudo curl -SL $REV -o /usr/local/bin/docker_build
sudo chmod 0755 /usr/local/bin/docker_build
docker_build "${BASH_SOURCE[0]}" "$@"
