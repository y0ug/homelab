# secrets.deactivate
#!/usr/bin/env bash

# if [ -n "$ZSH_VERSION" ]; then
#     emulate -L bash
# fi

if [ "${BASH_SOURCE-}" = "$0" ]; then
  echo "You must source this script: source $0" >&2
  exit 33
fi
# Get list of variables from terraform.dec.env and unset them
if [ -f "$(pwd)/.dec/terraform.dec.env" ]; then
  while IFS='=' read -r key _; do
    if [ -n "$key" ] && [[ ! "$key" =~ ^# ]]; then
      unset "$key"
    fi
  done <"$(pwd)/.dec/terraform.dec.env"
fi
unset KUBE_CONFIG_PATH
unset SCW_CONFIG_PATH
unset SECRETS_ACTIVATED
