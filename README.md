# balena-cloud-apps
[![balena-cloud-apps](https://circleci.com/gh/b23prodtm/balena-cloud-apps.svg?style=shield)](https://app.circleci.com/pipelines/github/b23prodtm/balena-cloud-apps)
 This is a free NodeJS script to package the containers native interface BalenaOS for the Raspberry Pi and similar platforms.
## The open source [Balena-CLI](https://github.com/balena-io/balena-cli) is required, first install Balena-CLI on the host that's sending command lines.

Within an open source application, like  [balena-sound](https://github.com/balenalabs/balena-sound), [wifi-repeater](https://github.com/balenalabs-incubator/wifi-repeater), install this module:
```Shell
#!/usr/bin/env bash
cd application
yarn add balena-cloud-apps
npm link balena-cloud-apps
```

### Template fields 
(`BALENA_PROJECTS_FLAGS`) take variable names `%%templates_var%%` that are replaced by ther value in `<arch>.env`
Make changes to the Dockerfile.template files.

Initialize .env and package.json:

    post_install

> It will scan for any Docker files in the sub-folders and reset package.json, `common.env` and `<arch>.env` files.

### Configure template environment

Complete common definitions (leading and trailing ( spaces ) when defining arrays !!):
```common.env
BALENA_PROJECTS=( MY/PATH MY/RELATIVE/PATH )
BALENA_PROJECTS_FLAGS=( BALENA_MACHINE_NAME MY_VARIABLE )
```
Define architectures: 
An ARM computer units like Raspberry PI use `armhf.env` (or `aarch64.env` if it's deployed on a 64 bits platform), desktop units are often `x86_64.env`:
```x86_64.env
BALENA_ARCH=x86_64
BALENA_MACHINE_NAME=intel-nuc
IMG_TAG=latest
PRIMARY_HUB=docker-hub-balenalib-repo\\/container-servìce-image
```

# Test
Run unit tests on local host or CI

    yarn test

### Build dependencies
Docker Image dependencies are required to validate test units. Theses dependencies include build images needed by Docker based environments:
  - Docker and Balena Cloud platform (DockerHub, etc.)
  - CircleCI, TravisCI, etc.

First login to Docker or Balena, if you already have an account or [create one](https://hub.docker.com).

    docker login or balena login
    
The folder `deployments` contains Dockerfile templates that maybe pulled from Docker.

    balena_deploy test/build/

Finally select the corresponding architecture `ARM32, ARM64 bits or X86-64 (choose 1, 2 or 3)` and choose to `build dependencies`

It takes a few minutes for the docker machine to pull, update local images and to push them to the repository. They take the name `$DOCKER_USER/<image>` and get a public URL at `https://hub.docker.com/r/$DOCKER_USER/<image>`

## Deploy
Deploy to Docker or BalenaOS, easy, choose targets:

    balena_deploy .

You can build locally:

    docker_build . . <DOCKER_USER>/<IMAGE>:<TAG> <BALENA_ARCH>

In BASH scripts, use arguments:

    balena_deploy . x86_64 --nobuild --exit
    balena_deploy . armhf --balena


# Updating and managing npm version
Follow general guidelines in the documention about [versioning this project on npm](https://docs.npmjs.com/packages-and-modules/updating-and-managing-your-published-packages)

Basically, commit all your changes and bump to the next version, then push tags:

    # version string without the leading "v."
    npm version "0.0.1"
    git push --tags

The continuous integration system will detect the new version tag and deploy to NPMJS if all build steps succeed.

# CLI functions
All endpoints in command line shell scripts are registered in package.json. When balena-cloud-apps installs itself, the functions become available to environment PATH.
