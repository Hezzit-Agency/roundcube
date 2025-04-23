# 📬 Hezzit Roundcube Webmail – Docker Edition

[![Dev Build Status](https://github.com/Hezzit-Agency/roundcube/actions/workflows/docker-publish-dev.yml/badge.svg)](https://github.com/Hezzit-Agency/roundcube/actions/workflows/docker-publish-dev.yml)


Welcome to the **Dockerized Roundcube** setup from **Hezzit** — fast to deploy, easy to customize, and ready for production. Built for flexibility, it supports two operation modes:

- 🔧 **fpm-only**: Use it behind your own Nginx reverse proxy.
- 🚀 **full**: Includes Nginx + PHP-FPM in a single container.

> 📦 Image: `ghcr.io/hezzit-agency/roundcube`

---

## ⚡ Quick Launch

You don’t need to build anything. Just pull and run:

### 🐚 Docker CLI Example
```bash
docker pull ghcr.io/hezzit-agency/roundcube:latest

docker run \
  -e RUN_MODE=fpm-only \
  -e MAX_UPLOAD_SIZE=100M \
  -e PHP_MEMORY_LIMIT=256M \
  -v "$PWD/roundcube_data/config/config.inc.php:/var/www/html/config/config.inc.php:ro" \
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
      # - "8080:80"   # Use this for RUN_MODE=full (internal Nginx)
      - "9000:9000"   # Use this for RUN_MODE=fpm-only (external Nginx). Adjust to match your external Nginx config.
    environment:
      # --- Mode Selection ---
      RUN_MODE: "fpm-only"         # Set to "full" or "fpm-only"
      # --- Upload and Memory Limits ---
      MAX_UPLOAD_SIZE: "100M"      # Max upload size, e.g., 100M or 1G
      PHP_MEMORY_LIMIT: "256M"     # PHP memory limit, e.g., 256M or 512M
      # --- Timezone (Optional) ---
      # TZ: "Europe/London"        # Examples: "America/Sao_Paulo", "Europe/Paris", "America/New_York"
      # NOTE: Roundcube-specific settings (DB, SMTP, IMAP, DES_KEY, etc.)
      # should be configured directly in the mounted config.inc.php file below.
    volumes:
      # --- Main Roundcube Configuration File ---
      - ./roundcube_data/config/config.inc.php:/var/www/html/config/config.inc.php:ro
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

### 📁 Volume Mounts

| Host Path                                | Container Path                                     | Purpose                        |
|------------------------------------------|----------------------------------------------------|--------------------------------|
| `roundcube_data/config/config.inc.php`   | `/var/www/html/config/config.inc.php`              | Main Roundcube config          |
| `roundcube_data/plugins/`                | `/custom_plugins/`                                 | Custom plugins directory       |
| `roundcube_data/skins/`                  | `/custom_skins/`                                   | Custom skins directory         |
| `roundcube_data/logs/`                   | `/var/www/html/logs/`                              | Logs (optional)                |
| `roundcube_data/temp/`                   | `/var/www/html/temp/`                              | Temp files (optional)          |
| `roundcube_data/php.ini`                 | `/usr/local/etc/php/conf.d/zz-custom.ini`          | Additional PHP config (optional)|

---

## 🧠 How It Works

- The container dynamically switches between `fpm-only` and `full` mode.
- PHP and Nginx configs are adjusted based on the chosen limits.
- Custom plugins and skins are copied into the container.
- `supervisord` is used to manage the processes.
- Healthcheck confirms PHP and Nginx are active (based on mode).

---

## 👨‍💻 Development & Testing

To build locally:
```bash
docker build -t ghcr.io/hezzit-agency/roundcube:dev .
```
To run it interactively:
```bash
docker run -it ghcr.io/hezzit-agency/roundcube:dev
```

---
Built with ❤️ by [Hezzit](http://hezz.it). Contributions are welcome!

>📄 License MIT

