#!/bin/bash

set -eu
TOPDIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

# Define the directory containing the secrets
SECRETS_DIR="${TOPDIR}/.balena/secrets"

# Array of secret files
mapfile -t secrets < <(ls "$SECRETS_DIR")

# Function to display current secrets
display_secrets() {
    echo "Current secrets:"
    for secret in "${secrets[@]}"; do
        echo "$secret: $(cat "$SECRETS_DIR/$secret" | cut -c 1-3)****"
    done
    echo
}

# Function to edit a specific secret file
edit_secret() {
    local secret_file="$1"
    echo "Editing $secret_file..."
    nano "$secret_file"  # You can replace 'nano' with your preferred text editor
}

# prompt user input
prompt_user_input() {
  # Prompt user to edit each secret file
  for secret in "${secrets[@]}"; do
      read -r -p "Do you want to edit the secret file for $secret? (y/n): " choice
      if [[ "$choice" == "y" || "$choice" == "Y" ]]; then
          edit_secret "$SECRETS_DIR/$secret"
          echo "$secret file updated."
      else
          echo "No changes made to $secret file."
      fi
  done
}

# Read secrets from SECRETS_DIR and write to the output the cli
#   options: 
#      -x echo secrets (3 letters***)
#      -e export secrets
#      <directory> change directory for reading secrets
read_secrets() {
  exp=""; sep=""
  while [ "$#" -gt 0 ]; do case "$1" in
    -[rR]*);;
    -[xX]*)
      exp="echo "
      sep=" &&"
      ;;
    -[eE]*)
      exp="export "
      sep=" &&"
      ;;
    *)
      printf "%s\n" "$0 Wrong Argument: $1"
      exit 1
      ;;
  esac; shift; done
  printf "%s" "RUN " 
  for secret in "${secrets[@]}"; do
    printf "%s \\\\\n" "--mount=type=secret,id=${secret#*secret_}"
  done
  printf "%s\n" "### BALENA BEGIN"
  printf "%s \\\\\n" "# RUN"   
  printf "%s\n" "### BALENA END"
  for secret in "${secrets[@]}"; do
    secret=${secret#*secret_}
    printf "%s%s=\$(cat %s)%s \\\\\n" "$exp" "${secret^^}" "/run/secrets/${secret}" "$sep"
  done
}

# Usage
usage() {
  printf "\%sn" "Usage: ${BASH_SOURCE[0]} [--mount|-m] [-r] [-w] [-x] [-d <folder>]"
}
# Check if the secrets directory exists
if [[ ! -d "$SECRETS_DIR" ]]; then
    echo "Secrets directory not found!"
    exit 1
fi

# prints secrets VARIABLES="$(cat /run/secret/***)"
mount=""
while [ "$#" -gt 0 ]; do case "$1" in
  -[xXeERr]*)
    read_secrets $*
    exit 0
    ;;
  -[wW]*)
    prompt_user_input
    ;;
  -[dD]*)
    SECRETS_DIR=$2
    shift
    ;;
  -[hH]*|--help*)
    usage
    exit 0
    ;;
  *)
    printf "%s\n" "Wrong argument: $1"
    usage
    exit 1
    ;;
esac; shift; done

# Display current secrets
display_secrets