# 🚀 n8n Auto Installer

A fully automated shell script to install, configure, and run [n8n](https://n8n.io) on a fresh Ubuntu 18 , 20 , 22 , 24 | Almalinux 8 , 9 | Centos 8 , 9 server with Docker, PostgreSQL, and NGINX + SSL using Let's Encrypt.

> ✨ Developed by **shahin salektootoonchi**  
> 🌍 https://digicloud.host | https://oxincloud.net  
> 🧑‍💻 GitHub: [@shahinst](https://github.com/shahinst)

---

## 📦 Features

- 🔧 Installs all dependencies: Docker, Docker Compose, NGINX, Certbot
- 🐳 Runs n8n and PostgreSQL via Docker Compose
- 🔐 Enables Basic Auth with auto-generated strong password
- 🌍 Configures NGINX reverse proxy with automatic SSL via Let's Encrypt
- 📁 Generates a full installation log at `/opt/n8n/install.log`
- 🔁 Detects and optionally removes any existing installation
- 🧠 Smart prompts: asks for domain name and handles clean reinstallation
- 🌍 Configures NGINX reverse proxy with automatic SSL via Let's Encrypt
- 🌍 Install in Ubuntu 18 , 20 , 22 , 24 | Almalinux 8 , 9 | Centos 8 , 9
---

## 📥 Installation

> ⚠️ This script is intended for a **fresh 18 , 20 , 22 , 24 | Almalinux 8 , 9 | Centos 8 , 9** server with root access.

1. Connect to your server via SSH.
2. Run the following command:


curl -sSL https://raw.githubusercontent.com/shahinst/n8n-autoinstall/main/install_n8n.sh | bash
Follow the prompts:

Enter your domain (e.g. n8n.domain.com)

Script will automatically install and configure everything

✅ After Installation
Once completed, you'll see something like:

pgsql
Copy
Edit
🎉 n8n has been successfully installed!

📝 Installation Log: /opt/n8n/install.log
📄 License
MIT License © shahinst
