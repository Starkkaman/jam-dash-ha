# Changelog

## 0.2.2

- Fix: every proxy key was rejected as "does not look like a Jam-Dash key" on the add-on's Alpine base,
  whose regex refuses repeat counts over 255. Spaces or line breaks pasted around a key are now ignored.

## 0.2.1

- Session cookies are now kept per server. When a server signs you in with its own Jam-Dash password
  (its key is not accepted, or Home Assistant access is off there), the cookie it sets for `/` is
  scoped to that server's `s/<slug>/` path, so two such servers no longer sign each other out.
  Cookie names are unchanged; cookies with any other path are left as they are.

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
