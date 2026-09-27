#!/bin/sh
# ASUSWRT WireGuard server watchdog. Intended for cru every 5 minutes.
. /jffs/scripts/router-tools-common.sh || exit 1

STATE="/jffs/wg_watchdog.state"
OFF_FILE="/jffs/wg_watchdog.off"
SLEEP_AFTER_RESTART=4
log() { logger -t wg_watchdog "$@"; }
get_state() { [ -f "$STATE" ] && awk -F= -v k="$1" '$1==k{print $2}' "$STATE"; }
write_state() {
    la=$(get_state last_alert); lc=$(get_state last_no_client)
    case "$1" in last_alert) la=$(date +%s);; last_no_client) lc=$(date +%s);; esac
    { echo "last_alert=$la"; echo "last_no_client=$lc"; } > "$STATE"
}
can_alert() { last=$(get_state last_alert); [ -z "$last" ] && return 0; now=$(date +%s); [ $((now-last)) -ge "$ALERT_COOLDOWN" ]; }
can_no_client_alert() { last=$(get_state last_no_client); [ -z "$last" ] && return 0; now=$(date +%s); [ $((now-last)) -ge "$NO_CLIENT_COOLDOWN" ]; }

[ -f "$OFF_FILE" ] && { log "skipped (maintenance flag present)"; exit 0; }
NOW=$(date +%s)
WGS_ENABLE=$(nvram get wgs_enable)
WGS1_ENABLE=$(nvram get wgs1_enable)
WG1_UP=$(ip link show "$WG_INTERFACE" 2>/dev/null | grep -o 'UP,LOWER_UP')
PORT=$(nvram get wgs1_port); [ -z "$PORT" ] && PORT="$WG_FALLBACK_PORT"
PORT_LISTEN=$(netstat -lnu 2>/dev/null | grep ":${PORT}[[:space:]]")
healthy() { [ "$WGS_ENABLE" = 1 ] && [ "$WGS1_ENABLE" = 1 ] && [ -n "$WG1_UP" ] && [ -n "$PORT_LISTEN" ]; }
ACTION=""
if [ "$WGS_ENABLE" != 1 ] || [ "$WGS1_ENABLE" != 1 ]; then
    log "disabled detected - re-enabling"
    nvram set wgs_enable=1; nvram set wgs1_enable=1; nvram commit
    service restart_wgs; sleep "$SLEEP_AFTER_RESTART"; ACTION="re-enabled (was disabled)"
elif ! healthy; then
    log "$WG_INTERFACE unhealthy - restarting WireGuard server"
    service restart_wgs; sleep "$SLEEP_AFTER_RESTART"; ACTION="restarted (server down)"
fi
if [ -n "$ACTION" ]; then
    WGS_ENABLE=$(nvram get wgs_enable); WGS1_ENABLE=$(nvram get wgs1_enable)
    WG1_UP=$(ip link show "$WG_INTERFACE" 2>/dev/null | grep -o 'UP,LOWER_UP')
    PORT_LISTEN=$(netstat -lnu 2>/dev/null | grep ":${PORT}[[:space:]]")
    if healthy; then
        log "recovery verified OK"
        can_alert && { telegram_notify "✅ *WireGuard server recovered*\n\n$ACTION — server verified running again on UDP ${PORT}."; write_state last_alert; }
    else
        log "RECOVERY FAILED"
        can_alert && { telegram_notify "⚠️ *MANUAL ATTENTION NEEDED*\n\nWireGuard server could not be restored.\nenable=$WGS_ENABLE/$WGS1_ENABLE iface_up='$WG1_UP' port=$PORT"; write_state last_alert; }
    fi
    exit 0
fi
if healthy; then
    LATEST=0
    WG_DATA=$(wg show all dump 2>/dev/null | tail -n +2)
    while read -r line; do
        [ -z "$line" ] && continue
        IP_INT=$(echo "$line" | awk '{print $5}' | cut -d/ -f1); HS=$(echo "$line" | awk '{print $6}')
        [ "$IP_INT" = 0.0.0.0 ] && continue; [ "$IP_INT" = off ] && continue
        [ "$HS" -eq 0 ] 2>/dev/null && continue; [ "$HS" -gt "$LATEST" ] && LATEST=$HS
    done <<EOF2
$WG_DATA
EOF2
    if [ "$LATEST" -gt 0 ] && [ $((NOW-LATEST)) -gt "$NO_CLIENT_THRESHOLD" ]; then
        HOURS=$(((NOW-LATEST)/3600)); log "no client handshake in ${HOURS}h"
        can_no_client_alert && { telegram_notify "📵 *WireGuard: no clients for ~${HOURS}h*\n\nServer is healthy, but no device has connected in the last ${HOURS} hours."; write_state last_no_client; }
    fi
fi
log "ok (enable=$WGS_ENABLE/$WGS1_ENABLE iface_up='$WG1_UP' port=$PORT listening=yes)"
