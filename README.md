# 🚀 n8n Auto Installer

[![GitHub license](https://img.shields.io/github/license/shahinst/n8n-autoinstall)](https://github.com/shahinst/n8n-autoinstall/blob/main/LICENSE)
[![GitHub stars](https://img.shields.io/github/stars/shahinst/n8n-autoinstall)](https://github.com/shahinst/n8n-autoinstall/stargazers)
[![GitHub forks](https://img.shields.io/github/forks/shahinst/n8n-autoinstall)](https://github.com/shahinst/n8n-autoinstall/network)
[![GitHub issues](https://img.shields.io/github/issues/shahinst/n8n-autoinstall)](https://github.com/shahinst/n8n-autoinstall/issues)

An automated installation script for [n8n](https://n8n.io/) workflow automation platform with Docker, PostgreSQL, Nginx reverse proxy, and a built-in management service.

## 🌟 Features

- ✅ **Multi-OS Support**: Ubuntu, Debian, CentOS, RHEL, AlmaLinux, Rocky Linux
- 🐳 **Docker-based installation** with PostgreSQL database
- 🌐 **Nginx reverse proxy** configuration
- 🔐 **Automatic SSL certificate** installation with Let's Encrypt
- 🎯 **Service-based management** - Easy menu-driven interface
- 🔄 **Domain switching** - Change between domain and IP address
- 📦 **Automatic dependency management**
- 🔧 **Zero-configuration setup** - just run and go!
- 📝 **Domain validation** with DNS checking
- 🔄 **Fallback installation methods** for reliability
- 📊 **Real-time status monitoring**
- 🎨 **Color-coded interface** for better user experience

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

### One-Command Installation

```bash
curl -O https://raw.githubusercontent.com/shahinst/n8n-autoinstall/main/install_n8n.sh
chmod +x install_n8n.sh
sudo ./install_n8n.sh
```

After the initial setup completes, you can manage n8n using:

```bash
sudo n8n
```

## 🎮 Management Menu

Once installed, the `sudo n8n` command provides a full management interface:

```
═══════════════════════════════════════
       n8n Management Service
═══════════════════════════════════════

Status: ✅ Installed
Domain/IP: yourdomain.com
SSL: ✅ Enabled
Service: 🟢 Running

════════════════════════════════════════

  1. Install n8n with domain
  2. Install n8n without domain
  3. Reinstall n8n
  4. Change n8n domain
  5. Exit

════════════════════════════════════════
```

### Menu Options Explained

#### 1️⃣ Install n8n with Domain
- Prompts for your domain name
- Validates domain and checks DNS resolution
- Installs n8n with domain configuration
- Automatically installs SSL certificate
- Configures HTTPS with secure cookies

#### 2️⃣ Install n8n without Domain
- Installs n8n using server IP address
- No domain or SSL required
- Perfect for testing or internal use
- Quick setup without DNS configuration

#### 3️⃣ Reinstall n8n
- Completely removes existing installation
- Cleans up containers, volumes, and configurations
- Offers choice between domain or IP installation
- ⚠️ **Warning**: Removes all workflows and data

#### 4️⃣ Change n8n Domain
Intelligent domain management with multiple options:

**If currently using IP:**
- Switch to domain name
- Automatically configures SSL

**If currently using domain:**
- Change to a different domain
- Switch to IP address (removes SSL)
- Automatically handles certificate migration

#### 5️⃣ Exit
- Safely exits the management menu

## 🔧 What the Script Does

### 1. System Detection & Dependency Installation
- Automatically detects your operating system
- Installs Docker, Docker Compose, and Nginx
- Installs DNS utilities for domain validation
- Configures services to start automatically

### 2. Domain Validation (for domain installations)
- Checks domain format validity
- Verifies DNS resolution
- Compares domain IP with server IP
- Warns about configuration mismatches
- Allows override for advanced users

### 3. n8n Setup
- Creates a dedicated directory (`/opt/n8n`)
- Sets up PostgreSQL 15 database with secure credentials
- Configures n8n with Docker Compose
- Saves configuration for future management
- Provides fallback installation method

### 4. Web Server Configuration
- Configures Nginx as reverse proxy
- Sets up proper headers for WebSocket support
- Handles different OS-specific Nginx configurations
- Supports both IP and domain access

### 5. SSL Certificate (Domain installations)
- Automatically obtains SSL certificate from Let's Encrypt
- Updates configuration for HTTPS
- Configures secure cookies and protocols
- Handles certificate renewal setup

### 6. Service Creation
- Creates system-wide `n8n` command
- Installs management script to `/opt/n8n_service.sh`
- Enables easy access to management menu
- Preserves configuration across sessions

## 📁 Installation Structure

After installation, you'll find:

```
/opt/n8n/
├── docker-compose.yml          # Main configuration
├── config.txt                  # Installation configuration (domain, SSL status)
├── database_info.txt           # Database credentials (secure)
└── install.log                 # Installation log

/usr/local/bin/
└── n8n                         # Management command

/opt/
└── n8n_service.sh             # Management script
```

## 🌐 Access Your Installation

After successful installation:

- **With domain + SSL**: `https://yourdomain.com`
- **With domain (no SSL)**: `http://yourdomain.com`
- **With IP**: `http://your-server-ip`
- **Direct access**: `http://your-server-ip:5678`

The script will display the exact URL at the end of installation.

## 🔐 Database Information

The script automatically generates secure database credentials:

- **Database Type**: PostgreSQL 15
- **Database Name**: n8ndb
- **Database User**: n8n
- **Database Password**: *randomly generated (16 characters)*

All database information is saved to `/opt/n8n/database_info.txt` (readable only by root).

## 🛠️ Management Commands

### Access Management Menu
```bash
sudo n8n
```

### Check Service Status
```bash
# Check Docker containers
docker ps

# Check specific n8n container
docker logs n8n

# Check Nginx status
systemctl status nginx
```

### View Configuration
```bash
cat /opt/n8n/config.txt
```

### View Installation Logs
```bash
cat /opt/n8n/install.log
```

### Manual Container Management
```bash
cd /opt/n8n

# Restart services
docker-compose restart

# Stop services
docker-compose down

# Start services
docker-compose up -d

# View logs
docker-compose logs -f
```

## 🔄 Updating n8n

To update n8n to the latest version:

```bash
cd /opt/n8n
docker-compose pull
docker-compose up -d
```

Or use the management menu:
```bash
sudo n8n
# Choose option 3 (Reinstall) to get the latest version
```

## 🔧 Troubleshooting

### Common Issues

#### Domain not resolving
- Ensure DNS A record points to your server IP
- Wait for DNS propagation (can take up to 48 hours)
- Use `nslookup yourdomain.com` to check DNS

#### SSL certificate fails
- Verify domain points to server IP
- Check if ports 80 and 443 are open
- Ensure no other web server is running on port 80
- Script will fallback to HTTP if SSL fails

#### Cannot access n8n
1. Check if containers are running: `docker ps`
2. Check nginx status: `systemctl status nginx`
3. Check firewall: `ufw status` or `firewall-cmd --list-all`
4. Try direct access: `http://your-ip:5678`

#### Service menu not working
```bash
# Reinstall the service
sudo bash /opt/n8n_service.sh
```

### Cloud Provider Firewall

If using AWS, Azure, Google Cloud, or other cloud providers:

**Required Ports:**
- Port 80 (HTTP)
- Port 443 (HTTPS)
- Port 5678 (n8n direct access)

Make sure to open these ports in your cloud provider's security group/firewall settings.

## 🗑️ Uninstallation

To completely remove n8n:

```bash
# Stop and remove containers
docker stop n8n postgres
docker rm n8n postgres
docker volume rm n8n_data postgres-data

# Remove installation directories
sudo rm -rf /opt/n8n

# Remove Nginx configuration
sudo rm -f /etc/nginx/sites-available/n8n
sudo rm -f /etc/nginx/sites-enabled/n8n
sudo rm -f /etc/nginx/conf.d/n8n.conf
sudo systemctl reload nginx

# Remove service command
sudo rm -f /usr/local/bin/n8n
sudo rm -f /opt/n8n_service.sh

# Remove SSL certificates (if domain was used)
sudo certbot delete --cert-name yourdomain.com
```

## 📊 Features Comparison

| Feature | With Domain | Without Domain |
|---------|-------------|----------------|
| SSL/HTTPS | ✅ Automatic | ❌ Not available |
| Custom Domain | ✅ Yes | ❌ IP only |
| DNS Required | ✅ Yes | ❌ No |
| Production Ready | ✅ Yes | ⚠️ Testing only |
| Easy Setup | ⚠️ DNS setup needed | ✅ Instant |
| Secure Cookies | ✅ Yes | ❌ No |

## 🎯 Use Cases

### With Domain (Recommended for Production)
- Production deployments
- Team collaboration
- Public-facing automations
- Webhook integrations
- Professional setup

### Without Domain (Good for Testing)
- Local development
- Testing workflows
- Internal network use
- Quick prototyping
- Learning n8n

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

### How to Contribute

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

### Ideas for Contributions
- Support for additional operating systems
- Backup and restore functionality
- Monitoring integration
- Auto-update feature
- Multi-instance support

## 📝 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🆘 Support

- **Issues**: [GitHub Issues](https://github.com/shahinst/n8n-autoinstall/issues)
- **Discussions**: [GitHub Discussions](https://github.com/shahinst/n8n-autoinstall/discussions)
- **Digicloud**: [https://digicloud.host](https://digicloud.host)
- **Oxincloud**: [https://oxincloud.net](https://oxincloud.net)

## ⭐ Star History

[![Star History Chart](https://api.star-history.com/svg?repos=shahinst/n8n-autoinstall&type=Date)](https://star-history.com/#shahinst/n8n-autoinstall)

## 📚 Related Links

- [n8n Official Documentation](https://docs.n8n.io/)
- [Docker Documentation](https://docs.docker.com/)
- [Nginx Documentation](https://nginx.org/en/docs/)
- [Let's Encrypt Documentation](https://letsencrypt.org/docs/)

## 🎓 Tutorial

### First Time Setup

1. **Download and run the installer:**
   ```bash
   curl -O https://raw.githubusercontent.com/shahinst/n8n-autoinstall/main/install_n8n.sh
   chmod +x install_n8n.sh
   sudo ./install_n8n.sh
   ```

2. **After installation completes, access the menu:**
   ```bash
   sudo n8n
   ```

3. **Choose your installation type:**
   - Option 1 for domain (recommended for production)
   - Option 2 for IP address (good for testing)

4. **Access your n8n instance:**
   - Navigate to the URL shown after installation
   - Complete the setup wizard
   - Create your admin account

### Changing Configuration Later

1. **Access the management menu:**
   ```bash
   sudo n8n
   ```

2. **Choose option 4 (Change n8n domain)**

3. **Select your desired change:**
   - Switch from IP to domain
   - Change to different domain
   - Switch from domain to IP

### Reinstalling

If you need to start fresh:

```bash
sudo n8n
# Choose option 3 (Reinstall)
# Select your preferred installation type
```

## 💡 Tips & Best Practices

1. **Use a domain for production** - SSL and custom domains are essential for security
2. **Keep your server updated** - Regular system updates improve security
3. **Backup your data** - Create regular backups of Docker volumes
4. **Monitor logs** - Check logs regularly for issues
5. **Use strong passwords** - The script generates secure passwords, keep them safe
6. **Configure firewall** - Only open necessary ports
7. **Enable auto-updates** - Keep n8n updated for latest features and security

## 🔒 Security Recommendations

- Always use SSL/HTTPS for production (install with domain)
- Keep database credentials secure (stored in `/opt/n8n/database_info.txt`)
- Regularly update n8n and system packages
- Configure proper firewall rules
- Use strong authentication for n8n users
- Limit SSH access to your server
- Consider using fail2ban for additional protection

---

**Made with ❤️ by [Digicloud Company](https://digicloud.host)**

*If this project helped you, please consider giving it a ⭐ star!*

## 🙏 Acknowledgments

- [n8n.io](https://n8n.io/) for creating an amazing automation platform
- The open-source community for continuous support
- All contributors who help improve this project
