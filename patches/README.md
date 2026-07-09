# patches/

Every iStoreOS-specific delta lives here as a `-p1` patch applied at **build
time** to a pristine copy of the package tree. The tracked source files
(`Makefile`, `root/`, `htdocs/`, `po/`) are **never modified in place**, so
`git rebase upstream/master` (or `upstream/dev`) stays conflict-free.

Patches are applied in lexical order by `.github/scripts/build.sh` before the
package is handed to the OpenWrt SDK.

## Policy

- Keep the number of patches, and each patch, as small as possible.
- Never patch in a "project-specific hack". If upstream has a better fix,
  drop the patch and rebase onto upstream instead.
- Never vendor OpenWrt packages or downgrade functionality.
- One concern per patch, with a `Subject:`/description header explaining *why*.

## Current patches

| File | Purpose |
| ---- | ------- |
| `0001-makefile-explicit-metadata.patch` | Declare explicit `PKG_VERSION` / `PKG_RELEASE` / `PKG_MAINTAINER` / `PKG_LICENSE` so a standalone SDK build produces a properly versioned `.ipk`. `luci.mk` otherwise derives the version from a surrounding LuCI git checkout, which does not exist in an out-of-tree build. No functional or dependency change. |

## Audit note (why there are so few patches)

HomeProxy is already fully compatible with the iStoreOS 24.10 base:

- Firewalling is 100% `firewall4` / `nftables` (nftables includes at
  `table-pre` / `table-post`); there is **no** `fw3` or iptables-legacy code.
- DNS hijacking uses dnsmasq `nftset=` (needs `dnsmasq-full`, the iStoreOS
  default) — no ipset, no dnsmasq forks.
- Service management is `procd`; RPC is `rpcd` (ucode backend); the LuCI UI is
  served by `uhttpd`.
- All hard dependencies (`sing-box`, `firewall4`, `kmod-nft-tproxy`) exist in
  the OpenWrt 24.10 x86_64 feeds that iStoreOS 24.10 tracks.

So no compatibility *code* change is required — only build metadata.
