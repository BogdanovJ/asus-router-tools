# Operations & Troubleshooting

## Verify WireGuard
```sh
nvram get wgs_enable
nvram get wgs1_enable
nvram get wgs1_port
ip link show wgs1
wg show
```

## Verify schedules
```sh
cru l
```
Expected defaults:
```text
*/5 * * * * /jffs/scripts/wg_watchdog.sh #wg_watchdog#
27 6 * * * /jffs/scripts/router_report.sh #router_report#
```

## Test the report
```sh
/jffs/scripts/router_report.sh
```

## Watchdog logs
ASUS firmware log locations vary. Try:
```sh
logread | grep wg_watchdog
# or
grep wg_watchdog /tmp/syslog.log | tail -50
```

## Maintenance mode
Pause automatic WireGuard recovery:
```sh
touch /jffs/wg_watchdog.off
```
Resume:
```sh
rm -f /jffs/wg_watchdog.off
```

## Reboot persistence test
After a normal router reboot:
```sh
cru l
wg show
```
Both cron jobs should have been recreated by `/jffs/scripts/services-start`.

## WAN interface
The report prefers `nvram get wan0_gw_ifname`, which correctly resolves PPPoE interfaces such as `ppp0`, then falls back to `wan0_ifname`.

## Telegram failure
Check DNS, Internet connectivity, bot token/chat ID, and run the report manually. Credentials must exist only in `/jffs/configs/router-tools.conf`.
