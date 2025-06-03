#!/bin/sh

/usr/sbin/nginx 2>&1 | sed 's/^/[__NGINX__] /'
