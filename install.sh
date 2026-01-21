#!/bin/bash

# Pterodactyl Installer TUDO-EM-UM para GitHub Codespaces + Cloudflare Tunnel
# Instala painel, wings e configura túneis automaticamente

set -e

# Enhanced Colors
PURPLE='\033[38;5;57m'
DARK_PURPLE='\033[38;5;93m'
GREEN='\033[0;32m'
BRIGHT_GREEN='\033[1;32m'
RED='\033[0;31m'
BRIGHT_RED='\033[1;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BRIGHT_BLUE='\033[1;34m'
CYAN='\033[0;36m'
BRIGHT_CYAN='\033[1;36m'
WHITE='\033[1;37m'
GRAY='\033[0;90m'
NC='\033[0m'

# Variáveis
WORKSPACE="/workspaces/$(basename $(pwd))"
PANEL_DIR="$WORKSPACE/pterodactyl"
WINGS_DIR="$WORKSPACE/wings"
CF_TUNNEL_TOKEN=""
DOMAIN_BASE=""

# Enhanced Output Functions
output() { 
    echo -e "    ${GRAY}●${NC} $1" 
}

success() { 
    echo -e "    ${BRIGHT_GREEN}✓ SUCCESS${NC} $1" 
}

error() { 
    echo -e "    ${BRIGHT_RED}✗ ERROR${NC} $1" 1>&2 
}

warning() { 
    echo -e "    ${YELLOW}⚠ WARNING${NC} $1" 
}

info() { 
    echo -e "    ${BRIGHT_BLUE}ℹ INFO${NC} $1" 
}

section() {
    echo -e "\n    ${GRAY}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "    ${BRIGHT_CYAN}$1${NC}"
    echo -e "    ${GRAY}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
}

print_brake() {
    for ((n = 0; n < $1; n++)); do echo -n "#"; done
    echo ""
}

# Logo
show_logo() {
    clear
    # Definição de cores (certifique-se de ter essas variáveis no início do seu script)
    PURPLE='\033[0;35m'
    NC='\033[0m' # No Color

    echo -e "${PURPLE}  ██╗  ██╗ █████╗ ██████╗ ██╗██╗   ██╗███╗   ███╗${NC}"
    echo -e "${PURPLE}  ██║  ██║██╔══██╗██╔══██╗██║██║   ██║████╗ ████║${NC}"
    echo -e "${PURPLE}  ███████║███████║██████╔╝██║██║   ██║██╔████╔██║${NC}"
    echo -e "${PURPLE}  ██╔══██║██╔══██║██╔══██╗██║██║   ██║██║╚██╔╝██║${NC}"
    echo -e "${PURPLE}  ██║  ██║██║  ██║██║  ██║██║╚██████╔╝██║ ╚═╝ ██║${NC}"
    echo -e "${PURPLE}  ╚═╝  ╚═╝╚═╝  ╚═╝╚═╝  ╚═╝╚═╝ ╚═════╝ ╚═╝     ╚═╝${NC}"
    echo ""
    echo "=================================================="
    echo "       Pterodactyl Install + Cloudflare Tunnel    "
    echo "=================================================="
    echo ""
}

# Verificar ambiente Codespaces
check_environment() {
    output "Verificando ambiente Codespaces..."
    
    if [ ! -d "/workspaces" ]; then
        error "Este script deve ser executado no GitHub Codespaces!"
        exit 1
    fi
    
    success "Ambiente Codespaces OK"
}

# Instalar dependências do sistema
install_system_deps() {
    output "Instalando dependências do sistema..."
    
    sudo apt-get update -qq
    sudo apt-get install -yqq \
        curl git unzip \
        mariadb-server mariadb-client \
        redis-server \
        php8.3 php8.3-cli php8.3-mysql php8.3-redis \
        php8.3-curl php8.3-gd php8.3-mbstring php8.3-bcmath \
        php8.3-xml php8.3-zip php8.3-intl \
        composer docker.io
    
    success "Dependências instaladas"
}

# Configurar MariaDB
setup_database() {
    output "Configurando MariaDB..."
    
    sudo service mariadb start
    
    # Configuração básica
    sudo mysql -e "DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');"
    sudo mysql -e "DROP DATABASE IF EXISTS test;"
    sudo mysql -e "DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';"
    sudo mysql -e "FLUSH PRIVILEGES;"
    
    # Criar banco e usuário
    sudo mysql -e "CREATE DATABASE IF NOT EXISTS panel;"
    sudo mysql -e "CREATE USER IF NOT EXISTS 'pterodactyl'@'localhost' IDENTIFIED BY 'password';"
    sudo mysql -e "GRANT ALL PRIVILEGES ON panel.* TO 'pterodactyl'@'localhost';"
    sudo mysql -e "FLUSH PRIVILEGES;"
    
    success "MariaDB configurado"
}

# Instalar Pterodactyl Panel
install_panel() {
    output "Instalando Pterodactyl Panel..."
    
    mkdir -p "$PANEL_DIR"
    cd "$PANEL_DIR"
    
    # Baixar última versão
    curl -L https://github.com/pterodactyl/panel/releases/latest/download/panel.tar.gz | tar -xz
    
    # Instalar dependências PHP
    composer install --no-dev --optimize-autoloader
    
    # Configurar .env
    cp .env.example .env
    php artisan key:generate --force
    
    # Configurar banco de dados
    sed -i "s/DB_DATABASE=.*/DB_DATABASE=panel/" .env
    sed -i "s/DB_USERNAME=.*/DB_USERNAME=pterodactyl/" .env
    sed -i "s/DB_PASSWORD=.*/DB_PASSWORD=password/" .env
    sed -i "s/APP_ENV=.*/APP_ENV=production/" .env
    sed -i "s/CACHE_DRIVER=.*/CACHE_DRIVER=redis/" .env
    sed -i "s/SESSION_DRIVER=.*/SESSION_DRIVER=redis/" .env
    sed -i "s/QUEUE_CONNECTION=.*/QUEUE_CONNECTION=redis/" .env
    
    # Migrações
    php artisan migrate --seed --force
    
    # Criar usuário admin
    php artisan p:user:make --email=admin@${DOMAIN_BASE} --username=admin --name-first=Admin --name-last=User --password=admin123 --admin=1
    
    success "Panel instalado"
}

# Instalar Wings (modo simulado)
install_wings() {
    output "Instalando Wings (simulado para Codespaces)..."
    
    mkdir -p "$WINGS_DIR"
    cd "$WINGS_DIR"
    
    # Wings requer Docker privileged e systemd - não disponível no Codespaces
    # Criando estrutura básica para simulação
    echo "# Wings simulado para Codespaces" > README.md
    echo "Wings requer Docker privileged mode e systemd." >> README.md
    echo "Estas funcionalidades não estão disponíveis no GitHub Codespaces." >> README.md
    
    success "Wings simulado criado"
}

# Instalar Cloudflared
install_cloudflared() {
    output "Instalando Cloudflared..."
    
    # Baixar e instalar cloudflared
    curl -L https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb -o cloudflared.deb
    sudo dpkg -i cloudflared.deb
    rm cloudflared.deb
    
    success "Cloudflared instalado"
}

# Configurar túneis Cloudflare
setup_cloudflare_tunnel() {
    output "Configurando túnel Cloudflare..."
    
    if [ -z "$CF_TUNNEL_TOKEN" ]; then
        error "Token do túnel Cloudflare não fornecido!"
        echo "Você precisa criar um túnel no Cloudflare Zero Trust e obter o token."
        echo ""
        echo "Passos:"
        echo "1. Acesse https://dash.cloudflare.com/"
        echo "2. Vá para Zero Trust > Access > Tunnels"
        echo "3. Crie um novo túnel"
        echo "4. Copie o token de autenticação"
        echo ""
        echo -n "Cole o token do túnel: "
        read -r CF_TUNNEL_TOKEN
    fi
    
    # Criar configuração do túnel
    mkdir -p "$HOME/.cloudflared"
    
    cat > "$HOME/.cloudflared/config.yml" << EOF
tunnel: pterodactyl-codespaces
credentials-file: $HOME/.cloudflared/credentials.json

ingress:
  - hostname: panel.${DOMAIN_BASE}
    service: http://localhost:8000
  - hostname: wings.${DOMAIN_BASE}
    service: http://localhost:8080
  - service: http_status:404
EOF
    
    # Autenticar túnel
    echo "$CF_TUNNEL_TOKEN" | cloudflared tunnel --config $HOME/.cloudflared/config.yml login
    
    success "Túnel Cloudflare configurado"
}

# Criar scripts de inicialização
create_startup_scripts() {
    output "Criando scripts de inicialização..."
    
    # Script para iniciar tudo
    cat > "$WORKSPACE/start-all.sh" << 'EOF'
#!/bin/bash

echo "🚀 Iniciando Pterodactyl + Cloudflare Tunnel..."
echo ""

# Iniciar MariaDB
echo "📦 Iniciando MariaDB..."
sudo service mariadb start

# Iniciar Redis
echo "キャッシング Iniciando Redis..."
sudo service redis-server start

# Iniciar túnel Cloudflare
echo "☁️  Iniciando Cloudflare Tunnel..."
cloudflared tunnel --config $HOME/.cloudflared/config.yml run &

# Aguardar túnel iniciar
sleep 5

# Iniciar Panel
echo "🎮 Iniciando Pterodactyl Panel..."
cd /workspaces/*/pterodactyl
php artisan serve --host=0.0.0.0 --port=8000 &

# Iniciar Wings simulado
echo "🐳 Iniciando Wings (simulado)..."
echo "Wings não está disponível no Codespaces" > /tmp/wings-status.txt

echo ""
echo "✅ Tudo iniciado!"
echo "🔗 Acesse:"
echo "   Panel: https://panel.$(cat /tmp/domain_base)"
echo "   Wings: https://wings.$(cat /tmp/domain_base)"
echo ""
echo "Pressione CTRL+C para parar tudo"
wait
EOF

    chmod +x "$WORKSPACE/start-all.sh"
    
    success "Scripts de inicialização criados"
}

# Enhanced Main Menu
show_main_menu() {
    clear
    show_logo
    
    echo -e "    ${GRAY}┌─${BRIGHT_CYAN} MENU PRINCIPAL ${GRAY}────────────────────────────────┐${NC}"
    echo -e "    ${GRAY}│${NC}                                                ${GRAY}│${NC}"
    echo -e "    ${GRAY}│${NC}  ${BRIGHT_GREEN}1${NC}) 📦 ${WHITE}Instalar tudo automaticamente${NC}        ${GRAY}│${NC}"
    echo -e "    ${GRAY}│${NC}  ${YELLOW}2${NC}) ⚙️  ${WHITE}Instalar apenas dependências${NC}         ${GRAY}│${NC}"
    echo -e "    ${GRAY}│${NC}  ${BRIGHT_BLUE}3${NC}) ☁️  ${WHITE}Configurar Cloudflare Tunnel${NC}        ${GRAY}│${NC}"
    echo -e "    ${GRAY}│${NC}  ${PURPLE}4${NC}) ▶️  ${WHITE}Iniciar serviços${NC}                   ${GRAY}│${NC}"
    echo -e "    ${GRAY}│${NC}                                                ${GRAY}│${NC}"
    echo -e "    ${GRAY}│${NC}  ${BRIGHT_RED}0${NC}) 🚪 ${WHITE}Sair${NC}                              ${GRAY}│${NC}"
    echo -e "    ${GRAY}└────────────────────────────────────────────────┘${NC}"
    echo ""
    echo -n "    ${BRIGHT_CYAN}➤${NC} Selecione uma opção: "
}

# Complete Installation Process
install_everything() {
    section "🚀 INICIANDO INSTALAÇÃO COMPLETA"
    
    # Solicitar domínio base
    echo -n "    ${BRIGHT_CYAN}➤${NC} Digite seu domínio base ${GRAY}(ex: meuprojeto.com)${NC}: "
    read -r DOMAIN_BASE
    
    if [ -z "$DOMAIN_BASE" ]; then
        error "Domínio base é obrigatório!"
        return 1
    fi
    
    echo "$DOMAIN_BASE" > /tmp/domain_base
    
    info "Domínio configurado: $DOMAIN_BASE"
    
    # Processo de instalação
    section "📦 INSTALANDO DEPENDÊNCIAS DO SISTEMA"
    install_system_deps
    
    section "🗄️  CONFIGURANDO BANCO DE DADOS"
    setup_database
    
    section "🎮 INSTALANDO PTERODACTYL PANEL"
    install_panel
    
    section "🐳 PREPARANDO WINGS (SIMULADO)"
    install_wings
    
    section "☁️  CONFIGURANDO CLOUDFLARE TUNNEL"
    install_cloudflared
    setup_cloudflare_tunnel
    
    section "⚙️  CRIANDO SCRIPTS DE INICIALIZAÇÃO"
    create_startup_scripts
    
    # Mensagem final
    clear
    show_logo
    
    echo -e "    ${GRAY}┌─${BRIGHT_GREEN} INSTALAÇÃO CONCLUÍDA COM SUCESSO! ${GRAY}────────────┐${NC}"
    echo -e "    ${GRAY}│${NC}                                                ${GRAY}│${NC}"
    echo -e "    ${GRAY}│${NC}  ${WHITE}📋 PRÓXIMOS PASSOS:${NC}                          ${GRAY}│${NC}"
    echo -e "    ${GRAY}│${NC}  ${BRIGHT_GREEN}1.${NC} Execute: ${BRIGHT_CYAN}./start-all.sh${NC}              ${GRAY}│${NC}"
    echo -e "    ${GRAY}│${NC}                                                ${GRAY}│${NC}"
    echo -e "    ${GRAY}│${NC}  ${WHITE}🔗 Acesse:${NC}                                   ${GRAY}│${NC}"
    echo -e "    ${GRAY}│${NC}  Panel: ${BRIGHT_BLUE}https://panel.$DOMAIN_BASE${NC}        ${GRAY}│${NC}"
    echo -e "    ${GRAY}│${NC}  Wings: ${BRIGHT_BLUE}https://wings.$DOMAIN_BASE${NC}        ${GRAY}│${NC}"
    echo -e "    ${GRAY}│${NC}                                                ${GRAY}│${NC}"
    echo -e "    ${GRAY}│${NC}  ${WHITE}🔐 Credenciais:${NC}                              ${GRAY}│${NC}"
    echo -e "    ${GRAY}│${NC}  Email: ${YELLOW}admin@$DOMAIN_BASE${NC}               ${GRAY}│${NC}"
    echo -e "    ${GRAY}│${NC}  Senha: ${YELLOW}admin123${NC}                         ${GRAY}│${NC}"
    echo -e "    ${GRAY}│${NC}                                                ${GRAY}│${NC}"
    echo -e "    ${GRAY}│${NC}  ${WHITE}⚠️  IMPORTANTE:${NC}                              ${GRAY}│${NC}"
    echo -e "    ${GRAY}│${NC}  • Configure DNS no Cloudflare              ${GRAY}│${NC}"
    echo -e "    ${GRAY}│${NC}  • Wings em modo simulado                   ${GRAY}│${NC}"
    echo -e "    ${GRAY}│${NC}  • Ambiente para desenvolvimento            ${GRAY}│${NC}"
    echo -e "    ${GRAY}└────────────────────────────────────────────────┘${NC}"
    echo ""
    echo -n "    ${BRIGHT_CYAN}➤${NC} Pressione ENTER para continuar... "
    read -r
}

# Install Dependencies Only
install_deps_only() {
    section "⚙️  INSTALANDO APENAS DEPENDÊNCIAS"
    
    install_system_deps
    setup_database
    
    success "Dependências instaladas com sucesso!"
    info "Agora você pode instalar o resto manualmente."
    
    echo -n "    ${BRIGHT_CYAN}➤${NC} Pressione ENTER para continuar... "
    read -r
}

# Setup Cloudflare Only
setup_cf_only() {
    section "☁️  CONFIGURANDO APENAS CLOUDFLARE TUNNEL"
    
    echo -n "    ${BRIGHT_CYAN}➤${NC} Digite seu domínio base: "
    read -r DOMAIN_BASE
    
    if [ -z "$DOMAIN_BASE" ]; then
        error "Domínio base é obrigatório!"
        echo -n "    ${BRIGHT_CYAN}➤${NC} Pressione ENTER para continuar... "
        read -r
        return 1
    fi
    
    echo "$DOMAIN_BASE" > /tmp/domain_base
    
    install_cloudflared
    setup_cloudflare_tunnel
    create_startup_scripts
    
    success "Cloudflare Tunnel configurado com sucesso!"
    echo -n "    ${BRIGHT_CYAN}➤${NC} Pressione ENTER para continuar... "
    read -r
}

# Start Services
start_services() {
    section "▶️  INICIANDO TODOS OS SERVIÇOS"
    
    if [ ! -f "./start-all.sh" ]; then
        error "Script start-all.sh não encontrado!"
        warning "Execute primeiro a instalação completa."
        echo -n "    ${BRIGHT_CYAN}➤${NC} Pressione ENTER para continuar... "
        read -r
        return 1
    fi
    
    info "Iniciando todos os serviços..."
    ./start-all.sh
}

# Main Menu Loop
main() {
    while true; do
        show_main_menu
        read -r choice
        
        case $choice in
            1)
                install_everything
                ;;
            2)
                install_deps_only
                ;;
            3)
                setup_cf_only
                ;;
            4)
                start_services
                ;;
            0)
                clear
                show_logo
                echo -e "    ${GRAY}┌─${BRIGHT_CYAN} ATÉ MAIS! ${GRAY}───────────────────────────────────┐${NC}"
                echo -e "    ${GRAY}│${NC}                                                ${GRAY}│${NC}"
                echo -e "    ${GRAY}│${NC}  ${WHITE}👋 Obrigado por usar o Pterodactyl Installer!${NC}  ${GRAY}│${NC}"
                echo -e "    ${GRAY}│${NC}  ${WHITE}Volte sempre que precisar!${NC}                    ${GRAY}│${NC}"
                echo -e "    ${GRAY}└────────────────────────────────────────────────┘${NC}"
                echo ""
                exit 0
                ;;
            *)
                error "Opção inválida!"
                echo -n "    ${BRIGHT_CYAN}➤${NC} Pressione ENTER para continuar... "
                read -r
                ;;
        esac
    done
}

# Executar
main
