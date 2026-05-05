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

TARGET_HOST="${TARGET%:*}"
TARGET_PORT="${TARGET##*:}"

echo "Starting Tailscale in userspace networking mode..."
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

echo "Forwarding public TCP :${LISTEN_PORT} -> ${TARGET_HOST}:${TARGET_PORT} via Tailscale SOCKS5 proxy"

exec socat -d -d \
  "TCP-LISTEN:${LISTEN_PORT},fork,reuseaddr" \
  "EXEC:ncat --proxy 127.0.0.1:1055 --proxy-type socks5 ${TARGET_HOST} ${TARGET_PORT}"
