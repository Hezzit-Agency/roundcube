#!/bin/sh
# ./docker-entrypoint.sh

set -e

# --- Seleção do Modo de Execução ---
# Define o modo padrão como 'full' (Nginx + FPM)
RUN_MODE_DEFAULT="full"
# Usa a variável $RUN_MODE ou o padrão
RUN_MODE=${RUN_MODE:-$RUN_MODE_DEFAULT}

SUPERVISOR_CONF_FILE="/etc/supervisor/supervisord-full.conf" # Padrão

if [ "$RUN_MODE" = "fpm-only" ]; then
  echo "Modo FPM-Only detectado. Nginx interno NÃO será iniciado."
  SUPERVISOR_CONF_FILE="/etc/supervisor/supervisord-fpm-only.conf"
else
  echo "Modo Full (Nginx + FPM) detectado."
  # A configuração do Nginx só é relevante no modo 'full'
  # --- Configuração de Limite de Upload ---
  UPLOAD_SIZE_DEFAULT="100M"
  UPLOAD_SIZE=${MAX_UPLOAD_SIZE:-$UPLOAD_SIZE_DEFAULT}
  echo "Ajustando client_max_body_size do Nginx para: ${UPLOAD_SIZE}"
  sed -i "s|client_max_body_size.*|client_max_body_size ${UPLOAD_SIZE};|" /etc/nginx/http.d/default.conf
  # --- Fim da Configuração de Limite de Upload ---
fi

# --- Configuração do PHP (sempre aplicável) ---
# Limite de Upload PHP (aplicado mesmo em fpm-only)
UPLOAD_SIZE_PHP_DEFAULT="100M"
UPLOAD_SIZE_PHP=${MAX_UPLOAD_SIZE:-$UPLOAD_SIZE_PHP_DEFAULT}
echo "Ajustando upload_max_filesize e post_max_size do PHP para: ${UPLOAD_SIZE_PHP}"
echo "; Configurações de upload definidas via entrypoint" > /usr/local/etc/php/conf.d/99-upload-settings.ini
echo "upload_max_filesize = ${UPLOAD_SIZE_PHP}" >> /usr/local/etc/php/conf.d/99-upload-settings.ini
echo "post_max_size = ${UPLOAD_SIZE_PHP}" >> /usr/local/etc/php/conf.d/99-upload-settings.ini

# Limite de Memória PHP
PHP_MEMORY_LIMIT_DEFAULT="128M"
PHP_MEMORY_LIMIT=${PHP_MEMORY_LIMIT:-$PHP_MEMORY_LIMIT_DEFAULT}
echo "Ajustando memory_limit do PHP para: ${PHP_MEMORY_LIMIT}"
echo "; Limite de memória definido via entrypoint" > /usr/local/etc/php/conf.d/98-memory-limit.ini
echo "memory_limit = ${PHP_MEMORY_LIMIT}" >> /usr/local/etc/php/conf.d/98-memory-limit.ini

# Garante permissões nos arquivos .ini criados
chown www-data:www-data /usr/local/etc/php/conf.d/99-upload-settings.ini /usr/local/etc/php/conf.d/98-memory-limit.ini
chmod 644 /usr/local/etc/php/conf.d/99-upload-settings.ini /usr/local/etc/php/conf.d/98-memory-limit.ini
echo "Configurações do PHP aplicadas."
# --- Fim da Configuração do PHP ---


# --- Cópia de Plugins/Skins ---
copy_custom_files() {
  local src_dir="$1"
  local dest_dir="$2"
  if [ -d "$src_dir" ] && [ -n "$(ls -A "$src_dir")" ]; then
    echo "Copiando arquivos customizados de $src_dir para $dest_dir..."
    mkdir -p "$dest_dir"
    cp -Rf "$src_dir/." "$dest_dir/"
    echo "Cópia de $src_dir concluída."
  else
    echo "Diretório $src_dir não encontrado ou vazio. Nenhuma cópia realizada."
  fi
}
copy_custom_files "/custom_plugins" "/var/www/html/plugins"
copy_custom_files "/custom_skins" "/var/www/html/skins"
# --- Fim da Cópia ---

# Executa o supervisord com o arquivo de configuração correto
echo "Executando comando principal: supervisord com config $SUPERVISOR_CONF_FILE"
# O CMD original é ignorado, nós chamamos supervisord diretamente aqui
exec /usr/bin/supervisord -c "$SUPERVISOR_CONF_FILE"