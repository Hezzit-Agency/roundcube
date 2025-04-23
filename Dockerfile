# Complete Dockerfile for Roundcube with Nginx, PHP-FPM, and Entrypoint for Overlay

# Use the official PHP FPM Alpine base image (already includes PHP and FPM)
FROM php:8.3-fpm-alpine

# Roundcube version (can be changed at build time with --build-arg)
ARG ROUNDCUBE_VERSION=1.6.10
ENV ROUNDCUBE_VERSION=${ROUNDCUBE_VERSION}

# Default working directory
WORKDIR /var/www/html

# Install Nginx, Supervisor, system/PHP dependencies, and tools
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
        oniguruma-dev \
    # Install runtime dependencies and necessary tools
    && apk add --no-cache \
        nginx \
        supervisor \
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
        sed \
    # === EDIT NGINX.CONF TO ENSURE FOREGROUND (CORRECTED DIRECTIVE) ===
    # Delete any existing 'daemon' or 'daemonize' directive line (commented or not)
    && sed -i '/^\s*#*\s*daemon\(ize\)\?\s*.*;/d' /etc/nginx/nginx.conf \
    # Add 'daemon off;' correctly at the beginning of the file (global context)
    && sed -i '1i daemon off;' /etc/nginx/nginx.conf \
    # ============================================
    # Install composer globally
    && wget https://getcomposer.org/installer -O - -q | php -- --install-dir=/usr/local/bin --filename=composer \
    # Configure PHP extensions requiring options (e.g., GD)
    && docker-php-ext-configure gd --with-freetype --with-jpeg \
    # Install PHP extensions required for Roundcube and common ones
    && docker-php-ext-install -j$(nproc) \
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
        opcache \
    # Remove build dependencies to keep the image smaller
    && apk del .build-deps \
    # Create directory for supervisor logs (optional, but good practice)
    && mkdir -p /var/log/supervisor

# Copy BOTH Supervisor configuration files
COPY supervisord-full.conf /etc/supervisor/supervisord-full.conf
COPY supervisord-fpm-only.conf /etc/supervisor/supervisord-fpm-only.conf

# Copy Nginx configuration (only used in 'full' mode)
COPY nginx-default.conf /etc/nginx/http.d/default.conf

# Copy the helper PHP script for DES key extraction
COPY check-key.php /usr/local/bin/check-key.php
RUN chmod +x /usr/local/bin/check-key.php

# Copy and set execute permission for the entrypoint script
COPY docker-entrypoint.sh /docker-entrypoint.sh
RUN chmod +x /docker-entrypoint.sh

# --- Install Roundcube ---

# Step 1: Download and Extract Roundcube
RUN echo "----> Downloading Roundcube version ${ROUNDCUBE_VERSION}..." \
    && cd /tmp \
    && wget "https://github.com/roundcube/roundcubemail/releases/download/${ROUNDCUBE_VERSION}/roundcubemail-${ROUNDCUBE_VERSION}-complete.tar.gz" -O roundcube.tar.gz \
    && echo "----> Extracting Roundcube to /var/www/html..." \
    && tar -xzf roundcube.tar.gz --strip-components=1 -C /var/www/html \
    && rm roundcube.tar.gz

# Step 2: Install 'classic' skin dependency using Composer
RUN echo "----> Requiring classic skin..." \
    && cd /var/www/html \
    && composer require --no-update roundcube/classic:"~1.6" --profile

# Step 3: Install PHP Dependencies using Composer
RUN echo "----> Installing composer dependencies (add --verbose here for more details if needed)..." \
    && cd /var/www/html \
    && composer install --no-dev --optimize-autoloader --no-progress --profile

# Step 4: Create Dirs, Set Permissions, and Clean Up
RUN echo "----> Creating directories and setting permissions..." \
    && cd /var/www/html \
    && mkdir -p temp logs SQL \
    # Set base ownership/permissions
    && chown -R www-data:www-data /var/www/html \
    && find /var/www/html -type d -exec chmod 755 {} \; \
    && find /var/www/html -type f -exec chmod 644 {} \; \
    # Adjust permissions for directories needing write access by www-data (safer: only user)
    && echo "----> Adjusting write permissions for specific directories..." \
    && chown -R www-data:www-data temp logs config plugins skins SQL \
    && chmod -R u+rwX temp logs config plugins skins SQL \
    # Clean up
    && echo "----> Cleaning up temporary files and caches..." \
    && rm -rf /tmp/* \
              /var/www/html/installer \
              /root/.composer

# Define Volumes for persistent data and main external configuration
# Note that /plugins and /skins are NOT defined here, as they will be managed
# by the entrypoint script using mounts at /custom_plugins and /custom_skins
VOLUME /var/www/html/config /var/www/html/logs /var/www/html/temp

# Expose the Nginx port (80) and the PHP-FPM port (9000)
EXPOSE 80 9000

# Define the Entrypoint
ENTRYPOINT ["/docker-entrypoint.sh"]

# Default command (will be passed to the entrypoint)
# The entrypoint will add the "-c <correct_conf_file>"
CMD ["/usr/bin/supervisord"]