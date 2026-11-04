# Tests

## Local (no Home Assistant)

```sh
tests/run.sh                         # uses nginx from PATH if present
NGINX=/path/to/nginx tests/run.sh    # or point at an nginx binary
```

It renders the nginx config with sample options through the add-on's own `jam-dash/render.sh` and
`jam-dash/nginx.conf.tmpl`, then:

- checks that an empty or malformed `url` / `proxy_key` is refused with a clear message, that the key
  never appears in output, `nginx.conf` or the log format, and that the key file is mode 600;
- with nginx: runs `nginx -t`; with nginx, node and curl: starts a fake Jam-Dash that echoes the request
  headers, checks that a non-Supervisor client gets 403, and (with 127.0.0.1 standing in for the
  Supervisor) that the key, `X-Forwarded-Prefix`, `X-Remote-User-*`, `Host`, `X-Forwarded-Proto` and
  WebSocket upgrade headers reach the upstream and that a client-sent key is replaced.

Without nginx it prints a NOTE and does only the static checks. `run.sh` (bashio) itself only runs
inside the add-on.

## Manual install test in Home Assistant

Either:

- **As a repository:** push this repo, then in Home Assistant go to **Settings › Add-ons › Add-on store
  › ⋮ › Repositories**, add the repo URL, and install **Jam-Dash** from the store; or
- **As a local add-on:** copy the `jam-dash/` folder into Home Assistant's `/addons` share (Samba or
  SSH add-on), then **Add-on store › ⋮ › Check for updates**; it appears under **Local add-ons**.
  Home Assistant builds the image on the device from the Dockerfile.

Then:

1. Start with empty `proxy_key`: the add-on must stop and the log must say the option is empty.
2. Set `url` and a real key from Jam-Dash (**Settings › Home Assistant access**), start, open the panel.
3. You should be signed in without a password; `GET /auth/state` reports `"via":"home_assistant"` and your HA display name.
4. Check live updates (WebSocket / event streams), images, a large download and an upload.
5. The add-on log shows requests with the HA user name, never the key.
6. Make a **New key** in Jam-Dash: the panel must fall back to Jam-Dash's normal sign-in until you paste
   the new key and restart the add-on.
7. As a non-admin HA user, the panel must not be listed.
