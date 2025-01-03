#!/usr/bin/env bash

# Read .env file and convert to JSON
env_to_json() {
  local file="${1:-.env}"
  echo "{"
  grep -v '^#' "$file" | grep '=' | while IFS='=' read -r key value; do
    # Remove leading/trailing whitespace and quotes
    key=$(echo "$key" | sed 's/^[ \t]*//;s/[ \t]*$//')
    value=$(echo "$value" | sed 's/^[ \t]*//;s/[ \t]*$//;s/^["\x27]//;s/["\x27]$//')
    echo "  \"$key\": \"$value\","
  done | sed '$ s/,$//'
  echo "}"
}

# Usage: ./script.sh [env_file]
env_to_json "$1"
