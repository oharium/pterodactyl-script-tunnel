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

clear
echo -e "${DEEP_PURPLE}██╗  ██╗ █████╗ ██████╗ ██╗██╗   ██╗███╗   ███╗${RESET}"
echo -e "${DEEP_PURPLE}██║  ██║██╔══██╗██╔══██╗██║██║   ██║████╗ ████║${RESET}"
echo -e "${DEEP_PURPLE}███████║███████║██████╔╝██║██║   ██║██╔████╔██║${RESET}"
echo -e "${DEEP_PURPLE}██╔══██║██╔══██║██╔══██╗██║██║   ██║██║╚██╔╝██║${RESET}"
echo -e "${DEEP_PURPLE}██║  ██║██║  ██║██║  ██║██║╚██████╔╝██║ ╚═╝ ██║${RESET}"
echo -e "${DEEP_PURPLE}╚═╝  ╚═╝╚═╝  ╚═╝╚═╝  ╚═╝╚═╝ ╚═════╝ ╚═╝     ╚═╝${RESET}"
echo -e "${PURPLE}    Installer by Harium | Cloudflare Edition (FULL FIX)${RESET}\n"

# ===== CLOUDFLARE TUNNEL TOKEN =====
CF_TUNNEL_TOKEN=""
echo -e "${DEEP_PURPLE}◆${RESET} Deseja usar ${PURPLE}Cloudflare Tunnel${RESET}? (y/N): "
read -r USE_CF
if [[ "$USE_CF" =~ [Yy] ]]; then
    echo -e "${PURPLE}▶ Cole seu Cloudflare Tunnel Token:${RESET}"
    read -r CF_TUNNEL_TOKEN
fi

# ===== FUNÇÃO DE CORREÇÃO AUTOMÁTICA (Resolve erros de dependência) =====
fix_environment() {
    echo -e "${CYAN}▶ Corrigindo dependências e permissões (PHP 8.3)...${RESET}"
    
    # 1. Garante pacotes críticos que o instalador às vezes pula
    apt-get update -q
    apt-get install -y php8.3-fpm php8.3-mysql php8.3-gd php8.3-mbstring php8.3-bcmath php8.3-xml php8.3-curl php8.3-zip unzip composer < /dev/null

    # 2. Se for o Painel, corrige a pasta vendor e o autoload
    if [ -d "/var/www/pterodactyl" ]; then
        cd /var/www/pterodactyl
        export COMPOSER_ALLOW_SUPERUSER=1
        # Instala dependências se a pasta vendor não existir ou estiver incompleta
        composer install --no-dev --optimize-autoloader --no-interaction
        
        # Ajusta Nginx para o socket do PHP 8.3
        [ -f /etc/nginx/sites-available/pterodactyl.conf ] && sed -i 's/php[0-9.]*-fpm.sock/php8.3-fpm.sock/g' /etc/nginx/sites-available/pterodactyl.conf
        
        # Gera chave e limpa cache para tirar o Erro 500
        php artisan key:generate --force || true
        php artisan optimize:clear
        
        # Permissões Finais
        chown -R www-data:www-data /var/www/pterodactyl/*
        chmod -R 775 storage/* bootstrap/cache/
    fi

    # 3. Inicia serviços (Compatível com Codespace)
    mkdir -p /run/php/
    service php8.3-fpm restart || /usr/sbin/php-fpm8.3 --fpm-config /etc/php/8.3/fpm/php-fpm.conf || true
    service nginx restart || true
    service mysql start || true
}

install_cloudflared() {
    if [[ -n "$CF_TUNNEL_TOKEN" ]]; then
        echo -e "${PURPLE}◆ Configurando Cloudflared...${RESET}"
        ARCH=$(dpkg --print-architecture)
        wget -q -O /tmp/cloudflared.deb "https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-$ARCH.deb"
        dpkg -i /tmp/cloudflared.deb || apt-get install -f -y
        cloudflared service install "$CF_TUNNEL_TOKEN" || true
    fi
}

execute() {
    # Roda o instalador oficial do Pterodactyl
    bash <(curl -sL https://debian.pterodactyl-installer.se) --$1

    # Após o instalador, rodamos o nosso "Fix" para garantir que funcione
    fix_environment

    # Se instalou o painel, configura o tunnel
    if [[ "$1" == *"panel"* ]]; then
        install_cloudflared
    fi
}

# ===== MENU COMPLETO =====
echo -e "${PURPLE}O que você deseja fazer?${RESET}"
echo "[0] Install the Panel (Cloudflare Tunnel support)"
echo "[1] Install Wings (Daemon)"
echo "[2] Install Both (Panel & Wings)"
echo "[3] Uninstall"
echo -n "* Selecione 0-3: "
read -r choice

case $choice in
    0) execute "panel" ;;
    1) execute "wings" ;;
    2) 
        execute "panel"
        execute "wings"
        ;;
    3) bash <(curl -sL https://debian.pterodactyl-installer.se) --uninstall ;;
    *) echo -e "${DEEP_PURPLE}Opção inválida.${RESET}" ;;
esac

echo -e "\n${PURPLE}✔ Processo finalizado com sucesso por Harium.${RESET}"
