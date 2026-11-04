#!/bin/sh
# Render the nginx config for Jam-Dash. Shared by run.sh (in the add-on) and tests/run.sh.
# Usage: render.sh <url> <proxy_key> <template> <out_dir>
# Writes <out_dir>/nginx.conf and <out_dir>/proxy-key.conf (mode 600). Never prints the key.
set -eu

url="${1-}"; key="${2-}"; tmpl="${3:?template}"; out="${4:?out_dir}"

fail() { echo "[jam-dash] $*" >&2; exit 1; }

[ -n "$url" ] || fail "Option 'url' is empty. Set it to where Jam-Dash runs, e.g. http://192.168.1.20:8484"
[ -n "$key" ] || fail "Option 'proxy_key' is empty. In Jam-Dash open Settings > Home Assistant access, turn it on and paste the key here."

url="${url%/}"
echo "$url" | grep -Eq '^https?://[A-Za-z0-9._~-]+(:[0-9]{1,5})?$|^https?://\[[0-9A-Fa-f:.]+\](:[0-9]{1,5})?$' \
    || fail "Option 'url' must be scheme://host[:port] with no path, e.g. http://jam-dash.local:8484"
echo "$key" | grep -Eq '^[A-Za-z0-9._~+/=-]{16,512}$' \
    || fail "Option 'proxy_key' does not look like a Jam-Dash key (copy it again from Jam-Dash)."

# Resolver: the container's nameservers (Home Assistant's DNS plugin inside HA).
resolver=""
if [ -r /etc/resolv.conf ]; then
    for ns in $(awk '$1=="nameserver"{print $2}' /etc/resolv.conf); do
        case "$ns" in *:*) ns="[${ns%%\%*}]";; esac
        resolver="$resolver $ns"
    done
fi
resolver="${resolver# }"
[ -n "$resolver" ] || resolver="172.30.32.3"

mkdir -p "$out"
for d in client_body proxy fastcgi uwsgi scgi; do mkdir -p "$out/$d"; done

umask 077
printf 'proxy_set_header X-Jam-Dash-Proxy "%s";\n' "$key" > "$out/proxy-key.conf"
umask 022

sed -e "s|@RUN_DIR@|$out|g" \
    -e "s|@RESOLVER@|$resolver|g" \
    -e "s|@UPSTREAM@|$url|g" \
    -e "s|@KEY_FILE@|$out/proxy-key.conf|g" \
    "$tmpl" > "$out/nginx.conf"

echo "[jam-dash] Proxying Home Assistant ingress to $url"
