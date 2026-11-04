# Tests

## Local (no Home Assistant)

```sh
tests/run.sh                         # uses nginx from PATH if present
NGINX=/path/to/nginx tests/run.sh    # or point at an nginx binary
```

It renders the nginx config with sample options through the add-on's own `jam-dash/render.sh` and
`jam-dash/nginx.conf.tmpl`, then:

- checks that no servers, or a server with an empty or malformed name / `url` / `proxy_key`, is refused
  with a clear message naming the server;
- slugs (lowercase, `a-z0-9-`, `-2`/`-3` on clashes), JSON escaping of names, the two-server render
  (one key file per server, mode 600, keys never in output or the nginx config), one server (root
  redirects) vs two (root serves the landing page), and the legacy `url` / `proxy_key` options becoming
  one server "Jam-Dash";
- that `servers.json` contains no keys or upstream addresses;
- with nginx: `nginx -t` on each render; with nginx, node and curl: starts two fake Jam-Dash servers that
  echo the request headers, checks that a non-Supervisor client gets 403, and (with 127.0.0.1 standing in
  for the Supervisor) that `s/<slug>/` is stripped and routed to the right server with its own key,
  `X-Forwarded-Prefix` = ingress path + `/s/<slug>`, `X-Remote-User-*`, `Host`, `X-Forwarded-Proto` and
  WebSocket upgrade headers, that a client-sent key is replaced, the `s/<slug>` slash redirect, the
  landing page and `servers.json` over HTTP, and the one-server redirect.

Without nginx it prints a NOTE and does only the static checks. `run.sh` (bashio) itself only runs
inside the add-on, so its `jq` extraction of `/data/options.json` is only covered by the manual test.

## Manual install test in Home Assistant

Either:

- **As a repository:** push this repo, then in Home Assistant go to **Settings › Add-ons › Add-on store
  › ⋮ › Repositories**, add the repo URL, and install **Jam-Dash** from the store; or
- **As a local add-on:** copy the `jam-dash/` folder into Home Assistant's `/addons` share (Samba or
  SSH add-on), then **Add-on store › ⋮ › Check for updates**; it appears under **Local add-ons**.
  Home Assistant builds the image on the device from the Dockerfile.

Then:

1. Start with no servers (or a server with an empty `proxy_key`): the add-on must stop and the log must
   say what is missing.
2. Add one server (name, url, real key from Jam-Dash **Settings › Home Assistant access**), start, open
   the panel: it should go straight to that server.
3. You should be signed in without a password; `GET /auth/state` reports `"via":"home_assistant"` and your HA display name.
4. Check live updates (WebSocket / event streams), images, a large download and an upload.
5. The add-on log shows requests with the HA user name, never the key.
6. Make a **New key** in Jam-Dash: the panel must fall back to Jam-Dash's normal sign-in until you paste
   the new key and restart the add-on.
7. As a non-admin HA user, the panel must not be listed.
8. Add a second server (its own key): the panel shows two cards with status dots; both **Open** buttons
   work, Tab reaches them, and the page follows the light/dark setting.
9. Upgrade test: install 0.1.0 with `url` / `proxy_key`, update to 0.2.0 without touching options: the
   panel still opens Jam-Dash (now at `s/jam-dash/`).
