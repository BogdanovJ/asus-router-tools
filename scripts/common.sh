#!/bin/sh
CONFIG="/jffs/configs/router-tools.conf"
PEERS="/jffs/configs/wg-peers.conf"

[ -r "$CONFIG" ] || { logger -t router-tools "missing $CONFIG"; exit 1; }
# shellcheck disable=SC1090
. "$CONFIG"

: "${WG_INTERFACE:=wgs1}"
: "${WG_FALLBACK_PORT:=443}"
: "${NO_CLIENT_THRESHOLD:=86400}"
: "${ALERT_COOLDOWN:=900}"
: "${NO_CLIENT_COOLDOWN:=86400}"

telegram_notify() {
    [ -n "$TELEGRAM_BOT_TOKEN" ] && [ -n "$TELEGRAM_CHAT_ID" ] || return 1
    curl -fsS -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
      --data-urlencode "chat_id=${TELEGRAM_CHAT_ID}" \
      --data-urlencode "text=$1" \
      --data-urlencode "parse_mode=Markdown" >/dev/null
}

peer_name() {
    ip="$1"
    if [ -r "$PEERS" ]; then
        name=$(awk -F'|' -v ip="$ip" '$1==ip {sub(/^[^|]*\|/, ""); print; exit}' "$PEERS")
        [ -n "$name" ] && { printf '%s' "$name"; return; }
    fi
    printf '%s' "$ip"
}
