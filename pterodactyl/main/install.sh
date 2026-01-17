#!/bin/bash

set -e

######################################################################################
#                                                                                    #
# Project 'pterodactyl-installer' - HARIUM EDITION                                   #
#                                                                                    #
# Modified by Harium to support Cloudflare Tunnels and Codespace Environments.      #
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

# ===== FUNÇÃO DE REPARO AUTOMÁTICO (O CORAÇÃO DO FIX) =====
fix_codespace_errors() {
    echo -e "${CYAN}* Aplicando correções automáticas Harium para Codespace...${RESET}"
    
    # 1. Forçar drivers PHP que o instalador oficial as vezes pula
    echo "extension=pdo_mysql.so" | sudo tee /etc/php/8.3/cli/conf.d/20-pdo_mysql.ini > /dev/null
    echo "extension=mysqlnd.so" | sudo tee /etc/php/8.3/cli/conf.d/10-mysqlnd.ini > /dev/null

    # 2. Corrigir permissões de pasta (Garante que o Erro 500 não aconteça)
    if [ -d "/var/www/pterodactyl" ]; then
        cd /var/www/pterodactyl
        sudo chown -R www-data:www-data /var/www/pterodactyl/*
        sudo chmod -R 775 storage/* bootstrap/cache/
        
        # Garante que o .env use 127.0.0.1 (evita erro de socket)
        sudo sed -i "s/DB_HOST=.*/DB_HOST=127.0.0.1/g" .env
        
        # Instala dependências caso o script oficial tenha falhado silenciosamente
        sudo composer install --no-dev --optimize-autoloader --no-interaction --ignore-platform-reqs || true
        
        # Gera chave e limpa cache
        sudo php8.3 artisan key:generate --force --no-interaction || true
        sudo php8.3 artisan optimize:clear
    fi

    # 3. Corrigir Nginx (Tira o 'Welcome to nginx' e ativa o Painel)
    sudo rm -f /etc/nginx/sites-enabled/default
    if [ -f "/etc/nginx/sites-available/pterodactyl.conf" ]; then
        sudo ln -sf /etc/nginx/sites-available/pterodactyl.conf /etc/nginx/sites-enabled/pterodactyl.conf
    fi

    # 4. Reiniciar serviços
    sudo service php8.3-fpm restart
    sudo service nginx restart
    sudo service mariadb start || sudo service mysql start
}

# ===== BANNER HARIUM =====
clear
echo -e "${DEEP_PURPLE}██╗  ██╗ █████╗ ██████╗ ██╗██╗   ██╗███╗   ███╗${RESET}"
echo -e "${DEEP_PURPLE}██║  ██║██╔══██╗██╔══██╗██║██║   ██║████╗ ████║${RESET}"
echo -e "${DEEP_PURPLE}███████║███████║██████╔╝██║██║   ██║██╔████╔██║${RESET}"
echo -e "${DEEP_PURPLE}██╔══██║██╔══██║██╔══██╗██║██║   ██║██║╚██╔╝██║${RESET}"
echo -e "${DEEP_PURPLE}██║  ██║██║  ██║██║  ██║██║╚██████╔╝██║ ╚═╝ ██║${RESET}"
echo -e "${DEEP_PURPLE}╚═╝  ╚═╝╚═╝  ╚═╝╚═╝  ╚═╝╚═╝ ╚═════╝ ╚═╝     ╚═╝${RESET}"
echo -e "${PURPLE}    Installer by Harium | Cloudflare & Codespace Edition${RESET}\n"

# ===== PRÉ-REQUISITOS =====
prepare_system() {
    echo -e "${CYAN}* Preparando dependências do sistema...${RESET}"
    sudo apt-get update -y -q
    sudo apt-get install -y php8.3-mysql php8.3-zip php8.3-bcmath php8.3-common php8.3-fpm php8.3-curl php8.3-mbstring php8.3-xml php8.3-gd libsodium-dev unzip composer mariadb-server nginx < /dev/null
}

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
  
  prepare_system

  [ -f /tmp/lib.sh ] && rm -rf /tmp/lib.sh
  curl -sSL -o /tmp/lib.sh "$GITHUB_BASE_URL"/master/lib/lib.sh
  source /tmp/lib.sh

  [[ "$1" == *"canary"* ]] && export GITHUB_SOURCE="master" && export SCRIPT_RELEASE="canary"
  
  # Roda a UI oficial
  run_ui "${1//_canary/}" |& tee -a $LOG_PATH

  # APLICA AS CORREÇÕES IMEDIATAMENTE APÓS O INSTALADOR PARAR
  if [[ "$1" == *"panel"* ]]; then
      fix_codespace_errors
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

# Menu
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

rm -rf /tmp/lib.sh
echo -e "\n${PURPLE}✔ Finalizado com sucesso por Harium!${RESET}"
