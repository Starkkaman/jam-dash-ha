# Jam-Dash add-ons for Home Assistant

Home Assistant add-on repository for [Jam-Dash](https://github.com/Starkkaman/jam-dash), a home-server dashboard.

| Add-on | What it does |
| --- | --- |
| [Jam-Dash](jam-dash/) | Opens your Jam-Dash (running anywhere on your network) in the Home Assistant sidebar via ingress, so it works wherever Home Assistant works, including the companion app and remote access. |

## Install

1. In Home Assistant: **Settings › Add-ons › Add-on store › ⋮ › Repositories**.
2. Add `https://github.com/Starkkaman/jam-dash-ha` and close the dialog.
3. Find **Jam-Dash** in the store, install it, then follow its **Documentation** tab
   (also in [jam-dash/DOCS.md](jam-dash/DOCS.md)).

Supported architectures: `aarch64`, `amd64` (the ones current Home Assistant base images support).

## Development

`tests/run.sh` renders and checks the nginx config without Home Assistant; see [tests/README.md](tests/README.md).
