variable "DOCKER_ORG" {
  default = "betothreeprod"
}

variable "BAKE_TAG" {
  default = "latest"
}

variable "PLATFORM" {
  default = "linux/amd64"
}

variable "BALENA_ARCH" {
  default = "x86_64"
}

group "default" {
  targets = ["testsvc"]
}

target "testsvc" {
  context    = "."
  dockerfile = "Dockerfile.${BALENA_ARCH}"
  platforms  = ["${PLATFORM}"]
  tags       = [
    "${DOCKER_ORG}/testsvc:latest",
    "${DOCKER_ORG}/testsvc:${BAKE_TAG}"
  ]
  args = {
    PUID = "1000"
    PGID = "1000"
  }
  secret = [
    "id=master_password,src=.balena/secrets/secret_master_password"
  ]
}
