#!/bin/sh
# docker-entrypoint.sh
# Entrypoint script for Roundcube container
# Handles: Run mode selection, ENV var configurations (Upload Size, Memory Limit),
#          DES Key security check (vs defaults.inc.php AND config.inc.php.sample) using PHP helper,
#          Custom plugin/skin sync (using rsync).

# Exit immediately if a command exits with a non-zero status
set -e

# --- BEGIN: Function Definition ---
# Function to call the PHP helper script to extract the key
# Argument 1: Path to the config file
extract_key_php() {
  local config_file="$1"
  # Define the full path to the PHP script
  local php_script="/usr/local/bin/check-key.php"

  # Check if the PHP script exists and is executable
  if [ ! -x "$php_script" ]; then
    echo >&2 "ERROR: Key extraction script $php_script not found or not executable."
    # Return empty to indicate extraction failure
    echo ""
    return
  fi

  # Call the PHP script, pass the config file path
  # Capture only stdout (the key) and suppress stderr unless debugging
  # Use 'php' explicitly to execute the script
  /usr/local/bin/php "$php_script" "$config_file" 2>/dev/null || echo ""
}
# --- END: Function Definition ---

# --- BEGIN: DES Key Security Check ---
echo "Performing DES Key security check..."

DEFAULT_CONFIG_FILE="/var/www/html/config/defaults.inc.php"
SAMPLE_CONFIG_FILE="/var/www/html/config/config.inc.php.sample"
USER_CONFIG_FILE="/var/www/html/config/config.inc.php"
FALLBACK_DEFAULT_KEY='rcmail-!24ByteDESkey*Str' # Fallback if PHP parsing fails unexpectedly

# 1. Check if user config file exists
if [ ! -f "$USER_CONFIG_FILE" ]; then
  echo >&2 "############################################################"
  echo >&2 "ERROR: Configuration file not found!"
  echo >&2 "Please mount your customized config.inc.php to $USER_CONFIG_FILE."
  echo >&2 "You can copy and modify the sample file found in roundcube_data/config.inc.php.sample from the Github Repository."
  echo >&2 "https://raw.githubusercontent.com/Hezzit-Agency/roundcube/main/roundcube_data/config.inc.php.sample"
  echo >&2 "Container startup aborted."
  echo >&2 "############################################################"
  sleep 60
  exit 1
fi

# 2. Extract keys using PHP helper script
# Note: Suppress PHP warnings/errors from output using 2>/dev/null if desired, but stderr logs are useful
echo "Extracting keys using PHP helper..."
DEFAULT_DES_KEY=$(extract_key_php "$DEFAULT_CONFIG_FILE")
SAMPLE_DES_KEY=$(extract_key_php "$SAMPLE_CONFIG_FILE")
USER_DES_KEY=$(extract_key_php "$USER_CONFIG_FILE")

# Handle cases where default keys couldn't be parsed
if [ -z "$DEFAULT_DES_KEY" ]; then
  echo >&2 "WARNING: Could not extract/parse des_key from $DEFAULT_CONFIG_FILE. Using known default for check."
  DEFAULT_DES_KEY=$FALLBACK_DEFAULT_KEY
fi
if [ -z "$SAMPLE_DES_KEY" ]; then
  echo >&2 "WARNING: Could not extract/parse des_key from $SAMPLE_CONFIG_FILE. Using known default for check."
  SAMPLE_DES_KEY=$FALLBACK_DEFAULT_KEY
fi

# 3. Check if user key was found/extracted
if [ -z "$USER_DES_KEY" ]; then
   echo >&2 "############################################################"
   echo >&2 "ERROR: \$config['des_key'] not found, empty, or could not be parsed in config.inc.php."
   echo >&2 "This key is mandatory for security."
   # Suggest key logic
   if command -v openssl >/dev/null 2>&1; then
     # CORRECTED: Generate 24 bytes -> 32 Base64 characters
     suggested_key=$(openssl rand -base64 24)
     echo >&2 "Suggested key value to add to your config (32 characters): '$suggested_key'"
   else
     echo >&2 "Cannot generate suggested key: 'openssl' command not found."
     echo >&2 "Generate one manually (32 chars), e.g., using: openssl rand -base64 24"
   fi
   echo >&2 ""
   echo >&2 "Container startup aborted."
   echo >&2 "############################################################"
   sleep 60
   exit 1
fi

VALIDATE_DES_KEY="${VALIDATE_DES_KEY:-true}"


if [[ "$VALIDATE_DES_KEY" == "false" || "$VALIDATE_DES_KEY" == "0" ]]; then
	echo "WARNING: DES_KEY Validate disabled by environment variable."
else
	# 4. Check key length
	key_len=${#USER_DES_KEY}
	required_len=32 # CORRECTED: Expect 32 characters for a key generated from 24 random bytes

	# 5. Compare user key with BOTH defaults/samples and check length
	key_is_default=0
	if [ "$USER_DES_KEY" = "$DEFAULT_DES_KEY" ] || [ "$USER_DES_KEY" = "$SAMPLE_DES_KEY" ]; then
		key_is_default=1
	fi

	key_length_incorrect=0
	if [[ $key_len -lt 24 || $key_len -gt 32 ]]; then
		key_length_incorrect=1
	fi

	# Abort if key matches either default OR if length is incorrect
	if [ "$key_is_default" -eq 1 ] || [ "$key_length_incorrect" -eq 1 ]; then
	  echo >&2 "############################################################"
	  echo >&2 "ERROR: SECURITY RISK DETECTED - INVALID 'des_key'!"
	  echo >&2 "Your Roundcube 'des_key' in config.inc.php is invalid because:"
	  if [ "$key_is_default" -eq 1 ]; then
		echo >&2 "  - It matches one of the default insecure values."
	  fi
	  if [ "$key_length_incorrect" -eq 1 ]; then
		echo >&2 "  - Its length ($key_len characters) is incorrect (expected 24 or 32 characters)."
	  fi
	  echo >&2 "Using a default or invalid length key can be a security risk."
	  echo >&2 ""
	  echo >&2 "Please generate a strong random key (e.g., 24 or 32 characters long using base64)"
	  echo >&2 "and update \$config['des_key'] in your config.inc.php."
	  # Suggest key logic
	   if command -v openssl >/dev/null 2>&1; then
		 suggested_key=$(openssl rand -base64 24)
		 echo >&2 "Suggested key value: '$suggested_key'"
	   else
		 echo >&2 "Cannot generate suggested key: 'openssl' command not found."
		 echo >&2 "Generate one manually (32 chars), e.g., using: openssl rand -base64 24"
	   fi
	   echo >&2 ""
	   echo >&2 "Container startup aborted for security reasons."
	   echo >&2 "############################################################"
	  sleep 60
	  exit 1
	fi
	echo "DES key check passed (different from defaults/samples and correct length)."
fi
# --- END: DES Key Security Check ---


# --- Execution Mode Selection ---
# (Rest of the script: RUN_MODE check, PHP/Nginx config, rsync)
RUN_MODE_DEFAULT="full"
RUN_MODE=${RUN_MODE:-$RUN_MODE_DEFAULT}

# --- PHP Configuration ---
UPLOAD_SIZE_PHP_DEFAULT="100M"
UPLOAD_SIZE_PHP=${MAX_UPLOAD_SIZE:-$UPLOAD_SIZE_PHP_DEFAULT}
echo "Adjusting PHP upload_max_filesize and post_max_size to: ${UPLOAD_SIZE_PHP}"
echo "; Upload settings defined via entrypoint" > /usr/local/etc/php/conf.d/99-upload-settings.ini
echo "upload_max_filesize = ${UPLOAD_SIZE_PHP}" >> /usr/local/etc/php/conf.d/99-upload-settings.ini
echo "post_max_size = ${UPLOAD_SIZE_PHP}" >> /usr/local/etc/php/conf.d/99-upload-settings.ini

PHP_MEMORY_LIMIT_DEFAULT="256M"
PHP_MEMORY_LIMIT=${PHP_MEMORY_LIMIT:-$PHP_MEMORY_LIMIT_DEFAULT}
echo "Adjusting PHP memory_limit to: ${PHP_MEMORY_LIMIT}"
echo "; Memory limit defined via entrypoint" > /usr/local/etc/php/conf.d/98-memory-limit.ini
echo "memory_limit = ${PHP_MEMORY_LIMIT}" >> /usr/local/etc/php/conf.d/98-memory-limit.ini

chown www-data:www-data /usr/local/etc/php/conf.d/99-upload-settings.ini /usr/local/etc/php/conf.d/98-memory-limit.ini
chmod 644 /usr/local/etc/php/conf.d/99-upload-settings.ini /usr/local/etc/php/conf.d/98-memory-limit.ini
echo "PHP configurations applied."

# --- Function to Sync Custom Plugins/Skins using rsync ---
sync_custom_files() {
  local src_dir="$1"
  local dest_dir="$2"
  if [ -d "$src_dir" ] && [ -n "$(ls -A "$src_dir")" ]; then
    echo "Syncing contents from $src_dir to $dest_dir using rsync..."
    mkdir -p "$dest_dir"
    rsync -a "$src_dir/" "$dest_dir/"
    echo "Sync completed for $src_dir."
    chown -R www-data:www-data "$dest_dir"
  else
    echo "Source directory $src_dir not found or empty. Sync skipped."
  fi
}

# Sync custom plugins and skins
sync_custom_files "/custom_plugins" "/var/www/html/plugins"
sync_custom_files "/custom_skins" "/var/www/html/skins"

if [ "$RUN_MODE" = "fpm-only" ]; then
  echo "FPM-Only mode detected. Internal Nginx will NOT be started."
  exec /usr/local/bin/php-fpm-cmd.sh
else
  echo "Full mode (Nginx + FPM) detected."
  # --- Upload Limit Configuration ---
  UPLOAD_SIZE_DEFAULT="100M"
  UPLOAD_SIZE=${MAX_UPLOAD_SIZE:-$UPLOAD_SIZE_DEFAULT}
  echo "Adjusting Nginx client_max_body_size to: ${UPLOAD_SIZE}"
  sed -i "s|client_max_body_size.*|client_max_body_size ${UPLOAD_SIZE};|" /etc/nginx/http.d/default.conf
  
  # Start PHP-FPM in the background
  /usr/local/bin/php-fpm-cmd.sh &
  PHP_PID=$!
  # Start Nginx in the background
  /usr/local/bin/nginx-cmd.sh &
  NGINX_PID=$!
  echo "Processes started: php-fpm PID=$PHP_PID, nginx PID=$NGINX_PID"
  # Trap SIGTERM to gracefully shut down services
  trap "echo 'SIGTERM received, stopping Nginx and PHP-FPM'; kill $PHP_PID $NGINX_PID 2>/dev/null" SIGTERM
  # Wait for one of the processes to exit
  wait -n $PHP_PID $NGINX_PID 2>/dev/null
  echo "One of the processes has exited, shutting down the container..."
  # Kill the remaining process if still running
  kill $PHP_PID $NGINX_PID 2>/dev/null || true
  # Wait for both processes to fully terminate
  wait $PHP_PID 2>/dev/null || true
  wait $NGINX_PID 2>/dev/null || true

fi