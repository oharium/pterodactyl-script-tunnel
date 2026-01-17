#!/bin/bash

set -e

# ===== UI COLORS =====
PURPLE="\033[35m"
DEEP_PURPLE="\033[38;5;93m"
GRAY="\033[90m"
CYAN="\033[36m"
RESET="\033[0m"

# ===== CONFIGURAÇÕES =====
export GITHUB_BASE_URL="https://raw.githubusercontent.com/pterodactyl-installer/pterodactyl-installer"

clear
echo -e "${DEEP_PURPLE}██╗  ██╗ █████╗ ██████╗ ██╗██╗   ██╗███╗   ███╗${RESET}"
echo -e "${DEEP_PURPLE}██║  ██║██╔══██╗██╔══██╗██║██║   ██║████╗ ████║${RESET}"
echo -e "${DEEP_PURPLE}███████║███████║██████╔╝██║██║   ██║██╔████╔██║${RESET}"
echo -e "${DEEP_PURPLE}██╔══██║██╔══██║██╔══██╗██║██║   ██║██║╚██╔╝██║${RESET}"
echo -e "${DEEP_PURPLE}██║  ██║██║  ██║██║  ██║██║╚██████╔╝██║ ╚═╝ ██║${RESET}"
echo -e "${DEEP_PURPLE}╚═╝  ╚═╝╚═╝  ╚═╝╚═╝  ╚═╝╚═╝ ╚═════╝ ╚═╝     ╚═╝${RESET}"
echo -e "${PURPLE}    Installer by Harium | Cloudflare Edition (FULL FIX)${RESET}\n"

# ===== PERGUNTA CLOUDFLARE =====
CF_TUNNEL_TOKEN=""
echo -e "${DEEP_PURPLE}◆${RESET} Deseja usar ${PURPLE}Cloudflare Tunnel${RESET}? (y/N): "
read -r USE_CF
if [[ "$USE_CF" =~ [Yy] ]]; then
    echo -e "${PURPLE}▶ Cole seu Cloudflare Tunnel Token:${RESET}"
    read -r CF_TUNNEL_TOKEN
fi

# ===== FUNÇÃO DE CORREÇÃO (Onde resolvemos o erro do Composer) =====
fix_environment() {
    echo -e "${CYAN}▶ Instalando extensões PHP faltantes...${RESET}"
    
    # Instala exatamente o que o Composer pediu (e o sodium/bcmath)
    apt-get update -q
    apt-get install -y php8.3-mysql php8.3-zip php8.3-bcmath php8.3-common php8.3-fpm php8.3-curl php8.3-mbstring php8.3-xml php8.3-gd libsodium-dev < /dev/null

    if [ -d "/var/www/pterodactyl" ]; then
        echo -e "${CYAN}▶ Forçando dependências do Composer...${RESET}"
        cd /var/www/pterodactyl
        export COMPOSER_ALLOW_SUPERUSER=1
        
        # O pulo do gato: --ignore-platform-reqs faz ele instalar mesmo com o erro do PHP local do Codespace
        composer install --no-dev --optimize-autoloader --no-interaction --ignore-platform-reqs
        
        # Configurações do Painel
        [ ! -f .env ] && cp .env.example .env
        php artisan key:generate --force || true
        
        # Ajuste Nginx
        [ -f /etc/nginx/sites-available/pterodactyl.conf ] && sed -i 's/php[0-9.]*-fpm.sock/php8.3-fpm.sock/g' /etc/nginx/sites-available/pterodactyl.conf
        
        chown -R www-data:www-data /var/www/pterodactyl/*
        chmod -R 775 storage/* bootstrap/cache/
    fi

    # Inicia os serviços no braço
    mkdir -p /run/php/
    service php8.3-fpm restart || /usr/sbin/php-fpm8.3 --fpm-config /etc/php/8.3/fpm/php-fpm.conf || true
    service nginx restart || true
    service mysql start || true
}

install_cloudflared() {
    if [[ -n "$CF_TUNNEL_TOKEN" ]]; then
        echo -e "${PURPLE}◆ Instalando Cloudflared...${RESET}"
        ARCH=$(dpkg --print-architecture)
        wget -q -O /tmp/cloudflared.deb "https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-$ARCH.deb"
        dpkg -i /tmp/cloudflared.deb || apt-get install -f -y
        cloudflared service install "$CF_TUNNEL_TOKEN" || true
    fi
}

execute() {
    # Roda o oficial
    bash <(curl -sL https://debian.pterodactyl-installer.se) --$1
    # Aplica nossa correção
    fix_environment
    # Se for painel, bota o tunnel
    if [[ "$1" == *"panel"* ]]; then
        install_cloudflared
    fi
}

# ===== MENU ORIGINAL RESTAURADO =====
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
    *) echo "Opção inválida." ;;
esac

echo -e "\n${PURPLE}✔ Processo finalizado com sucesso!${RESET}"
