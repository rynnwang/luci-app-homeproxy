# luci-app-homeproxy — iStoreOS edition

A minimal, rebase-friendly packaging of
[douglarek/luci-app-homeproxy](https://github.com/douglarek/luci-app-homeproxy)
(itself based on [immortalwrt/homeproxy](https://github.com/immortalwrt/homeproxy))
for **iStoreOS 24.10.x** on **x86_64**.

HomeProxy is a [sing-box](https://github.com/SagerNet/sing-box) client for
OpenWrt. It supports Socks5, HTTP(S), Shadowsocks, VMess, Trojan, WireGuard,
Hysteria(2), VLESS, ShadowTLS, TUIC and more, with rule-based routing.

## What this fork changes

Almost nothing — and that is the point.

- The upstream application source (`Makefile`, `root/`, `htdocs/`, `po/`) is
  kept **byte-for-byte identical** to upstream so the fork rebases cleanly.
- Every iStoreOS-specific delta lives as a `-p1` patch under
  [`patches/`](patches/) and is applied only at build time.
- A reproducible build against the **official OpenWrt 24.10 SDK** replaces the
  previous hand-rolled `ipkg-build` script.
- CI publishes a versioned `*.ipk` artifact and attaches it to releases.

There are **no new features, no UI changes, and no functionality downgrades.**

## Download

Grab a prebuilt `.ipk` from the [Releases page](../../releases):

- **Continuous** — a rolling pre-release rebuilt on **every commit** to
  `dev`/`master`. Always the newest build; the file name carries the version
  (e.g. `luci-app-homeproxy_1.0.0~git<date>.<sha>-r1_all.ipk`).
- **`vX.Y.Z`** — pinned, stable tagged releases.

Then follow [INSTALL.md](INSTALL.md).

## Why so few changes were needed

iStoreOS 24.10 tracks the OpenWrt 24.10 ABI, and HomeProxy is already built for
exactly that base:

| Component | HomeProxy uses | iStoreOS 24.10 |
| --------- | -------------- | -------------- |
| Firewall  | `firewall4` + `nftables` (nft includes at `table-pre`/`table-post`) | default |
| DNS split | dnsmasq `nftset=` (needs `dnsmasq-full`) | `dnsmasq-full` is default |
| Service   | `procd` | default |
| RPC       | `rpcd` (ucode backend) | default |
| Web UI    | `uhttpd` | default |

There is **no `fw3` and no iptables-legacy** code anywhere in the tree, so
nothing had to be removed. All hard dependencies — `sing-box`, `firewall4`,
`kmod-nft-tproxy` — exist in the OpenWrt 24.10 x86_64 feeds. `chinadns-ng` is an
optional runtime enhancement (auto-detected), not a build dependency.

The only patch is build metadata (`PKG_VERSION`/`PKG_RELEASE`). See
[`patches/README.md`](patches/README.md).

## Documentation

- [BUILD.md](BUILD.md) — how to build the `.ipk` (CI or locally)
- [INSTALL.md](INSTALL.md) — how to install and remove on iStoreOS
- [Upstream Wiki](https://github.com/douglarek/luci-app-homeproxy/wiki) — usage / configuration

## Known limitations

- **x86_64 only.** The package itself is architecture-independent
  (`PKGARCH=all`); the arch-specific bit is the separate `sing-box` binary. Only
  the x86_64 build is verified here. Other targets need a matching SDK.
- **`sing-box` must be installed separately** from the feed (`opkg install
  sing-box`). It is a dependency, not vendored.
- **`dnsmasq-full` is required** for the DNS-based routing modes. It ships by
  default on iStoreOS; on stock OpenWrt you must swap `dnsmasq` → `dnsmasq-full`
  first.
- Tracks the OpenWrt 24.10 series only (security-supported until Sept 2026).

## License

GPL-2.0-only, inherited from upstream. See [LICENSE](LICENSE).
