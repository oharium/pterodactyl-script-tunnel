#!/bin/bash

set -e

# ===== CORES =====
PURPLE="\033[35m"
DEEP_PURPLE="\033[38;5;93m"
CYAN="\033[36m"
RESET="\033[0m"

clear
echo -e "${DEEP_PURPLE}██╗  ██╗ █████╗ ██████╗ ██╗██╗   ██╗███╗   ███╗${RESET}"
echo -e "${DEEP_PURPLE}██║  ██║██╔══██╗██╔══██╗██║██║   ██║████╗ ████║${RESET}"
echo -e "${DEEP_PURPLE}███████║███████║██████╔╝██║██║   ██║██╔████╔██║${RESET}"
echo -e "${DEEP_PURPLE}██╔══██║██╔══██║██╔══██╗██║██║   ██║██║╚██╔╝██║${RESET}"
echo -e "${DEEP_PURPLE}██║  ██║██║  ██║██║  ██║██║╚██████╔╝██║ ╚═╝ ██║${RESET}"
echo -e "${DEEP_PURPLE}╚═╝  ╚═╝╚═╝  ╚═╝╚═╝  ╚═╝╚═╝ ╚═════╝ ╚═╝     ╚═╝${RESET}"
echo -e "${PURPLE}   Auto-Installer Cloudflare Edition | 2026 Fix${RESET}\n"

# 1. PRÉ-REQUISITOS E DEPENDÊNCIAS
echo -e "${CYAN}▶ Instalando dependências do sistema...${RESET}"
apt-get update -q
apt-get install -y software-properties-common curl wget git zip unzip tar nginx mariadb-server < /dev/null

# 2. INSTALAÇÃO DO PHP (Detecta e instala o 8.3 que é o mais estável para Pterodactyl hoje)
echo -e "${CYAN}▶ Configurando PHP 8.3...${RESET}"
apt-get install -y php8.3-fpm php8.3-mysql php8.3-gd php8.3-mbstring php8.3-bcmath php8.3-xml php8.3-curl php8.3-zip < /dev/null

# 3. COMPOSER (Instalação limpa)
if ! command -v composer >/dev/null 2>&1; then
    curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer
fi

# 4. DOWNLOAD E CONFIGURAÇÃO DO PTERODACTYL
echo -e "${CYAN}▶ Baixando Pterodactyl Panel...${RESET}"
mkdir -p /var/www/pterodactyl
cd /var/www/pterodactyl
curl -Lo panel.tar.gz https://github.com/pterodactyl/panel/releases/latest/download/panel.tar.gz
tar -xzvf panel.tar.gz
chmod -R 755 storage/* bootstrap/cache/

# 5. INSTALAÇÃO DE DEPENDÊNCIAS PHP (Onde dava erro)
echo -e "${CYAN}▶ Instalando dependências do Composer (Silencioso)...${RESET}"
export COMPOSER_ALLOW_SUPERUSER=1
composer install --no-dev --optimize-autoloader --no-interaction

# 6. CONFIGURAÇÃO DO NGINX (DINÂMICA)
echo -e "${CYAN}▶ Configurando Nginx...${RESET}"
PHP_SOCKET="/run/php/php8.3-fpm.sock"
mkdir -p /run/php/

cat <<EOF > /etc/nginx/sites-available/pterodactyl.conf
server {
    listen 80;
    server_name _;
    root /var/www/pterodactyl/public;
    index index.php;
    charset utf-8;

    location / {
        try_files \$uri \$uri/ /index.php?\$query_string;
    }

    location ~ \.php$ {
        fastcgi_split_path_info ^(.+\.php)(/.+)$;
        fastcgi_pass unix:$PHP_SOCKET;
        fastcgi_index index.php;
        include fastcgi_params;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        fastcgi_intercept_errors off;
    }
}
EOF

ln -sf /etc/nginx/sites-available/pterodactyl.conf /etc/nginx/sites-enabled/pterodactyl.conf
rm -f /etc/nginx/sites-enabled/default

# 7. INICIALIZAÇÃO DE SERVIÇOS (Compatível com Codespace e VPS)
echo -e "${CYAN}▶ Iniciando serviços...${RESET}"
service php8.3-fpm start || /usr/sbin/php-fpm8.3 --fpm-config /etc/php/8.3/fpm/php-fpm.conf
service nginx restart

# 8. CLOUDFLARE TUNNEL (OPCIONAL)
echo -e "${PURPLE}▶ Deseja ativar o Cloudflare Tunnel agora? (y/n)${RESET}"
read -r CONFIRM_CF
if [[ "$CONFIRM_CF" =~ [Yy] ]]; then
    echo -e "${CYAN}Cole seu Token:${RESET}"
    read -r CF_TOKEN
    if [[ -z "$(command -v cloudflared)" ]]; then
        wget -q https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb
        dpkg -i cloudflared-linux-amd64.deb
    fi
    cloudflared service install "$CF_TOKEN" || echo "Tunnel já configurado."
fi

# 9. PERMISSÕES FINAIS
chown -R www-data:www-data /var/www/pterodactyl/*
echo -e "${DEEP_PURPLE}✔ INSTALAÇÃO FINALIZADA SEM ERROS!${RESET}"
