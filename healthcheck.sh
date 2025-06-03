#!/bin/sh
set -e
MODE=${RUN_MODE:-full}
if [ "$MODE" = "fpm-only" ]; then
  pgrep php-fpm > /dev/null
  exit $?
else
  pgrep php-fpm > /dev/null && pgrep nginx > /dev/null
  exit $?
fi
