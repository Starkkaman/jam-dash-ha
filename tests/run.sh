#!/bin/sh
# Local test without Home Assistant: renders the nginx config with sample options using the
# add-on's own render.sh + templates, then validates it.
#   - nginx on PATH (or NGINX=/path/to/nginx): runs `nginx -t`, then a live proxy test
#     (needs node + curl) against two fake Jam-Dash servers that echo the headers they received.
#   - no nginx: only static checks on the rendered files (says so).
# Not covered here: run.sh's jq extraction of /data/options.json (needs the add-on container).
set -u
here="$(cd "$(dirname "$0")" && pwd)"
addon="$here/../jam-dash"
work="$(mktemp -d)"
ngx_pid=""; up_pids=""
trap 'kill $ngx_pid $up_pids 2>/dev/null; rm -rf "$work"' EXIT
NGINX="${NGINX:-$(command -v nginx || true)}"
P1="${UP_PORT:-18484}"; P2=$((P1+1))
fails=0
ok()  { echo "ok   - $*"; }
bad() { echo "FAIL - $*"; fails=$((fails+1)); }
US="$(printf '\037')"

KEY1="key-one_0123456789abcdefABCDEF"
KEY2="key-two_0123456789abcdefABCDEF"
KEY3="key-three_0123456789abcdefABCD"
# servers <out> [name url key]... : write a server list like run.sh's jq produces.
servers() { f="$1"; shift; : > "$f"; while [ $# -ge 3 ]; do printf '%s\037%s\037%s\n' "$1" "$2" "$3" >> "$f"; shift 3; done; }
render() { "$addon/render.sh" "$1" "$2" "$3" "$addon" "$4" >"$work/render.log" 2>&1; }
refused() { # <label> <expected message part> <list> <legacy_url> <legacy_key>
    if render "$3" "$4" "$5" "$work/x"; then bad "$1 accepted"
    elif grep -qF "$2" "$work/render.log"; then ok "$1 refused"
    else bad "$1: unexpected message: $(cat "$work/render.log")"; fi
}
nokeys() { # <file> <label>
    if grep -qE "$KEY1|$KEY2|$KEY3|127\.0\.0\.1|smol\.lan|truenas\.lan" "$1"; then bad "$2 leaks a key or upstream"; else ok "$2 has no keys or upstreams"; fi
}

# 1. Refuses to start on missing / malformed options, with a clear message.
servers "$work/empty"
refused "no servers"            "No servers configured"                "$work/empty" "" ""
servers "$work/l" "A" "" "$KEY1";                       refused "empty url"     "Option 'url' of server 1" "$work/l" "" ""
servers "$work/l" "A" "http://h:1" "";                  refused "empty key"     "Option 'proxy_key' of server 1" "$work/l" "" ""
servers "$work/l" "" "http://h:1" "$KEY1";              refused "empty name"    "Server 1 has no name" "$work/l" "" ""
servers "$work/l" "A" "http://h:1/path" "$KEY1";        refused "url with path" "must be scheme://host" "$work/l" "" ""
servers "$work/l" "A" "http://h:1" 'bad"key;0123456789'; refused "unsafe key"   "does not look like" "$work/l" "" ""
servers "$work/l" "A" "http://h:1" "$KEY1" "B" "http://h:2" ""; refused "second server without key" "of server 2 (\"B\")" "$work/l" "" ""
refused "legacy url without key" "Option 'proxy_key' of server 1 (\"Jam-Dash\")" "$work/empty" "http://h:1" ""

# 2. Slugs: lowercase a-z0-9-, unique with -2, -3 on clashes, fallback "server".
servers "$work/clash" "TrueNAS" "http://truenas.lan:8484" "$KEY1" "truenas!" "http://truenas.lan:8485" "$KEY2" \
        "True NAS" "http://truenas.lan:8486" "$KEY3" "***" "http://truenas.lan:8487" "$KEY3"
if render "$work/clash" "" "" "$work/c"; then
    [ "$(cat "$work/c/www/servers.json")" = '[{"name":"TrueNAS","slug":"truenas","path":"s/truenas/"},{"name":"truenas!","slug":"truenas-2","path":"s/truenas-2/"},{"name":"True NAS","slug":"true-nas","path":"s/true-nas/"},{"name":"***","slug":"server","path":"s/server/"}]' ] \
        && ok "slugs and clashes" || bad "slugs: $(cat "$work/c/www/servers.json")"
else bad "clash render: $(cat "$work/render.log")"; fi
servers "$work/q" 'Say "hi" \ there' "http://h:1" "$KEY1" "Smol-Boi" "http://h:2" "$KEY2"
render "$work/q" "" "" "$work/q2" && node -e 'const s=JSON.parse(require("fs").readFileSync(process.argv[1]));if(s[0].name!=="Say \"hi\" \\ there"||s[1].slug!=="smol-boi")process.exit(1)' "$work/q2/www/servers.json" 2>/dev/null \
    && ok "servers.json is valid JSON with escaped names" || bad "servers.json escaping: $(cat "$work/q2/www/servers.json")"

# 3. Two-server render.
servers "$work/two" "smol-boi" "http://127.0.0.1:$P1/" "$KEY1" "TrueNAS" "http://127.0.0.1:$P2" "$KEY2"
if render "$work/two" "" "" "$work/two-out"; then ok "two servers rendered"; else bad "render failed"; cat "$work/render.log"; exit 1; fi
o="$work/two-out"; conf="$o/nginx.conf"
grep -qE "$KEY1|$KEY2" "$work/render.log" && bad "key printed by render" || ok "keys not printed (the log shows names and addresses only)"
nokeys "$o/www/servers.json" "servers.json"
grep -qE "$KEY1|$KEY2" "$conf" "$o/servers.conf" "$o/root.conf" && bad "key inlined in nginx config" || ok "keys only in include files"
[ "$(stat -c %a "$o/keys/smol-boi.conf")" = 600 ] && [ "$(stat -c %a "$o/keys/truenas.conf")" = 600 ] && ok "key files mode 600" || bad "key file mode"
grep -qF "$KEY1" "$o/keys/smol-boi.conf" && grep -qF "$KEY2" "$o/keys/truenas.conf" && ok "one key per server" || bad "key files"
grep -q '@[A-Z_]*@' "$conf" "$o/servers.conf" && bad "unrendered placeholder" || ok "no placeholders left"
grep -q 'try_files /index.html' "$o/root.conf" && ok "2 servers: root serves the landing page" || bad "2 servers: root.conf"
for want in 'listen 8099' 'allow 172.30.32.2;' 'deny  all;' 'client_max_body_size 0;' 'proxy_buffering off;'; do
    grep -qF "$want" "$conf" && ok "has: $want" || bad "missing: $want"
done
for want in 'location /s/smol-boi/' 'location /s/truenas/' 'X-Forwarded-Prefix "$http_x_ingress_path/s/truenas"' \
            'Upgrade $http_upgrade' "set \$jd_upstream \"http://127.0.0.1:$P1\";"; do
    grep -qF "$want" "$o/servers.conf" && ok "has: $want" || bad "missing: $want"
done
sed -n '/log_format/,/;/p' "$conf" | grep -qi 'jam_dash_proxy' && bad "log_format logs the key header" || ok "log_format has no key header"

# 4. One server: root redirects; legacy options become one server "Jam-Dash".
servers "$work/one" "smol-boi" "http://127.0.0.1:$P1" "$KEY1"
render "$work/one" "" "" "$work/one-out" && grep -qF 'return 302 $http_x_ingress_path/s/smol-boi/;' "$work/one-out/root.conf" \
    && ok "1 server: root redirects to it" || bad "1 server: root.conf"
if render "$work/empty" "http://127.0.0.1:$P1" "$KEY1" "$work/legacy-out"; then
    [ "$(cat "$work/legacy-out/www/servers.json")" = '[{"name":"Jam-Dash","slug":"jam-dash","path":"s/jam-dash/"}]' ] \
        && ok "legacy url/proxy_key -> one server \"Jam-Dash\"" || bad "legacy servers.json"
    grep -q 'old single-server options' "$work/render.log" && ok "legacy use is logged" || bad "legacy log line"
    nokeys "$work/legacy-out/www/servers.json" "legacy servers.json"
else bad "legacy render: $(cat "$work/render.log")"; fi
render "$work/one" "http://legacy.lan:1" "$KEY3" "$work/both" && ! grep -q legacy "$work/both/servers.conf" \
    && ok "servers list wins over legacy options" || bad "servers list vs legacy"

if [ -z "$NGINX" ]; then
    echo "NOTE - nginx not found: skipped 'nginx -t' and the live proxy test (static checks only)."
    [ $fails -eq 0 ] && echo "PASS (static only)" || echo "$fails failure(s)"; exit $fails
fi

# 5. nginx -t on the rendered configs.
for c in "$conf" "$work/one-out/nginx.conf" "$work/legacy-out/nginx.conf"; do
    if "$NGINX" -t -q -e /dev/stderr -c "$c" >"$work/t.log" 2>&1; then ok "nginx -t ($(basename "$(dirname "$c")"))"; else bad "nginx -t $c"; cat "$work/t.log"; fi
done

# 6. Live test: two fake Jam-Dash servers echoing what they got.
if ! command -v node >/dev/null || ! command -v curl >/dev/null; then
    echo "NOTE - node/curl missing: skipped live proxy test."; exit $fails
fi
for p in $P1 $P2; do
    node -e '
    require("http").createServer((q,s)=>{s.setHeader("content-type","application/json");
     s.end(JSON.stringify({port:+process.argv[1],url:q.url,h:q.headers}))}).listen(+process.argv[1],"127.0.0.1");' "$p" &
    up_pids="$up_pids $!"
done
start() { "$NGINX" -e /dev/stderr -c "$1" >>"$work/ngx.log" 2>&1 & ngx_pid=$!; sleep 1; }
stop()  { kill $ngx_pid; wait $ngx_pid 2>/dev/null; ngx_pid=""; }
code() { curl -s -o /dev/null -w '%{http_code}' "$@"; }
local_conf() { sed 's/allow 172.30.32.2;/allow 127.0.0.1;/' "$1" > "$1.local"; echo "$1.local"; }
U=http://127.0.0.1:8099
IP='X-Ingress-Path: /api/hassio_ingress/TOKEN'

start "$conf"
[ "$(code $U/)" = 403 ] && ok "non-Supervisor client refused (403)" || bad "expected 403"
stop

start "$(local_conf "$conf")"
body=$(curl -s -H "$IP" -H 'X-Remote-User-Id: u1' -H 'X-Remote-User-Name: alice' \
       -H 'X-Remote-User-Display-Name: Alice A' -H 'X-Jam-Dash-Proxy: forged' "$U/s/truenas/api/v1/x?y=1")
check() { echo "$body" | grep -qF "$1" && ok "$2 got $1" || bad "$2 missing $1 in $body"; }
check "\"port\":$P2" truenas
check '"url":"/api/v1/x?y=1"' truenas
check "\"x-jam-dash-proxy\":\"$KEY2\"" truenas
check '"x-forwarded-prefix":"/api/hassio_ingress/TOKEN/s/truenas"' truenas
check '"x-remote-user-id":"u1"' truenas
check '"x-remote-user-display-name":"Alice A"' truenas
check "\"host\":\"127.0.0.1:$P2\"" truenas
check '"x-forwarded-proto":"http"' truenas
echo "$body" | grep -q forged && bad "client-sent key passed through" || ok "client-sent key replaced"
body=$(curl -s -H "$IP" "$U/s/smol-boi/")
check "\"port\":$P1" smol-boi; check '"url":"/"' smol-boi; check "\"x-jam-dash-proxy\":\"$KEY1\"" smol-boi
body=$(curl -s -H "$IP" -H 'Connection: Upgrade' -H 'Upgrade: websocket' "$U/s/smol-boi/ws")
check '"upgrade":"websocket"' smol-boi-ws; check '"connection":"upgrade"' smol-boi-ws
loc=$(curl -s -o /dev/null -w '%{redirect_url}|%{http_code}' -H "$IP" "$U/s/truenas")
case "$loc" in *"/api/hassio_ingress/TOKEN/s/truenas/|301") ok "s/<slug> -> s/<slug>/";; *) bad "slash redirect: $loc";; esac
[ "$(code "$U/s/nope/")" = 404 ] && ok "unknown server 404" || bad "unknown server"
page=$(curl -s -H "$IP" "$U/")
echo "$page" | grep -q '<ul id="servers"' && ok "2 servers: landing page served at /" || bad "landing page"
echo "$page" | grep -qE "$KEY1|$KEY2|127\.0\.0\.1" && bad "landing page leaks" || ok "landing page has no keys or upstreams"
sj=$(curl -s -D "$work/h" "$U/servers.json")
[ "$sj" = '[{"name":"smol-boi","slug":"smol-boi","path":"s/smol-boi/"},{"name":"TrueNAS","slug":"truenas","path":"s/truenas/"}]' ] \
    && ok "GET servers.json" || bad "GET servers.json: $sj"
grep -qi 'content-type: application/json' "$work/h" && ok "servers.json is application/json" || bad "servers.json type"
stop

start "$(local_conf "$work/one-out/nginx.conf")"
loc=$(curl -s -o /dev/null -w '%{redirect_url}|%{http_code}' -H "$IP" "$U/")
case "$loc" in *"/api/hassio_ingress/TOKEN/s/smol-boi/|302") ok "1 server: / redirects to s/smol-boi/";; *) bad "1 server redirect: $loc";; esac
stop

grep -qE "$KEY1|$KEY2" "$work/ngx.log" && bad "key in nginx log" || ok "key not in nginx log"
[ $fails -eq 0 ] && echo "PASS" || echo "$fails failure(s)"
exit $fails
