#!/bin/bash
set -e

# ================== COLORS ==================
DEEP_PURPLE="\e[38;5;55m"
PURPLE="\e[38;5;93m"
RESET="\e[0m"

# ================== BANNER ==================
clear
echo -e "${DEEP_PURPLE}██╗  ██╗ █████╗ ██████╗ ██╗██╗   ██╗███╗   ███╗${RESET}"
echo -e "${DEEP_PURPLE}██║  ██║██╔══██╗██╔══██╗██║██║   ██║████╗ ████║${RESET}"
echo -e "${DEEP_PURPLE}███████║███████║██████╔╝██║██║   ██║██╔████╔██║${RESET}"
echo -e "${DEEP_PURPLE}██╔══██║██╔══██║██╔══██╗██║██║   ██║██║╚██╔╝██║${RESET}"
echo -e "${DEEP_PURPLE}██║  ██║██║  ██║██║  ██║██║╚██████╔╝██║ ╚═╝ ██║${RESET}"
echo -e "${DEEP_PURPLE}╚═╝  ╚═╝╚═╝  ╚═╝╚═╝  ╚═╝╚═╝ ╚═════╝ ╚═╝     ╚═╝${RESET}"
echo -e "${PURPLE}    Installer by Harium | Cloudflare & Codespace Edition${RESET}\n"

# ================== ROOT ==================
if [ "$EUID" -ne 0 ]; then
  echo "❌ Execute como root (sudo)"
  exit 1
fi

# ================== SYSTEM UPDATE ==================
echo "🔄 Verificando atualizações do sistema..."
apt update -y

UPGRADABLE=$(apt list --upgradable 2>/dev/null | grep -c upgradable || true)
if [ "$UPGRADABLE" -gt 0 ]; then
  echo "⬆️ Atualizando sistema..."
  apt upgrade -y
else
  echo "✅ Sistema já está atualizado"
fi

# ================== DOCKER ==================
install_docker() {
  if command -v docker >/dev/null 2>&1; then
    echo "🐳 Docker já instalado"
    return
  fi

  echo "🐳 Instalando Docker..."
  apt install -y ca-certificates curl gnupg lsb-release
  curl -fsSL https://get.docker.com | sh
  systemctl enable docker || true
  systemctl start docker || true
}

# ================== DOCKER COMPOSE ==================
install_compose() {
  if docker compose version >/dev/null 2>&1; then
    COMPOSE="docker compose"
    return
  fi

  echo "📦 Instalando Docker Compose..."
  curl -L https://github.com/docker/compose/releases/download/2.27.0/docker-compose-linux-x86_64 \
    -o /usr/local/bin/docker-compose
  chmod +x /usr/local/bin/docker-compose
  COMPOSE="docker-compose"
}

# ================== INTERACTIVE SETUP ==================
clear
echo -e "${DEEP_PURPLE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo -e "${PURPLE}   🧩 CONFIGURAÇÃO DO PTERODACTYL PANEL${RESET}"
echo -e "${DEEP_PURPLE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo

# -------- EXPOSIÇÃO --------
echo -e "${PURPLE}🌐 MODO DE EXPOSIÇÃO DO PAINEL${RESET}"
echo
echo "  [1] ☁️  Cloudflare Tunnel  (sem abrir portas)"
echo "  [2] 🌍 DNS / IP / Localhost"
echo
read -rp "👉 Escolha uma opção [1-2]: " EXPOSE_MODE
echo

# -------- ADMIN --------
echo -e "${PURPLE}👤 CONTA ADMINISTRADOR${RESET}"
echo
read -rp "👉 Email do administrador [admin@localhost]: " ADMIN_EMAIL
ADMIN_EMAIL="${ADMIN_EMAIL:-admin@localhost}"
echo

# -------- DATABASE --------
echo -e "${PURPLE}🗄️  BANCO DE DADOS${RESET}"
echo "   Pressione ENTER para gerar uma senha segura automaticamente"
echo
read -rsp "👉 Senha do banco de dados: " DB_PASS
echo
if [ -z "$DB_PASS" ]; then
  DB_PASS=$(openssl rand -hex 16)
  echo "🔐 Senha gerada automaticamente"
fi
echo

# -------- CLOUDFLARE --------
if [ "$EXPOSE_MODE" = "1" ]; then
  USE_CF=true

  echo -e "${PURPLE}☁️  CLOUDFLARE TUNNEL${RESET}"
  echo
  read -rp "👉 Domínio do painel (https://painel.seudominio.com): " APP_URL
  echo
  read -rp "👉 Token do Cloudflare Tunnel: " CLOUDFLARED_TOKEN
  PANEL_PORT=80
else
  USE_CF=false

  echo -e "${PURPLE}🌍 ACESSO DIRETO${RESET}"
  echo
  read -rp "👉 URL do painel [http://localhost:8030]: " APP_URL
  APP_URL="${APP_URL:-http://localhost:8030}"
  PANEL_PORT=8030
fi

# -------- RESUMO --------
echo
echo -e "${DEEP_PURPLE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo -e "${PURPLE}📋 RESUMO DA CONFIGURAÇÃO${RESET}"
echo -e "${DEEP_PURPLE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo
echo " 🌐 URL do Painel : $APP_URL"
echo " 📧 Admin Email  : $ADMIN_EMAIL"
echo " 🔐 DB Password : ********"
if [ "$USE_CF" = true ]; then
  echo " ☁️ Cloudflare  : Ativado"
else
  echo " 🌍 Cloudflare  : Desativado"
fi
echo
read -rp "✅ Deseja continuar com a instalação? (Y/n): " CONFIRM
CONFIRM="${CONFIRM:-Y}"

if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
  echo
  echo "❌ Instalação cancelada pelo usuário."
  exit 0
fi

echo
echo -e "${PURPLE}🚀 Iniciando instalação...${RESET}"
echo

# ================== CONFIRM ==================
echo
echo -e "${PURPLE}📋 Resumo:${RESET}"
echo "URL: $APP_URL"
echo "Admin: $ADMIN_EMAIL"
echo "Cloudflare: $USE_CF"
read -rp "Continuar? (Y/n): " CONFIRM
CONFIRM="${CONFIRM:-Y}"
[[ ! "$CONFIRM" =~ ^[Yy]$ ]] && exit 0

# ================== INSTALL ==================
install_docker
install_compose

# ================== SETUP ==================
mkdir -p /opt/pterodactyl/panel
cd /opt/pterodactyl/panel
mkdir -p data/{database,var,logs}

# ================== DOCKER COMPOSE ==================
cat <<EOF > docker-compose.yml
version: "3.8"

services:
  database:
    image: mariadb:10.5
    restart: always
    environment:
      MYSQL_DATABASE: panel
      MYSQL_USER: pterodactyl
      MYSQL_PASSWORD: "${DB_PASS}"
      MYSQL_ROOT_PASSWORD: "${DB_PASS}"
    volumes:
      - ./data/database:/var/lib/mysql

  cache:
    image: redis:alpine
    restart: always

  panel:
    image: ghcr.io/pterodactyl/panel:latest
    restart: always
    depends_on:
      - database
      - cache
    ports:
      - "${PANEL_PORT}:80"
    environment:
      APP_URL: "${APP_URL}"
      APP_TIMEZONE: UTC
      APP_SERVICE_AUTHOR: "${ADMIN_EMAIL}"
      TRUSTED_PROXIES: "*"
      DB_HOST: database
      DB_PORT: 3306
      DB_DATABASE: panel
      DB_USERNAME: pterodactyl
      DB_PASSWORD: "${DB_PASS}"
      CACHE_DRIVER: redis
      SESSION_DRIVER: redis
      QUEUE_DRIVER: redis
      REDIS_HOST: cache
      APP_ENV: production
    volumes:
      - ./data/var:/app/var
      - ./data/logs:/app/storage/logs
EOF

# ================== START ==================
echo "🚀 Iniciando containers..."
$COMPOSE up -d
sleep 10

# ================== ADMIN ==================
echo "👤 Criando administrador..."
$COMPOSE run --rm panel php artisan p:user:make \
  --email="$ADMIN_EMAIL" \
  --username=admin \
  --name-first=Admin \
  --name-last=User \
  --admin=1

# ================== CLOUDFLARED ==================
if [ "$USE_CF" = true ]; then
  echo "☁️ Instalando Cloudflared..."
  if ! command -v cloudflared >/dev/null; then
    curl -L https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64 \
      -o /usr/local/bin/cloudflared
    chmod +x /usr/local/bin/cloudflared
  fi
  cloudflared tunnel run --token "$CLOUDFLARED_TOKEN" >/tmp/cloudflared.log 2>&1 &
fi

# ================== DONE ==================
echo
echo -e "${PURPLE}✅ Pterodactyl instalado com sucesso!${RESET}"
echo -e "${PURPLE}🌐 Painel: ${APP_URL}${RESET}"
echo -e "${PURPLE}☁️ Cloudflare ativo se configurado${RESET}"
