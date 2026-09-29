#!/bin/sh
CONFIG="/jffs/configs/cluster-watchdog.conf"
STATE_DIR="/jffs/router-tools/state/cluster-watchdog"
LOCK="/tmp/cluster_watchdog.lock"
[ -r "$CONFIG" ] || { logger -t cluster_watchdog "missing $CONFIG"; exit 1; }
. "$CONFIG"
[ -r "${TELEGRAM_CONFIG:-/jffs/configs/router-tools.conf}" ] && . "${TELEGRAM_CONFIG:-/jffs/configs/router-tools.conf}"
: "${FAIL_THRESHOLD:=5}"
: "${RECOVERY_THRESHOLD:=2}"
: "${PING_TIMEOUT:=2}"
: "${TCP_TIMEOUT:=3}"
: "${SSH_PORT:=22}"
: "${CP_API_PORT:=6443}"
mkdir -p "$STATE_DIR"
mkdir "$LOCK" 2>/dev/null || exit 0
trap 'rmdir "$LOCK" 2>/dev/null' EXIT INT TERM
log(){ logger -t cluster_watchdog "$*"; }
notify(){
 T="${TOKEN:-$TELEGRAM_BOT_TOKEN}"; C="${CHAT_ID:-$TELEGRAM_CHAT_ID}"
 [ -n "$T" ] && [ -n "$C" ] || return 1
 curl -fsS --max-time 10 -X POST "https://api.telegram.org/bot$T/sendMessage"   --data-urlencode "chat_id=$C" --data-urlencode "text=$1" --data-urlencode "parse_mode=Markdown" >/dev/null 2>&1
}
ping_ok(){ ping -c 1 -W "$PING_TIMEOUT" "$1" >/dev/null 2>&1; }
tcp_ok(){ command -v nc >/dev/null 2>&1 && nc -z -w "$TCP_TIMEOUT" "$1" "$2" >/dev/null 2>&1; }
duration(){ s=$1; d=$((s/86400)); h=$(((s%86400)/3600)); m=$(((s%3600)/60)); [ "$d" -gt 0 ] && printf "%dd %dh %dm" "$d" "$h" "$m" || { [ "$h" -gt 0 ] && printf "%dh %dm" "$h" "$m" || printf "%dm" "$m"; }; }

rm -f /tmp/cw.result.* 2>/dev/null
OLDIFS="$IFS"; IFS='
'
for H in $HOSTS; do
 [ -z "$H" ] && continue
 KEY=$(echo "$H"|cut -d'|' -f1); NAME=$(echo "$H"|cut -d'|' -f2); IP=$(echo "$H"|cut -d'|' -f3); ROLE=$(echo "$H"|cut -d'|' -f4)
 SF="$STATE_DIR/$KEY.state"; STATUS=UP; FAILS=0; SUCCESSES=0; FIRST_FAILURE=0; DOWN_SINCE=0; LAST_SEEN=0
 [ -r "$SF" ] && . "$SF"
 NOW=$(date +%s); P=0; S=0; A=0
 ping_ok "$IP" && P=1
 tcp_ok "$IP" "$SSH_PORT" && S=1
 [ "$ROLE" = cp ] && tcp_ok "$IP" "$CP_API_PORT" && A=1
 ALIVE=0; [ "$P" -eq 1 ] && ALIVE=1; [ "$S" -eq 1 ] && ALIVE=1
 if [ "$ALIVE" -eq 1 ]; then
  LAST_SEEN=$NOW; FAILS=0
  if [ "$STATUS" = DOWN ]; then
   SUCCESSES=$((SUCCESSES+1))
   if [ "$SUCCESSES" -ge "$RECOVERY_THRESHOLD" ]; then
    notify "🟢 *$NAME RECOVERED*

IP: \`$IP\`
Offline for: *$(duration $((NOW-DOWN_SINCE)))*
Ping: $([ "$P" -eq 1 ]&&echo OK||echo failed)
SSH: $([ "$S" -eq 1 ]&&echo OK||echo failed)"
    STATUS=UP; SUCCESSES=0; FIRST_FAILURE=0; DOWN_SINCE=0
   fi
  else SUCCESSES=0; FIRST_FAILURE=0; fi
 else
  SUCCESSES=0; FAILS=$((FAILS+1)); [ "$FIRST_FAILURE" -eq 0 ] && FIRST_FAILURE=$NOW
  if [ "$STATUS" != DOWN ] && [ "$FAILS" -ge "$FAIL_THRESHOLD" ]; then STATUS=DOWN; DOWN_SINCE=$FIRST_FAILURE; fi
 fi
 { echo "STATUS=$STATUS"; echo "FAILS=$FAILS"; echo "SUCCESSES=$SUCCESSES"; echo "FIRST_FAILURE=$FIRST_FAILURE"; echo "DOWN_SINCE=$DOWN_SINCE"; echo "LAST_SEEN=$LAST_SEEN"; } > "$SF.tmp" && mv "$SF.tmp" "$SF"

 AF="$STATE_DIR/$KEY.api"; API_STATUS=OK; API_FAILS=0; API_SUCCESSES=0; [ -r "$AF" ] && . "$AF"
 if [ "$ROLE" = cp ] && [ "$ALIVE" -eq 1 ]; then
  if [ "$A" -eq 1 ]; then
   API_FAILS=0
   if [ "$API_STATUS" = DOWN ]; then API_SUCCESSES=$((API_SUCCESSES+1)); [ "$API_SUCCESSES" -ge "$RECOVERY_THRESHOLD" ] && { notify "🟢 *Kubernetes API RECOVERED*

$NAME (\`$IP\`) is reachable and TCP/$CP_API_PORT responds again."; API_STATUS=OK; API_SUCCESSES=0; }; fi
  else
   API_SUCCESSES=0; API_FAILS=$((API_FAILS+1))
   [ "$API_STATUS" != DOWN ] && [ "$API_FAILS" -ge "$FAIL_THRESHOLD" ] && { API_STATUS=DOWN; notify "🟠 *CONTROL PLANE ALIVE — K8S API DOWN*

$NAME: \`$IP\`
Host responds, but TCP/$CP_API_PORT failed $API_FAILS consecutive checks."; }
  fi
 fi
 { echo "API_STATUS=$API_STATUS"; echo "API_FAILS=$API_FAILS"; echo "API_SUCCESSES=$API_SUCCESSES"; } > "$AF"
 echo "$NAME|$IP|$STATUS|$FAILS" > "/tmp/cw.result.$KEY"
done
IFS="$OLDIFS"

TOTAL=0; DOWN=0; DETAILS=""; NEW=""
for F in /tmp/cw.result.*; do
 [ -f "$F" ] || continue; L=$(cat "$F"); N=$(echo "$L"|cut -d'|' -f1); I=$(echo "$L"|cut -d'|' -f2); ST=$(echo "$L"|cut -d'|' -f3); FA=$(echo "$L"|cut -d'|' -f4)
 TOTAL=$((TOTAL+1))
 if [ "$ST" = DOWN ]; then DOWN=$((DOWN+1)); DETAILS="$DETAILS
🔴 $N — \`$I\`"; [ "$FA" -eq "$FAIL_THRESHOLD" ] && NEW="$NEW$N|$I
"
 else DETAILS="$DETAILS
🟢 $N — \`$I\`"; fi
done
FLAG="$STATE_DIR/all-down.flag"
if [ "$TOTAL" -gt 0 ] && [ "$DOWN" -eq "$TOTAL" ]; then
 [ -f "$FLAG" ] || { notify "⚠️ *K3S CLUSTER UNREACHABLE*

All monitored hosts failed at least $FAIL_THRESHOLD consecutive checks.
$DETAILS

Possible shared power, switch, or LAN problem."; date +%s > "$FLAG"; }
else
 [ -f "$FLAG" ] && { rm -f "$FLAG"; notify "🟢 *K3S CLUSTER CONNECTIVITY RETURNING*

At least one monitored host is reachable again.
$DETAILS"; }
 IFS='
'; for D in $NEW; do [ -z "$D" ] && continue; N=$(echo "$D"|cut -d'|' -f1); I=$(echo "$D"|cut -d'|' -f2); notify "🔴 *$N DOWN*

IP: \`$I\`
No ping or SSH response for $FAIL_THRESHOLD consecutive one-minute checks."; done; IFS="$OLDIFS"
fi
log "check complete: total=$TOTAL down=$DOWN"
