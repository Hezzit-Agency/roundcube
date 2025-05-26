#!/bin/sh

/usr/local/sbin/php-fpm -F 2>&1 | sed 's/^/\033[0;35m[PHP-FPM]\033[0m /'