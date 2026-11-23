```
fly launch --copy-config --yes
```

## Log pruning

Heralding appends to `log_session.json`, `log_session.csv`, `log_auth.csv` and `heralding.log` on the `/logs` volume and never rotates them. `prune-logs.sh` runs once before heralding starts (so a full volume can't block boot), then every 10 minutes. Any file over `MAX_LOG_BYTES` is trimmed in place to its newest `KEEP_LOG_BYTES`, on whole lines, keeping CSV headers.

| Variable | Default | Meaning |
| --- | --- | --- |
| `MAX_LOG_BYTES` | `209715200` (200MiB) | Prune a file once it grows past this |
| `KEEP_LOG_BYTES` | `104857600` (100MiB) | Size to trim it down to |
| `PRUNE_INTERVAL` | `600` | Seconds between prune passes |

Override with `[env]` in `fly.toml`. Pruning permanently discards the oldest entries, so copy logs off the volume first if you want to keep them.
