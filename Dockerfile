# Dockerfile Completo para Roundcube com Nginx, PHP-FPM e Entrypoint para Overlay

# Usar a imagem base PHP FPM Alpine (já tem PHP e FPM)
FROM php:8.3-fpm-alpine

# Versão do Roundcube (pode ser alterada no build com --build-arg)
ARG ROUNDCUBE_VERSION=1.6.10
ENV ROUNDCUBE_VERSION=${ROUNDCUBE_VERSION}

# Diretório de trabalho padrão
WORKDIR /var/www/html

# Instalar Nginx, Supervisor, dependências do sistema/PHP e ferramentas
# Cria um grupo virtual .build-deps que será removido depois
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
        # Instala dependências de runtime e ferramentas necessárias
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
        # Instalar composer globalmente
        && wget https://getcomposer.org/installer -O - -q | php -- --install-dir=/usr/local/bin --filename=composer \
        # Configurar extensões PHP que precisam de opções (ex: GD)
        && docker-php-ext-configure gd --with-freetype --with-jpeg \
        # Instalar extensões PHP necessárias para Roundcube e comuns
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
        # Remover dependências de build para manter a imagem menor
        && apk del .build-deps \
        # Criar diretório para logs do supervisor (opcional, mas boa prática)
        && mkdir -p /var/log/supervisor

# Copiar AMBOS os arquivos de configuração do Supervisor
COPY supervisord.conf /etc/supervisor/supervisord-full.conf
COPY supervisord-fpm-only.conf /etc/supervisor/supervisord-fpm-only.conf

# Copiar configuração do Nginx (usado apenas no modo 'full')
COPY nginx-default.conf /etc/nginx/http.d/default.conf

# Copiar e dar permissão ao script de entrada
COPY docker-entrypoint.sh /docker-entrypoint.sh
RUN chmod +x /docker-entrypoint.sh

# Instalar Roundcube
RUN cd /tmp \
    # Baixar a versão completa do Roundcube
    && wget "https://github.com/roundcube/roundcubemail/releases/download/${ROUNDCUBE_VERSION}/roundcubemail-${ROUNDCUBE_VERSION}-complete.tar.gz" -O roundcube.tar.gz \
    # Extrair o conteúdo para o diretório de trabalho (/var/www/html)
    && tar -xzf roundcube.tar.gz --strip-components=1 -C /var/www/html \
    # Remover o arquivo baixado
    && rm roundcube.tar.gz \
    # Navegar para o diretório do Roundcube
    && cd /var/www/html \
    # Instalar dependências do PHP via Composer (sem dependências de desenvolvimento)
    && composer install --no-dev --optimize-autoloader --no-progress \
    # Criar diretórios necessários para Roundcube
    && mkdir -p temp logs \
    # Definir proprietário e permissões para a aplicação web
    # Importante fazer ANTES do entrypoint rodar, pois ele manipula plugins/skins
    && chown -R www-data:www-data /var/www/html \
    && find /var/www/html -type d -exec chmod 755 {} \; \
    && find /var/www/html -type f -exec chmod 644 {} \; \
    # Ajustar permissões para diretórios que precisam de escrita pelo www-data
    && chown -R www-data:www-data temp logs config plugins skins \
    && chmod -R ug+rwX temp logs config plugins skins \
    # Limpar arquivos temporários e caches
    && rm -rf /tmp/* \
              /var/www/html/installer \
              /root/.composer

# Definir Volumes para dados persistentes e configuração externa principal
# Note que /plugins e /skins NÃO são definidos aqui, pois serão gerenciados
# pelo script de entrada usando montagens em /custom_plugins e /custom_skins
VOLUME /var/www/html/config /var/www/html/logs /var/www/html/temp

# Expor a porta do Nginx (80) e a do PHP-FPM (9000)
EXPOSE 80 9000

# Definir o Entrypoint
ENTRYPOINT ["/docker-entrypoint.sh"]

# Comando padrão (será passado para o entrypoint)
# O entrypoint adicionará o "-c <arquivo_conf_correto>"
CMD ["/usr/bin/supervisord"]