#!/bin/bash

set -e

# ───────────── OS Detection ─────────────
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS=$ID
else
    echo "[✗] Cannot detect OS"
    exit 1
fi

echo "[+] Detected OS: $OS"

# ───────────── Required Binary Check ─────────────
if [[ "$OS" =~ ^(ubuntu|debian)$ ]]; then
    BACKEND_PATH=/usr/lib/git-core/git-http-backend
elif [[ "$OS" =~ ^(fedora|rhel|centos|rocky|almalinux)$ ]]; then
    BACKEND_PATH=/usr/libexec/git-core/git-http-backend
else
    echo "[✗] Unsupported OS: $OS"
    exit 1
fi

if [ ! -x "$BACKEND_PATH" ]; then
    echo "[✗] git-http-backend not found at $BACKEND_PATH"
    exit 1
fi

# ───────────── Install Dependencies ─────────────
if [[ "$OS" =~ ^(ubuntu|debian)$ ]]; then
    sudo apt update
    sudo apt install -y git apache2 apache2-utils
    CONF_SRC="git.ubuntu.conf"
    APACHE_USER=www-data
    APACHE_CONF_DIR=/etc/apache2/conf-available
    APACHE_SERVICE=apache2
elif [[ "$OS" =~ ^(fedora|rhel|centos|rocky|almalinux)$ ]]; then
    sudo dnf install -y git httpd policycoreutils-python-utils httpd-tools
    CONF_SRC="git.fedora.conf"
    APACHE_USER=apache
    APACHE_CONF_DIR=/etc/httpd/conf.d
    APACHE_SERVICE=httpd
fi

# ───────────── Copy Apache Config ─────────────
echo "[+] Copying Apache config..."
sudo cp "$CONF_SRC" "$APACHE_CONF_DIR/git.conf"

if [[ "$OS" =~ ^(ubuntu|debian)$ ]]; then
    echo "[+] Enabling Apache modules..."
    sudo a2enconf git
    sudo a2enmod cgid env alias auth_basic authn_file dav dav_fs
fi

# ───────────── Create Password File ─────────────
PASSWD_PATH="$APACHE_CONF_DIR/git.passwd"
sudo htpasswd -bc "$PASSWD_PATH" bob bobpassword

# ───────────── Prepare Repo Directory ─────────────
echo "[+] Creating /repos directory..."
sudo mkdir -p /repos
sudo chmod 0755 /repos
sudo chown "$APACHE_USER":"$APACHE_USER" /repos

if [[ "$OS" =~ ^(fedora|rhel|centos|rocky|almalinux)$ ]]; then
    echo "[+] Setting SELinux context for /repos..."
    sudo semanage fcontext -a -t httpd_sys_rw_content_t "/repos(/.*)?"
    sudo restorecon -Rv /repos
fi

# ───────────── Start Apache ─────────────
echo "[+] Starting Apache..."
sudo systemctl enable --now "$APACHE_SERVICE"

# ───────────── Create Test Repo ─────────────
echo "[+] Creating test.git bare repo..."
cd /repos
sudo -u "$APACHE_USER" git init --bare test.git

# ───────────── Clone and Push ─────────────
echo "[+] Cloning and pushing to test.git..."
cd ~
git config --global user.email "you@example.com"
git config --global user.name "Your Name"

rm -rf test
if git clone http://bob@localhost/repos/test.git; then
    cd test
    echo "hello world" > README.md
    git add README.md
    git commit -m "initial commit"
    git push
    echo "[✓] Test repo pushed successfully!"
else
    echo "[✗] Failed to clone the test repo."
    echo "    Check Apache logs or try visiting http://localhost/repos/test.git"
    exit 1
fi

echo "[✓] Git HTTP server is ready and test.git is live!"
