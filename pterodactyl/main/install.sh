#!/bin/bash

set -e

# ===== UI COLORS =====
PURPLE="\033[35m"
DEEP_PURPLE="\033[38;5;93m"
GRAY="\033[90m"
CYAN="\033[36m"
RESET="\033[0m"

# ===== CONFIGURAÇÕES =====
export GITHUB_SOURCE="v1.2.0"
export SCRIPT_RELEASE="v1.2.1-harium"
export GITHUB_BASE_URL="https://raw.githubusercontent.com/pterodactyl-installer/pterodactyl-installer"
LOG_PATH="/var/log/pterodactyl-installer.log"

# ===== DETECÇÃO DE AMBIENTE =====
IS_CODESPACE=false
if [[ -n "$CODESPACES" ]]; then
    IS_CODESPACE=true
    ENVIRONMENT="GitHub Codespace"
else
    ENVIRONMENT="Standard VPS"
fi

clear
echo -e "${DEEP_PURPLE}██╗  ██╗ █████╗ ██████╗ ██╗██╗   ██╗███╗   ███╗${RESET}"
echo -e "${DEEP_PURPLE}██║  ██║██╔══██╗██╔══██╗██║██║   ██║████╗ ████║${RESET}"
echo -e "${DEEP_PURPLE}███████║███████║██████╔╝██║██║   ██║██╔████╔██║${RESET}"
echo -e "${DEEP_PURPLE}██╔══██║██╔══██║██╔══██╗██║██║   ██║██║╚██╔╝██║${RESET}"
echo -e "${DEEP_PURPLE}██║  ██║██║  ██║██║  ██║██║╚██████╔╝██║ ╚═╝ ██║${RESET}"
echo -e "${DEEP_PURPLE}╚═╝  ╚═╝╚═╝  ╚═╝╚═╝  ╚═╝╚═╝ ╚═════╝ ╚═╝     ╚═╝${RESET}"
echo -e "${PURPLE}   Installer by Harium | Cloudflare Edition${RESET}"
echo -e "${GRAY}   Detectado: ${CYAN}$ENVIRONMENT${RESET}\n"

# ===== INSTALAÇÃO DE DEPENDÊNCIAS =====
echo -e "${PURPLE}◆ Verificando dependências do sistema...${RESET}"
apt-get update -q
apt-get install -y curl wget git gnupg2 ca-certificates lsb-release apt-transport-https > /dev/null 2>&1

# ===== CLOUDFLARE TUNNEL LOGIC =====
CF_TUNNEL_TOKEN=""
echo -e "${DEEP_PURPLE}◆${RESET} Deseja usar ${PURPLE}Cloudflare Tunnel${RESET}? (y/N): "
read -r USE_CF
if [[ "$USE_CF" =~ [Yy] ]]; then
    echo -e "${PURPLE}▶ Cole seu Cloudflare Tunnel Token:${RESET}"
    read -r CF_TUNNEL_TOKEN
fi

install_cloudflared() {
    if [[ -n "$CF_TUNNEL_TOKEN" ]]; then
        echo -e "${PURPLE}◆ Instalando Cloudflared Service...${RESET}"
        
        # Detecta arquitetura para baixar o binário correto
        ARCH=$(dpkg --print-architecture)
        URL="https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-$ARCH.deb"
        
        wget -q --show-progress -O /tmp/cloudflared.deb "$URL"
        dpkg -i /tmp/cloudflared.deb || apt-get install -f -y
        
        # Instala como serviço (Inicia no boot)
        cloudflared service install "$CF_TUNNEL_TOKEN" || echo "Serviço já existe ou erro na instalação."
        echo -e "${GRAY}✔ Tunnel ativo e configurado.${RESET}"
    fi
}

# ===== PTERODACTYL LOGIC =====
setup_lib() {
    [ -f /tmp/lib.sh ] && rm -rf /tmp/lib.sh
    curl -sSL -o /tmp/lib.sh "$GITHUB_BASE_URL"/master/lib/lib.sh
    source /tmp/lib.sh
}

execute() {
    echo -e "\n\n* pterodactyl-installer (Harium) $(date) \n\n" >>$LOG_PATH
    
    setup_lib
    update_lib_source
    
    # Se for codespace, algumas verificações de virtualização podem falhar, 
    # o instalador original tenta lidar com isso.
    run_ui "${1}" |& tee -a $LOG_PATH

    # Se instalou o painel, roda o tunnel logo após
    if [[ "$1" == *"panel"* ]]; then
        install_cloudflared
    fi
}

# ===== MENU PRINCIPAL =====
options=(
    "Install the Panel (Cloudflare Tunnel support)"
    "Install Wings (Daemon)"
    "Install Both (Panel & Wings)"
    "Uninstall"
)

actions=(
    "panel"
    "wings"
    "panel_wings"
)

echo -e "${PURPLE}O que você deseja fazer?${RESET}"
for i in "${!options[@]}"; do
    echo -e "[$i] ${options[$i]}"
done

echo -n "* Selecione 0-3: "
read -r choice

case $choice in
    0) execute "panel" ;;
    1) execute "wings" ;;
    2) 
        execute "panel"
        execute "wings"
        ;;
    3) 
        setup_lib
        run_ui "uninstall"
        ;;
    *) echo -e "${DEEP_PURPLE}Opção inválida.${RESET}" ;;
esac

echo -e "\n${PURPLE}✔ Processo finalizado por Harium.${RESET}"
if [[ -n "$CF_TUNNEL_TOKEN" ]]; then
    echo -e "${CYAN}ℹ NOTA:${RESET} No Cloudflare Dashboard, aponte seu CNAME para ${PURPLE}http://localhost:80${RESET}"
fi
