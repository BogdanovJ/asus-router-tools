#!/bin/sh
# Daily Telegram router health and WireGuard activity report.
. /jffs/scripts/router-tools-common.sh || exit 1
UPTIME=$(uptime | awk -F'( |,|:)+' '{if ($7=="min") m=$6; else {if ($7~/day/) {d=$6; h=$8; m=$9} else {h=$6; m=$7}}} {if (d!="") printf "%sd ",d; printf "%sh %sm",h,m}')
TEMP_RAW=$(cat /sys/class/thermal/thermal_zone0/temp 2>/dev/null)
[ -n "$TEMP_RAW" ] && CPU_TEMP=$(awk "BEGIN {printf \"%.1f°C\", $TEMP_RAW/1000}") || CPU_TEMP="n/a"
RAM_TOTAL=$(awk '/MemTotal:/ {print $2}' /proc/meminfo); RAM_FREE=$(awk '/MemFree:/ {print $2}' /proc/meminfo)
RAM_BUFF=$(awk '/^(Buffers|Cached):/ {s+=$2} END {print s+0}' /proc/meminfo); RAM_USED=$((RAM_TOTAL-RAM_FREE-RAM_BUFF)); RAM_PERC=$((RAM_USED*100/RAM_TOTAL))
WAN_IF=$(nvram get wan0_gw_ifname); [ -z "$WAN_IF" ] && WAN_IF=$(nvram get wan0_ifname)
WAN_LINE=$(grep "${WAN_IF}:" /proc/net/dev | sed 's/.*://'); WAN_RX_BYTES=$(echo "$WAN_LINE" | awk '{print $1}'); WAN_TX_BYTES=$(echo "$WAN_LINE" | awk '{print $9}')
: "${WAN_RX_BYTES:=0}"; : "${WAN_TX_BYTES:=0}"
WAN_RX_GB=$(awk "BEGIN {printf \"%.2f GB\", $WAN_RX_BYTES/1073741824}"); WAN_TX_GB=$(awk "BEGIN {printf \"%.2f GB\", $WAN_TX_BYTES/1073741824}")
NOW=$(date +%s); WG_DATA=$(wg show all dump 2>/dev/null | tail -n +2); WG_REPORT=""
while read -r line; do
    [ -z "$line" ] && continue
    IP_INT=$(echo "$line" | awk '{print $5}' | cut -d/ -f1); LATEST_HS=$(echo "$line" | awk '{print $6}'); RX=$(echo "$line" | awk '{print $7}'); TX=$(echo "$line" | awk '{print $8}')
    [ "$IP_INT" = 0.0.0.0 ] && continue; [ "$IP_INT" = off ] && continue; [ "$LATEST_HS" -eq 0 ] 2>/dev/null && continue
    NAME=$(peer_name "$IP_INT")
    RX_VAL=$(awk "BEGIN {if ($RX >= 1073741824) printf \"%.2f GB\",$RX/1073741824; else printf \"%.2f MB\",$RX/1048576}")
    TX_VAL=$(awk "BEGIN {if ($TX >= 1073741824) printf \"%.2f GB\",$TX/1073741824; else printf \"%.2f MB\",$TX/1048576}")
    DIFF=$((NOW-LATEST_HS)); [ "$DIFF" -lt 180 ] && STATUS="🔥 PUMPING" || STATUS="✅ Active"; HS_H=$(awk "BEGIN {printf \"%.1f\",$DIFF/3600}")
    WG_REPORT="$WG_REPORT
👤 *$NAME* ($IP_INT)
- Status: $STATUS (${HS_H}h ago)
- Transfer: ↓$RX_VAL | ↑$TX_VAL"
done <<EOF2
$WG_DATA
EOF2
[ -z "$WG_REPORT" ] && WG_REPORT="\n_No WireGuard clients with recorded handshakes._"
FINAL_MSG="🏠 *Router Health Report: $(date +%Y-%m-%d)*

📉 *Vitals*
- Uptime: $UPTIME
- Temp: $CPU_TEMP
- RAM: $RAM_PERC%

🌐 *WAN Pulse ($WAN_IF)*
- Total Rx: $WAN_RX_GB
- Total Tx: $WAN_TX_GB

📊 *WireGuard Activity*
$WG_REPORT"
telegram_notify "$FINAL_MSG"
