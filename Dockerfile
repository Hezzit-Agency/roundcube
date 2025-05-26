# Complete Dockerfile for Roundcube with Nginx, PHP-FPM, and Entrypoint for Overlay
# Optimized for smaller image size using multi-stage builds

# ---- Builder Stage ----
# This stage will compile assets, download dependencies, and prepare the application.
# Its artifacts will be copied to the final image, but this stage itself won't be part of the final image.
FROM php:8.3-fpm-alpine AS builder

# Roundcube version (can be changed at build time with --build-arg)
ARG ROUNDCUBE_VERSION=1.6.10
ENV ROUNDCUBE_VERSION=${ROUNDCUBE_VERSION}

# Set a temporary working directory for build operations to keep things clean
WORKDIR /app

# --- Install System Dependencies and Tools for Building ---
# Install build-time dependencies for PHP extensions,
# PHP packages for composer (if not already in base image),
# and tools like wget, tar.
RUN apk add --no-cache \
    # Build tools for PHP extensions
    build-base \
    autoconf \
    # Development libraries for PHP extensions
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
    # Utilities for downloading and extraction
    wget \
    tar \
    # PHP components often needed by Composer (explicitly adding for robustness)
    php-json \
    php-phar

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

# --- Download and Prepare Roundcube Application ---

# Create the target directory where Roundcube will reside
RUN mkdir -p /var/www/html

# Step 1.1: Download Roundcube
RUN echo "----> Downloading Roundcube version ${ROUNDCUBE_VERSION}..." \
    && wget "https://github.com/roundcube/roundcubemail/releases/download/${ROUNDCUBE_VERSION}/roundcubemail-${ROUNDCUBE_VERSION}-complete.tar.gz" -O roundcube.tar.gz
# Step 1.2: Extract Roundcube
RUN echo "----> Extracting Roundcube to /var/www/html..." \
    && tar -xzf roundcube.tar.gz --strip-components=1 -C /var/www/html \
    && rm roundcube.tar.gz # Clean up downloaded archive

# Step 2.1: Download 'classic' skin
RUN echo "----> Downloading classic skin release 1.6.0..." \
    && wget "https://github.com/roundcube/classic/archive/refs/tags/1.6.0.tar.gz" -O classic-skin.tar.gz
# Step 2.2: Create target directory for classic skin
RUN echo "----> Creating target directory for classic skin..." \
    && mkdir -p /var/www/html/skins/classic
# Step 2.3: Extract 'classic' skin
RUN echo "----> Extracting classic skin to /var/www/html/skins/classic..." \
    && tar -xzf classic-skin.tar.gz --strip-components=1 -C /var/www/html/skins/classic \
    && rm classic-skin.tar.gz # Clean up downloaded archive

# Change WORKDIR to Roundcube's location for composer install
WORKDIR /var/www/html

# Step 3: Install PHP Dependencies using Composer
RUN echo "----> Installing composer dependencies (add --verbose here for more details if needed)..." \
    && composer install --no-dev --optimize-autoloader --no-progress --profile \
    # Clean up composer cache and Roundcube installer after build to reduce layer size for copying
    && echo "----> Cleaning up composer cache and Roundcube installer..." \
    && rm -rf /root/.composer \
    && rm -rf /var/www/html/installer


# ---- Final Stage ----
# This stage will be the actual image that gets deployed.
# It starts from a fresh base image and copies only necessary artifacts from the builder stage.
FROM php:8.3-fpm-alpine

# Set Roundcube version environment variable (mostly for informational purposes in the final image)
# The ARG must be redeclared in this stage if used to set an ENV here.
ARG ROUNDCUBE_VERSION=1.6.10
ENV ROUNDCUBE_VERSION=${ROUNDCUBE_VERSION}

# Default working directory
WORKDIR /var/www/html

# --- Install Runtime Dependencies and Tools ---
# Install only essential runtime dependencies and tools.
# Development libraries (-dev) are not needed here.
RUN apk add --no-cache \
    nginx \
    # Runtime libraries for PHP extensions (must match what was compiled in builder)
    icu-libs \
    libzip \
    libpng \
    libjpeg-turbo \
    freetype \
    openldap \
    imagemagick \ # Provides runtime libs for imagick PHP extension and potentially CLI tools if Roundcube uses them
    postgresql-libs \
    mariadb-connector-c \
    oniguruma \
    # Other necessary tools for runtime
    rsync \
    openssl \
    sed
    # The php:fpm-alpine image already has the www-data user and group.
    # If not, you would add them here, e.g.:
    # && addgroup -g 82 -S www-data && adduser -u 82 -D -S -G www-data www-data || true

# === EDIT NGINX.CONF TO ENSURE FOREGROUND (CORRECTED DIRECTIVE) ===
# Delete any existing 'daemon' or 'daemonize' directive line (commented or not)
RUN sed -i '/^\s*#*\s*daemon\(ize\)\?\s*.*;/d' /etc/nginx/nginx.conf
# Add 'daemon off;' correctly at the beginning of the file (global context)
RUN sed -i '1i daemon off;' /etc/nginx/nginx.conf
# ============================================

# Copy application code (with vendor dependencies) from the builder stage
COPY --from=builder /var/www/html /var/www/html

# Copy cmd scripts
COPY nginx-cmd.sh /usr/local/bin/nginx-cmd.sh
COPY php-fpm-cmd.sh /usr/local/bin/php-fpm-cmd.sh
# Copy Nginx configuration (only used in 'full' mode)
COPY nginx-default.conf /etc/nginx/http.d/default.conf
# Copy the helper PHP script for DES key extraction
COPY check-key.php /usr/local/bin/check-key.php

# Set execute permissions for copied scripts in a single layer for efficiency
RUN chmod +x /usr/local/bin/nginx-cmd.sh \
               /usr/local/bin/php-fpm-cmd.sh \
               /usr/local/bin/check-key.php

# Copy and set execute permission for the entrypoint script
COPY docker-entrypoint.sh /docker-entrypoint.sh
RUN chmod +x /docker-entrypoint.sh

# --- Finalize Permissions and Clean Up ---

# Step 4.1: Create Dirs (temp, logs, SQL) required by Roundcube if not already part of copied app
# config, plugins, skins are part of the application code copied from builder.
RUN echo "----> Creating directories (temp, logs, SQL)..." \
    && mkdir -p temp logs SQL

# Step 4.2 & 4.3: Set base ownership and permissions for /var/www/html and adjust for specific dirs
# This ensures www-data (which PHP-FPM and Nginx workers typically run as) can write to necessary locations.
RUN echo "----> Setting base ownership and permissions for /var/www/html..." \
    && chown -R www-data:www-data /var/www/html \
    && find /var/www/html -type d -exec chmod 755 {} \; \
    && find /var/www/html -type f -exec chmod 644 {} \; \
    && echo "----> Adjusting write permissions for specific directories..." \
    # Ensure these directories exist before chown/chmod; mkdir -p above handles temp, logs, SQL.
    # config, plugins, skins should exist from the COPY --from=builder.
    && chown -R www-data:www-data temp logs config plugins skins SQL \
    && chmod -R u+rwX temp logs config plugins skins SQL

# Step 4.4: Clean up temporary files and apk cache from the final image
RUN echo "----> Cleaning up temporary files and caches..." \
    && rm -rf /tmp/* \
               /var/cache/apk/* # Crucial for reducing final image size

# Define Volumes for persistent data and main external configuration
# Note that /plugins and /skins are NOT defined here, as they will be managed
# by the entrypoint script using mounts at /custom_plugins and /custom_skins
VOLUME /var/www/html/SQL /var/www/html/logs /var/www/html/temp

# Expose the Nginx port (80) and the PHP-FPM port (9000)
EXPOSE 80 9000

# Define the Entrypoint
ENTRYPOINT ["/docker-entrypoint.sh"]