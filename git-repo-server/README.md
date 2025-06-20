# Git Repo Server — Git over HTTP with Apache

This project demonstrates how to configure **Apache HTTPD** to serve Git repositories over **HTTP/S** using the `git-http-backend` CGI script. It includes secure access via **Basic Authentication**, optional **SELinux** configuration (for RHEL-based distros), and fully automated cross-platform setup scripts that support both **Rocky Linux/Fedora** and **Ubuntu/Debian** systems.

---

## 📦 Features

- Git hosting over HTTP/S using Apache and `git-http-backend`
- Secure access using `.htpasswd` (Basic Auth)
- SELinux-aware configuration for Fedora/RHEL
- OS-aware Apache configuration (Fedora vs Ubuntu)
- One-step installation via `install-server.sh`
- Easy repository creation with `add-repo.sh`
- Repository deletion with `delete-repo.sh`
- Repository discovery via `list-repos.sh`
- Compatible with both **APT** and **DNF** based systems

---

## 📁 Files

| File               | Description                                                             |
|--------------------|-------------------------------------------------------------------------|
| `git.fedora.conf`  | Apache config for Fedora/RHEL (`/usr/libexec/git-core/...`)             |
| `git.ubuntu.conf`  | Apache config for Ubuntu/Debian (`/usr/lib/git-core/...`)               |
| `install-server.sh`| Installs and configures the Git HTTP server                             |
| `add-repo.sh`      | Adds a new bare Git repository to `/repos`                              |
| `delete-repo.sh`   | Deletes an existing Git repository from `/repos`                        |
| `list-repos.sh`    | Lists existing repositories in `/repos`                                 |
| `_config.yml`      | GitHub Pages config (optional)                                          |
| `LICENSE`          | MIT License                                                             |
| `README.md`        | You're reading it                                                       |

---

## 🚀 Getting Started

> ✅ Works on **Ubuntu**, **Debian**, **Fedora**, **Rocky**, **CentOS**, and **AlmaLinux**

```bash
git clone https://github.com/funkybooboo/git-repo-server.git
cd git-repo-server
chmod +x install-server.sh add-repo.sh delete-repo.sh list-repos.sh
./install-server.sh
````

Then access the test repo in your browser:
📡 [http://localhost/repos/test.git](http://localhost/repos/test.git)

---

## ➕ Add a New Repository

```bash
./add-repo.sh my-project
```

Then clone it:

```bash
git clone http://bob@localhost/repos/my-project.git
```

---

## 🗑️ Delete a Repository

```bash
./delete-repo.sh my-project
```

This will prompt you for confirmation before permanently deleting the repository from `/repos`.

---

## 📋 List Existing Repositories

```bash
./list-repos.sh
```

Filter by name:

```bash
./list-repos.sh my
```

---

## 🔐 Default Access

| Field    | Value         |
| -------- | ------------- |
| User     | `bob`         |
| Password | `bobpassword` |

You can modify the credentials inside `install-server.sh` or directly using:

```bash
# Ubuntu
sudo htpasswd /etc/apache2/conf-available/git.passwd bob

# Fedora
sudo htpasswd /etc/httpd/conf.d/git.passwd bob
```

---

## ⚙️ How It Works

Apache is configured to:

* Serve `/repos/*.git` using `git-http-backend`
* Restrict access via Basic Auth
* Use the correct backend path depending on distro:

  * **Ubuntu**: `/usr/lib/git-core/git-http-backend`
  * **Fedora**: `/usr/libexec/git-core/git-http-backend`
* Set the required environment: `GIT_PROJECT_ROOT=/repos`
* Enable all required Apache modules:

  * `cgid`, `alias`, `env`, `auth_basic`, `authn_file`, `dav`, `dav_fs`
* On Fedora-based systems, applies SELinux contexts to `/repos`

---

## 📎 Tips & Notes

* ✅ Apache modules are enabled automatically on Ubuntu
* 🔐 Add additional users with `htpasswd`
* 🌍 Expose port 80 and configure DNS for remote access
* 🔁 Restart Apache with:

```bash
# Ubuntu/Debian
sudo systemctl restart apache2

# Fedora/RHEL
sudo systemctl restart httpd
```

---

## 🐧 Credits

Created by [@funkybooboo](https://github.com/funkybooboo)
Based on a guide by [The Urban Penguin](https://x.com/theurbanpenguin)
