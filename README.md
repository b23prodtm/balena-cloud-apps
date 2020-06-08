# balena-cloud
[![Balena-Cloud](https://circleci.com/gh/b23prodtm/balena-cloud.svg?style=shield)](https://app.circleci.com/pipelines/github/b23prodtm/balena-cloud)
 Shell scripts package of containers native interface from Balena Cloud

## Usage
```Shell
#!/usr/bin/env bash
npm install balena-cloud
```
Copy test/build/ folder to the root folder of your project
Make changes to the Dockerfile, common.env and <arch>.env files

Deploy to balena

    balena_deploy .

You can build locally:

    docker_build .

In BASH scripts, use arguments:
```Console
balena_deploy . x86_64 --nobuild --exit
balena_deploy . armhf --balena
```
## Environment Variables
There are some data information to complete and describe the project.
It follows that:
```common.env
BALENA_PROJECTS=(MY/PATH MY/RELATIVE/PATH)
BALENA_PROJECTS_FLAGS=(BALENA_MACHINE_NAME MY_VARIABLE)
```
Architectures: ARM is armhf and aarch64, INTEL/AMD is x86_64
```x86_64.env
DKR_ARCH=x86_64
BALENA_MACHINE_NAME=intel-nuc
IMG_TAG=latest
PRIMARY_HUB=docker-hub-balenalib-repo\\/container-servìce-image
```
## Test
Run unit tests on local host or CI

    cd test
    # DEBUG=1
    ./build-tests.sh
