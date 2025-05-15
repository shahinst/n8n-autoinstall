#!/bin/bash
clear
echo -e "\e[1;36m"
echo "###########################################"
echo "#           Digicloud Company             #"
echo "###########################################"
echo -e "\e[0m"
echo "🌐 https://digicloud.host"
echo "🌐 https://oxincloud.net"
echo "🔗 GitHub: https://github.com/shahinst"
echo

# Configuration Variables
N8N_DIR="/opt/n8n"
DOCKER_COMPOSE_FILE="$N8N_DIR/docker-compose.yml"
LOG_FILE="$N8N_DIR/install.log"
DB_USER="n8n"
DB_PASS=$(openssl rand -hex 8)
DB_NAME="n8ndb"
DB_VERSION="postgres:15"
DB_TYPE="PostgreSQL 15"

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

# Function to install dependencies based on OS
install_dependencies() {
  echo "📦 Installing dependencies for $OS $VERSION_ID..."
  
  case $OS in
    ubuntu|debian)
      apt update -y > "$LOG_FILE" 2>&1
      apt install -y curl wget git openssl ca-certificates gnupg lsb-release >> "$LOG_FILE" 2>&1
      
      # Install Docker on Ubuntu if not already installed
      if ! command -v docker &> /dev/null; then
        echo "🐳 Installing Docker..."
        # Add Docker's official GPG key
        mkdir -p /etc/apt/keyrings
        curl -fsSL https://download.docker.com/linux/$OS/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg >> "$LOG_FILE" 2>&1
        echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/$OS $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
        apt update -y >> "$LOG_FILE" 2>&1
        apt install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin >> "$LOG_FILE" 2>&1
      fi
      
      # Install Docker Compose if not already installed
      if ! command -v docker-compose &> /dev/null; then
        echo "🐙 Installing Docker Compose..."
        apt install -y docker-compose >> "$LOG_FILE" 2>&1
        
        # Fallback if package not available
        if ! command -v docker-compose &> /dev/null; then
          curl -SL https://github.com/docker/compose/releases/download/v2.16.0/docker-compose-linux-x86_64 -o /usr/local/bin/docker-compose >> "$LOG_FILE" 2>&1
          chmod +x /usr/local/bin/docker-compose
        fi
      fi
      
      # Install Nginx
      apt install -y nginx >> "$LOG_FILE" 2>&1
      ;;
      
    centos|rhel|almalinux|rocky)
      # Install required packages
      if command -v dnf &> /dev/null; then
        dnf -y update >> "$LOG_FILE" 2>&1
        dnf -y install curl wget openssl ca-certificates >> "$LOG_FILE" 2>&1
        
        # Install Docker
        if ! command -v docker &> /dev/null; then
          echo "🐳 Installing Docker..."
          dnf -y install dnf-plugins-core >> "$LOG_FILE" 2>&1
          dnf config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo >> "$LOG_FILE" 2>&1
          dnf -y install docker-ce docker-ce-cli containerd.io >> "$LOG_FILE" 2>&1
        fi
        
        # Install NGINX
        dnf -y install nginx >> "$LOG_FILE" 2>&1
      else
        # Fallback to yum for older CentOS versions
        yum -y update >> "$LOG_FILE" 2>&1
        yum -y install curl wget openssl ca-certificates >> "$LOG_FILE" 2>&1
        
        # Install Docker
        if ! command -v docker &> /dev/null; then
          echo "🐳 Installing Docker..."
          yum -y install yum-utils >> "$LOG_FILE" 2>&1
          yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo >> "$LOG_FILE" 2>&1
          yum -y install docker-ce docker-ce-cli containerd.io >> "$LOG_FILE" 2>&1
        fi
        
        # Install NGINX
        yum -y install nginx >> "$LOG_FILE" 2>&1
      fi
      
      # Install Docker Compose if not already installed
      if ! command -v docker-compose &> /dev/null; then
        echo "🐙 Installing Docker Compose..."
        curl -SL https://github.com/docker/compose/releases/download/v2.16.0/docker-compose-linux-x86_64 -o /usr/local/bin/docker-compose >> "$LOG_FILE" 2>&1
        chmod +x /usr/local/bin/docker-compose
        ln -sf /usr/local/bin/docker-compose /usr/bin/docker-compose
      fi
      
      # Enable and start services
      systemctl enable docker >> "$LOG_FILE" 2>&1
      systemctl start docker >> "$LOG_FILE" 2>&1
      systemctl enable nginx >> "$LOG_FILE" 2>&1
      systemctl start nginx >> "$LOG_FILE" 2>&1
      
      # Configure SELinux if enabled
      if command -v getenforce &> /dev/null && [ "$(getenforce)" != "Disabled" ]; then
        echo "🔒 Configuring SELinux for Docker and Nginx..."
        setsebool -P httpd_can_network_connect 1 >> "$LOG_FILE" 2>&1
      fi
      
      # Configure firewall if active
      if systemctl is-active --quiet firewalld; then
        echo "🔥 Configuring firewall..."
        firewall-cmd --permanent --add-service=http >> "$LOG_FILE" 2>&1
        firewall-cmd --permanent --add-service=https >> "$LOG_FILE" 2>&1
        firewall-cmd --reload >> "$LOG_FILE" 2>&1
      fi
      ;;
      
    *)
      echo "❌ Unsupported OS: $OS"
      exit 1
      ;;
  esac
  
  # Ensure Docker is running
  systemctl enable docker >> "$LOG_FILE" 2>&1
  systemctl start docker >> "$LOG_FILE" 2>&1
  
  echo "✅ Dependencies installed successfully!"
}

# 🔍 Check for previous installation
if [ -d "$N8N_DIR" ]; then
  echo -e "\n⚠️  n8n is already installed."
  read -p "❓ Do you want to remove it and reinstall? (yes/no): " CONFIRM
  if [[ "$CONFIRM" != "yes" ]]; then
    echo "❌ Installation aborted."
    exit 1
  fi
  echo "🧹 Removing previous installation..."
  docker stop $(docker ps -q --filter ancestor=n8nio/n8n) 2>/dev/null
  docker rm $(docker ps -aq --filter ancestor=n8nio/n8n) 2>/dev/null
  docker stop n8n 2>/dev/null
  docker rm n8n 2>/dev/null
  docker rm -f n8n-n8n-1 n8n-postgres-1 2>/dev/null
  docker volume rm n8n_data postgres-data 2>/dev/null
  docker volume rm $(docker volume ls -q -f name=n8n) 2>/dev/null
  rm -rf $N8N_DIR
fi

# Create installation directory
mkdir -p $N8N_DIR

# 🌐 Ask for domain
read -p "🌐 Enter domain for n8n (leave blank to use server IP): " DOMAIN
if [[ -z "$DOMAIN" ]]; then
  DOMAIN=$(hostname -I | awk '{print $1}')
  USE_IP=true
else
  USE_IP=false
fi

# Detect OS and install dependencies
detect_os
install_dependencies

# Add alternative Docker run command if docker-compose fails
echo "📑 Adding fallback installation method..."
cat > $N8N_DIR/run-direct.sh <<EOF
#!/bin/bash
docker volume create n8n_data
docker run -it -d --restart always --name n8n -p 5678:5678 \
  -v n8n_data:/home/node/.n8n \
  -e N8N_SECURE_COOKIE=false \
  docker.n8n.io/n8nio/n8n
EOF
chmod +x $N8N_DIR/run-direct.sh

echo "📄 Writing docker-compose.yml..."
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
      # Security settings
      - N8N_SECURE_COOKIE=false  # Disable secure cookie to allow HTTP access
      - N8N_HOST=$DOMAIN
      - N8N_PROTOCOL=http
      - WEBHOOK_URL=http://$DOMAIN/
    depends_on:
      - postgres
    volumes:
      - n8n_data:/home/node/.n8n

volumes:
  postgres-data:
  n8n_data:
EOF

echo "🚀 Starting Docker containers..."
cd $N8N_DIR
if ! docker-compose up -d >> "$LOG_FILE" 2>&1; then
  # Try with docker compose (newer syntax)
  if ! docker compose up -d >> "$LOG_FILE" 2>&1; then
    echo "⚠️ Docker Compose failed, trying direct Docker run method..."
    # Stop any existing running containers and clean up
    docker stop n8n 2>/dev/null
    docker rm n8n 2>/dev/null
    
    # Run using direct docker command
    docker volume create n8n_data >> "$LOG_FILE" 2>&1
    docker run -d --restart always --name n8n -p 5678:5678 \
      -v n8n_data:/home/node/.n8n \
      -e N8N_SECURE_COOKIE=false \
      docker.n8n.io/n8nio/n8n >> "$LOG_FILE" 2>&1
    
    if [ $? -ne 0 ]; then
      echo "❌ Installation failed. Check the log at $LOG_FILE"
      exit 1
    fi
    echo "✅ Started n8n using direct Docker method!"
  fi
fi

echo "🌐 Configuring NGINX..."
# Determine Nginx configuration directory based on OS
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
    listen 80;
    server_name $DOMAIN;
    
    location / {
        proxy_pass http://localhost:5678;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_cache_bypass \$http_upgrade;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOF

# Enable the site in Nginx (Ubuntu/Debian style)
if [[ "$OS" == "ubuntu" || "$OS" == "debian" ]]; then
  ln -sf $NGINX_CONF_FILE /etc/nginx/sites-enabled/n8n
fi

# Test and reload nginx configuration
if [[ "$OS" == "centos" || "$OS" == "rhel" || "$OS" == "almalinux" || "$OS" == "rocky" ]]; then
  nginx -t >> "$LOG_FILE" 2>&1 && systemctl reload nginx >> "$LOG_FILE" 2>&1
else
  nginx -t >> "$LOG_FILE" 2>&1 && systemctl reload nginx >> "$LOG_FILE" 2>&1
fi

# 🔐 If domain was provided, install SSL
if [[ "$USE_IP" == false ]]; then
  echo "🔐 Attempting to obtain SSL certificate..."
  
  # Install certbot based on OS
  if [[ "$OS" == "ubuntu" || "$OS" == "debian" ]]; then
    apt install -y certbot python3-certbot-nginx >> "$LOG_FILE" 2>&1
    certbot --nginx --non-interactive --agree-tos -m admin@$DOMAIN -d $DOMAIN >> "$LOG_FILE" 2>&1
  elif [[ "$OS" == "centos" || "$OS" == "rhel" || "$OS" == "almalinux" || "$OS" == "rocky" ]]; then
    if command -v dnf &> /dev/null; then
      dnf -y install certbot python3-certbot-nginx >> "$LOG_FILE" 2>&1
    else
      yum -y install certbot python3-certbot-nginx >> "$LOG_FILE" 2>&1
    fi
    certbot --nginx --non-interactive --agree-tos -m admin@$DOMAIN -d $DOMAIN >> "$LOG_FILE" 2>&1
  fi
  
  if [ $? -eq 0 ]; then
    echo "✅ SSL certificate installed successfully!"
    
    # Update environment variables for HTTPS in docker-compose
    sed -i 's/N8N_PROTOCOL=http/N8N_PROTOCOL=https/g' $DOCKER_COMPOSE_FILE
    sed -i 's#WEBHOOK_URL=http://#WEBHOOK_URL=https://#g' $DOCKER_COMPOSE_FILE
    sed -i 's/N8N_SECURE_COOKIE=false/N8N_SECURE_COOKIE=true/g' $DOCKER_COMPOSE_FILE
    
    # Restart containers with updated settings
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

# Check if n8n is accessible
echo "🔍 Verifying n8n is running on port 5678..."
for i in {1..12}; do
  if curl -s http://localhost:5678 > /dev/null; then
    echo "✅ n8n is running properly!"
    break
  fi
  if [ $i -eq 12 ]; then
    echo "⚠️ Could not verify n8n is running. Please check logs."
  else
    echo "⏳ Waiting for n8n to start... (attempt $i/12)"
    sleep 5
  fi
done

# Save database information to a file
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

# 💬 Final message
echo -e "\n🎉 n8n has been successfully installed!"
echo -e "🌍 Access n8n at: $ACCESS_URL"
echo -e "📝 Complete the setup wizard in your browser to configure your n8n instance"
echo -e "\n📊 Database Information:"
echo -e "   Type:     $DB_TYPE"
echo -e "   Name:     $DB_NAME"
echo -e "   User:     $DB_USER"
echo -e "   Password: $DB_PASS"
echo -e "   Host:     postgres (Docker container)"
echo -e "   Port:     5432"
echo -e "\n🔐 This database information has been saved to: $N8N_DIR/database_info.txt"
echo -e "\n📜 Installation Log: $LOG_FILE"
