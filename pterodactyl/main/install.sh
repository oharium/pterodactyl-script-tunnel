#!/bin/bash

set -e

######################################################################################
#                                                                                    #
# Project 'pterodactyl-installer' - HARIUM EDITION                                   #
#                                                                                    #
# Modified by Harium to support Cloudflare Tunnels and Codespace Environments.       #
#                                                                                    #
######################################################################################

# ===== CORES E ESTILO =====
PURPLE="\033[35m"
DEEP_PURPLE="\033[38;5;93m"
CYAN="\033[36m"
RESET="\033[0m"

export GITHUB_SOURCE="v1.2.0"
export SCRIPT_RELEASE="v1.2.1-harium"
export GITHUB_BASE_URL="https://raw.githubusercontent.com/pterodactyl-installer/pterodactyl-installer"
LOG_PATH="/var/log/pterodactyl-installer.log"

# ===== DETECÇÃO DE AMBIENTE =====
IS_CODESPACE=false
if [[ -n "$CODESPACES" ]] || [[ -d "/workspaces" ]]; then
    IS_CODESPACE=true
fi

# ===== BANNER HARIUM =====
clear
echo -e "${DEEP_PURPLE}██╗  ██╗ █████╗ ██████╗ ██╗██╗   ██╗███╗   ███╗${RESET}"
echo -e "${DEEP_PURPLE}██║  ██║██╔══██╗██╔══██╗██║██║   ██║████╗ ████║${RESET}"
echo -e "${DEEP_PURPLE}███████║███████║██████╔╝██║██║   ██║██╔████╔██║${RESET}"
echo -e "${DEEP_PURPLE}██╔══██║██╔══██║██╔══██╗██║██║   ██║██║╚██╔╝██║${RESET}"
echo -e "${DEEP_PURPLE}██║  ██║██║  ██║██║  ██║██║╚██████╔╝██║ ╚═╝ ██║${RESET}"
echo -e "${DEEP_PURPLE}╚═╝  ╚═╝╚═╝  ╚═╝╚═╝  ╚═╝╚═╝ ╚═════╝ ╚═╝     ╚═╝${RESET}"
echo -e "${PURPLE}    Installer by Harium | Cloudflare & Codespace Edition${RESET}\n"

if [ "$IS_CODESPACE" = true ]; then
    echo -e "${CYAN}[!] Ambiente detectado: GitHub Codespace${RESET}"
else
    echo -e "${CYAN}[!] Ambiente detectado: VPS/Servidor Padrão${RESET}"
fi

# Check for curl
if ! [ -x "$(command -v curl)" ]; then
  echo "* curl is required in order for this script to work."
  exit 1
fi

# ===== FUNÇÃO DE PRÉ-REQUISITOS (EVITA ERROS DE DEPENDÊNCIA) =====
prepare_system() {
    echo -e "${CYAN}* Preparando dependências do sistema...${RESET}"
    sudo apt-get update -y -q
    # Instala o essencial que o Codespace não tem por padrão para o PHP 8.3
    sudo apt-get install -y php8.3-mysql php8.3-zip php8.3-bcmath php8.3-common php8.3-fpm php8.3-curl php8.3-mbstring php8.3-xml php8.3-gd libsodium-dev unzip composer < /dev/null
}

# ===== FUNÇÃO CLOUDFLARE TUNNEL =====
install_cloudflare() {
    echo -e -n "\n${PURPLE}* Deseja instalar o Cloudflare Tunnel para este serviço? (y/N): ${RESET}"
    read -r CONFIRM_CF
    if [[ "$CONFIRM_CF" =~ [Yy] ]]; then
        echo -e "${PURPLE}* Insira seu Cloudflare Tunnel Token:${RESET}"
        read -r CF_TOKEN
        if [[ -n "$CF_TOKEN" ]]; then
            ARCH=$(dpkg --print-architecture)
            wget -q -O /tmp/cloudflared.deb "https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-$ARCH.deb"
            sudo dpkg -i /tmp/cloudflared.deb
            sudo cloudflared service install "$CF_TOKEN" || true
            echo -e "${CYAN}* Cloudflare Tunnel configurado!${RESET}"
        fi
    fi
}

# ===== EXECUÇÃO PRINCIPAL =====
execute() {
  echo -e "\n\n* pterodactyl-installer-harium $(date) \n\n" >>$LOG_PATH
  
  # Preparar sistema antes de rodar o oficial
  prepare_system

  # Download lib.sh original
  [ -f /tmp/lib.sh ] && rm -rf /tmp/lib.sh
  curl -sSL -o /tmp/lib.sh "$GITHUB_BASE_URL"/master/lib/lib.sh
  source /tmp/lib.sh

  [[ "$1" == *"canary"* ]] && export GITHUB_SOURCE="master" && export SCRIPT_RELEASE="canary"
  
  # Rodar interface oficial
  run_ui "${1//_canary/}" |& tee -a $LOG_PATH

  # Se for instalação de painel, oferece o Cloudflare Tunnel ao final
  if [[ "$1" == *"panel"* ]]; then
      install_cloudflare
  fi

  if [[ -n $2 ]]; then
    echo -e -n "\n* Instalação de $1 concluída. Deseja prosseguir para $2? (y/N): "
    read -r CONFIRM
    if [[ "$CONFIRM" =~ [Yy] ]]; then
      execute "$2"
    fi
  fi
}

# Menu de Opções
done=false
while [ "$done" == false ]; do
  options=(
    "Instalar Painel Pterodactyl (Harium Fix)"
    "Instalar Wings (Daemon)"
    "Instalar Painel e Wings no mesmo servidor"
    "Desinstalar Painel ou Wings"
    "Instalar Versão Canary (Instável)"
  )

  actions=(
    "panel"
    "wings"
    "panel;wings"
    "uninstall"
    "panel_canary"
  )

  echo -e "${PURPLE}O que você gostaria de fazer?${RESET}"
  for i in "${!options[@]}"; do
    echo -e "[$i] ${options[$i]}"
  done

  echo -n "* Selecione 0-$((${#actions[@]} - 1)): "
  read -r action

  if [[ -n "$action" ]] && [ "$action" -lt "${#actions[@]}" ]; then
    done=true
    IFS=";" read -r i1 i2 <<<"${actions[$action]}"
    execute "$i1" "$i2"
  else
    echo -e "${DEEP_PURPLE}Opção inválida!${RESET}"
  fi
done

# Limpeza final
rm -rf /tmp/lib.sh
echo -e "\n${PURPLE}✔ Finalizado com sucesso por Harium!${RESET}"
