#!/bin/bash

set -e

# ===== UI COLORS (Dark & Clean) =====
PURPLE="\033[35m"
DEEP_PURPLE="\033[38;5;93m"
GRAY="\033[90m"
RESET="\033[0m"

# ===== CONFIGURAÇÕES =====
export GITHUB_SOURCE="v1.2.0"
export SCRIPT_RELEASE="v1.2.0-harium"
export GITHUB_BASE_URL="https://raw.githubusercontent.com/pterodactyl-installer/pterodactyl-installer"
LOG_PATH="/var/log/pterodactyl-installer.log"

# ===== CHECAGEM DE REQUISITOS =====
if ! [ -x "$(command -v curl)" ]; then
  echo -e "* curl é necessário. Instalando..."
  apt-get update && apt-get install -y curl
fi

clear
# ASCII ART HARIUM
echo -e "${DEEP_PURPLE}██╗  ██╗ █████╗ ██████╗ ██╗██╗   ██╗███╗   ███╗${RESET}"
echo -e "${DEEP_PURPLE}██║  ██║██╔══██╗██╔══██╗██║██║   ██║████╗ ████║${RESET}"
echo -e "${DEEP_PURPLE}███████║███████║██████╔╝██║██║   ██║██╔████╔██║${RESET}"
echo -e "${DEEP_PURPLE}██╔══██║██╔══██║██╔══██╗██║██║   ██║██║╚██╔╝██║${RESET}"
echo -e "${DEEP_PURPLE}██║  ██║██║  ██║██║  ██║██║╚██████╔╝██║ ╚═╝ ██║${RESET}"
echo -e "${DEEP_PURPLE}╚═╝  ╚═╝╚═╝  ╚═╝╚═╝  ╚═╝╚═╝ ╚═════╝ ╚═╝     ╚═╝${RESET}"
echo -e "${PURPLE}   Installer made by Harium | Cloudflare Edition${RESET}\n"

# ===== CLOUDFLARE TUNNEL LOGIC =====
CF_TUNNEL_TOKEN=""
echo -e "${DEEP_PURPLE}◆${RESET} Deseja usar ${PURPLE}Cloudflare Tunnel${RESET} em vez de porta aberta/SSL manual? (y/N): "
read -r USE_CF
if [[ "$USE_CF" =~ [Yy] ]]; then
    echo -e "${PURPLE}▶ Cole seu Cloudflare Tunnel Token:${RESET}"
    read -r CF_TUNNEL_TOKEN
fi

install_cloudflared() {
    if [[ -n "$CF_TUNNEL_TOKEN" ]]; then
        echo -e "${PURPLE}◆ Instalando e configurando Cloudflared Service...${RESET}"
        # Download do binário oficial
        curl -L --output /tmp/cloudflared.deb https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb
        dpkg -i /tmp/cloudflared.deb
        
        # Instala como serviço do sistema (roda no boot)
        cloudflared service install "$CF_TUNNEL_TOKEN"
        echo -e "${GRAY}✔ Tunnel ativo e configurado para iniciar no boot.${RESET}"
    fi
}

# ===== PTERODACTYL LOGIC =====
[ -f /tmp/lib.sh ] && rm -rf /tmp/lib.sh
curl -sSL -o /tmp/lib.sh "$GITHUB_BASE_URL"/master/lib/lib.sh
source /tmp/lib.sh

execute() {
    echo -e "\n\n* pterodactyl-installer (Harium) $(date) \n\n" >>$LOG_PATH
    [[ "$1" == *"canary"* ]] && export GITHUB_SOURCE="master"
    
    update_lib_source
    run_ui "${1//_canary/}" |& tee -a $LOG_PATH

    # Se for o painel, após a instalação, configura o túnel
    if [[ "$1" == *"panel"* ]]; then
        install_cloudflared
    fi
}

# ===== MENU PRINCIPAL =====
done=false
while [ "$done" == false ]; do
    options=(
        "Install the Panel (Cloudflare Tunnel support)"
        "Install Wings"
        "Install Both"
        "Uninstall"
    )

    actions=(
        "panel"
        "wings"
        "panel;wings"
        "uninstall"
    )

    echo -e "${PURPLE}O que você deseja fazer?${RESET}"
    for i in "${!options[@]}"; do
        echo -e "[$i] ${options[$i]}"
    done

    echo -n "* Selecione 0-$((${#actions[@]} - 1)): "
    read -r action

    if [[ -n "$action" && "$action" -lt ${#actions[@]} ]]; then
        done=true
        IFS=";" read -r i1 i2 <<<"${actions[$action]}"
        execute "$i1" "$i2"
    else
        echo -e "${DEEP_PURPLE}Opção inválida.${RESET}"
    fi
done

echo -e "\n${PURPLE}✔ Processo finalizado por Harium.${RESET}"
if [[ -n "$CF_TUNNEL_TOKEN" ]]; then
    echo -e "${GRAY}Lembre-se: No painel da Cloudflare, aponte seu domínio para http://localhost:80${RESET}"
fi
