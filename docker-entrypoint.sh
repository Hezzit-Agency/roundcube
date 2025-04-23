#!/bin/sh
# ./docker-entrypoint.sh - Updated to use rsync

# Exit immediately if a command exits with a non-zero status
set -e

# --- Execution Mode Selection ---
# Default mode is 'full' (Nginx + FPM)
RUN_MODE_DEFAULT="full"
# Use the $RUN_MODE variable from environment, or the default
RUN_MODE=${RUN_MODE:-$RUN_MODE_DEFAULT}

# Default supervisor config file
SUPERVISOR_CONF_FILE="/etc/supervisor/supervisord-full.conf"

if [ "$RUN_MODE" = "fpm-only" ]; then
  echo "FPM-Only mode detected. Internal Nginx will NOT be started."
  SUPERVISOR_CONF_FILE="/etc/supervisor/supervisord-fpm-only.conf"
else
  echo "Full mode (Nginx + FPM) detected."
  # Nginx configuration is only relevant in 'full' mode
  # --- Upload Limit Configuration ---
  UPLOAD_SIZE_DEFAULT="100M" # Default from user's provided file
  UPLOAD_SIZE=${MAX_UPLOAD_SIZE:-$UPLOAD_SIZE_DEFAULT}
  echo "Adjusting Nginx client_max_body_size to: ${UPLOAD_SIZE}"
  # Use '|' as sed delimiter to avoid issues with paths
  sed -i "s|client_max_body_size.*|client_max_body_size ${UPLOAD_SIZE};|" /etc/nginx/http.d/default.conf
  # --- End Upload Limit Configuration ---
fi

# --- PHP Configuration (always applicable) ---
# PHP Upload Limit (applied even in fpm-only mode)
UPLOAD_SIZE_PHP_DEFAULT="100M" # Default from user's provided file
UPLOAD_SIZE_PHP=${MAX_UPLOAD_SIZE:-$UPLOAD_SIZE_PHP_DEFAULT}
echo "Adjusting PHP upload_max_filesize and post_max_size to: ${UPLOAD_SIZE_PHP}"
# Create specific ini file for upload settings
echo "; Upload settings defined via entrypoint" > /usr/local/etc/php/conf.d/99-upload-settings.ini
echo "upload_max_filesize = ${UPLOAD_SIZE_PHP}" >> /usr/local/etc/php/conf.d/99-upload-settings.ini
echo "post_max_size = ${UPLOAD_SIZE_PHP}" >> /usr/local/etc/php/conf.d/99-upload-settings.ini

# PHP Memory Limit
PHP_MEMORY_LIMIT_DEFAULT="128M"
PHP_MEMORY_LIMIT=${PHP_MEMORY_LIMIT:-$PHP_MEMORY_LIMIT_DEFAULT}
echo "Adjusting PHP memory_limit to: ${PHP_MEMORY_LIMIT}"
# Create specific ini file for memory limit
echo "; Memory limit defined via entrypoint" > /usr/local/etc/php/conf.d/98-memory-limit.ini
echo "memory_limit = ${PHP_MEMORY_LIMIT}" >> /usr/local/etc/php/conf.d/98-memory-limit.ini

# Ensure correct permissions on created .ini files
chown www-data:www-data /usr/local/etc/php/conf.d/99-upload-settings.ini /usr/local/etc/php/conf.d/98-memory-limit.ini
chmod 644 /usr/local/etc/php/conf.d/99-upload-settings.ini /usr/local/etc/php/conf.d/98-memory-limit.ini
echo "PHP configurations applied."
# --- End PHP Configuration ---


# --- Function to Sync Custom Plugins/Skins using rsync ---
sync_custom_files() {
  local src_dir="$1"
  local dest_dir="$2"
  # Check if the source directory exists and is not empty
  if [ -d "$src_dir" ] && [ -n "$(ls -A "$src_dir")" ]; then
    echo "Syncing contents from $src_dir to $dest_dir using rsync..."
    # Ensure the destination directory exists
    mkdir -p "$dest_dir"
    # Use rsync -a: archive mode (recursive, preserves permissions, links, etc.)
    # Trailing slash on src_dir ($src_dir/) is crucial: it copies the *contents*
    # of the source directory into the destination directory, merging/overwriting files.
    rsync -a "$src_dir/" "$dest_dir/"
    echo "Sync completed for $src_dir."
    #Ensure ownership after rsync if needed (though -a usually preserves it)
    chown -R www-data:www-data "$dest_dir"
  else
    echo "Source directory $src_dir not found or empty. Sync skipped."
  fi
}
# --- End Sync Function ---

# Sync custom plugins and skins
sync_custom_files "/custom_plugins" "/var/www/html/plugins"
sync_custom_files "/custom_skins" "/var/www/html/skins"

# Execute supervisord with the correct configuration file
echo "Executing main command: supervisord with config $SUPERVISOR_CONF_FILE"
# The original CMD is ignored; we call supervisord directly here with the chosen config
exec /usr/bin/supervisord -c "$SUPERVISOR_CONF_FILE"