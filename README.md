# Git Repo Server — Git over HTTP with Apache

This project demonstrates how to configure **Apache HTTPD** to serve Git repositories over **HTTP/S** using the `git-http-backend` CGI script. It includes secure access via **Basic Authentication**, optional **SELinux** configuration (for RHEL-based distros), and an automated setup script that supports both **Rocky Linux/Fedora** and **Ubuntu/Debian** systems.

---

## 📦 What This Includes

- Git hosting over HTTP/S using Apache
- Secure repository access with `.htpasswd` (Basic Auth)
- SELinux-friendly setup for Fedora/RHEL/Rocky
- Bare Git repository initialization
- One-step automated installation via `install.sh`
- Support for both DNF and APT-based Linux systems

---

## 📂 Files

| File         | Description                                         |
|--------------|-----------------------------------------------------|
| `git.conf`   | Apache configuration for Git over HTTP              |
| `install.sh` | OS-aware install script for Fedora and Ubuntu       |
| `_config.yml`| GitHub Pages config (used only if site-hosted)      |
| `LICENSE`    | Project license (MIT)                               |
| `README.md`  | You're looking at it 😉                              |

---

## 🚀 Quick Start

> ✅ Works on **Rocky Linux 8.10+, Fedora**, and **Ubuntu/Debian** systems.

```bash
git clone https://github.com/funkybooboo/git-repo-server.git
cd git-repo-server
chmod +x install.sh
./install.sh
````

Then open your browser and access:
📡 `http://localhost/repos/test.git`

> 💡 You’ll be prompted to create a user password if not auto-set in the script.

---

## 🔐 Example Credentials

By default, the script sets up:

* **Username:** `bob`
* **Password:** `bobpassword` (can be changed in the script)

To test access:

```bash
git clone http://bob@localhost/repos/test.git
```

---

## 📘 How It Works

Apache serves Git repositories over HTTP using the `git-http-backend` CGI script. This setup:

* Defines `/repos` as the Git project root (`GIT_PROJECT_ROOT`)
* Enables CGI and necessary Apache modules (`mod_alias`, `mod_env`, `mod_auth_basic`, etc.)
* Protects access with `.htpasswd`
* On Fedora/RHEL: configures SELinux to allow HTTPD read/write access with `httpd_sys_rw_content_t`

---

## 📎 Notes

* ✅ SELinux configuration is automatically applied only on Fedora/RHEL-based systems.
* ✅ Apache modules are auto-enabled on Ubuntu/Debian.
* 🔒 You can modify the Apache `git.conf` file to control authentication or expose different repo roots.
