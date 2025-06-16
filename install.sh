#!/bin/bash

set -e

# Detect OS and package manager
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS=$ID
else
    echo "Cannot detect OS"
    exit 1
fi

# Install required packages
echo "[+] Installing required packages..."
if [[ "$OS" =~ ^(fedora|rhel|centos|rocky|almalinux)$ ]]; then
    sudo dnf install -y git httpd policycoreutils-python-utils httpd-tools
    APACHE_USER=apache
    APACHE_CONF_DIR=/etc/httpd/conf.d
    APACHE_SERVICE=httpd
elif [[ "$OS" =~ ^(ubuntu|debian)$ ]]; then
    sudo apt update
    sudo apt install -y git apache2 apache2-utils
    APACHE_USER=www-data
    APACHE_CONF_DIR=/etc/apache2/conf-available
    APACHE_SERVICE=apache2
else
    echo "Unsupported OS: $OS"
    exit 1
fi

# Copy Apache configuration
echo "[+] Copying Apache config..."
sudo cp git.conf "$APACHE_CONF_DIR/git.conf"

# Enable config on Ubuntu/Debian
if [[ "$OS" =~ ^(ubuntu|debian)$ ]]; then
    sudo a2enconf git
    sudo a2enmod cgi
    sudo a2enmod env
    sudo a2enmod alias
    sudo a2enmod auth_basic
    sudo a2enmod authn_file
fi

# Create password file and user
echo "[+] Creating HTTP Basic Auth user..."
sudo htpasswd -bc "$APACHE_CONF_DIR/git.passwd" bob bobpassword

# Create repo directory
echo "[+] Setting up Git repo directory..."
sudo mkdir -m 0755 -p /repos
sudo chown "$APACHE_USER":"$APACHE_USER" /repos

# SELinux (Fedora/RHEL-based only)
if [[ "$OS" =~ ^(fedora|rhel|centos|rocky|almalinux)$ ]]; then
    echo "[+] Configuring SELinux permissions..."
    sudo semanage fcontext -a -t httpd_sys_rw_content_t "/repos(/.*)?"
    sudo restorecon -Rv /repos
fi

# Enable and start Apache
echo "[+] Enabling and starting Apache..."
sudo systemctl enable --now "$APACHE_SERVICE"

# Initialize a test repository
echo "[+] Creating test repository..."
cd /repos
sudo -u "$APACHE_USER" git init --bare test.git

# Local test push
echo "[+] Cloning and pushing to test repository..."
cd ~
git config --global user.email "you@example.com"
git config --global user.name "Your Name"
git clone http://localhost/repos/test.git
cd test
echo hello > Readme
git add Readme
git commit -m "initial commit"
git push

echo "[✓] Setup complete."
