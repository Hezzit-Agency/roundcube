<p align="center">
    <img src="https://raw.githubusercontent.com/Hezzit-Agency/roundcube/main/logo.png"
        height="100">
</p>
<p align="center">
  <a href="https://github.com/Hezzit-Agency/roundcube/actions/workflows/docker-publish-dev.yml">
    <img src="https://github.com/Hezzit-Agency/roundcube/actions/workflows/docker-publish-dev.yml/badge.svg" alt="Dev Build" />
  </a>
  <a href="https://github.com/Hezzit-Agency/roundcube/actions/workflows/docker-publish.yml">
    <img src="https://github.com/Hezzit-Agency/roundcube/actions/workflows/docker-publish.yml/badge.svg" alt="Release Build" />
  </a>
  <a href="https://github.com/Hezzit-Agency/roundcube/releases">
    <img src="https://img.shields.io/github/v/release/Hezzit-Agency/roundcube?label=Latest%20Release" alt="Latest Release" />
  </a>
  <a href="https://github.com/Hezzit-Agency/roundcube/pkgs/container/roundcube">
    <img src="https://img.shields.io/docker/image-size/ghcr.io/hezzit-agency/roundcube/latest?label=Image%20Size" alt="Docker Image Size" />
  </a>
</p>

# 📬 Hezzit Roundcube Webmail – Docker Edition
Welcome to the **Dockerized Roundcube** setup from **Hezzit** — fast to deploy, easy to customize, and ready for production. Built for flexibility, it supports two operation modes:

- 🔧 **fpm-only**: Use it behind your own Nginx reverse proxy.
- 🚀 **full**: Includes Nginx + PHP-FPM in a single container.

> 📦 Image: `ghcr.io/hezzit-agency/roundcube`

---

## ⚡ Quick Launch

You don’t need to build anything. Just pull and run:

### 💚 Docker CLI Example
```bash
docker pull ghcr.io/hezzit-agency/roundcube:latest

docker run \
  -e RUN_MODE=fpm-only \
  -e MAX_UPLOAD_SIZE=100M \
  -e PHP_MEMORY_LIMIT=256M \
  -v "$PWD/roundcube_data/config.inc.php:/var/www/html/config/config.inc.php:ro" \
  -v "$PWD/roundcube_data/plugins:/custom_plugins:ro" \
  -v "$PWD/roundcube_data/skins:/custom_skins:ro" \
  -v "$PWD/roundcube_data/logs:/var/www/html/logs" \
  -v "$PWD/roundcube_data/temp:/var/www/html/temp" \
  -v "$PWD/roundcube_data/php.ini:/usr/local/etc/php/conf.d/zz-custom.ini:ro" \
  -p 9000:9000 \
  ghcr.io/hezzit-agency/roundcube:latest
```

### 🧱 Docker Compose Example
```yaml
services:
  roundcube:
    image: ghcr.io/hezzit-agency/roundcube:latest
    restart: unless-stopped
    ports:
      # Adjust the exposed port based on the selected RUN_MODE:
      #- "8080:80"   # Use this for RUN_MODE=full (internal Nginx)
      - "9000:9000"   # Use this for RUN_MODE=fpm-only (external Nginx). Adjust to match your external Nginx config.
    environment:
      # --- Mode Selection ---
      RUN_MODE: "fpm-only"         # Set to "full" or "fpm-only"
      # --- Upload and Memory Limits ---
      MAX_UPLOAD_SIZE: "100M"      # Max upload size, e.g., 100M or 1G
      PHP_MEMORY_LIMIT: "256M"     # PHP memory limit, e.g., 256M or 512M
      # --- Timezone (Optional) ---
      #TZ: "Europe/London"        # Examples: "America/Sao_Paulo", "Europe/Paris", "America/New_York"
      # --- Roundcube DES_KEY Checker (Optional) ---
      # Use to activate or deactivate the DES_KEY checker, preventing or not initialization (DEFAULT "false")
      #ROUNDCUBE_SKIP_DES_KEY_CHECK: "true" #OR "false"
      ################################
      # NOTE: Roundcube-specific settings (DB, SMTP, IMAP, DES_KEY, etc.)
      # should be configured directly in the mounted config.inc.php file below.
      ################################
    volumes:
      # --- Main Roundcube Configuration File ---
      - ./roundcube_data/config.inc.php:/var/www/html/config/config.inc.php:ro
      # --- Custom Plugins and Skins ---
      - ./roundcube_data/plugins:/custom_plugins:ro
      - ./roundcube_data/skins:/custom_skins:ro
      # --- Logs and Temp Files (Optional Persistence) ---
      - ./roundcube_data/logs:/var/www/html/logs
      - ./roundcube_data/temp:/var/www/html/temp
      # --- Additional PHP Configuration (Optional) ---
      # Use this file for additional PHP directives.
      # Avoid setting upload_max_filesize, post_max_size, and memory_limit here if using ENV variables above.
      - ./roundcube_data/php.ini:/usr/local/etc/php/conf.d/zz-custom.ini:ro
    healthcheck:
      # Healthcheck ensures proper startup based on the RUN_MODE
      test: ["CMD-SHELL", "MODE=$${RUN_MODE:-full}; if [ \"$$MODE\" = \"fpm-only\" ]; then supervisorctl status php-fpm | grep -q RUNNING; else supervisorctl status php-fpm | grep -q RUNNING && supervisorctl status nginx | grep -q RUNNING; fi"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 60s
```

### ⚙️ config.inc.php Example

```php
<?php

$config = [];

// ----------------------------------
// SQL DATABASE
// ----------------------------------

// Database connection string (DSN) for read+write operations
// Choose ONE of the options below based on your setup.

// OPTION 1: SQLite (for simple testing, data is stored inside the container volume)
// Ensure the '/var/www/html/SQL' directory is created with write permissions
// for www-data in the Dockerfile (as discussed previously).
$config['db_dsnw'] = 'sqlite:////var/www/html/SQL/sqlite.db?mode=0646';

// OPTION 2: MySQL/MariaDB (running in another Docker container)
// Uncomment the line below and replace placeholders:
// - 'user': The database user created for Roundcube.
// - 'password': The password for that user.
// - 'db_mariadb': The **service name** of your MariaDB/MySQL container in docker-compose.yml.
// - 'roundcubemail': The name of the database created for Roundcube.
// Ensure the 'pdo_mysql' PHP extension is installed in the Dockerfile (it currently is).
// $config['db_dsnw'] = 'mysql://user:password@db_mariadb/roundcubemail';

// OPTION 3: PostgreSQL (running in another Docker container)
// Uncomment the line below and replace placeholders:
// - 'user': The database user created for Roundcube.
// - 'password': The password for that user.
// - 'db_postgres': The **service name** of your PostgreSQL container in docker-compose.yml.
// - 'roundcubemail': The name of the database created for Roundcube.
// Ensure the 'pdo_pgsql' PHP extension is installed in the Dockerfile (it currently is).
// $config['db_dsnw'] = 'pgsql://user:password@db_postgres/roundcubemail';

// --- IMAP Configuration ---
// Connect to the 'mailserver' service within the Docker network.
// Use 'ssl://' prefix for Implicit TLS (port 993 usually).
// Use 'tls://' prefix for STARTTLS (port 143 usually).
// Using Implicit TLS on port 993 (standard and recommended).
$config['imap_host'] = 'ssl://mailserver:993';
//$config['imap_host'] = 'ssl://imap.yourdomain.com:993'; //(Another example)
//$config['smtp_host'] = 'tls://mail.yourdomain.com:143'; //(Another example)
// Optional: If mailserver requires full email address for login
// $config['username_domain'] = 'yourdomain.com'; // Replace with your domain

// --- SMTP Configuration ---
// Connect to the 'mailserver' service within the Docker network.
// Use 'ssl://' prefix for Implicit TLS (port 465 usually).
// Use 'tls://' prefix for STARTTLS (port 587 usually).
// Using STARTTLS on port 587 (standard submission port).
$config['smtp_host'] = 'tls://mailserver:587';
//$config['smtp_host'] = 'tls://smtp.yourdomain.com:587'; //(Another example)
//$config['smtp_host'] = 'ssl://mail.yourdomain.com:465'; //(Another example)

// SMTP username (if required) if you use %u as the username Roundcube
// will use the current username for login
$config['smtp_user'] = '%u';

// SMTP password (if required) if you use %p as the password Roundcube
// will use the current user's password for login
$config['smtp_pass'] = '%p';

// provide an URL where a user can get support for this Roundcube installation
// PLEASE DO NOT LINK TO THE ROUNDCUBE.NET WEBSITE HERE!
$config['support_url'] = '';

// Name your service. This is displayed on the login screen and in the window title
$config['product_name'] = 'Roundcube Webmail';

// REQUIRED: Secure key for encryption purposes (e.g., session data, passwords).
// MUST be changed to a random 24-byte string for security!
// You can generate one using: openssl rand -base64 24
// WARNING: Changing this key after users have logged in might cause issues.
$config['des_key'] = 'PLEASE_CHANGE_THIS_24BYTE_KEY!';

// List of active plugins (in plugins/ directory)
$config['plugins'] = [
    'archive',
    'zipdownload',
];

// skin name: folder from skins/
$config['skin'] = 'elastic';

// Enables display of email address with name instead of a name (and address in title)
$config['message_show_email'] = true;

// compose html formatted messages by default
//  0 - never,
//  1 - always,
//  2 - on reply to HTML message,
//  3 - on forward or reply to HTML message
//  4 - always, except when replying to plain text message
$config['htmleditor'] = 1;

// Message size limit. Note that SMTP server(s) may use a different value.
// This limit is verified when user attaches files to a composed message.
// Size in bytes (possible unit suffix: K, M, G)
// RECOMMENDED TO SET THE SAME SETTING AS >>MAX_UPLOAD_SIZE<<
$config['max_message_size'] = '100M';

// Display remote resources (inline images, styles) in HTML messages. Default: 0.
// 0 - Never, always ask
// 1 - Allow from my contacts (all writeable addressbooks + collected senders and recipients)
// 2 - Always allow
// 3 - Allow from trusted senders only
$config['show_images'] = 1;

// When replying:
// -1 - don't cite the original message
// 0  - place cursor below the original message
// 1  - place cursor above original message (top posting)
// 2  - place cursor above original message (top posting), but do not indent the quote
$config['reply_mode'] = 1;
```

---

## 🌟 Highlights

- 🐳 Minimal Alpine-based image
- 🧠 Smart auto-mode switching via environment variables
- 💡 Easy integration with custom plugins and themes
- 🔄 Configurable limits (upload size, memory, etc.)
- 📦 Persistent volumes for configs, logs, and temp
- ✅ Built-in healthcheck

---

## ⚙️ Configuration Cheat Sheet

### 📌 Environment Variables

| Name               | Default   | Description                              |
|--------------------|-----------|------------------------------------------|
| `RUN_MODE`        | `full`    | Mode of operation: `full` or `fpm-only` |
| `MAX_UPLOAD_SIZE` | `100M`    | Upload file size limit                   |
| `PHP_MEMORY_LIMIT`| `256M`    | PHP memory limit                         |
| `TZ`              | `UTC`     | Timezone, e.g., `Europe/London`          |
| `ROUNDCUBE_SKIP_DES_KEY_CHECK` | `false`     | Skip DES key check `(not recommended)` |

### 📁 Volume Mounts

| Host Path                                | Container Path                                     | Purpose                        |
|------------------------------------------|----------------------------------------------------|--------------------------------|
| `roundcube_data/config.inc.php`   | `/var/www/html/config/config.inc.php`              | Main Roundcube config          |
| `roundcube_data/plugins/`                | `/custom_plugins/`                                 | Custom plugins directory       |
| `roundcube_data/skins/`                  | `/custom_skins/`                                   | Custom skins directory         |
| `roundcube_data/logs/`                   | `/var/www/html/logs/`                              | Logs (optional)                |
| `roundcube_data/temp/`                   | `/var/www/html/temp/`                              | Temp files (optional)          |
| `roundcube_data/php.ini`                 | `/usr/local/etc/php/conf.d/zz-custom.ini`          | Additional PHP config (optional)|

---

## 🔐 DES Key Validation

The container enforces strong DES key configuration:
- Must be different from default/sample
- Must be 24 or 32 characters
If your key is invalid or missing, startup will abort.
To skip the validation (not recommended), set:
```bash
ROUNDCUBE_SKIP_DES_KEY_CHECK=true
```

---

## 👨‍💻 Local Development

To build locally:
```bash
docker build -t hezzit-roundcube:dev .
```
To run it interactively:
```bash
docker run -it hezzit-roundcube:dev
```

---

## 🙏 Acknowledgements

Special thanks to the creators and maintainers of the original [Roundcube Webmail](https://roundcube.net/), a powerful open-source IMAP client that this project is based on.

Also, appreciation to the open-source communities behind:
- [Nginx](https://nginx.org/) – Fast and flexible web server
- [PHP-FPM](https://www.php.net/manual/en/install.fpm.php) – PHP FastCGI Process Manager
- [Supervisor](http://supervisord.org/) – Process control system
- [Alpine Linux](https://alpinelinux.org/) – Lightweight base image
- [Docker](https://www.docker.com/) – The container platform powering this distribution

Without these tools, this container wouldn’t be possible.

---
Built with ❤️ by [Hezzit](http://hezz.it). Contributions are welcome!

>📄 License MIT

