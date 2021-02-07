# balena-cloud
[![Balena-Cloud](https://circleci.com/gh/b23prodtm/balena-cloud.svg?style=shield)](https://app.circleci.com/pipelines/github/b23prodtm/balena-cloud)
 Shell scripts package to the containers native interface BalenaOS for the Raspberry Pi.
 Containers pushes to the official [Balena-CLI](https://github.com/balena-io/balena-cli) and also builds to the docker Hub registry.

## Usage

Within an open source application, like  [balena-sound](https://github.com/balenalabs/balena-sound), [wifi-repeater](https://github.com/balenalabs-incubator/wifi-repeater), install this module:
```Shell
#!/usr/bin/env bash
cd application
npm install balena-cloud
post_install
```

### Set Environment Variables
Make changes to the Dockerfile, `common.env` and `<arch>.env` files

Complete these common definitions:
```common.env
BALENA_PROJECTS=(MY/PATH MY/RELATIVE/PATH)
BALENA_PROJECTS_FLAGS=(BALENA_MACHINE_NAME MY_VARIABLE)
```
Define architectures: ARM computer units like Raspberry PI use `armhf.env` (or `aarch64.env` if set deployed on a 64 bits platform), desktop units are often `x86_64.env`:
```x86_64.env
DKR_ARCH=x86_64
BALENA_MACHINE_NAME=intel-nuc
IMG_TAG=latest
PRIMARY_HUB=docker-hub-balenalib-repo\\/container-servìce-image
```
Template fields (`BALENA_PROJECTS_FLAGS`) take variable names `%%templates_var%%` that are replaced by ther value in `<arch>.env`

## Test
Run unit tests on local host or CI

    cd test
    # DEBUG=1
    ./build-tests.sh

### Build dependencies
Docker Image dependencies are required to validate test units. Theses dependencies include build images needed by Docker based environments:
  - Docker and cloud platform (BalenaOS, etc.)
  - CircleCI, TravisCI, etc.
  - Kubernetes and similar (Openshift, Micro-k8s, etc.)

First login to Docker, if you already have an account or [create one](https://hub.docker.com).

    docker login
    
The folder `deployments` contains Dockerfile templates that maybe pulled from Docker.

    balena_deploy test/build/

Finally select the corresponding architecture `ARM32, ARM64 bits or X86-64 (choose 1, 2 or 3)` and choose to `build dependencies`

It takes a few minutes for the docker machine to pull, update local images and to push them to the repository. They take the name `$DOCKER_USER/<image>` and get a public URL at `https://hub.docker.com/r/$DOCKER_USER/<image>`

## Deploy
Deploy to Docker or BalenOS, easy, choose targets:

    balena_deploy .

You can build locally:

    docker_build .

In BASH scripts, use arguments:
```Console
balena_deploy . x86_64 --nobuild --exit
balena_deploy . armhf --balena
```
