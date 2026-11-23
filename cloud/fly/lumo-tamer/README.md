# lumo-tamer on fly.io

[lumo-tamer](https://github.com/ZeroTricks/lumo-tamer) exposes Proton Lumo as an
OpenAI-compatible API. This deployment runs the API server on Fly with a
Tailscale sidecar, reachable only from the tailnet as:

```
http://lumo.barn-banana.ts.net:3003
```

Nothing is published through Fly's proxy (`fly.toml` has no `[[services]]`
block), so the only way in is Tailscale. Traffic is plaintext over the tailnet;
there is no TLS listener.

The image is built from a pinned upstream commit (`LUMO_TAMER_COMMIT` in the
`Dockerfile`). Auth state, config and Tailscale state all live on the `data`
volume mounted at `/app/data`, so redeploys keep the node identity and the
Proton session.

## Deploy

```sh
fly apps create heywoodlh-lumo-tamer
fly volumes create data -r lax -s 1 -a heywoodlh-lumo-tamer

fly secrets set \
  TAILSCALE_AUTHKEY="tskey-auth-..." \
  LUMO_API_KEY="$(openssl rand -hex 32)" \
  LUMO_VAULT_KEY="$(openssl rand -base64 32)" \
  -a heywoodlh-lumo-tamer

fly deploy
```

- `TAILSCALE_AUTHKEY` is only used on first boot (or when the state file is
  gone). Use a reusable, non-ephemeral auth key.
- `LUMO_API_KEY` is written into `config.yaml` on first boot and is the bearer
  token OpenAI clients must send.
- `LUMO_VAULT_KEY` encrypts `sessions/vault.enc`. Changing it makes the existing
  Proton session unreadable, so keep it.

The hostname flag is `--hostname=lumo` in `start.sh`; that is what produces
`lumo.barn-banana.ts.net`. Tailnet ACLs must allow `tcp:3003` to this node.

On the first boot the machine stays up but the API server is paused, because
lumo-tamer refuses to start without a Proton session.

## Initial authentication

lumo-tamer needs an interactive Proton login once. The machine is already
running (paused) after `fly deploy`, so SSH in and run the auth command:

```sh
fly ssh console -a heywoodlh-lumo-tamer
cd /app
tamer auth login          # Proton username, password, TOTP if enabled
exit

fly apps restart heywoodlh-lumo-tamer
```

`tamer auth login` uses Proton's SRP flow and the Go helper that is baked into
the image at `/app/dist/proton-auth`. It writes `sessions/vault.enc` and updates
`/app/data/config.yaml` with `auth.method`, both of which are on the volume.
Tokens refresh automatically afterwards (every 20 hours by default).

### If Proton returns a CAPTCHA

The login method cannot solve CAPTCHAs, and the egress IP is Fly's, not yours.
Two practical fallbacks, both run in the same `fly ssh console` session:

**rclone (simplest).** Locally run `rclone config` with a `protondrive` remote
named `lumo-tamer` (rclone handles any CAPTCHA in your browser), verify with
`rclone about lumo-tamer:`, then copy the INI section from
`~/.config/rclone/rclone.conf`:

```sh
tamer auth rclone         # paste the [lumo-tamer] section
```

This gives token refresh but not conversation sync — fine for the API server.

**Import a vault built locally (needed for browser auth).** Browser auth is the
only method that supports conversation sync, but this image has no browser. Run
it on your workstation against the *same* vault key, then upload the vault:

```sh
# local, in a lumo-tamer checkout
mkdir -p ~/lumo-auth
printf '%s' "$LUMO_VAULT_KEY" > ~/lumo-auth/lumo-vault-key
cat > ~/lumo-auth/config.yaml <<'EOF'
auth:
  method: "browser"
  vault:
    path: "/home/you/lumo-auth/vault.enc"
    keyFilePath: "/home/you/lumo-auth/lumo-vault-key"
EOF
tamer auth browser        # Chrome already logged in at --remote-debugging-port=9222

fly sftp shell -a heywoodlh-lumo-tamer
put ~/lumo-auth/vault.enc /app/data/sessions/vault.enc
put ~/lumo-auth/config.yaml /app/data/config.yaml
```

The local vault key file must contain exactly the base64 value of the
`LUMO_VAULT_KEY` secret. If your desktop keychain already holds a
`lumo-tamer`/`vault-key` entry, lumo-tamer prefers it over the key file; remove
that entry first or the imported vault will not decrypt.

After any of these, `fly apps restart heywoodlh-lumo-tamer` and check:

```sh
fly logs -a heywoodlh-lumo-tamer
curl http://lumo.barn-banana.ts.net:3003/health
```

## Using the API

```sh
curl http://lumo.barn-banana.ts.net:3003/v1/chat/completions \
  -H "Authorization: Bearer $LUMO_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"model":"lumo","messages":[{"role":"user","content":"hello"}]}'
```

`/health` and `/metrics` are unauthenticated (front them with tailnet ACLs).

## Notes

- One machine only: the `data` volume cannot be attached to several machines.
  Keep the count at one when redeploying or scaling.
- Changing `LUMO_API_KEY` after first boot does nothing, because `config.yaml`
  is only generated when missing. Edit `/app/data/config.yaml` over
  `fly ssh console` or delete it and restart to regenerate.
- The vault key file is rewritten from the Fly secret on every boot, so the
  secret is the source of truth.
