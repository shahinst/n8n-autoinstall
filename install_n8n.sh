#!/bin/bash

# Modified n8n installation script with automatic fixes
# Auto-accepts all prompts, shows progress, and fixes common issues

# Exit on any error
set -e

# Set non-interactive mode for all installations
export DEBIAN_FRONTEND=noninteractive
export NEEDRESTART_MODE=a

clear
echo -e "\e[1;36m"
echo "###########################################"
echo "#           Digicloud Company             #"
echo "###########################################"
echo "🌐 https://digicloud.host"
echo "🌐 https://oxincloud.net"
echo "🔗 GitHub: https://github.com/shahinst"
echo -e "\e[0m"

# Configuration Variables
N8N_DIR="/opt/n8n"
DOCKER_COMPOSE_FILE="$N8N_DIR/docker-compose.yml"
LOG_FILE="$N8N_DIR/install.log"
DB_USER="n8n"
DB_PASS=$(openssl rand -hex 8)
DB_NAME="n8ndb"
DB_VERSION="postgres:15"
DB_TYPE="PostgreSQL 15"

# Progress bar function
show_progress() {
    local current=$1
    local total=$2
    local message=$3
    local percent=$((current * 100 / total))
    local filled=$((percent / 2))
    local empty=$((50 - filled))
    
    printf "\r\e[1;32m[%s%s] %d%% - %s\e[0m" \
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
        echo "🖥️ Detected OS: $OS $VERSION_ID"
    else
        echo "❌ Unsupported OS: Cannot detect operating system"
        exit 1
    fi
}

# Function to install dependencies with progress
install_dependencies() {
    echo ""
    echo "📦 Installing dependencies for $OS $VERSION_ID..."
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
            apt-get install -y -qq curl wget git openssl ca-certificates gnupg lsb-release net-tools >> "$LOG_FILE" 2>&1
            
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
                dnf -y -q install curl wget openssl ca-certificates net-tools >> "$LOG_FILE" 2>&1
                
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
                yum -y -q install curl wget openssl ca-certificates net-tools >> "$LOG_FILE" 2>&1
                
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
            echo "❌ Unsupported OS: $OS"
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
    echo "✅ All dependencies installed successfully!"
}

# Check for previous installation - Auto-remove without prompting
if [ -d "$N8N_DIR" ]; then
    echo -e "\n⚠️  Previous n8n installation detected."
    echo "🧹 Auto-removing previous installation..."
    docker stop $(docker ps -q --filter ancestor=n8nio/n8n) 2>/dev/null || true
    docker rm $(docker ps -aq --filter ancestor=n8nio/n8n) 2>/dev/null || true
    docker stop n8n 2>/dev/null || true
    docker rm n8n 2>/dev/null || true
    docker rm -f n8n-n8n-1 n8n-postgres-1 2>/dev/null || true
    docker volume rm n8n_data postgres-data 2>/dev/null || true
    docker volume rm $(docker volume ls -q -f name=n8n) 2>/dev/null || true
    rm -rf $N8N_DIR
    echo "✅ Previous installation removed!"
fi

# Create installation directory
mkdir -p $N8N_DIR

# Get server IP automatically
SERVER_IP=$(hostname -I | awk '{print $1}')
echo ""
echo "🌐 Auto-detected Server IP: $SERVER_IP"

# Ask for domain with timeout
echo ""
echo "🌐 Enter domain for n8n (press Enter to use IP: $SERVER_IP): "
read -t 30 DOMAIN || DOMAIN=""

if [ -z "$DOMAIN" ]; then
    DOMAIN=$SERVER_IP
    USE_IP=true
    echo "📍 Using server IP: $DOMAIN"
else
    USE_IP=false
    echo "🌐 Using domain: $DOMAIN"
fi

# Detect OS and install dependencies
detect_os
install_dependencies

echo ""
echo "📄 Creating docker-compose configuration..."
cat > $DOCKER_COMPOSE_FILE <<EOF
version: "3.7"

services:
  postgres:
    image: $DB_VERSION
    restart: always
    environment:
      - POSTGRES_USER=$DB_USER
      - POSTGRES_PASSWORD=$DB_PASS
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
      - DB_POSTGRESDB_PASSWORD=$DB_PASS
      - N8N_SECURE_COOKIE=false
      - N8N_HOST=$DOMAIN
      - N8N_PORT=5678
      - N8N_PROTOCOL=http
      - WEBHOOK_URL=http://$DOMAIN/
    depends_on:
      postgres:
        condition: service_healthy
    volumes:
      - n8n_data:/home/node/.n8n

volumes:
  postgres-data:
  n8n_data:
EOF

echo "🚀 Starting Docker containers..."
cd $N8N_DIR

# Pull images first
echo "📥 Pulling Docker images (this may take a few minutes)..."
docker pull postgres:15 >> "$LOG_FILE" 2>&1
docker pull docker.n8n.io/n8nio/n8n >> "$LOG_FILE" 2>&1

# Start containers
if ! docker-compose up -d >> "$LOG_FILE" 2>&1; then
    if ! docker compose up -d >> "$LOG_FILE" 2>&1; then
        echo "⚠️ Docker Compose failed, trying direct Docker run method..."
        docker stop n8n postgres 2>/dev/null || true
        docker rm n8n postgres 2>/dev/null || true
        
        docker volume create n8n_data >> "$LOG_FILE" 2>&1
        docker volume create postgres-data >> "$LOG_FILE" 2>&1
        
        # Start postgres first
        docker run -d --name postgres --restart always \
          -e POSTGRES_USER=$DB_USER \
          -e POSTGRES_PASSWORD=$DB_PASS \
          -e POSTGRES_DB=$DB_NAME \
          -v postgres-data:/var/lib/postgresql/data \
          postgres:15 >> "$LOG_FILE" 2>&1
        
        echo "⏳ Waiting for PostgreSQL to start..."
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
          -e N8N_SECURE_COOKIE=false \
          -e N8N_HOST=$DOMAIN \
          -e N8N_PORT=5678 \
          -e N8N_PROTOCOL=http \
          -v n8n_data:/home/node/.n8n \
          docker.n8n.io/n8nio/n8n >> "$LOG_FILE" 2>&1
        
        if [ $? -ne 0 ]; then
            echo "❌ Installation failed. Check the log at $LOG_FILE"
            exit 1
        fi
        echo "✅ Started n8n using direct Docker method!"
    fi
fi

echo "🌐 Configuring NGINX..."

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

# Create Nginx configuration - FIXED for IP access
cat > $NGINX_CONF_FILE <<EOF
server {
    listen 80 default_server;
    listen [::]:80 default_server;
    server_name $DOMAIN _;
    
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
nginx -t >> "$LOG_FILE" 2>&1
if [ $? -ne 0 ]; then
    echo "⚠️ Nginx configuration test failed, checking logs..."
    nginx -t
fi

systemctl reload nginx >> "$LOG_FILE" 2>&1

# Wait for n8n to be ready
echo ""
echo "🔍 Waiting for n8n to start (this may take 30-60 seconds)..."
WAIT_COUNT=0
MAX_WAIT=30

while [ $WAIT_COUNT -lt $MAX_WAIT ]; do
    if curl -s -o /dev/null -w "%{http_code}" http://localhost:5678 | grep -q "200\|302"; then
        echo "✅ n8n is running and responding!"
        break
    fi
    
    WAIT_COUNT=$((WAIT_COUNT + 1))
    if [ $WAIT_COUNT -eq $MAX_WAIT ]; then
        echo "⚠️ n8n is taking longer than expected to start"
        echo "📋 Checking container status..."
        docker ps -a | grep -E "n8n|postgres"
        echo ""
        echo "📋 Last 20 lines of n8n logs:"
        docker logs --tail 20 n8n 2>/dev/null || docker logs --tail 20 n8n-n8n-1 2>/dev/null
    else
        echo "⏳ Still waiting... ($WAIT_COUNT/$MAX_WAIT)"
        sleep 2
    fi
done

# SSL installation if domain provided
if [[ "$USE_IP" == false ]]; then
    echo ""
    echo "🔐 Installing SSL certificate (auto-accepting all prompts)..."
    
    if [[ "$OS" == "ubuntu" || "$OS" == "debian" ]]; then
        apt-get install -y -qq certbot python3-certbot-nginx >> "$LOG_FILE" 2>&1
        certbot --nginx --non-interactive --agree-tos --register-unsafely-without-email -d $DOMAIN >> "$LOG_FILE" 2>&1
    elif [[ "$OS" == "centos" || "$OS" == "rhel" || "$OS" == "almalinux" || "$OS" == "rocky" ]]; then
        if command -v dnf &> /dev/null; then
            dnf -y -q install certbot python3-certbot-nginx >> "$LOG_FILE" 2>&1
        else
            yum -y -q install certbot python3-certbot-nginx >> "$LOG_FILE" 2>&1
        fi
        certbot --nginx --non-interactive --agree-tos --register-unsafely-without-email -d $DOMAIN >> "$LOG_FILE" 2>&1
    fi
    
    if [ $? -eq 0 ]; then
        echo "✅ SSL certificate installed successfully!"
        
        sed -i 's/N8N_PROTOCOL=http/N8N_PROTOCOL=https/g' $DOCKER_COMPOSE_FILE
        sed -i 's#WEBHOOK_URL=http://#WEBHOOK_URL=https://#g' $DOCKER_COMPOSE_FILE
        sed -i 's/N8N_SECURE_COOKIE=false/N8N_SECURE_COOKIE=true/g' $DOCKER_COMPOSE_FILE
        
        cd $N8N_DIR
        echo "🔄 Restarting n8n with HTTPS settings..."
        if command -v docker-compose &> /dev/null; then
            docker-compose down >> "$LOG_FILE" 2>&1
            docker-compose up -d >> "$LOG_FILE" 2>&1
        else
            docker compose down >> "$LOG_FILE" 2>&1
            docker compose up -d >> "$LOG_FILE" 2>&1
        fi
        
        ACCESS_URL="https://$DOMAIN"
    else
        echo "⚠️ SSL certificate installation failed. Using HTTP instead."
        ACCESS_URL="http://$DOMAIN"
    fi
else
    ACCESS_URL="http://$DOMAIN"
fi

# Final connectivity test
echo ""
echo "🔍 Final connectivity test..."
sleep 5

HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" $ACCESS_URL)
if [ "$HTTP_CODE" = "200" ] || [ "$HTTP_CODE" = "302" ]; then
    echo "✅ n8n is accessible from outside!"
else
    echo "⚠️ HTTP Response Code: $HTTP_CODE"
    echo "🔍 Testing direct port access..."
    DIRECT_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://$DOMAIN:5678)
    if [ "$DIRECT_CODE" = "200" ] || [ "$DIRECT_CODE" = "302" ]; then
        echo "✅ n8n is accessible on port 5678 directly"
        echo "⚠️ But Nginx proxy might have issues"
        echo "🌍 Try accessing: http://$DOMAIN:5678"
    fi
fi

# Save database info
cat > $N8N_DIR/database_info.txt <<EOF
# n8n Database Information
# ====================================
Database Type: $DB_TYPE
Database Name: $DB_NAME
Database User: $DB_USER
Database Password: $DB_PASS
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

# Final message
echo ""
echo "🎉 ═══════════════════════════════════════════════════════════════"
echo "🎉 n8n Installation Complete!"
echo "🎉 ═══════════════════════════════════════════════════════════════"
echo ""
echo "🌍 Access n8n at: \e[1;32m$ACCESS_URL\e[0m"
echo ""
echo "📌 Alternative access (if main URL doesn't work):"
echo "   • Direct: http://$DOMAIN:5678"
echo "   • Via Nginx: http://$DOMAIN"
echo ""
echo "⚠️  IMPORTANT: If you're using a cloud provider (AWS, Azure, Google Cloud, etc.),"
echo "    make sure to open these ports in your security group/firewall:"
echo "    • Port 80 (HTTP)"
echo "    • Port 443 (HTTPS)"
echo "    • Port 5678 (n8n direct access)"
echo ""
echo "📊 Database Information:"
echo "   Type:     $DB_TYPE"
echo "   Name:     $DB_NAME"
echo "   User:     $DB_USER"
echo "   Password: $DB_PASS"
echo ""
echo "🔐 Database info saved to: $N8N_DIR/database_info.txt"
echo "📜 Installation log: $LOG_FILE"
echo ""
echo "🔧 Useful commands:"
echo "   • Check status:  docker ps"
echo "   • View logs:     docker logs n8n"
echo "   • Restart:       cd $N8N_DIR && docker-compose restart"
echo "   • Stop:          cd $N8N_DIR && docker-compose down"
echo ""
