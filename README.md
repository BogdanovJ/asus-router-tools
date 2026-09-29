# ASUS Router Utility Scripts

Small BusyBox `/bin/sh` utilities for ASUSWRT/ASUSWRT-Merlin routers: a WireGuard watchdog, external k3s cluster watchdog, daily Telegram health report, and DuckDNS custom-DDNS hook.

The repository contains **no credentials**. Telegram secrets are stored locally on the router under `/jffs/configs/`.

## Features

- Checks the ASUS WireGuard server every 5 minutes.
- Re-enables WireGuard if the firmware reports it disabled.
- Restarts the server when the interface/listening port disappears.
- Verifies recovery and sends a Telegram alert.
- Optional 24-hour no-client-handshake warning with cooldowns.
- Maintenance off-switch to suppress automatic recovery.
- Daily Telegram report at **06:27**.
- Report includes uptime, CPU temperature, RAM use, WAN traffic since boot, WireGuard peer activity and transfer counters.
- Friendly WireGuard names are mapped by VPN IP rather than public key.
- External k3s host watchdog with glitch tolerance, DOWN/recovery confirmation, and a separate control-plane API check.
- Correlates a complete cluster outage into a single Telegram alert instead of alerting for every host independently.
- `services-start` recreates `cru` jobs after every reboot.
- DuckDNS `ddns-start` hook with credentials kept outside Git.
- Designed for BusyBox shell; no Python or Entware required.

## Tested setup

Originally migrated/tested on an ASUS RT-AX88U Pro using the built-in WireGuard server as `wgs1`, with PPPoE WAN exposed as `ppp0`. The scripts detect the WAN gateway interface through NVRAM, so they are not hard-coded to PPPoE.

Firmware implementations differ. Review NVRAM variable names and `service restart_wgs` before using this on another ASUS family/firmware.

## Repository layout

```text
.
├── README.md
├── LICENSE
├── .gitignore
├── install.sh
├── uninstall.sh
├── config/
│   ├── router-tools.conf.example
│   ├── wg-peers.conf.example
│   ├── cluster-watchdog.conf.example
│   └── duckdns.conf.example
├── docs/
│   ├── OPERATIONS.md
│   ├── SECURITY.md
│   └── DDNS.md
└── scripts/
    ├── common.sh
    ├── ddns-start
    ├── router_report.sh
    ├── cluster_watchdog.sh
    ├── services-start
    └── wg_watchdog.sh
```

## Requirements

Router-side commands used: `cru`, `nvram`, `service`, `wg`, `ip`, `netstat`, `ping`, `nc`, `curl`, `awk`, `grep`, `sed`, `logger`, and standard BusyBox utilities. JFFS custom scripts must be enabled if your firmware requires that setting.

## Installation

Copy/clone the repository onto the router or copy these files to a temporary directory, then:

```sh
chmod +x install.sh
./install.sh
```

The installer copies executable files to `/jffs/scripts/`, creates example local configuration only when missing, and **does not activate cron jobs automatically**. This gives you a chance to test first.

Edit:

```sh
vi /jffs/configs/router-tools.conf
vi /jffs/configs/wg-peers.conf
vi /jffs/configs/cluster-watchdog.conf
```

Set your Telegram bot token and chat ID in the first file. For DuckDNS, edit `/jffs/configs/duckdns.conf` and create `/jffs/configs/duckdns.token` containing only the token. See `docs/DDNS.md`. The peer file uses:

```text
10.6.0.2|Jay
10.6.0.3|VSG Phone
```

## Test before scheduling

Check WireGuard:

```sh
wg show
ip link show wgs1
```

Send one report manually:

```sh
/jffs/scripts/router_report.sh
```

Run the WireGuard watchdog manually:

```sh
/jffs/scripts/wg_watchdog.sh
echo $?
```

Run the cluster watchdog manually:

```sh
/jffs/scripts/cluster_watchdog.sh
echo $?
```

Once the tests are satisfactory, install the schedules without rebooting:

```sh
/jffs/scripts/services-start
cru l
```

Default schedule:

```text
WireGuard watchdog  every 5 minutes
Router report       06:27 every day
Cluster watchdog    every minute
```

## Maintenance mode

Prevent the watchdog from restarting WireGuard while intentionally working on it:

```sh
touch /jffs/wg_watchdog.off
```

Re-enable monitoring:

```sh
rm -f /jffs/wg_watchdog.off
```

## Configuration

`router-tools.conf` supports:

```sh
TELEGRAM_BOT_TOKEN="..."
TELEGRAM_CHAT_ID="..."
WG_INTERFACE="wgs1"
WG_FALLBACK_PORT="443"
NO_CLIENT_THRESHOLD="86400"
ALERT_COOLDOWN="900"
NO_CLIENT_COOLDOWN="86400"
```

`cluster-watchdog.conf` contains the monitored hosts and thresholds. By default it requires five consecutive failed one-minute checks before declaring a host DOWN, and two consecutive successful checks before announcing recovery. A host counts as reachable if ping or TCP/22 succeeds; the control plane also gets an independent TCP/6443 check.

The WireGuard port is normally read from `nvram get wgs1_port`; `443` is only a fallback.

## How persistence works

`ddns-start` is a firmware hook and is not scheduled by cron. ASUS routers do not preserve normal cron entries across reboot, so for the scheduled utilities `/jffs/scripts/services-start` is invoked by supported firmware at service startup and recreates the three named `cru` jobs. It first deletes each named job, making repeated execution idempotent.

## Uninstall

```sh
./uninstall.sh
```

This removes the cron jobs and executable scripts but intentionally leaves `/jffs/configs/router-tools.conf` and `wg-peers.conf` in place so credentials/configuration are not destroyed accidentally.

## Important notes

WAN byte counters and WireGuard transfer counters are **since boot/interface creation**, not a historical 24-hour database. The report's handshake age is a point-in-time snapshot. If you need true daily deltas/history, store counters periodically or export them to a monitoring system.

See `docs/OPERATIONS.md` for diagnostics and `docs/SECURITY.md` before publishing a fork.
