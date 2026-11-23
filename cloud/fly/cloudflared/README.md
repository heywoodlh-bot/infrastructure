Tailscale-enabled cloudflared deployment on fly.io.

```
fly launch --no-deploy --copy-config
flyctl secrets set TAILSCALE_AUTHKEY="SOMEKEY"
flyctl secrets set CLOUDFLARE_TOKEN="SOMEKEY"
fly deploy
```

On the prompt to tweak settings, press "yes", set port to 0.

Tailscale state is kept on a 1GB `tailscale` volume (mounted at `/var/lib/tailscale`), so the node keeps its identity across restarts and `TAILSCALE_AUTHKEY` is only needed on first boot. Create it before the first deploy:

```
fly volumes create tailscale -r lax -s 1
```
