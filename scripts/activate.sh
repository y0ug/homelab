#!/usr/bin/env bash

_get_env() {
  ENV="${1:-prod}"
  if [ ! -d "$(pwd)/secrets/$ENV" ]; then
    echo "Environment $ENV not found, using prod" >&2
    ENV="prod"
  fi
  echo "$ENV"
}

_setup_secrets() {
  local ENV=$(_get_env "$ENV")
  DEST=$(pwd)/.dec
  SRC=$(pwd)/secrets/$ENV

  mkdir -p "$DEST"
  sops -d "$SRC/kube_config.sops.yaml" >"$DEST/kube_config.dec.yaml"
  sops -d "$SRC/scw.sops.yaml" >"$DEST/scw.dec.yaml"
  sops -d --output-type dotenv "$SRC/terraform.sops.yaml" >"$DEST/terraform.dec.env"

  export KUBECONFIG="$DEST/kube_config.dec.yaml"
  export SCW_CONFIG_PATH="$DEST/scw.dec.yaml"
  export SECRETS_ACTIVATED=1

  # Source terraform env vars
  if [ -f "$DEST/terraform.dec.env" ]; then
    set -a
    source "$DEST/terraform.dec.env"
    set +a
  fi
}

# if [ -n "$ZSH_VERSION" ]; then
#   emulate -L bash
# fi

if [ "${BASH_SOURCE-}" = "$0" ]; then
  echo "You must source this script: source $0" >&2
  exit 33
fi

_setup_secrets "$1"

# if [ -n "$ZSH_VERSION" ]; then
#   emulate -L zsh
# fi
