#!/usr/bin/env bash
set -Eeuo pipefail

exec ncat \
  --proxy 127.0.0.1:1055 \
  --proxy-type socks5 \
  "${TARGET_HOST}" \
  "${TARGET_PORT}"
