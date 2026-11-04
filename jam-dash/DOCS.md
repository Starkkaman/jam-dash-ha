# Jam-Dash

This add-on puts your Jam-Dash dashboard in the Home Assistant sidebar. Jam-Dash keeps running where it
already runs (another machine, NAS, container); the add-on is a small nginx proxy that forwards Home
Assistant ingress to it. Anywhere you can open Home Assistant, at home, through Nabu Casa or your own
remote access, or in the companion app, you can open Jam-Dash.

## Setup

1. **In Jam-Dash:** open **Settings › Home Assistant access** and turn it on. Jam-Dash shows a proxy key
   once. Copy it now (if you lose it, press **New key** and use the new one).
2. **In Home Assistant:** open this add-on's **Configuration** tab and set:
   - **url**: where Jam-Dash runs, scheme, host and port only, for example `http://192.168.1.20:8484`
     or `http://jam-dash.local:8484`. No path, no trailing page.
   - **proxy_key**: the key you copied.
3. Save and **Start** the add-on. Turn on **Show in sidebar** if you want it there.
4. Open **Jam-Dash** from the sidebar (or **Open Web UI** on the add-on page).

## How sign-in works

You do not enter a Jam-Dash password inside Home Assistant. Home Assistant has already signed you in,
and its Supervisor tells the add-on which Home Assistant user is making each request. The add-on
forwards that user (`X-Remote-User-Id`, `-Name`, `-Display-Name`) to Jam-Dash together with the proxy
key. Jam-Dash signs the request in as that Home Assistant user only when the key matches (Jam-Dash reports such a session as signed in "via Home Assistant").

## Why this is safe

- **Admins only.** The sidebar panel is limited to Home Assistant administrators (`panel_admin`).
- **Only the Supervisor can reach the add-on.** nginx accepts connections from the Supervisor's ingress
  gateway (172.30.32.2) only; everything else is refused. The add-on exposes no port on your network.
- **The key proves the request came through this add-on.** Anyone on your network could send
  "I am user X" headers straight to Jam-Dash; without the key Jam-Dash ignores those headers and applies
  its normal sign-in. Jam-Dash stores the key hashed, compares it in constant time and never logs it.
  The add-on stores it as a password option, keeps it in a file only root can read and never writes it to
  its log. A client cannot smuggle its own key: the add-on always replaces that header.
- **Turning it off is instant.** In Jam-Dash, turn **Home Assistant access** off (deletes the key) or
  press **New key** (the old one stops working immediately).
- Traffic between the add-on and Jam-Dash is plain HTTP unless your `url` uses `https://`. Use https or
  keep both on a network you trust; the key travels with each request.

## Troubleshooting

- **Add-on stops right after starting.** Open the **Log** tab. "Option 'url' is empty" or "Option
  'proxy_key' is empty" means a setting is missing; "must be scheme://host[:port]" means the URL has a path
  or a typo.
- **502 Bad Gateway.** Home Assistant cannot reach Jam-Dash at `url`. Check that Jam-Dash is running and
  that the address works from the Home Assistant machine. If a `.local` name does not resolve, use the IP
  address instead.
- **Jam-Dash asks for its password inside Home Assistant.** The key does not match (copied wrong, or a
  new key was made since) or Home Assistant access is off in Jam-Dash. Make a new key and paste it again,
  then restart the add-on.
- **Pages load but look broken, or live updates do not appear.** Your Jam-Dash version must support
  running under a path prefix; update Jam-Dash.
- **Large downloads or uploads stop.** The add-on does not limit size and allows transfers up to an hour
  of inactivity; check Jam-Dash's own limits and your reverse proxy in front of Home Assistant, if any.
