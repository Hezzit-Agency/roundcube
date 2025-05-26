# Complete Dockerfile for Roundcube with Nginx, PHP-FPM, and Entrypoint for Overlay

# Use the official PHP FPM Alpine base image (already includes PHP and FPM)
FROM php:8.3-fpm-alpine

# Roundcube version (can be changed at build time with --build-arg)
ARG ROUNDCUBE_VERSION=1.6.10
ENV ROUNDCUBE_VERSION=${ROUNDCUBE_VERSION}

# Default working directory
WORKDIR /var/www/html

# --- Install System Dependencies and Tools ---

# Install build-time dependencies
# Creates a virtual group .build-deps that will be removed later
RUN apk add --no-cache --virtual .build-deps \
        build-base \
        autoconf \
        icu-dev \
        libzip-dev \
        libpng-dev \
        libjpeg-turbo-dev \
        freetype-dev \
        openldap-dev \
        imagemagick-dev \
        postgresql-dev \
        mariadb-connector-c-dev \
        oniguruma-dev

# Install runtime dependencies and necessary tools
RUN apk add --no-cache \
        nginx \
        wget \
        tar \
        icu-libs \
        libpng \
        libjpeg-turbo \
        freetype \
        openldap \
        libzip \
        imagemagick \
        postgresql-libs \
        mariadb-connector-c \
        oniguruma \
        rsync \
        openssl \
        sed

# === EDIT NGINX.CONF TO ENSURE FOREGROUND (CORRECTED DIRECTIVE) ===
# Delete any existing 'daemon' or 'daemonize' directive line (commented or not)
RUN sed -i '/^\s*#*\s*daemon\(ize\)\?\s*.*;/d' /etc/nginx/nginx.conf
# Add 'daemon off;' correctly at the beginning of the file (global context)
RUN sed -i '1i daemon off;' /etc/nginx/nginx.conf
# ============================================

# Install composer globally
RUN wget https://getcomposer.org/installer -O - -q | php -- --install-dir=/usr/local/bin --filename=composer

# Configure PHP extensions requiring options (e.g., GD)
RUN docker-php-ext-configure gd --with-freetype --with-jpeg

# Install PHP extensions required for Roundcube and common ones
RUN docker-php-ext-install -j$(nproc) \
        zip \
        fileinfo \
        exif \
        ldap \
        pdo \
        pdo_sqlite \
        pdo_mysql \
        pdo_pgsql \
        gd \
        intl \
        mbstring \
        ctype \
        opcache

# Remove build dependencies to keep the image smaller
RUN apk del .build-deps

# Copy cmd of running binaries
COPY nginx-cmd.sh /usr/local/bin/nginx-cmd.sh
COPY php-fpm-cmd.sh /usr/local/bin/php-fpm-cmd.sh
RUN chmod +x /usr/local/bin/php-fpm-cmd.sh /usr/local/bin/nginx-cmd.sh

# Copy Nginx configuration (only used in 'full' mode)
COPY nginx-default.conf /etc/nginx/http.d/default.conf

# Copy the helper PHP script for DES key extraction
COPY check-key.php /usr/local/bin/check-key.php
RUN chmod +x /usr/local/bin/check-key.php

# Copy and set execute permission for the entrypoint script
COPY docker-entrypoint.sh /docker-entrypoint.sh
RUN chmod +x /docker-entrypoint.sh

# --- Install Roundcube ---

# Step 1.1: Download Roundcube
RUN echo "----> Downloading Roundcube version ${ROUNDCUBE_VERSION}..." \
    && cd /tmp \
    && wget "https://github.com/roundcube/roundcubemail/releases/download/${ROUNDCUBE_VERSION}/roundcubemail-${ROUNDCUBE_VERSION}-complete.tar.gz" -O roundcube.tar.gz

# Step 1.2: Extract Roundcube
RUN echo "----> Extracting Roundcube to /var/www/html..." \
    && cd /tmp \
    && tar -xzf roundcube.tar.gz --strip-components=1 -C /var/www/html \
    && rm roundcube.tar.gz

# Step 2.1: Download 'classic' skin
RUN echo "----> Downloading classic skin release 1.6.0..." \
    && cd /tmp \
    && wget "https://github.com/roundcube/classic/archive/refs/tags/1.6.0.tar.gz" -O classic-skin.tar.gz

# Step 2.2: Create target directory for classic skin
RUN echo "----> Creating target directory for classic skin..." \
    && mkdir -p /var/www/html/skins/classic

# Step 2.3: Extract 'classic' skin
RUN echo "----> Extracting classic skin to /var/www/html/skins/classic..." \
    && cd /tmp \
    && tar -xzf classic-skin.tar.gz --strip-components=1 -C /var/www/html/skins/classic \
    && rm classic-skin.tar.gz

# Step 2.4: Set ownership for classic skin and return to WORKDIR
RUN echo "----> Setting ownership for classic skin..." \
    && chown -R www-data:www-data /var/www/html/skins/classic \
    && cd /var/www/html # Go back to /var/www/html if subsequent steps expect it

# Step 3: Install PHP Dependencies using Composer
RUN echo "----> Installing composer dependencies (add --verbose here for more details if needed)..." \
    && cd /var/www/html \
    && composer install --no-dev --optimize-autoloader --no-progress --profile

# --- Finalize Permissions and Clean Up ---

# Step 4.1: Create Dirs (temp, logs, SQL)
RUN echo "----> Creating directories (temp, logs, SQL)..." \
    && cd /var/www/html \
    && mkdir -p temp logs SQL

# Step 4.2: Set base ownership and permissions for /var/www/html
RUN echo "----> Setting base ownership and permissions for /var/www/html..." \
    && chown -R www-data:www-data /var/www/html \
    && find /var/www/html -type d -exec chmod 755 {} \; \
    && find /var/www/html -type f -exec chmod 644 {} \;

# Step 4.3: Adjust write permissions for specific directories (temp, logs, config, plugins, skins, SQL)
RUN echo "----> Adjusting write permissions for specific directories..." \
    && cd /var/www/html \
    && chown -R www-data:www-data temp logs config plugins skins SQL \
    && chmod -R u+rwX temp logs config plugins skins SQL

# Step 4.4: Clean up temporary files, installer, and composer cache
RUN echo "----> Cleaning up temporary files and caches..." \
    && rm -rf /tmp/* \
              /var/www/html/installer \
              /root/.composer

# Define Volumes for persistent data and main external configuration
# Note that /plugins and /skins are NOT defined here, as they will be managed
# by the entrypoint script using mounts at /custom_plugins and /custom_skins
VOLUME /var/www/html/SQL /var/www/html/logs /var/www/html/temp

# Expose the Nginx port (80) and the PHP-FPM port (9000)
EXPOSE 80 9000

# Define the Entrypoint
ENTRYPOINT ["/docker-entrypoint.sh"]
