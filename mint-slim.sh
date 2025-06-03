#!/bin/sh
set -e

APP_BASE_DIR="/var/www/html"
CONFIG_DIR_FOR_CHECKKEY="$APP_BASE_DIR/config"
PHP_CONF_DIR="/usr/local/etc/php/conf.d"
SCRIPTS_DIR="/usr/local/bin"
HEALTHCHECK_SCRIPT_PATH="/healthcheck.sh"
PHP_FPM_CMD_SCRIPT_PATH="${SCRIPTS_DIR}/php-fpm-cmd.sh"
NGINX_CMD_SCRIPT_PATH="${SCRIPTS_DIR}/nginx-cmd.sh"
CHECK_KEY_SCRIPT_PATH="${SCRIPTS_DIR}/check-key.php"
PHP_EXECUTABLE_PATH="/usr/local/bin/php"
PHP_FPM_BINARY_PATH="/usr/local/sbin/php-fpm"
NGINX_BINARY_PATH="/usr/sbin/nginx"
CUSTOM_PLUGINS_SRC_DIR="/custom_plugins"
CUSTOM_SKINS_SRC_DIR="/custom_skins"
PLUGINS_DEST_DIR="$APP_BASE_DIR/plugins"
SKINS_DEST_DIR="$APP_BASE_DIR/skins"

NGINX_ETC_DIR="/etc/nginx"
NGINX_MAIN_CONF_FILE="$NGINX_ETC_DIR/nginx.conf"
NGINX_HTTP_D_DIR="$NGINX_ETC_DIR/http.d"
NGINX_DEFAULT_CONF_FILE="$NGINX_HTTP_D_DIR/default.conf"

SQL_TEMPLATE_DIR="/usr/local/share/roundcube-sql-template"
SQL_TEMPLATE_FILE_SQLITE="$SQL_TEMPLATE_DIR/sqlite.initial.sql"

PHP_FPM_MAIN_CONF_FILE="/usr/local/etc/php-fpm.conf"
PHP_FPM_POOL_DIR="/usr/local/etc/php-fpm.d"
PHP_FPM_WWW_CONF_FILE="${PHP_FPM_POOL_DIR}/www.conf"

access_path() {
    if [ -e "$1" ]; then
        ls -ld "$1" > /dev/null 2>&1 || true
    fi
}

access_and_read_head() {
    if [ -f "$1" ]; then
        ls -ld "$1" > /dev/null 2>&1 || true
        head -n 1 "$1" > /dev/null 2>&1 || true
    elif [ -e "$1" ]; then # If it's a directory or other type, just ls
        ls -ld "$1" > /dev/null 2>&1 || true
    fi
}

access_project_shell_script() {
    local script_path="$1"
    if [ -f "$script_path" ]; then
        ls -l "$script_path" > /dev/null 2>&1 || true
        if head -n 1 "$script_path" | grep -q -e "/bin/sh" -e "/usr/bin/env sh"; then
            sh -n "$script_path" > /dev/null 2>&1 || true
        fi
    fi
}

execute_binary_for_discovery() {
    local cmd_to_run="$1"
    if [ -x "$cmd_to_run" ]; then
        if "$cmd_to_run" --version > /dev/null 2>&1; then :
        elif "$cmd_to_run" -v > /dev/null 2>&1; then :
        elif "$cmd_to_run" -V > /dev/null 2>&1; then :
        elif "$cmd_to_run" --help > /dev/null 2>&1; then :
        elif [ "$cmd_to_run" = "/bin/sh" ] || [ "$cmd_to_run" = "/usr/bin/env" ]; then
             "$cmd_to_run" ":" > /dev/null 2>&1 || true
        else
             access_path "$cmd_to_run"
        fi
    else
        access_path "$cmd_to_run"
    fi
}

DIRECTORIES_TO_ACCESS="\
$APP_BASE_DIR \
$CONFIG_DIR_FOR_CHECKKEY \
$PLUGINS_DEST_DIR \
$SKINS_DEST_DIR \
$APP_BASE_DIR/SQL \
$APP_BASE_DIR/logs \
$APP_BASE_DIR/temp \
$CUSTOM_PLUGINS_SRC_DIR \
$CUSTOM_SKINS_SRC_DIR \
$PHP_CONF_DIR \
$SQL_TEMPLATE_DIR \
$SCRIPTS_DIR \
$NGINX_ETC_DIR \
$NGINX_HTTP_D_DIR \
$PHP_FPM_POOL_DIR \
/usr/local/etc \
/etc/ssl \
/tmp"
access_path "/"

for dir_path in $DIRECTORIES_TO_ACCESS; do
    access_path "$dir_path"
done

access_and_read_head "$NGINX_MAIN_CONF_FILE"
access_and_read_head "$NGINX_DEFAULT_CONF_FILE"
access_and_read_head "$PHP_FPM_MAIN_CONF_FILE"
access_and_read_head "$PHP_FPM_WWW_CONF_FILE"
access_path "$SQL_TEMPLATE_FILE_SQLITE"

access_path "$PHP_EXECUTABLE_PATH"
PHP_INFO_OUTPUT=$("$PHP_EXECUTABLE_PATH" -i)

PHP_INI_MAIN_FILE=$(echo "$PHP_INFO_OUTPUT" | grep -i '^Loaded Configuration File' | awk '{print $NF}' || true)
if [ -n "$PHP_INI_MAIN_FILE" ] && [ "$PHP_INI_MAIN_FILE" != "(none)" ] && [ -f "$PHP_INI_MAIN_FILE" ]; then
    access_and_read_head "$PHP_INI_MAIN_FILE"
fi

PARSED_INI_FILES=$(echo "$PHP_INFO_OUTPUT" | grep -i '^Additional .ini files parsed' | sed -e 's/Additional .ini files parsed => //g' || true)
if [ -n "$PARSED_INI_FILES" ] && [ "$PARSED_INI_FILES" != "(none)" ]; then
    echo "$PARSED_INI_FILES" | tr ',' '\n' | while read -r ini_file_path; do
        trimmed_ini_file_path=$(echo "$ini_file_path" | awk '{$1=$1};1')
        if [ -n "$trimmed_ini_file_path" ]; then
            access_and_read_head "$trimmed_ini_file_path"
        fi
    done
fi

"$PHP_EXECUTABLE_PATH" -m | sed -e 's/\[PHP Modules\]//g' -e 's/\[Zend Modules\]//g' -e 's/^\s*//' -e '/^$/d' | tr '\n' ' ' | xargs -n1 echo | while read -r module_name; do
    if [ -n "$module_name" ]; then
        "$PHP_EXECUTABLE_PATH" --ri "$module_name" > /dev/null 2>&1 || true
    fi
done

TARGET_EXECUTABLES="\
$PHP_FPM_BINARY_PATH \
$NGINX_BINARY_PATH \
$PHP_EXECUTABLE_PATH \
/usr/bin/openssl \
/usr/bin/rsync \
/usr/bin/pgrep \
/usr/bin/env \
/bin/sed \
/bin/sh \
/bin/sleep \
/bin/chown \
/bin/chmod \
/bin/mkdir \
/bin/cp \
/bin/ls \
/usr/bin/find \
/usr/bin/awk \
/usr/bin/grep \
/usr/bin/xargs \
/usr/bin/tr \
/usr/bin/head"

for cmd_path_loop in $TARGET_EXECUTABLES; do
    execute_binary_for_discovery "$cmd_path_loop"
done

access_project_shell_script "$PHP_FPM_CMD_SCRIPT_PATH"
access_project_shell_script "$NGINX_CMD_SCRIPT_PATH"
access_project_shell_script "$HEALTHCHECK_SCRIPT_PATH"
access_path "$CHECK_KEY_SCRIPT_PATH"

if [ -d "$APP_BASE_DIR" ]; then
    find "$APP_BASE_DIR" -print0 | while IFS= read -r -d $'\0' file_or_dir; do
        access_path "$file_or_dir"
    done
fi
