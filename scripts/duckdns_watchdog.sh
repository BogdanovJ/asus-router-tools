#!/bin/sh
# Refresh DuckDNS IPv4 independently of ASUS WAN/DDNS events.

CONFIG="/jffs/configs/duckdns.conf"
TAG="duckdns-watchdog"

log() {
    logger -t "$TAG" "$*"
}

if [ ! -r "$CONFIG" ]; then
    log "Missing DuckDNS configuration"
    exit 1
fi

. "$CONFIG"

TOKEN_FILE="${DUCKDNS_TOKEN_FILE:-/jffs/configs/duckdns.token}"

if [ -z "$DUCKDNS_DOMAIN" ] || [ ! -r "$TOKEN_FILE" ]; then
    log "Missing DuckDNS domain or token file"
    exit 1
fi

TOKEN="$(sed -n '1p' "$TOKEN_FILE" | tr -d '\r\n')"
WAN_IP="$(nvram get wan0_ipaddr)"

if [ -z "$TOKEN" ]; then
    log "DuckDNS token is empty"
    exit 1
fi

case "$WAN_IP" in
    ""|0.0.0.0|*[!0-9.]*)
        log "Invalid WAN IPv4 address"
        exit 1
        ;;
esac

RESULT="$(curl -fsS --max-time 20 --get \
    --data-urlencode "domains=$DUCKDNS_DOMAIN" \
    --data-urlencode "token=$TOKEN" \
    --data-urlencode "ip=$WAN_IP" \
    https://www.duckdns.org/update 2>/dev/null)"
RC=$?

unset TOKEN

if [ "$RC" -ne 0 ] || [ "$RESULT" != "OK" ]; then
    log "DuckDNS IPv4 refresh failed (curl=$RC)"
    exit 1
fi

# Successful routine refreshes remain silent.
exit 0