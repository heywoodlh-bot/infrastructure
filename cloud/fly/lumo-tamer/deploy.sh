#!/usr/bin/env bash
set -euo pipefail

APP="heywoodlh-lumo-tamer"
REGION="lax"
VOLUME="data"
FORCE="${FORCE:-false}"

cd "$(dirname "$0")"

fly apps list | awk '{print $1}' | grep -qx "$APP" || fly apps create "$APP"

fly volumes list -a "$APP" | grep -qE "[[:space:]]${VOLUME}[[:space:]]" ||
  fly volumes create "$VOLUME" -r "$REGION" -s 1 -a "$APP"

if [ "$FORCE" = "true" ]; then
  fly secrets set \
    TAILSCALE_AUTHKEY="$(op item get qp43o4locdg7gq64nhl5apqcoe --reveal --fields ts-authkey)" \
    LUMO_API_KEY="$(op item get qp43o4locdg7gq64nhl5apqcoe --reveal --fields api-key)" \
    LUMO_VAULT_KEY="$(op item get qp43o4locdg7gq64nhl5apqcoe --reveal --fields vault-key)" \
    -a "$APP"
fi

fly deploy --ha=false
