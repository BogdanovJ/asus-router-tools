#!/bin/sh
CONFIG="/jffs/configs/router-tools.conf"
PEERS="/jffs/configs/wg-peers.conf"

if [ ! -r "$CONFIG" ]; then
    logger -t router-tools "ERROR: missing configuration: $CONFIG"
    echo "ERROR: missing configuration: $CONFIG" >&2
    exit 1
fi

# shellcheck disable=SC1090
. "$CONFIG"

if [ -z "$TELEGRAM_BOT_TOKEN" ] || [ -z "$TELEGRAM_CHAT_ID" ]; then
    logger -t router-tools "ERROR: TELEGRAM_BOT_TOKEN or TELEGRAM_CHAT_ID is not configured"
fi

: "${WG_INTERFACE:=wgs1}"
: "${WG_FALLBACK_PORT:=443}"
: "${NO_CLIENT_THRESHOLD:=86400}"
: "${ALERT_COOLDOWN:=900}"
: "${NO_CLIENT_COOLDOWN:=86400}"

telegram_notify() {
    if [ -z "$TELEGRAM_BOT_TOKEN" ] || [ -z "$TELEGRAM_CHAT_ID" ]; then
        logger -t router-tools "Telegram notification skipped: credentials not configured"
        return 1
    fi

    if curl -fsS -X POST \
        "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
        --data-urlencode "chat_id=${TELEGRAM_CHAT_ID}" \
        --data-urlencode "text=$1" \
        --data-urlencode "parse_mode=Markdown" >/dev/null; then
        return 0
    fi

    rc=$?
    logger -t router-tools "Telegram notification failed (curl exit $rc)"
    return "$rc"
}
peer_name() {
    ip="$1"
    if [ -r "$PEERS" ]; then
        name=$(awk -F'|' -v ip="$ip" '$1==ip {sub(/^[^|]*\|/, ""); print; exit}' "$PEERS")
        [ -n "$name" ] && { printf '%s' "$name"; return; }
    fi
    printf '%s' "$ip"
}
