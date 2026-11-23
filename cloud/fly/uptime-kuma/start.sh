#!/usr/bin/env bash
mkdir -p /app/data/tailscale
/tailscale/tailscaled --state=/app/data/tailscale/tailscaled.state --socket=/var/run/tailscale/tailscaled.sock &
/tailscale/tailscale up --auth-key=${TAILSCALE_AUTHKEY} --hostname=uptime-kuma

/usr/bin/dumb-init -- node /app/server/server.js
