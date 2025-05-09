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

N8N_DIR="/opt/n8n"
DOCKER_COMPOSE_FILE="$N8N_DIR/docker-compose.yml"
LOG_FILE="$N8N_DIR/install.log"

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
  docker rm -f n8n-n8n-1 n8n-postgres-1 2>/dev/null
  docker volume rm $(docker volume ls -q -f name=n8n) 2>/dev/null
  rm -rf $N8N_DIR
fi

# 🌐 Ask for domain
read -p "🌐 Enter domain for n8n (leave blank to use server IP): " DOMAIN

if [[ -z "$DOMAIN" ]]; then
  DOMAIN=$(hostname -I | awk '{print $1}')
  USE_IP=true
else
  USE_IP=false
fi

mkdir -p $N8N_DIR

echo "📦 Installing dependencies..."
apt update && apt install -y docker.io docker-compose nginx

systemctl enable docker
systemctl start docker

echo "📄 Writing docker-compose.yml..."
N8N_PASSWORD=$(openssl rand -hex 16)

cat > $DOCKER_COMPOSE_FILE <<EOF
version: "3.7"
services:
  postgres:
    image: postgres:15
    restart: always
    environment:
      - POSTGRES_USER=n8n
      - POSTGRES_PASSWORD=n8npass
      - POSTGRES_DB=n8ndb
    volumes:
      - postgres-data:/var/lib/postgresql/data

  n8n:
    image: n8nio/n8n
    restart: always
    ports:
      - "5678:5678"
    environment:
      - DB_TYPE=postgresdb
      - DB_POSTGRESDB_HOST=postgres
      - DB_POSTGRESDB_PORT=5432
      - DB_POSTGRESDB_DATABASE=n8ndb
      - DB_POSTGRESDB_USER=n8n
      - DB_POSTGRESDB_PASSWORD=n8npass
      - N8N_BASIC_AUTH_ACTIVE=true
      - N8N_BASIC_AUTH_USER=admin
      - N8N_BASIC_AUTH_PASSWORD=$N8N_PASSWORD
      - N8N_HOST=$DOMAIN
      - N8N_PROTOCOL=http
      - WEBHOOK_URL=http://$DOMAIN/
    depends_on:
      - postgres
    volumes:
      - n8n-data:/home/node/.n8n

volumes:
  postgres-data:
  n8n-data:
EOF

echo "🚀 Starting Docker containers..."
cd $N8N_DIR
docker compose up -d

echo "🌐 Configuring NGINX..."
cat > /etc/nginx/sites-available/n8n <<EOF
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
    }
}
EOF

ln -sf /etc/nginx/sites-available/n8n /etc/nginx/sites-enabled/n8n
nginx -t && systemctl reload nginx

# 🔐 If domain was provided, install SSL
if [[ "$USE_IP" == false ]]; then
  echo "🔐 Obtaining SSL certificate..."
  apt install -y certbot python3-certbot-nginx
  certbot --nginx --non-interactive --agree-tos -m admin@$DOMAIN -d $DOMAIN
fi

# 💬 Final message
echo -e "\n🎉 n8n has been successfully installed!"
if [[ "$USE_IP" == true ]]; then
  echo "🌍 Access it at: http://$DOMAIN"
else
  echo "🌍 Access it at: https://$DOMAIN"
fi

echo -e "\n📝 Installation Log: $LOG_FILE"
