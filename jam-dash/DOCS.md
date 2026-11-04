# Jam-Dash

This add-on puts your Jam-Dash dashboards in the Home Assistant sidebar, one or several of them (for
example "smol-boi" and "TrueNAS") behind a single sidebar entry. Each Jam-Dash keeps running where it
already runs (another machine, NAS, container); the add-on is a small nginx proxy that forwards Home
Assistant ingress to it. Anywhere you can open Home Assistant, at home, through Nabu Casa or your own
remote access, or in the companion app, you can open your Jam-Dash servers.

## Setup

1. **In each Jam-Dash:** open **Settings › Home Assistant access** and turn it on. Jam-Dash shows a proxy
   key once. Copy it now (if you lose it, press **New key** and use the new one). Every server has its
   own key.
2. **In Home Assistant:** open this add-on's **Configuration** tab and add one entry per server under
   **servers**:
   - **name**: what people see, for example `smol-boi` or `TrueNAS`.
   - **url**: where that Jam-Dash runs, scheme, host and port only, for example
     `http://192.168.1.20:8484` or `http://jam-dash.local:8484`. No path.
   - **proxy_key**: the key you copied from that server.

   In YAML mode:

   ```yaml
   servers:
     - name: smol-boi
       url: http://192.168.1.20:8484
       proxy_key: "<key from smol-boi>"
     - name: TrueNAS
       url: http://truenas.local:8484
       proxy_key: "<key from TrueNAS>"
   ```
3. Save and **Start** the add-on. Turn on **Show in sidebar** if you want it there.
4. Open **Jam-Dash** from the sidebar (or **Open Web UI** on the add-on page). With one server you go
   straight to it. With several you get a page with one card per server, showing whether it answers
   and whether you are signed in, and an **Open** button.

### Server paths

Each server lives under its own path inside the add-on: `s/<slug>/`. The slug comes from the name:
lowercase, letters, digits and `-` only (`TrueNAS` becomes `truenas`, `smol boi` becomes `smol-boi`).
If two names give the same slug, later ones get `-2`, `-3` and so on, in list order. Renaming a server
changes its path, so bookmarks to the old path stop working.

`servers.json` at the add-on root lists `name`, `slug` and `path` for each server (never addresses or
keys). Jam-Dash can use it to switch between servers.

### Upgrading from 0.1

The old single `url` / `proxy_key` options still work: while the **servers** list is empty they are used
as one server named "Jam-Dash" (path `s/jam-dash/`, the sidebar entry goes straight there). To add more
servers, move that one into the **servers** list and clear the old fields.

## How sign-in works

You do not enter a Jam-Dash password inside Home Assistant. Home Assistant has already signed you in,
and its Supervisor tells the add-on which Home Assistant user is making each request. The add-on
forwards that user (`X-Remote-User-Id`, `-Name`, `-Display-Name`) to the Jam-Dash you opened, together
with that server's proxy key. Jam-Dash signs the request in as that Home Assistant user only when the key matches (Jam-Dash reports such a session as signed in "via Home Assistant").

## Why this is safe

- **Admins only.** The sidebar panel is limited to Home Assistant administrators (`panel_admin`).
- **Only the Supervisor can reach the add-on.** nginx accepts connections from the Supervisor's ingress
  gateway (172.30.32.2) only; everything else is refused. The add-on exposes no port on your network.
- **The key proves the request came through this add-on.** Anyone on your network could send
  "I am user X" headers straight to Jam-Dash; without the key Jam-Dash ignores those headers and applies
  its normal sign-in. Jam-Dash stores the key hashed, compares it in constant time and never logs it.
  The add-on stores it as a password option, keeps it in a file only root can read and never writes it to
  its log. A client cannot smuggle its own key: the add-on always replaces that header.
- **Each server only gets its own key.** smol-boi never sees TrueNAS's key, so one compromised server
  cannot sign in to another. The landing page and `servers.json` show names only, never addresses or keys.
- **Turning it off is instant.** In Jam-Dash, turn **Home Assistant access** off (deletes the key) or
  press **New key** (the old one stops working immediately).
- Traffic between the add-on and Jam-Dash is plain HTTP unless your `url` uses `https://`. Use https or
  keep both on a network you trust; the key travels with each request.

## Troubleshooting

- **Add-on stops right after starting.** Open the **Log** tab. "No servers configured" means the
  **servers** list is empty; "Option 'url' of server 2 ("TrueNAS") is empty" and similar messages name
  the server and the missing setting; "must be scheme://host[:port]" means the URL has a path or a typo.
- **Red dot / "Not reachable" / 502 Bad Gateway.** Home Assistant cannot reach that Jam-Dash at its `url`. Check that Jam-Dash is running and
  that the address works from the Home Assistant machine. If a `.local` name does not resolve, use the IP
  address instead.
- **Amber dot / Jam-Dash asks for its password inside Home Assistant.** That server's key does not match (copied wrong, or a
  new key was made since) or Home Assistant access is off in Jam-Dash. Make a new key and paste it again,
  then restart the add-on.
- **Pages load but look broken, or live updates do not appear.** Your Jam-Dash version must support
  running under a path prefix; update Jam-Dash.
- **Large downloads or uploads stop.** The add-on does not limit size and allows transfers up to an hour
  of inactivity; check Jam-Dash's own limits and your reverse proxy in front of Home Assistant, if any.
