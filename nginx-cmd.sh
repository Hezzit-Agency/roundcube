#!/bin/sh

/usr/sbin/nginx 2>&1 | sed 's/^/\033[0;32m[NGINX]\033[0m /'