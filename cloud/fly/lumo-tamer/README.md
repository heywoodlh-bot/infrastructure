Tailscale-enabled [lumo-tamer](https://github.com/ZeroTricks/lumo-tamer) deployment on fly.io, reachable only from the tailnet at `http://lumo.barn-banana.ts.net` (plaintext HTTP on port 80).

```
FORCE=true ./cloud/fly/lumo-tamer/deploy.sh
```

`FORCE=true` reads `TAILSCALE_AUTHKEY`, `LUMO_API_KEY` and `LUMO_VAULT_KEY` from 1Password; without it the script leaves existing secrets alone. Run `op-unlock` first (the script uses `op-wrapper` when available, otherwise it loads `~/.1password/session.sh`), and it aborts rather than staging empty secrets if 1Password is locked. The app and the `data` volume are created when missing and the deploy is limited to a single machine (`--ha=false`), so the script is safe to re-run.

lumo-tamer does not start without a Proton session, so the first boot keeps the machine up with the API paused. Authenticate once, then restart:

```
fly ssh console -a heywoodlh-lumo-tamer
cd /app && tamer auth login
exit
fly apps restart heywoodlh-lumo-tamer
```

If Proton returns a CAPTCHA, run `tamer auth rclone` in the same SSH session instead.

Tailscale state, `config.yaml` and `sessions/vault.enc` live on the `data` volume, so the node identity and the Proton session survive restarts and redeploys. Fly only attaches a volume to one machine, so keep the app at a single machine.
