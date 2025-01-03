#!/usr/bin/env bash
ENV="${1:-prod}"
export DEST=$(pwd)/.dec
export SRC=$(pwd)/secrets/$ENV

mkdir -p "$DEST"

sops -d "$SRC"/kube_config.sops.yaml >"$DEST/kube_config.dec.yaml"
sops -d "$SRC"/scw.sops.yaml >"$DEST/scw.dec.yaml"
sops -d --output-type dotenv "$SRC/terraform.sops.yaml" >$DEST/terraform.dec.env

export KUBE_CONFIG_PATH="$DEST/kube_config.dec.yaml"
export SCW_CONFIG_PATH="$DEST/scw.dec.yaml"
eval $(sops -d --output-type dotenv "$SRC/terraform.sops.yaml")
