#!/bin/sh
set -e

[ "$(id -u)" = 0 ] || echo "Note: run with an account allowed to write /jffs."

mkdir -p /jffs/scripts /jffs/configs /jffs/router-tools/state

cp scripts/common.sh /jffs/scripts/router-tools-common.sh
cp scripts/wg_watchdog.sh /jffs/scripts/wg_watchdog.sh
cp scripts/router_report.sh /jffs/scripts/router_report.sh
cp scripts/cluster_watchdog.sh /jffs/scripts/cluster_watchdog.sh
cp scripts/ddns-start /jffs/scripts/ddns-start
cp scripts/services-start /jffs/scripts/services-start

chmod 700 \
  /jffs/scripts/router-tools-common.sh \
  /jffs/scripts/wg_watchdog.sh \
  /jffs/scripts/router_report.sh \
  /jffs/scripts/cluster_watchdog.sh
chmod 755 /jffs/scripts/ddns-start /jffs/scripts/services-start

if [ ! -f /jffs/configs/router-tools.conf ]; then
  cp config/router-tools.conf.example /jffs/configs/router-tools.conf
  chmod 600 /jffs/configs/router-tools.conf
  echo "Created /jffs/configs/router-tools.conf — EDIT IT before testing."
fi

if [ ! -f /jffs/configs/wg-peers.conf ]; then
  cp config/wg-peers.conf.example /jffs/configs/wg-peers.conf
  chmod 600 /jffs/configs/wg-peers.conf
fi

if [ ! -f /jffs/configs/cluster-watchdog.conf ]; then
  cp config/cluster-watchdog.conf.example /jffs/configs/cluster-watchdog.conf
  chmod 600 /jffs/configs/cluster-watchdog.conf
  echo "Created /jffs/configs/cluster-watchdog.conf — EDIT monitored hosts if required."
fi

if [ ! -f /jffs/configs/duckdns.conf ]; then
  cp config/duckdns.conf.example /jffs/configs/duckdns.conf
  chmod 600 /jffs/configs/duckdns.conf
  echo "Created /jffs/configs/duckdns.conf — EDIT IT for DuckDNS."
fi

echo "Installed. Existing local configuration was preserved."
echo "Test: /jffs/scripts/router_report.sh"
echo "Test: /jffs/scripts/wg_watchdog.sh"
echo "Test: /jffs/scripts/cluster_watchdog.sh"
echo "When tests pass, run: /jffs/scripts/services-start"
