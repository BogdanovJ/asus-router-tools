#!/bin/sh

cru d wg_watchdog 2>/dev/null
cru d router_report 2>/dev/null
cru d cluster_watchdog 2>/dev/null

rm -f \
  /jffs/scripts/wg_watchdog.sh \
  /jffs/scripts/router_report.sh \
  /jffs/scripts/cluster_watchdog.sh \
  /jffs/scripts/ddns-start \
  /jffs/scripts/router-tools-common.sh \
  /jffs/scripts/services-start

rm -f /jffs/wg_watchdog.state /jffs/wg_watchdog.off
rm -rf /jffs/router-tools/state/cluster-watchdog

echo "Scripts/jobs removed. Config files under /jffs/configs were deliberately retained."
