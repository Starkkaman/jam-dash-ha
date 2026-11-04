#!/usr/bin/with-contenv bashio
# shellcheck shell=bash
# Read the add-on options, render the nginx config and run nginx in the foreground.

servers_list="$(mktemp)"
# One line per server, fields joined by \037 (unit separator); newlines/separators in values become spaces.
jq -r '(.servers // [])[] | [(.name // ""), (.url // ""), (.proxy_key // "")]
       | map(tostring | gsub("[\n\r\u001f]"; " ")) | join("\u001f")' \
    /data/options.json > "$servers_list"
legacy_url="$(jq -r '.url // ""' /data/options.json)"
legacy_key="$(jq -r '.proxy_key // ""' /data/options.json)"

if ! /opt/jam-dash/render.sh "$servers_list" "$legacy_url" "$legacy_key" /opt/jam-dash /run/nginx; then
    rm -f "$servers_list"
    bashio::log.fatal "Jam-Dash add-on not started: fix the option above in the Configuration tab, then start again."
    exit 1
fi
rm -f "$servers_list"
unset legacy_key

bashio::log.info "Starting nginx on port 8099 (ingress only)"
exec nginx -c /run/nginx/nginx.conf
