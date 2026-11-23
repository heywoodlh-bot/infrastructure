#!/usr/bin/env bash

# Prune once before heralding starts, so a full volume can't stop it from booting.
/prune-logs.sh
/prune-logs.sh --loop &

python3 -m http.server -d /web &

heralding
