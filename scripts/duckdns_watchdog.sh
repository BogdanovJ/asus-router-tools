#!/bin/sh
# Restore DuckDNS IPv4 even when ASUS DDNS sees no WAN IP change.

CONFIG="/jffs/configs/duckdns.conf"
TAG="duckdns-watchdog"

log() {
    logger -t "$TAG" "$*"
}

[ -r "$CONFIG" ] || {
    log "Missing DuckDNS config"
    exit 1
}

. "$CONFIG"

TOKEN_FILE="${DUCKDNS_TOKEN_FILE:-/jffs/configs/duckdns.token}"

[ -n "$DUCKDNS_DOMAIN" ] && [ -r "$TOKEN_FILE" ] || exit 1

TOKEN="$(sed -n '1p' "$TOKEN_FILE" | tr -d '\r\n')"
WAN_IP="$(nvram get wan0_ipaddr)"

[ -n "$TOKEN" ] || exit 1

case "$WAN_IP" in
    ""|0.0.0.0|*[!0-9.]*)
        log "Invalid WAN IP"
        exit 1
        ;;
esac

RESULT="$(curl -fsS --max-time 20 --get \
    --data-urlencode "domains=$DUCKDNS_DOMAIN" \
    --data-urlencode "token=$TOKEN" \
    --data-urlencode "ip=$WAN_IP" \
    https://www.duckdns.org/update 2>/dev/null)" || {
        log "DuckDNS refresh request failed"
        exit 1
    }

if [ "$RESULT" = "OK" ]; then
    exit 0
fi

log "DuckDNS refresh rejected"
exit 1

