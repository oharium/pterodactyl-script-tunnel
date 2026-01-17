#!/bin/bash

set -e

# ===== UI COLORS (Dark + Purple accent) =====
PURPLE="\033[35m"
DEEP_PURPLE="\033[38;5;93m"
GRAY="\033[90m"
RESET="\033[0m"

######################################################################################
#                                                                                    #
# Project 'pterodactyl-installer' (Custom fork)                                      #
#                                                                                    #
# Made by: Harium                                                                    #
#                                                                                    #
# This custom version adds:                                                          #
#  - Credit rename                                                                   #
#  - Optional Cloudflare Tunnel (cloudflared) token support                          #
#                                                                                    #
######################################################################################

export GITHUB_SOURCE="v1.2.0"
export SCRIPT_RELEASE="v1.2.0-harium"
export GITHUB_BASE_URL="https://raw.githubusercontent.com/pterodactyl-installer/pterodactyl-installer"

LOG_PATH="/var/log/pterodactyl-installer.log"
CF_TUNNEL_TOKEN=""

# check for curl
if ! [ -x "$(command -v curl)" ]; then
  echo "* curl is required in order for this script to work."
  echo "* install using apt (Debian and derivatives) or yum/dnf (CentOS)"
  exit 1
fi

# Ask for Cloudflare Tunnel token (optional)
echo -e "${DEEP_PURPLE}◆${RESET} Do you want to use ${PURPLE}Cloudflare Tunnel${RESET}? (y/N): "
read -r USE_CF
if [[ "$USE_CF" =~ [Yy] ]]; then
  echo -e "${PURPLE}▶ Paste your Cloudflare Tunnel token:${RESET}"
  read -r CF_TUNNEL_TOKEN
  export CF_TUNNEL_TOKEN
  echo -e "${GRAY}✔ Token stored for this session.${RESET}"
fi

# Always remove lib.sh, before downloading it
[ -f /tmp/lib.sh ] && rm -rf /tmp/lib.sh
curl -sSL -o /tmp/lib.sh "$GITHUB_BASE_URL"/master/lib/lib.sh
# shellcheck source=lib/lib.sh
source /tmp/lib.sh

execute() {
  echo -e "\n\n* pterodactyl-installer (Harium) $(date) \n\n" >>$LOG_PATH

  [[ "$1" == *"canary"* ]] && export GITHUB_SOURCE="master" && export SCRIPT_RELEASE="canary-harium"
  update_lib_source
  run_ui "${1//_canary/}" |& tee -a $LOG_PATH

  if [[ -n $2 ]]; then
    echo -e -n "* Installation of $1 completed. Do you want to proceed to $2 installation? (y/N): "
    read -r CONFIRM
    if [[ "$CONFIRM" =~ [Yy] ]]; then
      execute "$2"
    else
      error "Installation of $2 aborted."
      exit 1
    fi
  fi
}

clear
# ASCII Art corrigido para HARIUM
echo -e "${DEEP_PURPLE}██╗  ██╗ █████╗ ██████╗ ██╗██╗   ██╗███╗   ███╗${RESET}"
echo -e "${DEEP_PURPLE}██║  ██║██╔══██╗██╔══██╗██║██║   ██║████╗ ████║${RESET}"
echo -e "${DEEP_PURPLE}███████║███████║██████╔╝██║██║   ██║██╔████╔██║${RESET}"
echo -e "${DEEP_PURPLE}██╔══██║██╔══██║██╔══██╗██║██║   ██║██║╚██╔╝██║${RESET}"
echo -e "${DEEP_PURPLE}██║  ██║██║  ██║██║  ██║██║╚██████╔╝██║ ╚═╝ ██║${RESET}"
echo -e "${DEEP_PURPLE}╚═╝  ╚═╝╚═╝  ╚═╝╚═╝  ╚═╝╚═╝ ╚═════╝ ╚═╝     ╚═╝${RESET}"
echo -e "${PURPLE}Installer made by Harium${RESET}\n"

welcome ""

done=false
while [ "$done" == false ]; do
  options=(
    "Install the panel"
    "Install Wings"
    "Install both [0] and [1] on the same machine (wings script runs after panel)"
    "Install panel with canary version of the script (may be broken!)"
    "Install Wings with canary version of the script (may be broken!)"
    "Install both [3] and [4] on the same machine"
    "Uninstall panel or wings with canary version"
  )

  actions=(
    "panel"
    "wings"
    "panel;wings"
    "panel_canary"
    "wings_canary"
    "panel_canary;wings_canary"
    "uninstall_canary"
  )

  output "${PURPLE}What would you like to do?${RESET}"

  for i in "${!options[@]}"; do
    output "[$i] ${options[$i]}"
  done

  echo -n "* Input 0-$((${#actions[@]} - 1)): "
  read -r action

  [ -z "$action" ] && error "Input is required" && continue

  valid_input=("$(for ((i = 0; i <= ${#actions[@]} - 1; i += 1)); do echo "${i}"; done)")
  [[ ! " ${valid_input[*]} " =~ ${action} ]] && error "Invalid option"
  [[ " ${valid_input[*]} " =~ ${action} ]] && done=true && IFS=";" read -r i1 i2 <<<"${actions[$action]}" && execute "$i1" "$i2"
done

# Remove lib.sh
rm -rf /tmp/lib.sh

# Cloudflare Tunnel helper
if [[ -n "$CF_TUNNEL_TOKEN" ]]; then
  echo -e "\n${PURPLE}◆ Cloudflare Tunnel${RESET}"
  echo -e "${GRAY}To start manually, run:${RESET}"
  echo -e "${DEEP_PURPLE}cloudflared tunnel run --token $CF_TUNNEL_TOKEN${RESET}"
fi