# DuckDNS / `ddns-start`

`/jffs/scripts/ddns-start` is an Asuswrt-Merlin custom-DDNS hook for DuckDNS.
It is event-driven by the router firmware; it does **not** need a `cru` entry.

## Local files

Create `/jffs/configs/duckdns.conf`:

```sh
DUCKDNS_DOMAIN="your-subdomain"
DUCKDNS_TOKEN_FILE="/jffs/configs/duckdns.token"
```

Create the token file with only the DuckDNS token on its first line:

```sh
printf '%s\n' 'YOUR_DUCKDNS_TOKEN' > /jffs/configs/duckdns.token
chmod 600 /jffs/configs/duckdns.conf /jffs/configs/duckdns.token
```

The repository intentionally contains neither value.

## How it works

Merlin invokes `ddns-start` and normally passes the WAN IPv4 address as `$1`.
The hook calls the DuckDNS HTTPS update endpoint using BusyBox `wget`. If no
address is supplied, the `ip` parameter is empty and DuckDNS can use the public
source address.

On success the hook calls:

```sh
/sbin/ddns_custom_updated 1
```

On failure it calls `ddns_custom_updated 0`, logs the reason under the
`ddns-duckdns` syslog tag, and exits non-zero.

## Diagnostics

```sh
grep ddns-duckdns /tmp/syslog.log | tail -20
ls -l /jffs/scripts/ddns-start /jffs/configs/duckdns.*
```

A manual invocation is possible for diagnostics, but remember it also reports
completion to Merlin's DDNS subsystem:

```sh
/jffs/scripts/ddns-start "$(nvram get wan0_ipaddr)"
```

For PPPoE or other setups where that NVRAM value is not the actual public
address, allow Merlin to invoke the hook normally rather than relying on this
manual example.
