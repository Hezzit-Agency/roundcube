# 🚀 Full Stack Mail Server Deployment Guide (Traefik + Stalwart + Roundcube)

Welcome to your **comprehensive full-stack mail server setup**, built using:

- 🌐 [**Traefik**](https://github.com/traefik/traefik): Modern reverse proxy and edge router
- 📧 [**Stalwart Mail Server**](https://github.com/stalwartlabs/mail-server): High-performance email server
- 💌 [**Roundcube Webmail**](https://github.com/Hezzit-Agency/roundcube): Sleek, extensible webmail client pre-built at `ghcr.io/hezzit-agency/roundcube`

---

## 🛠️ Prerequisites & Preparation

> ⚠️ **IMPORTANT:** Before proceeding, replace all instances of `*.example.org`, `you@example.org`, and weak default passwords (like `example`, `roundcube_pass`) with your **actual domain names**, email address, and **secure credentials**.

---

## 🌐 DNS Configuration

Correct DNS setup is **critical** for ensuring your mail stack functions properly.

### ✅ Required DNS Records

| Hostname               | Record Type | Value                   | Purpose                          |
|------------------------|-------------|-------------------------|----------------------------------|
| mail.example.org       | A / AAAA    | YOUR_SERVER_PUBLIC_IP   | Stalwart Mail protocols          |
| adminmail.example.org  | A / AAAA    | YOUR_SERVER_PUBLIC_IP   | Stalwart Admin UI access         |
| webmail.example.org    | A / AAAA    | YOUR_SERVER_PUBLIC_IP   | Roundcube Webmail interface      |
| traefik.example.org    | A / AAAA    | YOUR_SERVER_PUBLIC_IP   | *(optional)* Traefik Dashboard   |

> ✨ Also configure **MX, SPF, DKIM, and DMARC** records to ensure mail deliverability.
> 🔗 Follow the [Stalwart DNS setup guide](https://stalw.art/docs/install/docker/).

---

## 🧱 Stack Overview

### 🔄 Traefik
- Routes HTTP/HTTPS traffic to web services
- Handles TCP pass-through for SMTP, IMAP, POP3
- Manages TLS certs via Let's Encrypt (ACME)

### 📮 Stalwart Mail Server
- Handles all mail protocols (SMTP, IMAP, POP3)
- Admin UI at `adminmail.example.org`

### 🛢️ MariaDB
- Backend database for Roundcube

### 💌 Roundcube Webmail
- Webmail frontend accessible at `webmail.example.org`

---

## 🐳 Docker Compose File (`docker-compose.yml`)

> 📌 Pin image versions (avoid `latest`) for stability in production environments.

```yaml
services:
  # --- Traefik: Reverse Proxy and Edge Router ---
  traefik:
    image: traefik:latest # Consider pinning to a specific version (e.g., traefik:v2.10) for stability
    container_name: traefik # Optional: Define a specific container name
    restart: always
    command:
      # --- API and Dashboard ---
      - --api.dashboard=true                # Enable the Traefik dashboard
      # --- Providers ---
      - --providers.docker=true             # Enable Docker configuration provider
      - --providers.docker.exposedbydefault=false # Only expose containers with 'traefik.enable=true' label
      # --- Entrypoints (Ports Traefik listens on) ---
      - --entrypoints.web.address=:80       # HTTP
      - --entrypoints.websecure.address=:443 # HTTPS
      - --entrypoints.smtp.address=:25        # SMTP (STARTTLS/plaintext)
      - --entrypoints.smtps.address=:465      # SMTPS (Implicit TLS)
      - --entrypoints.submission.address=:587 # Submission (STARTTLS)
      - --entrypoints.pop3.address=:110       # POP3 (STARTTLS/plaintext)
      - --entrypoints.pop3s.address=:995      # POP3S (Implicit TLS)
      - --entrypoints.imap.address=:143       # IMAP (STARTTLS/plaintext)
      - --entrypoints.imaps.address=:993      # IMAPS (Implicit TLS)
      # --- Let's Encrypt / ACME ---
      - --certificatesresolvers.le.acme.email=you@example.org # !!! CHANGE THIS to your valid email !!!
      - --certificatesresolvers.le.acme.storage=/letsencrypt/acme.json # Path inside container to store ACME certs
      - --certificatesresolvers.le.acme.tlschallenge=true       # Enable TLS-ALPN-01 challenge (consider httpchallenge if port 80 is open)
      # --- Logging (Optional) ---
      # - --log.level=DEBUG # Set log level (DEBUG, INFO, WARN, ERROR)
    ports:
      # Map host ports to Traefik's entrypoint ports
      - "80:80"       # HTTP
      - "443:443"     # HTTPS
      - "25:25"       # SMTP
      - "465:465"     # SMTPS
      - "587:587"     # Submission
      - "110:110"     # POP3
      - "995:995"     # POP3S
      - "143:143"     # IMAP
      - "993:993"     # IMAPS
    volumes:
      # Mount volume for persistent Let's Encrypt certificate storage
      - ./letsencrypt:/letsencrypt
      # Mount Docker socket (read-only) to allow Traefik to detect container changes
      - /var/run/docker.sock:/var/run/docker.sock:ro
    healthcheck:
      # Check if Traefik's internal ping endpoint is responding
      test: ["CMD", "wget", "--spider", "-q", "http://localhost:8080/ping"] # Use internal API port
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 60s # Give Traefik time to start up

  # --- Stalwart Mail Server ---
  mailserver:
    image: stalwartlabs/mail-server:latest # Consider pinning to a specific version
    container_name: stalwart # Optional: Define a specific container name
    restart: always
    hostname: mail.example.org # !!! CHANGE THIS to your primary mail domain !!!
    volumes:
      # Mount host directory for all Stalwart data (config, storage, logs, internal db)
      - ./stalwart-mail:/opt/stalwart-mail
    # --- Admin Access Information ---
    # For details on accessing the Stalwart Admin UI (routed via adminmail.example.org by default)
    # and initial setup/credentials, please refer to the official documentation:
    # https://stalw.art/docs/install/docker/
    labels:
      # Enable Traefik service discovery for this container
      - traefik.enable=true

      # --- HTTP Routing: Stalwart Admin UI ---
      # Route traffic for adminmail.example.org via HTTPS to Stalwart's internal port 8080
      - traefik.http.routers.mailadmin.rule=Host(`adminmail.example.org`) # !!! CHANGE DOMAIN !!!
      - traefik.http.routers.mailadmin.entrypoints=websecure             # Use HTTPS entrypoint
      - traefik.http.routers.mailadmin.tls.certresolver=le               # Use Let's Encrypt for TLS certs
      - traefik.http.services.mailadmin.loadbalancer.server.port=8080    # Stalwart's internal Admin UI/API port

      # --- TCP Routing: Mail Protocols (TLS Passthrough) ---
      # Traefik passes encrypted TCP traffic directly to Stalwart, which handles TLS.
      # Routing is based on the domain requested via SNI during the TLS handshake.

      # SMTP (Port 25)
      - traefik.tcp.routers.smtp.rule=HostSNI(`mail.example.org`) # !!! CHANGE DOMAIN !!!
      - traefik.tcp.routers.smtp.entrypoints=smtp
      - traefik.tcp.routers.smtp.tls.passthrough=true           # Stalwart handles TLS
      - traefik.tcp.services.smtp.loadbalancer.server.port=25   # Stalwart internal SMTP port
      # - traefik.tcp.services.smtp.loadbalancer.proxyprotocol.version=2 # !!! Enable ONLY if Stalwart is configured for PROXY protocol !!!

      # SMTPS (Port 465)
      - traefik.tcp.routers.smtps.rule=HostSNI(`mail.example.org`) # !!! CHANGE DOMAIN !!!
      - traefik.tcp.routers.smtps.entrypoints=smtps
      - traefik.tcp.routers.smtps.tls.passthrough=true
      - traefik.tcp.services.smtps.loadbalancer.server.port=465
      # - traefik.tcp.services.smtps.loadbalancer.proxyprotocol.version=2 # !!! Enable ONLY if Stalwart is configured for PROXY protocol !!!

      # Submission (Port 587)
      - traefik.tcp.routers.submission.rule=HostSNI(`mail.example.org`) # !!! CHANGE DOMAIN !!!
      - traefik.tcp.routers.submission.entrypoints=submission
      - traefik.tcp.routers.submission.tls.passthrough=true
      - traefik.tcp.services.submission.loadbalancer.server.port=587
      # - traefik.tcp.services.submission.loadbalancer.proxyprotocol.version=2 # !!! Enable ONLY if Stalwart is configured for PROXY protocol !!!

      # POP3 (Port 110)
      - traefik.tcp.routers.pop3.rule=HostSNI(`mail.example.org`) # !!! CHANGE DOMAIN !!!
      - traefik.tcp.routers.pop3.entrypoints=pop3
      - traefik.tcp.routers.pop3.tls.passthrough=true
      - traefik.tcp.services.pop3.loadbalancer.server.port=110
      # - traefik.tcp.services.pop3.loadbalancer.proxyprotocol.version=2 # !!! Enable ONLY if Stalwart is configured for PROXY protocol !!!

      # POP3S (Port 995)
      - traefik.tcp.routers.pop3s.rule=HostSNI(`mail.example.org`) # !!! CHANGE DOMAIN !!!
      - traefik.tcp.routers.pop3s.entrypoints=pop3s
      - traefik.tcp.routers.pop3s.tls.passthrough=true
      - traefik.tcp.services.pop3s.loadbalancer.server.port=995
      # - traefik.tcp.services.pop3s.loadbalancer.proxyprotocol.version=2 # !!! Enable ONLY if Stalwart is configured for PROXY protocol !!!

      # IMAP (Port 143)
      - traefik.tcp.routers.imap.rule=HostSNI(`mail.example.org`) # !!! CHANGE DOMAIN !!!
      - traefik.tcp.routers.imap.entrypoints=imap
      - traefik.tcp.routers.imap.tls.passthrough=true
      - traefik.tcp.services.imap.loadbalancer.server.port=143
      # - traefik.tcp.services.imap.loadbalancer.proxyprotocol.version=2 # !!! Enable ONLY if Stalwart is configured for PROXY protocol !!!

      # IMAPS (Port 993)
      - traefik.tcp.routers.imaps.rule=HostSNI(`mail.example.org`) # !!! CHANGE DOMAIN !!!
      - traefik.tcp.routers.imaps.entrypoints=imaps
      - traefik.tcp.routers.imaps.tls.passthrough=true
      - traefik.tcp.services.imaps.loadbalancer.server.port=993
      # - traefik.tcp.services.imaps.loadbalancer.proxyprotocol.version=2 # !!! Enable ONLY if Stalwart is configured for PROXY protocol !!!
    healthcheck:
      # Basic check if Stalwart's SMTP port is responding
      test: ["CMD-SHELL", "nc -z localhost 25 || exit 1"] # Use exit 1 on failure
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 60s # Give Stalwart time to initialize

  # --- MariaDB Database ---
  mariadb:
    image: mariadb:latest # Consider pinning to a specific version (e.g., mariadb:10.11)
    container_name: mariadb # Optional: Define a specific container name
    restart: always
    environment:
      MYSQL_ROOT_PASSWORD: 'example'     # !!! CHANGE THIS to a strong root password !!!
      MYSQL_DATABASE: roundcube          # Database name for Roundcube
      MYSQL_USER: roundcube              # Database user for Roundcube
      MYSQL_PASSWORD: 'roundcube_pass' # !!! CHANGE THIS to a strong password for the roundcube user !!!
    volumes:
      # Mount host directory for persistent database storage
      - ./mariadb_data:/var/lib/mysql
    healthcheck:
      # Check if the database server is responding using mysqladmin
      test: ["CMD-SHELL", "mysqladmin ping -h localhost -u root -p'${MYSQL_ROOT_PASSWORD}' || exit 1"] # Use root password variable
      interval: 30s
      timeout: 10s
      retries: 5
      start_period: 60s # Give MariaDB time to initialize

  # --- Roundcube Webmail ---
  roundcube:
    image: ghcr.io/hezzit-agency/roundcube:latest # Your Roundcube image
    container_name: roundcube # Optional: Define a specific container name
    restart: always
    depends_on: # Ensure DB and mailserver services are healthy before starting Roundcube
      mariadb:
        condition: service_healthy
      mailserver:
        condition: service_started # Mailserver healthcheck is basic, wait for it to start
    environment:
      # --- Mode Selection ---
      RUN_MODE: "full"                # Use internal Nginx + PHP-FPM (listens on port 80)
      # --- Upload/Memory Limits ---
      MAX_UPLOAD_SIZE: "100M"       # Set max upload size for PHP & internal Nginx (if applicable)
      PHP_MEMORY_LIMIT: "256M"      # Set memory limit for PHP (adjust if needed)
      # --- Database/Mail Config ---
      # Ensure these are set correctly in config.inc.php:
      # - DB Host: mariadb
      # - DB User/Pass/Name: Match MariaDB environment variables
      # - IMAP/SMTP Host: mailserver (service name)
      # - Secure des_key
    volumes:
      # Mount the main Roundcube configuration file (read-only is safer)
      - ./roundcube_data/config.inc.php:/var/www/html/config/config.inc.php:ro
      # Optional: Mount volumes for logs, temp files, custom plugins/skins if needed
      # - ./roundcube_data/logs:/var/www/html/logs
      # - ./roundcube_data/temp:/var/www/html/temp
      # - ./roundcube_data/plugins:/custom_plugins:ro # Mount custom plugins folder (if entrypoint handles it)
      # - ./roundcube_data/skins:/custom_skins:ro     # Mount custom skins folder (if entrypoint handles it)
    labels:
      # Enable Traefik for this service
      - traefik.enable=true
      # --- HTTP Routing: Roundcube Webmail ---
      # Route traffic for webmail.example.org via HTTPS to Roundcube's internal port 80
      - traefik.http.routers.roundcube.rule=Host(`webmail.example.org`) # !!! CHANGE DOMAIN !!!
      - traefik.http.routers.roundcube.entrypoints=websecure             # Use HTTPS entrypoint
      - traefik.http.routers.roundcube.tls.certresolver=le               # Use Let's Encrypt for TLS certs
      # Service points to the internal Nginx port (80) used in "full" mode
      - traefik.http.services.roundcube.loadbalancer.server.port=80
    healthcheck:
      # Healthcheck specific to the ghcr.io/hezzit-agency/roundcube image entrypoint logic
      # It checks if supervisor is running the correct processes based on RUN_MODE
      test: ["CMD-SHELL", "MODE=$${RUN_MODE:-full}; if [ \"$$MODE\" = \"fpm-only\" ]; then supervisorctl status php-fpm | grep -q RUNNING; else supervisorctl status php-fpm | grep -q RUNNING && supervisorctl status nginx | grep -q RUNNING; fi || exit 1"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 60s # Give Roundcube time to start
```

---

## ⚙️ Roundcube Configuration (`./roundcube/config.inc.php`)

> This is a minimal setup to get started. To customize, refer to the [Roundcube config reference](https://github.com/roundcube/roundcubemail/blob/master/config/defaults.inc.php).

```php
<?php
$config = [];
$config['db_dsnw'] = 'mysql://roundcube:roundcube_pass@mariadb/roundcube';
$config['imap_host'] = 'mailserver:143';
$config['smtp_host'] = 'mailserver:25';
$config['smtp_user'] = '%u';
$config['smtp_pass'] = '%p';
$config['support_url'] = '';
$config['product_name'] = 'Roundcube Webmail';
$config['des_key'] = '!_PLEASE_CHANGE_THIS_24BYTE_KEY_!';
$config['plugins'] = ['archive', 'zipdownload'];
$config['skin'] = 'elastic';
$config['message_show_email'] = true;
$config['htmleditor'] = 1;
$config['max_message_size'] = '80M';
$config['show_images'] = 1;
$config['reply_mode'] = 1;
```

---

## 💡 Pro Tips

- ✅ Add healthchecks to all services for better container monitoring
- 🔐 Use strong, rotated TLS certificates
- 🧪 Test mail deliverability with [Mail Tester](https://www.mail-tester.com/) or [MXToolbox](https://mxtoolbox.com/)
- ⚙️ For testing, use Let's Encrypt staging:  
  `--certificatesresolvers.le.acme.caServer=https://acme-staging-v02.api.letsencrypt.org/directory`

---

## ✅ Final Checklist

- [ ] A/AAAA + MX + SPF + DKIM + DMARC records configured
- [ ] Admin UI works at `https://adminmail.example.org`
- [ ] Webmail accessible at `https://webmail.example.org`
- [ ] SMTP, IMAP, POP3 ports exposed and reachable
- [ ] TLS certs valid & auto-renewed
- [ ] Mail send/receive functional, no spam folder issues

---

## 🔧 Optional Enhancements

- 🛡️ Setup **firewall rules** to harden access to ports
- 📦 Enable **backups** for mail data and Roundcube DB
- 🧪 Add **unit/integration tests** for mail flow using Mailhog or test scripts

---

Enjoy your **secure, production-ready, self-hosted email server!** ✉️