# Changelog

## 0.2.0

- Several Jam-Dash servers in one add-on: new `servers` option (name, url, proxy_key per server),
  one sidebar entry. Each server is proxied under `s/<slug>/` with its own key and
  `X-Forwarded-Prefix`.
- Landing page with one card per server (live status, Open button); with a single server the
  sidebar entry opens it directly.
- `servers.json` lists server names and paths (no addresses or keys) for Jam-Dash's server switcher.
- The old `url` / `proxy_key` options still work as one server named "Jam-Dash" while `servers` is
  empty. Its address moves from the ingress root to `s/jam-dash/` (the root redirects there).

## 0.1.0

- First release: Home Assistant ingress proxy to Jam-Dash, with sign-in via the Home Assistant user
  (proxy key), WebSocket and streaming support, and no request buffering for large transfers.
