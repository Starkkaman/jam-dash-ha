#!/bin/sh
# Local test without Home Assistant: renders the nginx config with sample options using the
# add-on's own render.sh + template, then validates it.
#   - nginx on PATH (or NGINX=/path/to/nginx): runs `nginx -t`, then a live proxy test
#     (needs node + curl) against a fake Jam-Dash that echoes the headers it received.
#   - no nginx: only static checks on the rendered file (says so).
set -u
here="$(cd "$(dirname "$0")" && pwd)"
addon="$here/../jam-dash"
work="$(mktemp -d)"
trap 'kill $ngx_pid $up_pid 2>/dev/null; rm -rf "$work"' EXIT
ngx_pid=""; up_pid=""
NGINX="${NGINX:-$(command -v nginx || true)}"
UP_PORT="${UP_PORT:-18484}"
fails=0
ok()  { echo "ok   - $*"; }
bad() { echo "FAIL - $*"; fails=$((fails+1)); }

KEY="test-key_0123456789abcdefABCDEF"
render() { "$addon/render.sh" "$1" "$2" "$addon/nginx.conf.tmpl" "$work/out" >"$work/render.log" 2>&1; }

# 1. Refuses to start on empty / malformed options, with a clear message.
render "" "$KEY"                    && bad "empty url accepted" || { grep -q "Option 'url' is empty" "$work/render.log" && ok "empty url refused" || bad "empty url message"; }
render "http://jam-dash.local:8484" "" && bad "empty key accepted" || { grep -q "Option 'proxy_key' is empty" "$work/render.log" && ok "empty key refused" || bad "empty key message"; }
render "http://host:8484/path" "$KEY" && bad "url with path accepted" || ok "url with path refused"
render "http://host:8484" 'bad"key;'  && bad "unsafe key accepted" || ok "unsafe key refused"

# 2. Renders with sample options.
if render "http://127.0.0.1:$UP_PORT/" "$KEY"; then ok "rendered"; else bad "render failed"; cat "$work/render.log"; exit 1; fi
conf="$work/out/nginx.conf"
grep -q "$KEY" "$work/render.log" && bad "key printed by render" || ok "key not printed"
grep -q "$KEY" "$conf" && bad "key inlined in nginx.conf" || ok "key only in include file"
[ "$(stat -c %a "$work/out/proxy-key.conf")" = 600 ] && ok "key file mode 600" || bad "key file mode"
grep -q '@[A-Z_]*@' "$conf" && bad "unrendered placeholder" || ok "no placeholders left"
for want in 'listen 8099' 'allow 172.30.32.2;' 'deny  all;' 'client_max_body_size 0;' 'proxy_buffering off;' \
            'X-Forwarded-Prefix $http_x_ingress_path' 'Upgrade $http_upgrade' "set \$jd_upstream \"http://127.0.0.1:$UP_PORT\";"; do
    grep -qF "$want" "$conf" && ok "has: $want" || bad "missing: $want"
done
sed -n '/log_format/,/;/p' "$conf" | grep -qi 'jam_dash_proxy' && bad "log_format logs the key header" || ok "log_format has no key header"

if [ -z "$NGINX" ]; then
    echo "NOTE - nginx not found: skipped 'nginx -t' and the live proxy test (static checks only)."
    [ $fails -eq 0 ] && echo "PASS (static only)" || echo "$fails failure(s)"; exit $fails
fi

# 3. nginx -t on the rendered config.
if "$NGINX" -t -q -e /dev/stderr -c "$conf" >"$work/t.log" 2>&1; then ok "nginx -t"; else bad "nginx -t"; cat "$work/t.log"; fi

# 4. Live test: a fake Jam-Dash echoing headers; the real config must refuse 127.0.0.1,
#    and a copy allowing 127.0.0.1 (stand-in for the Supervisor) must proxy correctly.
if ! command -v node >/dev/null || ! command -v curl >/dev/null; then
    echo "NOTE - node/curl missing: skipped live proxy test."; exit $fails
fi
node -e '
require("http").createServer((q,s)=>{s.setHeader("content-type","application/json");
 s.end(JSON.stringify({url:q.url,h:q.headers}))}).listen(+process.argv[1],"127.0.0.1");' "$UP_PORT" &
up_pid=$!
"$NGINX" -e /dev/stderr -c "$conf" >"$work/ngx.log" 2>&1 & ngx_pid=$!
sleep 1
code=$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:8099/)
[ "$code" = 403 ] && ok "non-Supervisor client refused (403)" || bad "expected 403, got $code"
kill $ngx_pid; wait $ngx_pid 2>/dev/null
sed 's/allow 172.30.32.2;/allow 127.0.0.1;/' "$conf" > "$work/out/local.conf"
"$NGINX" -e /dev/stderr -c "$work/out/local.conf" >"$work/ngx.log" 2>&1 & ngx_pid=$!
sleep 1
body=$(curl -s -H 'X-Ingress-Path: /api/hassio_ingress/TOKEN' -H 'X-Remote-User-Id: u1' \
       -H 'X-Remote-User-Name: alice' -H 'X-Remote-User-Display-Name: Alice A' \
       -H 'X-Jam-Dash-Proxy: forged' 'http://127.0.0.1:8099/api/v1/x?y=1')
check() { echo "$body" | grep -qF "$1" && ok "upstream got $1" || bad "upstream missing $1"; }
check '"url":"/api/v1/x?y=1"'
check "\"x-jam-dash-proxy\":\"$KEY\""
check '"x-forwarded-prefix":"/api/hassio_ingress/TOKEN"'
check '"x-remote-user-id":"u1"'
check '"x-remote-user-display-name":"Alice A"'
check "\"host\":\"127.0.0.1:$UP_PORT\""
check '"x-forwarded-proto":"http"'
echo "$body" | grep -q forged && bad "client-sent key passed through" || ok "client-sent key replaced"
grep -q "$KEY" "$work/ngx.log" && bad "key in nginx log" || ok "key not in nginx log"
body=$(curl -s -H 'Connection: Upgrade' -H 'Upgrade: websocket' http://127.0.0.1:8099/ws)
check '"upgrade":"websocket"'
check '"connection":"upgrade"'

[ $fails -eq 0 ] && echo "PASS" || echo "$fails failure(s)"
exit $fails
