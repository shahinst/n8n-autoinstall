#!/bin/bash

# n8n Service Installation Script
# Auto-installs n8n as a system service with management menu
# Created by Digicloud Company

# Exit on any error
set -e

# Set non-interactive mode for all installations
export DEBIAN_FRONTEND=noninteractive
export NEEDRESTART_MODE=a

# Configuration Variables
N8N_DIR="/opt/n8n"
DOCKER_COMPOSE_FILE="$N8N_DIR/docker-compose.yml"
LOG_FILE="$N8N_DIR/install.log"
SERVICE_FILE="/usr/local/bin/n8n"
CONFIG_FILE="$N8N_DIR/config.txt"
DB_USER="n8n"
DB_NAME="n8ndb"
DB_VERSION="postgres:15"
DB_TYPE="PostgreSQL 15"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}❌ Please run as root or with sudo${NC}"
    exit 1
fi

# Progress bar function
show_progress() {
    local current=$1
    local total=$2
    local message=$3
    local percent=$((current * 100 / total))
    local filled=$((percent / 2))
    local empty=$((50 - filled))
    
    printf "\r${GREEN}[%s%s] %d%% - %s${NC}" \
        "$(printf '%*s' "$filled" | tr ' ' '█')" \
        "$(printf '%*s' "$empty" | tr ' ' '░')" \
        "$percent" \
        "$message"
}

# Function to detect OS
detect_os() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$ID
        VERSION_ID=$VERSION_ID
        echo -e "${BLUE}🖥️  Detected OS: $OS $VERSION_ID${NC}"
    else
        echo -e "${RED}❌ Unsupported OS: Cannot detect operating system${NC}"
        exit 1
    fi
}

# Function to validate domain
validate_domain() {
    local domain=$1
    
    # Check if domain is empty or is an IP address
    if [ -z "$domain" ] || [[ $domain =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        return 1
    fi
    
    # Basic domain validation
    if [[ ! $domain =~ ^[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*$ ]]; then
        return 1
    fi
    
    # Check if domain resolves
    echo -e "${YELLOW}🔍 Checking DNS resolution for $domain...${NC}"
    if ! host $domain >/dev/null 2>&1 && ! nslookup $domain >/dev/null 2>&1 && ! dig $domain >/dev/null 2>&1; then
        echo -e "${YELLOW}⚠️  Warning: Domain does not resolve to any IP address${NC}"
        echo -e "${YELLOW}⚠️  Make sure your DNS is properly configured${NC}"
        read -p "Do you want to continue anyway? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            return 1
        fi
    fi
    
    # Check if domain points to this server
    SERVER_IP=$(hostname -I | awk '{print $1}')
    DOMAIN_IP=$(host $domain 2>/dev/null | grep "has address" | awk '{print $4}' | head -1)
    
    if [ -n "$DOMAIN_IP" ] && [ "$DOMAIN_IP" != "$SERVER_IP" ]; then
        echo -e "${YELLOW}⚠️  Warning: Domain points to $DOMAIN_IP but server IP is $SERVER_IP${NC}"
        read -p "Do you want to continue anyway? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            return 1
        fi
    fi
    
    return 0
}

# Function to install dependencies
install_dependencies() {
    echo ""
    echo -e "${CYAN}📦 Installing dependencies for $OS $VERSION_ID...${NC}"
    echo ""
    
    local total_steps=10
    local current_step=0
    
    case $OS in
        ubuntu|debian)
            current_step=$((current_step + 1))
            show_progress $current_step $total_steps "Updating package lists..."
            apt-get update -y > "$LOG_FILE" 2>&1
            
            current_step=$((current_step + 1))
            show_progress $current_step $total_steps "Installing basic utilities..."
            apt-get install -y -qq curl wget git openssl ca-certificates gnupg lsb-release net-tools dnsutils >> "$LOG_FILE" 2>&1
            
            # Install Docker if not present
            if ! command -v docker &> /dev/null; then
                current_step=$((current_step + 1))
                show_progress $current_step $total_steps "Adding Docker GPG key..."
                mkdir -p /etc/apt/keyrings
                curl -fsSL https://download.docker.com/linux/$OS/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg >> "$LOG_FILE" 2>&1
                
                current_step=$((current_step + 1))
                show_progress $current_step $total_steps "Adding Docker repository..."
                echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/$OS $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
                apt-get update -y >> "$LOG_FILE" 2>&1
                
                current_step=$((current_step + 1))
                show_progress $current_step $total_steps "Installing Docker Engine..."
                apt-get install -y -qq docker-ce docker-ce-cli containerd.io docker-compose-plugin >> "$LOG_FILE" 2>&1
            else
                current_step=$((current_step + 3))
                show_progress $current_step $total_steps "Docker already installed, skipping..."
                sleep 1
            fi
            
            # Install Docker Compose
            if ! command -v docker-compose &> /dev/null; then
                current_step=$((current_step + 1))
                show_progress $current_step $total_steps "Installing Docker Compose..."
                apt-get install -y -qq docker-compose >> "$LOG_FILE" 2>&1
                
                if ! command -v docker-compose &> /dev/null; then
                    curl -SL https://github.com/docker/compose/releases/download/v2.16.0/docker-compose-linux-x86_64 -o /usr/local/bin/docker-compose >> "$LOG_FILE" 2>&1
                    chmod +x /usr/local/bin/docker-compose
                fi
            else
                current_step=$((current_step + 1))
                show_progress $current_step $total_steps "Docker Compose already installed..."
                sleep 1
            fi
            
            current_step=$((current_step + 1))
            show_progress $current_step $total_steps "Installing Nginx..."
            apt-get install -y -qq nginx >> "$LOG_FILE" 2>&1
            
            # Configure UFW if active
            if command -v ufw &> /dev/null && ufw status | grep -q "Status: active"; then
                current_step=$((current_step + 1))
                show_progress $current_step $total_steps "Configuring UFW firewall..."
                ufw allow 80/tcp >> "$LOG_FILE" 2>&1
                ufw allow 443/tcp >> "$LOG_FILE" 2>&1
                ufw allow 5678/tcp >> "$LOG_FILE" 2>&1
            fi
            ;;
            
        centos|rhel|almalinux|rocky)
            if command -v dnf &> /dev/null; then
                current_step=$((current_step + 1))
                show_progress $current_step $total_steps "Updating system packages..."
                dnf -y -q update >> "$LOG_FILE" 2>&1
                
                current_step=$((current_step + 1))
                show_progress $current_step $total_steps "Installing basic utilities..."
                dnf -y -q install curl wget openssl ca-certificates net-tools bind-utils >> "$LOG_FILE" 2>&1
                
                if ! command -v docker &> /dev/null; then
                    current_step=$((current_step + 1))
                    show_progress $current_step $total_steps "Adding Docker repository..."
                    dnf -y -q install dnf-plugins-core >> "$LOG_FILE" 2>&1
                    dnf config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo >> "$LOG_FILE" 2>&1
                    
                    current_step=$((current_step + 1))
                    show_progress $current_step $total_steps "Installing Docker..."
                    dnf -y -q install docker-ce docker-ce-cli containerd.io >> "$LOG_FILE" 2>&1
                else
                    current_step=$((current_step + 2))
                    show_progress $current_step $total_steps "Docker already installed..."
                    sleep 1
                fi
                
                current_step=$((current_step + 1))
                show_progress $current_step $total_steps "Installing Nginx..."
                dnf -y -q install nginx >> "$LOG_FILE" 2>&1
            else
                current_step=$((current_step + 1))
                show_progress $current_step $total_steps "Updating system packages..."
                yum -y -q update >> "$LOG_FILE" 2>&1
                
                current_step=$((current_step + 1))
                show_progress $current_step $total_steps "Installing basic utilities..."
                yum -y -q install curl wget openssl ca-certificates net-tools bind-utils >> "$LOG_FILE" 2>&1
                
                if ! command -v docker &> /dev/null; then
                    current_step=$((current_step + 1))
                    show_progress $current_step $total_steps "Adding Docker repository..."
                    yum -y -q install yum-utils >> "$LOG_FILE" 2>&1
                    yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo >> "$LOG_FILE" 2>&1
                    
                    current_step=$((current_step + 1))
                    show_progress $current_step $total_steps "Installing Docker..."
                    yum -y -q install docker-ce docker-ce-cli containerd.io >> "$LOG_FILE" 2>&1
                else
                    current_step=$((current_step + 2))
                    show_progress $current_step $total_steps "Docker already installed..."
                    sleep 1
                fi
                
                current_step=$((current_step + 1))
                show_progress $current_step $total_steps "Installing Nginx..."
                yum -y -q install nginx >> "$LOG_FILE" 2>&1
            fi
            
            if ! command -v docker-compose &> /dev/null; then
                current_step=$((current_step + 1))
                show_progress $current_step $total_steps "Installing Docker Compose..."
                curl -SL https://github.com/docker/compose/releases/download/v2.16.0/docker-compose-linux-x86_64 -o /usr/local/bin/docker-compose >> "$LOG_FILE" 2>&1
                chmod +x /usr/local/bin/docker-compose
                ln -sf /usr/local/bin/docker-compose /usr/bin/docker-compose
            else
                current_step=$((current_step + 1))
                show_progress $current_step $total_steps "Docker Compose already installed..."
                sleep 1
            fi
            
            current_step=$((current_step + 1))
            show_progress $current_step $total_steps "Starting services..."
            systemctl enable docker >> "$LOG_FILE" 2>&1
            systemctl start docker >> "$LOG_FILE" 2>&1
            systemctl enable nginx >> "$LOG_FILE" 2>&1
            systemctl start nginx >> "$LOG_FILE" 2>&1
            
            if command -v getenforce &> /dev/null && [ "$(getenforce)" != "Disabled" ]; then
                current_step=$((current_step + 1))
                show_progress $current_step $total_steps "Configuring SELinux..."
                setsebool -P httpd_can_network_connect 1 >> "$LOG_FILE" 2>&1
            fi
            
            if systemctl is-active --quiet firewalld; then
                current_step=$((current_step + 1))
                show_progress $current_step $total_steps "Configuring firewall..."
                firewall-cmd --permanent --add-service=http >> "$LOG_FILE" 2>&1
                firewall-cmd --permanent --add-service=https >> "$LOG_FILE" 2>&1
                firewall-cmd --permanent --add-port=5678/tcp >> "$LOG_FILE" 2>&1
                firewall-cmd --reload >> "$LOG_FILE" 2>&1
            fi
            ;;
            
        *)
            echo -e "${RED}❌ Unsupported OS: $OS${NC}"
            exit 1
            ;;
    esac
    
    current_step=$((current_step + 1))
    show_progress $current_step $total_steps "Ensuring Docker is running..."
    systemctl enable docker >> "$LOG_FILE" 2>&1
    systemctl start docker >> "$LOG_FILE" 2>&1
    
    current_step=$total_steps
    show_progress $current_step $total_steps "Dependencies installation completed!"
    echo ""
    echo ""
    echo -e "${GREEN}✅ All dependencies installed successfully!${NC}"
}

# Function to clean previous installation
clean_installation() {
    echo -e "${YELLOW}🧹 Cleaning previous installation...${NC}"
    
    # Stop and remove containers
    docker stop $(docker ps -q --filter ancestor=n8nio/n8n) 2>/dev/null || true
    docker rm $(docker ps -aq --filter ancestor=n8nio/n8n) 2>/dev/null || true
    docker stop n8n postgres 2>/dev/null || true
    docker rm n8n postgres 2>/dev/null || true
    docker rm -f n8n-n8n-1 n8n-postgres-1 2>/dev/null || true
    
    # Stop using docker-compose if exists
    if [ -f "$DOCKER_COMPOSE_FILE" ]; then
        cd $N8N_DIR
        docker-compose down 2>/dev/null || docker compose down 2>/dev/null || true
    fi
    
    # Remove volumes
    docker volume rm n8n_data postgres-data 2>/dev/null || true
    docker volume rm $(docker volume ls -q -f name=n8n) 2>/dev/null || true
    
    # Remove nginx config
    if [[ "$OS" == "ubuntu" || "$OS" == "debian" ]]; then
        rm -f /etc/nginx/sites-enabled/n8n
        rm -f /etc/nginx/sites-available/n8n
    else
        rm -f /etc/nginx/conf.d/n8n.conf
    fi
    
    # Reload nginx
    nginx -t && systemctl reload nginx 2>/dev/null || true
    
    # Remove installation directory but keep logs
    if [ -f "$LOG_FILE" ]; then
        cp "$LOG_FILE" "/tmp/n8n_install_backup.log" 2>/dev/null || true
    fi
    
    rm -rf $N8N_DIR
    mkdir -p $N8N_DIR
    
    if [ -f "/tmp/n8n_install_backup.log" ]; then
        mv "/tmp/n8n_install_backup.log" "$LOG_FILE" 2>/dev/null || true
    fi
    
    echo -e "${GREEN}✅ Previous installation cleaned!${NC}"
}

# Function to create docker-compose file
create_docker_compose() {
    local domain=$1
    local use_ssl=$2
    local db_pass=$3
    
    local protocol="http"
    local secure_cookie="false"
    
    if [ "$use_ssl" = true ]; then
        protocol="https"
        secure_cookie="true"
    fi
    
    cat > $DOCKER_COMPOSE_FILE <<EOF
version: "3.7"

services:
  postgres:
    image: $DB_VERSION
    restart: always
    environment:
      - POSTGRES_USER=$DB_USER
      - POSTGRES_PASSWORD=$db_pass
      - POSTGRES_DB=$DB_NAME
    volumes:
      - postgres-data:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U $DB_USER"]
      interval: 10s
      timeout: 5s
      retries: 5

  n8n:
    image: docker.n8n.io/n8nio/n8n
    restart: always
    ports:
      - "5678:5678"
    environment:
      - DB_TYPE=postgresdb
      - DB_POSTGRESDB_HOST=postgres
      - DB_POSTGRESDB_PORT=5432
      - DB_POSTGRESDB_DATABASE=$DB_NAME
      - DB_POSTGRESDB_USER=$DB_USER
      - DB_POSTGRESDB_PASSWORD=$db_pass
      - N8N_SECURE_COOKIE=$secure_cookie
      - N8N_HOST=$domain
      - N8N_PORT=5678
      - N8N_PROTOCOL=$protocol
      - WEBHOOK_URL=${protocol}://$domain/
    depends_on:
      postgres:
        condition: service_healthy
    volumes:
      - n8n_data:/home/node/.n8n

volumes:
  postgres-data:
  n8n_data:
EOF
}

# Function to configure nginx
configure_nginx() {
    local domain=$1
    
    # Remove default nginx config
    if [[ "$OS" == "ubuntu" || "$OS" == "debian" ]]; then
        rm -f /etc/nginx/sites-enabled/default
    fi
    
    # Determine Nginx configuration directory
    if [[ "$OS" == "centos" || "$OS" == "rhel" || "$OS" == "almalinux" || "$OS" == "rocky" ]]; then
        NGINX_CONF_DIR="/etc/nginx/conf.d"
        NGINX_CONF_FILE="$NGINX_CONF_DIR/n8n.conf"
    else
        NGINX_CONF_DIR="/etc/nginx/sites-available"
        NGINX_CONF_FILE="$NGINX_CONF_DIR/n8n"
    fi
    
    # Create Nginx configuration
    cat > $NGINX_CONF_FILE <<EOF
server {
    listen 80 default_server;
    listen [::]:80 default_server;
    server_name $domain _;
    
    client_max_body_size 50M;
    
    location / {
        proxy_pass http://127.0.0.1:5678;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_cache_bypass \$http_upgrade;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_read_timeout 300s;
        proxy_connect_timeout 75s;
    }
}
EOF
    
    # Enable the site
    if [[ "$OS" == "ubuntu" || "$OS" == "debian" ]]; then
        ln -sf $NGINX_CONF_FILE /etc/nginx/sites-enabled/n8n
    fi
    
    # Test and reload nginx
    if nginx -t >> "$LOG_FILE" 2>&1; then
        systemctl reload nginx >> "$LOG_FILE" 2>&1
        echo -e "${GREEN}✅ Nginx configured successfully${NC}"
    else
        echo -e "${RED}⚠️  Nginx configuration test failed${NC}"
        nginx -t
    fi
}

# Function to install SSL
install_ssl() {
    local domain=$1
    
    echo -e "${CYAN}🔐 Installing SSL certificate...${NC}"
    
    if [[ "$OS" == "ubuntu" || "$OS" == "debian" ]]; then
        apt-get install -y -qq certbot python3-certbot-nginx >> "$LOG_FILE" 2>&1
    elif [[ "$OS" == "centos" || "$OS" == "rhel" || "$OS" == "almalinux" || "$OS" == "rocky" ]]; then
        if command -v dnf &> /dev/null; then
            dnf -y -q install certbot python3-certbot-nginx >> "$LOG_FILE" 2>&1
        else
            yum -y -q install certbot python3-certbot-nginx >> "$LOG_FILE" 2>&1
        fi
    fi
    
    certbot --nginx --non-interactive --agree-tos --register-unsafely-without-email -d $domain >> "$LOG_FILE" 2>&1
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✅ SSL certificate installed successfully!${NC}"
        return 0
    else
        echo -e "${YELLOW}⚠️  SSL certificate installation failed. Continuing with HTTP.${NC}"
        return 1
    fi
}

# Function to start n8n
start_n8n() {
    echo -e "${CYAN}🚀 Starting n8n containers...${NC}"
    
    # Pull images first
    echo "📥 Pulling Docker images..."
    docker pull postgres:15 >> "$LOG_FILE" 2>&1
    docker pull docker.n8n.io/n8nio/n8n >> "$LOG_FILE" 2>&1
    
    cd $N8N_DIR
    
    # Try docker-compose or docker compose
    if docker-compose up -d >> "$LOG_FILE" 2>&1 || docker compose up -d >> "$LOG_FILE" 2>&1; then
        echo -e "${GREEN}✅ n8n started successfully!${NC}"
    else
        echo -e "${YELLOW}⚠️  Docker Compose failed, trying direct Docker method...${NC}"
        
        # Read database password from docker-compose file
        DB_PASS=$(grep "POSTGRES_PASSWORD" $DOCKER_COMPOSE_FILE | cut -d'=' -f2)
        DOMAIN=$(grep "N8N_HOST" $DOCKER_COMPOSE_FILE | tail -1 | cut -d'=' -f2)
        
        docker volume create n8n_data >> "$LOG_FILE" 2>&1
        docker volume create postgres-data >> "$LOG_FILE" 2>&1
        
        # Start postgres
        docker run -d --name postgres --restart always \
          -e POSTGRES_USER=$DB_USER \
          -e POSTGRES_PASSWORD=$DB_PASS \
          -e POSTGRES_DB=$DB_NAME \
          -v postgres-data:/var/lib/postgresql/data \
          postgres:15 >> "$LOG_FILE" 2>&1
        
        sleep 10
        
        # Start n8n
        docker run -d --name n8n --restart always -p 5678:5678 \
          --link postgres:postgres \
          -e DB_TYPE=postgresdb \
          -e DB_POSTGRESDB_HOST=postgres \
          -e DB_POSTGRESDB_PORT=5432 \
          -e DB_POSTGRESDB_DATABASE=$DB_NAME \
          -e DB_POSTGRESDB_USER=$DB_USER \
          -e DB_POSTGRESDB_PASSWORD=$DB_PASS \
          -e N8N_HOST=$DOMAIN \
          -e N8N_PORT=5678 \
          -v n8n_data:/home/node/.n8n \
          docker.n8n.io/n8nio/n8n >> "$LOG_FILE" 2>&1
        
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}✅ n8n started using direct Docker method!${NC}"
        else
            echo -e "${RED}❌ Failed to start n8n${NC}"
            exit 1
        fi
    fi
}

# Function to wait for n8n
wait_for_n8n() {
    echo ""
    echo -e "${CYAN}🔍 Waiting for n8n to start (this may take 30-60 seconds)...${NC}"
    
    WAIT_COUNT=0
    MAX_WAIT=30
    
    while [ $WAIT_COUNT -lt $MAX_WAIT ]; do
        if curl -s -o /dev/null -w "%{http_code}" http://localhost:5678 | grep -q "200\|302"; then
            echo -e "${GREEN}✅ n8n is running and responding!${NC}"
            return 0
        fi
        
        WAIT_COUNT=$((WAIT_COUNT + 1))
        if [ $WAIT_COUNT -eq $MAX_WAIT ]; then
            echo -e "${YELLOW}⚠️  n8n is taking longer than expected to start${NC}"
            echo "📋 Checking container status..."
            docker ps -a | grep -E "n8n|postgres"
            return 1
        else
            echo "⏳ Still waiting... ($WAIT_COUNT/$MAX_WAIT)"
            sleep 2
        fi
    done
}

# Function to save configuration
save_config() {
    local domain=$1
    local has_ssl=$2
    local db_pass=$3
    
    cat > $CONFIG_FILE <<EOF
DOMAIN=$domain
HAS_SSL=$has_ssl
DB_PASSWORD=$db_pass
INSTALLED_DATE=$(date)
EOF
    
    chmod 600 $CONFIG_FILE
}

# Function to save database info
save_database_info() {
    local db_pass=$1
    
    cat > $N8N_DIR/database_info.txt <<EOF
# n8n Database Information
# ====================================
Database Type: $DB_TYPE
Database Name: $DB_NAME
Database User: $DB_USER
Database Password: $db_pass
Database Host: postgres (Docker container)
Database Port: 5432

# Connection Information
# ------------------------------------
* These details may be needed if you want to connect to the database directly.
* For most users, this is not necessary as n8n manages the database connection.

# Security Notice
# ------------------------------------
* Keep this information secure!
* This file is stored at: $N8N_DIR/database_info.txt
EOF
    
    chmod 600 $N8N_DIR/database_info.txt
}

# Function to install n8n with domain
install_with_domain() {
    clear
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}       Installing n8n with Domain${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
    echo ""
    
    read -p "Enter your domain name (e.g., n8n.example.com): " DOMAIN
    
    if ! validate_domain "$DOMAIN"; then
        echo -e "${RED}❌ Invalid domain or domain validation failed${NC}"
        read -p "Press Enter to continue..."
        return
    fi
    
    echo ""
    echo -e "${GREEN}✅ Domain validated: $DOMAIN${NC}"
    echo ""
    
    # Generate database password
    DB_PASS=$(openssl rand -hex 12)
    
    # Clean previous installation
    if [ -d "$N8N_DIR" ]; then
        clean_installation
    else
        mkdir -p $N8N_DIR
    fi
    
    # Install dependencies
    detect_os
    install_dependencies
    
    # Create docker-compose file
    echo -e "${CYAN}📄 Creating docker-compose configuration...${NC}"
    create_docker_compose "$DOMAIN" false "$DB_PASS"
    
    # Configure nginx
    echo -e "${CYAN}🌐 Configuring Nginx...${NC}"
    configure_nginx "$DOMAIN"
    
    # Start n8n
    start_n8n
    
    # Wait for n8n to be ready
    wait_for_n8n
    
    # Install SSL
    if install_ssl "$DOMAIN"; then
        # Update docker-compose with HTTPS
        create_docker_compose "$DOMAIN" true "$DB_PASS"
        
        echo -e "${CYAN}🔄 Restarting n8n with HTTPS...${NC}"
        cd $N8N_DIR
        docker-compose down >> "$LOG_FILE" 2>&1 || docker compose down >> "$LOG_FILE" 2>&1
        docker-compose up -d >> "$LOG_FILE" 2>&1 || docker compose up -d >> "$LOG_FILE" 2>&1
        
        wait_for_n8n
        
        save_config "$DOMAIN" "true" "$DB_PASS"
        ACCESS_URL="https://$DOMAIN"
    else
        save_config "$DOMAIN" "false" "$DB_PASS"
        ACCESS_URL="http://$DOMAIN"
    fi
    
    # Save database info
    save_database_info "$DB_PASS"
    
    # Final message
    echo ""
    echo -e "${GREEN}🎉 ═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}🎉 n8n Installation Complete!${NC}"
    echo -e "${GREEN}🎉 ═══════════════════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "🌍 Access n8n at: ${GREEN}$ACCESS_URL${NC}"
    echo ""
    echo -e "📊 Database Information:"
    echo "   Type:     $DB_TYPE"
    echo "   Name:     $DB_NAME"
    echo "   User:     $DB_USER"
    echo "   Password: $DB_PASS"
    echo ""
    echo -e "🔐 Database info saved to: $N8N_DIR/database_info.txt"
    echo -e "📜 Installation log: $LOG_FILE"
    echo ""
    read -p "Press Enter to continue..."
}

# Function to install n8n without domain
install_without_domain() {
    clear
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}       Installing n8n without Domain (IP Address)${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
    echo ""
    
    # Get server IP automatically
    SERVER_IP=$(hostname -I | awk '{print $1}')
    echo -e "🌐 Server IP: ${GREEN}$SERVER_IP${NC}"
    echo ""
    
    # Generate database password
    DB_PASS=$(openssl rand -hex 12)
    
    # Clean previous installation
    if [ -d "$N8N_DIR" ]; then
        clean_installation
    else
        mkdir -p $N8N_DIR
    fi
    
    # Install dependencies
    detect_os
    install_dependencies
    
    # Create docker-compose file
    echo -e "${CYAN}📄 Creating docker-compose configuration...${NC}"
    create_docker_compose "$SERVER_IP" false "$DB_PASS"
    
    # Configure nginx
    echo -e "${CYAN}🌐 Configuring Nginx...${NC}"
    configure_nginx "$SERVER_IP"
    
    # Start n8n
    start_n8n
    
    # Wait for n8n to be ready
    wait_for_n8n
    
    # Save configuration
    save_config "$SERVER_IP" "false" "$DB_PASS"
    
    # Save database info
    save_database_info "$DB_PASS"
    
    ACCESS_URL="http://$SERVER_IP"
    
    # Final message
    echo ""
    echo -e "${GREEN}🎉 ═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}🎉 n8n Installation Complete!${NC}"
    echo -e "${GREEN}🎉 ═══════════════════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "🌍 Access n8n at: ${GREEN}$ACCESS_URL${NC}"
    echo -e "🌍 Alternative: ${GREEN}http://$SERVER_IP:5678${NC}"
    echo ""
    echo -e "⚠️  ${YELLOW}IMPORTANT:${NC} If you're using a cloud provider, make sure to open:"
    echo "   • Port 80 (HTTP)"
    echo "   • Port 5678 (n8n direct access)"
    echo ""
    echo -e "📊 Database Information:"
    echo "   Type:     $DB_TYPE"
    echo "   Name:     $DB_NAME"
    echo "   User:     $DB_USER"
    echo "   Password: $DB_PASS"
    echo ""
    echo -e "🔐 Database info saved to: $N8N_DIR/database_info.txt"
    echo -e "📜 Installation log: $LOG_FILE"
    echo ""
    read -p "Press Enter to continue..."
}

# Function to change domain
change_domain() {
    clear
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}       Change n8n Domain${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
    echo ""
    
    # Check if n8n is installed
    if [ ! -f "$CONFIG_FILE" ]; then
        echo -e "${RED}❌ n8n is not installed. Please install it first.${NC}"
        read -p "Press Enter to continue..."
        return
    fi
    
    # Load current configuration
    source $CONFIG_FILE
    
    SERVER_IP=$(hostname -I | awk '{print $1}')
    
    echo -e "Current configuration:"
    if [[ "$DOMAIN" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        echo -e "  Mode: ${YELLOW}IP Address${NC}"
        echo -e "  Address: ${GREEN}$DOMAIN${NC}"
        echo ""
        echo "Options:"
        echo "  1. Switch to domain"
        echo "  2. Back to menu"
        echo ""
        read -p "Choose an option (1-2): " choice
        
        case $choice in
            1)
                read -p "Enter your domain name (e.g., n8n.example.com): " NEW_DOMAIN
                
                if ! validate_domain "$NEW_DOMAIN"; then
                    echo -e "${RED}❌ Invalid domain or domain validation failed${NC}"
                    read -p "Press Enter to continue..."
                    return
                fi
                
                echo ""
                echo -e "${CYAN}🔄 Switching to domain: $NEW_DOMAIN${NC}"
                
                # Update docker-compose
                create_docker_compose "$NEW_DOMAIN" false "$DB_PASSWORD"
                
                # Configure nginx
                configure_nginx "$NEW_DOMAIN"
                
                # Restart n8n
                echo -e "${CYAN}🔄 Restarting n8n...${NC}"
                cd $N8N_DIR
                docker-compose down >> "$LOG_FILE" 2>&1 || docker compose down >> "$LOG_FILE" 2>&1
                docker-compose up -d >> "$LOG_FILE" 2>&1 || docker compose up -d >> "$LOG_FILE" 2>&1
                
                wait_for_n8n
                
                # Try to install SSL
                if install_ssl "$NEW_DOMAIN"; then
                    create_docker_compose "$NEW_DOMAIN" true "$DB_PASSWORD"
                    
                    cd $N8N_DIR
                    docker-compose down >> "$LOG_FILE" 2>&1 || docker compose down >> "$LOG_FILE" 2>&1
                    docker-compose up -d >> "$LOG_FILE" 2>&1 || docker compose up -d >> "$LOG_FILE" 2>&1
                    
                    wait_for_n8n
                    
                    save_config "$NEW_DOMAIN" "true" "$DB_PASSWORD"
                    echo -e "${GREEN}✅ Successfully switched to: https://$NEW_DOMAIN${NC}"
                else
                    save_config "$NEW_DOMAIN" "false" "$DB_PASSWORD"
                    echo -e "${GREEN}✅ Successfully switched to: http://$NEW_DOMAIN${NC}"
                fi
                ;;
            2)
                return
                ;;
            *)
                echo -e "${RED}Invalid option${NC}"
                ;;
        esac
    else
        echo -e "  Mode: ${YELLOW}Domain${NC}"
        echo -e "  Domain: ${GREEN}$DOMAIN${NC}"
        echo -e "  SSL: ${GREEN}$HAS_SSL${NC}"
        echo ""
        echo "Options:"
        echo "  1. Change to a different domain"
        echo "  2. Switch to IP address"
        echo "  3. Back to menu"
        echo ""
        read -p "Choose an option (1-3): " choice
        
        case $choice in
            1)
                read -p "Enter new domain name (e.g., n8n.example.com): " NEW_DOMAIN
                
                if ! validate_domain "$NEW_DOMAIN"; then
                    echo -e "${RED}❌ Invalid domain or domain validation failed${NC}"
                    read -p "Press Enter to continue..."
                    return
                fi
                
                echo ""
                echo -e "${CYAN}🔄 Changing domain to: $NEW_DOMAIN${NC}"
                
                # Remove old SSL certificate if exists
                if [ "$HAS_SSL" = "true" ]; then
                    echo -e "${CYAN}🔐 Removing old SSL certificate...${NC}"
                    certbot delete --cert-name $DOMAIN --non-interactive >> "$LOG_FILE" 2>&1 || true
                fi
                
                # Update docker-compose
                create_docker_compose "$NEW_DOMAIN" false "$DB_PASSWORD"
                
                # Configure nginx
                configure_nginx "$NEW_DOMAIN"
                
                # Restart n8n
                echo -e "${CYAN}🔄 Restarting n8n...${NC}"
                cd $N8N_DIR
                docker-compose down >> "$LOG_FILE" 2>&1 || docker compose down >> "$LOG_FILE" 2>&1
                docker-compose up -d >> "$LOG_FILE" 2>&1 || docker compose up -d >> "$LOG_FILE" 2>&1
                
                wait_for_n8n
                
                # Try to install SSL
                if install_ssl "$NEW_DOMAIN"; then
                    create_docker_compose "$NEW_DOMAIN" true "$DB_PASSWORD"
                    
                    cd $N8N_DIR
                    docker-compose down >> "$LOG_FILE" 2>&1 || docker compose down >> "$LOG_FILE" 2>&1
                    docker-compose up -d >> "$LOG_FILE" 2>&1 || docker compose up -d >> "$LOG_FILE" 2>&1
                    
                    wait_for_n8n
                    
                    save_config "$NEW_DOMAIN" "true" "$DB_PASSWORD"
                    echo -e "${GREEN}✅ Successfully changed to: https://$NEW_DOMAIN${NC}"
                else
                    save_config "$NEW_DOMAIN" "false" "$DB_PASSWORD"
                    echo -e "${GREEN}✅ Successfully changed to: http://$NEW_DOMAIN${NC}"
                fi
                ;;
            2)
                echo ""
                echo -e "${CYAN}🔄 Switching to IP address: $SERVER_IP${NC}"
                
                # Remove SSL certificate if exists
                if [ "$HAS_SSL" = "true" ]; then
                    echo -e "${CYAN}🔐 Removing SSL certificate...${NC}"
                    certbot delete --cert-name $DOMAIN --non-interactive >> "$LOG_FILE" 2>&1 || true
                fi
                
                # Update docker-compose
                create_docker_compose "$SERVER_IP" false "$DB_PASSWORD"
                
                # Configure nginx
                configure_nginx "$SERVER_IP"
                
                # Restart n8n
                echo -e "${CYAN}🔄 Restarting n8n...${NC}"
                cd $N8N_DIR
                docker-compose down >> "$LOG_FILE" 2>&1 || docker compose down >> "$LOG_FILE" 2>&1
                docker-compose up -d >> "$LOG_FILE" 2>&1 || docker compose up -d >> "$LOG_FILE" 2>&1
                
                wait_for_n8n
                
                save_config "$SERVER_IP" "false" "$DB_PASSWORD"
                echo -e "${GREEN}✅ Successfully switched to: http://$SERVER_IP${NC}"
                ;;
            3)
                return
                ;;
            *)
                echo -e "${RED}Invalid option${NC}"
                ;;
        esac
    fi
    
    echo ""
    read -p "Press Enter to continue..."
}

# Function to reinstall n8n
reinstall_n8n() {
    clear
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}       Reinstall n8n${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "${YELLOW}⚠️  WARNING: This will remove all existing n8n data and workflows!${NC}"
    echo ""
    read -p "Are you sure you want to continue? (y/N): " -n 1 -r
    echo
    
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        return
    fi
    
    echo ""
    echo "Choose installation type:"
    echo "  1. Install with domain"
    echo "  2. Install without domain (IP)"
    echo "  3. Cancel"
    echo ""
    read -p "Choose an option (1-3): " choice
    
    case $choice in
        1)
            install_with_domain
            ;;
        2)
            install_without_domain
            ;;
        3)
            return
            ;;
        *)
            echo -e "${RED}Invalid option${NC}"
            read -p "Press Enter to continue..."
            ;;
    esac
}

# Function to show main menu
show_menu() {
    while true; do
        clear
        echo -e "${CYAN}"
        echo "###########################################"
        echo "#           Digicloud Company             #"
        echo "###########################################"
        echo "🌐 https://digicloud.host"
        echo "🌐 https://oxincloud.net"
        echo "🔗 GitHub: https://github.com/shahinst"
        echo -e "${NC}"
        echo ""
        echo -e "${GREEN}═══════════════════════════════════════${NC}"
        echo -e "${GREEN}       n8n Management Service${NC}"
        echo -e "${GREEN}═══════════════════════════════════════${NC}"
        echo ""
        
        # Check if n8n is installed
        if [ -f "$CONFIG_FILE" ]; then
            source $CONFIG_FILE
            echo -e "Status: ${GREEN}✅ Installed${NC}"
            echo -e "Domain/IP: ${GREEN}$DOMAIN${NC}"
            if [ "$HAS_SSL" = "true" ]; then
                echo -e "SSL: ${GREEN}✅ Enabled${NC}"
            else
                echo -e "SSL: ${YELLOW}❌ Disabled${NC}"
            fi
            
            # Check if containers are running
            if docker ps | grep -q "n8n"; then
                echo -e "Service: ${GREEN}🟢 Running${NC}"
            else
                echo -e "Service: ${RED}🔴 Stopped${NC}"
            fi
        else
            echo -e "Status: ${YELLOW}⚠️  Not Installed${NC}"
        fi
        
        echo ""
        echo "════════════════════════════════════════"
        echo ""
        echo "  1. Install n8n with domain"
        echo "  2. Install n8n without domain"
        echo "  3. Reinstall n8n"
        echo "  4. Change n8n domain"
        echo "  5. Exit"
        echo ""
        echo "════════════════════════════════════════"
        echo ""
        read -p "Choose an option (1-5): " choice
        
        case $choice in
            1)
                install_with_domain
                ;;
            2)
                install_without_domain
                ;;
            3)
                reinstall_n8n
                ;;
            4)
                change_domain
                ;;
            5)
                echo ""
                echo -e "${GREEN}👋 Goodbye!${NC}"
                echo ""
                exit 0
                ;;
            *)
                echo -e "${RED}Invalid option. Please try again.${NC}"
                sleep 2
                ;;
        esac
    done
}

# Main installation function (first time setup)
first_time_setup() {
    clear
    echo -e "${CYAN}"
    echo "###########################################"
    echo "#           Digicloud Company             #"
    echo "###########################################"
    echo "🌐 https://digicloud.host"
    echo "🌐 https://oxincloud.net"
    echo "🔗 GitHub: https://github.com/shahinst"
    echo -e "${NC}"
    echo ""
    echo -e "${GREEN}═══════════════════════════════════════${NC}"
    echo -e "${GREEN}   n8n Service Installer - First Setup${NC}"
    echo -e "${GREEN}═══════════════════════════════════════${NC}"
    echo ""
    
    # Create service command
    echo -e "${CYAN}📦 Creating n8n service command...${NC}"
    
    cat > $SERVICE_FILE <<'EOFSERVICE'
#!/bin/bash

# n8n Service Management Script
N8N_SCRIPT="/opt/n8n_service.sh"

if [ ! -f "$N8N_SCRIPT" ]; then
    echo "Error: n8n service script not found at $N8N_SCRIPT"
    exit 1
fi

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo "Please run with sudo: sudo n8n"
    exit 1
fi

bash "$N8N_SCRIPT"
EOFSERVICE
    
    chmod +x $SERVICE_FILE
    
    # Copy this script to persistent location
    cp "$0" /opt/n8n_service.sh
    chmod +x /opt/n8n_service.sh
    
    echo -e "${GREEN}✅ n8n service command created successfully!${NC}"
    echo ""
    echo -e "${GREEN}═══════════════════════════════════════${NC}"
    echo -e "${GREEN}   Installation Complete!${NC}"
    echo -e "${GREEN}═══════════════════════════════════════${NC}"
    echo ""
    echo -e "🎉 ${GREEN}n8n service has been installed successfully!${NC}"
    echo ""
    echo -e "📝 To manage n8n, run the following command:"
    echo -e "   ${CYAN}sudo n8n${NC}"
    echo ""
    echo -e "This will open the n8n management menu where you can:"
    echo "   • Install n8n with or without a domain"
    echo "   • Reinstall n8n"
    echo "   • Change domain settings"
    echo "   • And more..."
    echo ""
    echo -e "${YELLOW}⚠️  Important: Always use 'sudo n8n' to manage your n8n installation${NC}"
    echo ""
}

# Main execution
main() {
    # Check if this is first time setup or service menu
    if [ ! -f "$SERVICE_FILE" ]; then
        # First time setup
        first_time_setup
    else
        # Show service menu
        show_menu
    fi
}

# Run main function
main
