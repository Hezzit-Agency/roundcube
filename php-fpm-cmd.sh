#!/bin/sh

/usr/local/sbin/php-fpm -F 2>&1 | sed 's/^/[__PHP-FPM__] /'
