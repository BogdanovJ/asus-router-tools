#!/bin/sh
set -e
[ "$(id -u)" = 0 ] || echo "Note: run with an account allowed to write /jffs."
mkdir -p /jffs/scripts /jffs/configs
cp scripts/common.sh /jffs/scripts/router-tools-common.sh
cp scripts/wg_watchdog.sh /jffs/scripts/wg_watchdog.sh
cp scripts/router_report.sh /jffs/scripts/router_report.sh
cp scripts/ddns-start /jffs/scripts/ddns-start
cp scripts/services-start /jffs/scripts/services-start
chmod 700 /jffs/scripts/router-tools-common.sh /jffs/scripts/wg_watchdog.sh /jffs/scripts/router_report.sh
chmod 755 /jffs/scripts/ddns-start
chmod 755 /jffs/scripts/services-start
if [ ! -f /jffs/configs/router-tools.conf ]; then cp config/router-tools.conf.example /jffs/configs/router-tools.conf; chmod 600 /jffs/configs/router-tools.conf; echo "Created /jffs/configs/router-tools.conf — EDIT IT before testing."; fi
if [ ! -f /jffs/configs/wg-peers.conf ]; then cp config/wg-peers.conf.example /jffs/configs/wg-peers.conf; chmod 600 /jffs/configs/wg-peers.conf; fi
if [ ! -f /jffs/configs/duckdns.conf ]; then cp config/duckdns.conf.example /jffs/configs/duckdns.conf; chmod 600 /jffs/configs/duckdns.conf; echo "Created /jffs/configs/duckdns.conf — EDIT IT for DuckDNS."; fi
echo "Installed. Edit config, then run: /jffs/scripts/router_report.sh"
echo "When tests pass, run: /jffs/scripts/services-start"
