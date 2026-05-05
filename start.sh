#!/usr/bin/env bash
set -Eeuo pipefail

AUTHKEY="${TOKEN:-${TS_AUTHKEY:-}}"
TARGET="${TARGET:-}"
LISTEN_PORT="${LISTEN_PORT:-2711}"
TS_HOSTNAME="${TS_HOSTNAME:-railway-ssh-tunnel}"

if [ -z "$AUTHKEY" ]; then
  echo "ERROR: TOKEN or TS_AUTHKEY environment variable is required"
  exit 1
fi

if [ -z "$TARGET" ]; then
  echo "ERROR: TARGET environment variable is required, example: 100.116.147.124:22"
  exit 1
fi

export TARGET_HOST="${TARGET%:*}"
export TARGET_PORT="${TARGET##*:}"
export LISTEN_PORT="${LISTEN_PORT}"

echo "Starting Tailscale userspace networking..."

tailscaled \
  --tun=userspace-networking \
  --socks5-server=127.0.0.1:1055 \
  --outbound-http-proxy-listen=127.0.0.1:1055 \
  --state=mem: &

sleep 3

echo "Authenticating Tailscale..."

tailscale up \
  --auth-key="${AUTHKEY}" \
  --hostname="${TS_HOSTNAME}" \
  --accept-routes=true

echo "Tailscale status:"
tailscale status || true

echo "Starting Python TCP proxy:"
echo "0.0.0.0:${LISTEN_PORT} -> ${TARGET_HOST}:${TARGET_PORT} via Tailscale SOCKS5 127.0.0.1:1055"

exec python3 -u /proxy.py
