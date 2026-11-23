Tailscale-enabled uptime-kuma deployment on fly.io.

```
fly launch --no-deploy --copy-config
flyctl secrets set TAILSCALE_AUTHKEY="SOMEKEY"
fly deploy
```

On the prompt to tweak settings, press "yes", set port to 0.

Fly allows one volume per machine, so Tailscale state lives on the `kuma_data` volume at `/app/data/tailscale`. The node keeps its identity across restarts and `TAILSCALE_AUTHKEY` is only needed on first boot.
