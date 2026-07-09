# INSTALL.md — installing on iStoreOS 24.10.x (x86_64)

## Prerequisites

iStoreOS 24.10 already ships `firewall4`, `nftables`, `dnsmasq-full`, `procd`,
`rpcd` and `uhttpd`, so the only extra runtime dependency you must install is
`sing-box`.

```sh
opkg update
opkg install sing-box kmod-nft-tproxy
```

> `dnsmasq-full` is the iStoreOS default and is required for HomeProxy's
> DNS-based routing modes. Verify with `opkg list-installed | grep dnsmasq`.
> If you somehow have plain `dnsmasq`, swap it:
> `opkg install dnsmasq-full --force-overwrite` (this removes `dnsmasq`).

## Install

Get a prebuilt `.ipk` from the [Releases page](../../releases) — either the
rolling **Continuous build** (newest, rebuilt every commit) or a **`vX.Y.Z`**
tagged release. Then copy it to the router and install it:

```sh
scp luci-app-homeproxy_*_all.ipk root@192.168.100.1:/tmp/
ssh root@192.168.100.1 'opkg install /tmp/luci-app-homeproxy_*_all.ipk'
```

If `opkg` complains about the `sing-box` / `firewall4` / `kmod-nft-tproxy`
dependencies, install them first (see Prerequisites), then re-run.

## Access the UI

Open the LuCI web UI and go to **Services → HomeProxy**.

If the menu entry does not appear immediately, clear the LuCI cache:

```sh
rm -f /tmp/luci-indexcache /tmp/luci-modulecache/*
/etc/init.d/uhttpd restart
```

Then reload the browser. The menu is registered via
`/usr/share/luci/menu.d/luci-app-homeproxy.json` and its ACLs via
`/usr/share/rpcd/acl.d/luci-app-homeproxy.json`; the post-install script clears
the caches automatically, but a manual clear + hard refresh resolves any
stale-cache case.

## Service control

```sh
/etc/init.d/homeproxy enable
/etc/init.d/homeproxy start
/etc/init.d/homeproxy status
```

Runtime logs: `/var/run/homeproxy/homeproxy.log`.

## Upgrade

```sh
opkg install /tmp/luci-app-homeproxy_<newer>_all.ipk   # opkg replaces in place
```

Your configuration is preserved: `/etc/config/homeproxy` is a conffile, and
downloaded resources (certs, rulesets, geo databases, subscription lists) are
kept across upgrades.

## Uninstall

```sh
/etc/init.d/homeproxy stop
opkg remove luci-app-homeproxy
```

This tears down the nftables chains/sets, the policy-routing rules and the
dnsmasq drop-ins created by the service. To also wipe configuration and
downloaded data:

```sh
rm -rf /etc/config/homeproxy /etc/homeproxy
```

## Troubleshooting

| Symptom | Check |
| ------- | ----- |
| Service won't start | `logread -e homeproxy` and `/var/run/homeproxy/homeproxy.log`; confirm a node is configured and `sing-box check` passes. |
| No proxying, DNS leaks | Confirm `dnsmasq-full` is installed (needed for `nftset=`). |
| tproxy mode not working | Confirm `kmod-nft-tproxy` is installed and loaded (`lsmod | grep tproxy`). |
| Menu missing | Clear LuCI cache (see above) and hard-refresh the browser. |

## Known limitations

- x86_64 only; `sing-box` is a separate package (not vendored).
- Targets the OpenWrt 24.10 series (iStoreOS 24.10.x).
