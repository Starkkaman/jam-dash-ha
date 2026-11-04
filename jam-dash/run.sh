#!/usr/bin/with-contenv bashio
# shellcheck shell=bash
# Read the add-on options, render the nginx config and run nginx in the foreground.

url="$(bashio::config 'url')"
key="$(bashio::config 'proxy_key')"
[ "$url" = "null" ] && url=""
[ "$key" = "null" ] && key=""

if ! /opt/jam-dash/render.sh "$url" "$key" /opt/jam-dash/nginx.conf.tmpl /run/nginx; then
    bashio::log.fatal "Jam-Dash add-on not started: fix the option above in the Configuration tab, then start again."
    exit 1
fi
unset key

bashio::log.info "Starting nginx on port 8099 (ingress only)"
exec nginx -c /run/nginx/nginx.conf
