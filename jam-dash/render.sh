#!/bin/sh
# Render the nginx config for Jam-Dash. Shared by run.sh (in the add-on) and tests/run.sh.
# Usage: render.sh <servers.list> <legacy_url> <legacy_key> <addon_dir> <out_dir>
#   servers.list: one server per line, "name<US>url<US>proxy_key" (US = \037, the ASCII unit
#   separator; a non-whitespace delimiter so empty fields stay empty), from the `servers` option.
#   If it has no servers, the legacy top-level url + proxy_key become one server named "Jam-Dash".
# Writes <out_dir>/nginx.conf, root.conf, servers.conf, keys/<slug>.conf (mode 600) and
# www/servers.json + www/index.html. Never prints a key.
set -eu

list_in="${1:?servers.list}"; legacy_url="${2-}"; legacy_key="${3-}"; addon="${4:?addon_dir}"; out="${5:?out_dir}"

fail() { echo "[jam-dash] $*" >&2; exit 1; }
US="$(printf '\037')"

slugify() {
    printf '%s' "$1" | tr 'A-Z' 'a-z' | sed -e 's/[^a-z0-9]\{1,\}/-/g' -e 's/^-//' -e 's/-$//' | cut -c1-40 | sed 's/-$//'
}
json_str() { printf '"%s"' "$(printf '%s' "$1" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g')"; }

list="$(mktemp)"; trap 'rm -f "$list"' EXIT
grep -v '^[[:space:]]*$' "$list_in" > "$list" || true
if [ ! -s "$list" ]; then
    if [ -n "$legacy_url" ] || [ -n "$legacy_key" ]; then
        printf 'Jam-Dash\037%s\037%s\n' "$legacy_url" "$legacy_key" > "$list"
        echo "[jam-dash] Using the old single-server options (url, proxy_key) as server \"Jam-Dash\"."
    else
        fail "No servers configured. Add at least one under 'servers' (name, url, proxy_key) in the Configuration tab."
    fi
fi

rm -rf "$out/keys" "$out/www"
mkdir -p "$out/keys" "$out/www"
for d in client_body proxy fastcgi uwsgi scgi; do mkdir -p "$out/$d"; done
: > "$out/servers.conf"
json="["; slugs=" "; n=0; first_slug=""

while IFS="$US" read -r name url key; do
    n=$((n+1))
    label="server $n${name:+ (\"$name\")}"
    [ -n "$name" ] || fail "Server $n has no name."
    printf '%s' "$name" | grep -q '[[:cntrl:]]' && fail "Server $n: the name contains control characters."
    [ -n "$url" ] || fail "Option 'url' of $label is empty. Set it to where that Jam-Dash runs, e.g. http://192.168.1.20:8484"
    [ -n "$key" ] || fail "Option 'proxy_key' of $label is empty. In that Jam-Dash open Settings > Home Assistant access, turn it on and paste the key here."
    url="${url%/}"
    echo "$url" | grep -Eq '^https?://[A-Za-z0-9._~-]+(:[0-9]{1,5})?$|^https?://\[[0-9A-Fa-f:.]+\](:[0-9]{1,5})?$' \
        || fail "Option 'url' of $label must be scheme://host[:port] with no path, e.g. http://jam-dash.local:8484"
    # Length checked apart from the pattern: Alpine's (musl) regex refuses repeat counts over 255.
    key="$(printf '%s' "$key" | tr -d '[:space:]')"
    { [ "${#key}" -ge 16 ] && [ "${#key}" -le 512 ] && printf '%s' "$key" | grep -Eq '^[A-Za-z0-9._~+/=-]+$'; } \
        || fail "Option 'proxy_key' of $label does not look like a Jam-Dash key (copy it again from that Jam-Dash)."

    base="$(slugify "$name")"; [ -n "$base" ] || base="server"
    slug="$base"; i=2
    while case "$slugs" in *" $slug "*) true;; *) false;; esac; do slug="$base-$i"; i=$((i+1)); done
    slugs="$slugs$slug "
    [ -n "$first_slug" ] || first_slug="$slug"

    umask 077
    printf 'proxy_set_header X-Jam-Dash-Proxy "%s";\n' "$key" > "$out/keys/$slug.conf"
    umask 022
    sed -e "s|@SLUG@|$slug|g" -e "s|@UPSTREAM@|$url|g" -e "s|@KEY_FILE@|$out/keys/$slug.conf|g" \
        "$addon/location.conf.tmpl" >> "$out/servers.conf"

    [ "$json" = "[" ] || json="$json,"
    json="$json{\"name\":$(json_str "$name"),\"slug\":\"$slug\",\"path\":\"s/$slug/\"}"
    echo "[jam-dash] Server \"$name\" -> s/$slug/ (proxied to $url)"
done < "$list"

printf '%s]\n' "$json" > "$out/www/servers.json"
cp "$addon/index.html" "$out/www/index.html"

if [ "$n" -eq 1 ]; then
    printf 'location = / {\n    return 302 $http_x_ingress_path/s/%s/;\n}\n' "$first_slug" > "$out/root.conf"
else
    printf 'location = / {\n    root %s;\n    try_files /index.html =404;\n    add_header Cache-Control "no-store" always;\n}\n' "$out/www" > "$out/root.conf"
fi

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

sed -e "s|@RUN_DIR@|$out|g" -e "s|@RESOLVER@|$resolver|g" -e "s|@WWW_DIR@|$out/www|g" \
    "$addon/nginx.conf.tmpl" > "$out/nginx.conf"

echo "[jam-dash] $n server(s) configured."
