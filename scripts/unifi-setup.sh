#!/usr/bin/env bash

# Load from environment variables first, then use defaults
USE_COLOR=${USE_COLOR:-true}
BASTION_HOST=${BASTION_HOST:-"bastion"}
ROUTER_IP=${ROUTER_IP:-"10.83.10.1"}
ROUTER_USER=${ROUTER_USER:-"admin"}
OPTION_NAME=${OPTION_NAME:-"unifi-controller"}
NAMESPACE=${NAMESPACE:-"unifi-controller"}
SERVICE_NAME=${SERVICE_NAME:-"unifi-controller-public"}
AP_USERNAME=${AP_USERNAME:-"hca443"}
AP_PASSWORD=${AP_PASSWORD:-"ubnt"}
MODE=${MODE:-"check"} # Default mode

# Parse arguments (these override environment variables)
while [[ $# -gt 0 ]]; do
  key="$1"
  case $key in
  --no-color)
    USE_COLOR=false
    shift
    ;;
  --color)
    USE_COLOR=true
    shift
    ;;
  --update-option)
    MODE="update-option"
    shift
    ;;
  --adopt-aps)
    MODE="adopt-aps"
    shift
    ;;
  --all)
    MODE="all"
    shift
    ;;
  --ap-user)
    AP_USERNAME="$2"
    shift 2
    ;;
  --ap-pass)
    AP_PASSWORD="$2"
    shift 2
    ;;
  --bastion)
    BASTION_HOST="$2"
    shift 2
    ;;
  --router)
    ROUTER_IP="$2"
    shift 2
    ;;
  --router-user)
    ROUTER_USER="$2"
    shift 2
    ;;
  --option-name)
    OPTION_NAME="$2"
    shift 2
    ;;
  --namespace)
    NAMESPACE="$2"
    shift 2
    ;;
  --service)
    SERVICE_NAME="$2"
    shift 2
    ;;
  *)
    shift
    ;;
  esac
done

# Color codes
if [ "$USE_COLOR" = true ]; then
  RED='\033[0;31m'
  GREEN='\033[0;32m'
  YELLOW='\033[0;33m'
  BLUE='\033[0;34m'
  NC='\033[0m' # No Color
else
  RED=''
  GREEN=''
  YELLOW=''
  BLUE=''
  NC=''
fi

# Log function
log() {
  local level=$1
  local message=$2
  local color=""
  case $level in
  INFO) color=$BLUE ;;
  SUCCESS) color=$GREEN ;;
  WARNING) color=$YELLOW ;;
  ERROR) color=$RED ;;
  *) color=$NC ;;
  esac
  echo -e "${color}[$level] $message${NC}"
}

# Convert IP to hex function
ip_to_hex() {
  local ip=$1
  printf '0104%02X%02X%02X%02X' $(echo $ip | tr '.' ' ')
}

# Convert hex to IP function
hex_to_ip() {
  local hex=$1
  # Remove 0104 prefix if present
  if [[ "$hex" =~ ^0104 ]]; then
    hex=${hex:4}
  fi
  echo $hex | sed 's/\(..\)/0x\1 /g' | xargs printf "%d.%d.%d.%d"
}

# Get DHCP option from router
get_dhcp_option() {
  local option_name=$1
  ssh -J $BASTION_HOST $ROUTER_USER@$ROUTER_IP ":put [:serialize to=json [/ip/dhcp-server/option print as-value where name=\"$option_name\"]]"
}

# Set DHCP option on router
set_dhcp_option() {
  local option_name=$1
  local hex_value=$2
  ssh -J $BASTION_HOST $ROUTER_USER@$ROUTER_IP "/ip/dhcp-server/option set [find name=\"$option_name\"] value=0x$hex_value"
}

# Get AP information from router
get_ap_info() {
  ssh -J $BASTION_HOST $ROUTER_USER@$ROUTER_IP ":put [:serialize to=json [/ip/dhcp-server/lease print as-value where host-name~\"HM01-AP\"]]"
}

# Send inform command to AP
send_inform_to_ap() {
  local ap_ip=$1
  local controller_ip=$2

  log "INFO" "Sending adopt command to AP at $ap_ip..."

  # Try to connect and send the inform command
  if ssh -J $BASTION_HOST -o StrictHostKeyChecking=no $AP_USERNAME@$ap_ip "mca-cli-op set-inform http://$controller_ip:8080/inform"; then
    log "SUCCESS" "Sent adopt command to $ap_ip"
    return 0
  else
    log "ERROR" "Failed to send adopt command to $ap_ip"
    return 1
  fi
}

# Update DHCP option function
update_dhcp_option() {
  # Get the EXTERNAL-IP from kubectl
  EXTERNAL_IP=$(kubectl get service -n $NAMESPACE $SERVICE_NAME -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
  log "INFO" "Found External IP from Kubernetes: $EXTERNAL_IP"

  # Convert IP to hex
  IP_HEX=$(ip_to_hex "$EXTERNAL_IP")
  log "INFO" "Converted to hex format: 0x$IP_HEX"

  # Get current value from router using JSON
  CURRENT_JSON=$(get_dhcp_option "$OPTION_NAME")
  CURRENT_HEX=$(echo "$CURRENT_JSON" | jq -r '.[0]."raw-value" // "not-found"')

  if [ "$CURRENT_HEX" = "not-found" ]; then
    log "ERROR" "DHCP option '$OPTION_NAME' not found on router"
    return 1
  fi

  log "INFO" "Current hex value on router: 0x$CURRENT_HEX"

  # Convert current hex to IP for display
  if [ -n "$CURRENT_HEX" ]; then
    CURRENT_IP=$(hex_to_ip "$CURRENT_HEX")
    log "INFO" "Current IP on router: $CURRENT_IP"
  fi

  # Compare and update if different (case-insensitive)
  if [ "${IP_HEX,,}" = "${CURRENT_HEX,,}" ]; then
    log "SUCCESS" "No change needed - current value matches new value."
  else
    log "WARNING" "Value changed from $CURRENT_IP to $EXTERNAL_IP"
    log "INFO" "Updating DHCP option..."
    set_dhcp_option "$OPTION_NAME" "$IP_HEX"
    log "SUCCESS" "DHCP option '$OPTION_NAME' updated to 0x$IP_HEX (IP: $EXTERNAL_IP)"
  fi

  return 0
}

# Adopt APs function
adopt_aps() {
  CONTROLLER_IP=$(kubectl get service -n $NAMESPACE $SERVICE_NAME -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
  log "INFO" "Using controller IP: $CONTROLLER_IP"

  # Get AP information
  AP_INFO=$(get_ap_info)
  AP_COUNT=$(echo "$AP_INFO" | jq '. | length')

  if [ "$AP_COUNT" -eq 0 ]; then
    log "ERROR" "No UniFi APs found"
    return 1
  fi

  log "INFO" "Found $AP_COUNT UniFi APs to adopt"

  # Process each AP
  for ((i = 0; i < $AP_COUNT; i++)); do
    AP_IP=$(echo "$AP_INFO" | jq -r ".[$i].address")
    AP_NAME=$(echo "$AP_INFO" | jq -r ".[$i].\"host-name\"")
    AP_MAC=$(echo "$AP_INFO" | jq -r ".[$i].\"mac-address\"")

    log "INFO" "Processing AP: $AP_NAME ($AP_IP, $AP_MAC)"
    send_inform_to_ap "$AP_IP" "$CONTROLLER_IP"
  done

  return 0
}

# Show help function
show_help() {
  echo "UniFi AP Management Script"
  echo ""
  echo "Usage: $0 [options]"
  echo ""
  echo "Options:"
  echo "  --color/--no-color       Enable/disable colored output (default: $USE_COLOR)"
  echo "  --update-option          Update DHCP option with controller IP"
  echo "  --adopt-aps              Send adopt command to APs"
  echo "  --all                    Do both update-option and adopt-aps"
  echo "  --ap-user <username>     AP SSH username (default: $AP_USERNAME)"
  echo "  --ap-pass <password>     AP SSH password (default: $AP_PASSWORD)"
  echo "  --bastion <host>         Bastion host (default: $BASTION_HOST)"
  echo "  --router <ip>            Router IP (default: $ROUTER_IP)"
  echo "  --router-user <user>     Router username (default: $ROUTER_USER)"
  echo "  --option-name <name>     DHCP option name (default: $OPTION_NAME)"
  echo "  --namespace <namespace>  K8s namespace (default: $NAMESPACE)"
  echo "  --service <name>         K8s service name (default: $SERVICE_NAME)"
  echo "  --help                   Show this help"
  echo ""
  echo "Environment variables:"
  echo "  All parameters can also be set using environment variables with the same name."
  echo "  Example: export ROUTER_IP=\"192.168.1.1\""
}

# Main function
main() {
  # Show help if requested
  if [[ "$1" == "--help" ]]; then
    show_help
    return 0
  fi

  log "INFO" "Running UniFi AP Management Script in $MODE mode"
  log "INFO" "Using configuration:"
  log "INFO" "  Bastion: $BASTION_HOST"
  log "INFO" "  Router: $ROUTER_USER@$ROUTER_IP"

  case $MODE in
  update-option)
    update_dhcp_option
    ;;
  adopt-aps)
    adopt_aps
    ;;
  all)
    update_dhcp_option && adopt_aps
    ;;
  check)
    log "INFO" "Checking mode only - no changes will be made"
    CONTROLLER_IP=$(kubectl get service -n $NAMESPACE $SERVICE_NAME -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
    log "INFO" "Controller IP: $CONTROLLER_IP"

    # Get current option value
    CURRENT_JSON=$(get_dhcp_option "$OPTION_NAME")
    CURRENT_HEX=$(echo "$CURRENT_JSON" | jq -r '.[0]."raw-value" // "not-found"')

    if [ "$CURRENT_HEX" != "not-found" ]; then
      CURRENT_IP=$(hex_to_ip "$CURRENT_HEX")
      log "INFO" "Current DHCP option value: $CURRENT_IP"
    else
      log "WARNING" "DHCP option '$OPTION_NAME' not found"
    fi

    # Show APs
    AP_INFO=$(get_ap_info)
    AP_COUNT=$(echo "$AP_INFO" | jq '. | length')
    log "INFO" "Found $AP_COUNT UniFi APs:"

    for ((i = 0; i < $AP_COUNT; i++)); do
      AP_IP=$(echo "$AP_INFO" | jq -r ".[$i].address")
      AP_NAME=$(echo "$AP_INFO" | jq -r ".[$i].\"host-name\"")
      AP_MAC=$(echo "$AP_INFO" | jq -r ".[$i].\"mac-address\"")
      log "INFO" "  $AP_NAME ($AP_IP, $AP_MAC)"
    done
    ;;
  help)
    show_help
    ;;
  *)
    log "ERROR" "Unknown mode: $MODE"
    log "INFO" "Available modes: check, update-option, adopt-aps, all"
    show_help
    return 1
    ;;
  esac

  return 0
}

# Run the main function
main "$@"
