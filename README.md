# 🚀 n8n Auto Installer

[![GitHub license](https://img.shields.io/github/license/shahinst/n8n-autoinstall)](https://github.com/shahinst/n8n-autoinstall/blob/main/LICENSE)
[![GitHub stars](https://img.shields.io/github/stars/shahinst/n8n-autoinstall)](https://github.com/shahinst/n8n-autoinstall/stargazers)
[![GitHub forks](https://img.shields.io/github/forks/shahinst/n8n-autoinstall)](https://github.com/shahinst/n8n-autoinstall/network)
[![GitHub issues](https://img.shields.io/github/issues/shahinst/n8n-autoinstall)](https://github.com/shahinst/n8n-autoinstall/issues)

An automated installation script for [n8n](https://n8n.io/) workflow automation platform with Docker, PostgreSQL, and Nginx reverse proxy support.

## 🌟 Features

- ✅ **Multi-OS Support**: Ubuntu, Debian, CentOS, RHEL, AlmaLinux, Rocky Linux
- 🐳 **Docker-based installation** with PostgreSQL database
- 🌐 **Nginx reverse proxy** configuration
- 🔐 **Automatic SSL certificate** installation with Let's Encrypt
- 🔧 **Zero-configuration setup** - just run and go!
- 📦 **Automatic dependency management**
- 🔄 **Fallback installation methods** for reliability
- 📝 **Comprehensive logging** and error handling

## 📋 Prerequisites

- Root or sudo access on your server
- A domain name (optional, can use IP address)
- Internet connection
- Supported operating system:
  - Ubuntu 16.04+
  - Debian 9+
  - CentOS 7+
  - RHEL 7+
  - AlmaLinux 8+
  - Rocky Linux 8+

## ⚡ Quick Start

### One-Line Installation

```bash
curl -fsSL https://raw.githubusercontent.com/shahinst/n8n-autoinstall/main/install_n8n.sh | sudo bash
```

### Manual Installation

1. Download the script:
```bash
wget https://raw.githubusercontent.com/shahinst/n8n-autoinstall/main/install_n8n.sh
```

2. Make it executable:
```bash
chmod +x install_n8n.sh
```

3. Run the installation:
```bash
sudo ./install_n8n.sh
```

## 🔧 What the Script Does

### 1. System Detection & Dependency Installation
- Automatically detects your operating system
- Installs Docker, Docker Compose, and Nginx
- Configures services to start automatically

### 2. n8n Setup
- Creates a dedicated directory (`/opt/n8n`)
- Sets up PostgreSQL database with secure credentials
- Configures n8n with Docker Compose
- Provides fallback installation method

### 3. Web Server Configuration
- Configures Nginx as reverse proxy
- Sets up proper headers for WebSocket support
- Handles different OS-specific Nginx configurations

### 4. SSL Certificate (Optional)
- Automatically obtains SSL certificate if domain is provided
- Updates configuration for HTTPS
- Configures secure cookies and protocols

### 5. Security & Cleanup
- Generates secure database passwords
- Saves configuration securely
- Configures firewall rules (if enabled)
- Handles SELinux settings (if enabled)

## 📁 Installation Structure

After installation, you'll find:

```
/opt/n8n/
├── docker-compose.yml          # Main configuration
├── database_info.txt           # Database credentials (secure)
├── install.log                 # Installation log
└── run-direct.sh               # Fallback run script
```

## 🌐 Access Your Installation

After successful installation:

- **With domain**: `https://yourdomain.com` or `http://yourdomain.com`
- **With IP**: `http://your-server-ip`

The script will display the exact URL at the end of installation.

## 🔐 Database Information

The script automatically generates secure database credentials:

- **Database Type**: PostgreSQL 15
- **Database Name**: n8ndb
- **Database User**: n8n
- **Database Password**: *randomly generated*

All database information is saved to `/opt/n8n/database_info.txt` (readable only by root).

## 🛠️ Post-Installation

1. **Access the Web Interface**: Navigate to your n8n URL
2. **Complete Setup Wizard**: Follow the on-screen instructions
3. **Create Admin Account**: Set up your first user account
4. **Start Automating**: Begin creating your workflows!

## 🔧 Troubleshooting

### Check Service Status
```bash
# Check Docker containers
docker ps

# Check specific n8n container
docker logs n8n

# Check Nginx status
systemctl status nginx
```

### View Installation Logs
```bash
cat /opt/n8n/install.log
```

### Restart n8n
```bash
cd /opt/n8n
docker-compose restart
```

### Manual Fallback
If Docker Compose fails, use the fallback script:
```bash
cd /opt/n8n
./run-direct.sh
```

## 🔄 Updating n8n

To update n8n to the latest version:

```bash
cd /opt/n8n
docker-compose pull
docker-compose up -d
```

## 🗑️ Uninstallation

To completely remove n8n:

```bash
# Stop and remove containers
docker stop n8n
docker rm n8n
docker volume rm n8n_data postgres-data

# Remove installation directory
sudo rm -rf /opt/n8n

# Remove Nginx configuration
sudo rm /etc/nginx/sites-available/n8n
sudo rm /etc/nginx/sites-enabled/n8n
sudo systemctl reload nginx
```

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

### How to Contribute

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## 📝 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🆘 Support

- **Issues**: [GitHub Issues](https://github.com/shahinst/n8n-autoinstall/issues)
- **Digicloud**: [https://digicloud.host](https://digicloud.host)
- **Oxincloud**: [https://oxincloud.net](https://oxincloud.net)

## ⭐ Star History

[![Star History Chart](https://api.star-history.com/svg?repos=shahinst/n8n-autoinstall&type=Date)](https://star-history.com/#shahinst/n8n-autoinstall)

## 📚 Related Links

- [n8n Official Documentation](https://docs.n8n.io/)
- [Docker Documentation](https://docs.docker.com/)
- [Nginx Documentation](https://nginx.org/en/docs/)

---

**Made with ❤️ by [Digicloud Company](https://digicloud.host)**

*If this project helped you, please consider giving it a ⭐ star!*
