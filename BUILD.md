# BUILD.md — building the `.ipk`

The build never edits the source tree. It copies the pristine package into the
official OpenWrt SDK, applies `patches/*.patch`, and compiles. This keeps the
fork trivially rebaseable onto upstream.

## Option A — GitHub Actions (recommended)

The workflow [`.github/workflows/build.yml`](.github/workflows/build.yml) builds
against OpenWrt **24.10.2 / x86_64** and produces a versioned `.ipk`.

It runs automatically on:

- pushes to `master`/`dev` and PRs that touch the package or build files
  (produces a downloadable **run artifact**),
- **version tags** `v*` and published GitHub Releases (builds and **attaches
  the `.ipk` to a GitHub Release**, creating the release if the tag has none),
- manual **workflow_dispatch** (optionally choose the OpenWrt version).

Download the artifact from the run's **Summary → Artifacts**, or from the
release page.

### Cutting a release

A release is **not** created on merge — only a run artifact is. To publish a
release, push a version tag:

```sh
git tag v1.0.0
git push origin v1.0.0
```

CI then derives `PKG_VERSION` from the tag (`v` stripped), builds, creates the
`v1.0.0` release if it does not exist, and attaches
`luci-app-homeproxy_1.0.0-r1_all.ipk` to it. (Publishing a release manually from
the GitHub UI works too — the same job runs on the `release: published` event.)

## Option B — build locally

Requirements: a Linux host (or WSL2/container) with the OpenWrt SDK build
dependencies:

```sh
sudo apt-get install -y --no-install-recommends \
  build-essential clang flex bison g++ gawk gcc-multilib g++-multilib \
  gettext git libncurses-dev libssl-dev python3-setuptools rsync swig \
  unzip zlib1g-dev file wget zstd
```

From the repository root:

```sh
bash .github/scripts/build.sh
```

The resulting package lands in `./artifacts/luci-app-homeproxy_*_all.ipk`.

### Tunables (environment variables)

| Variable          | Default             | Meaning                                   |
| ----------------- | ------------------- | ----------------------------------------- |
| `OPENWRT_VERSION` | `24.10.2`           | OpenWrt release / SDK to build against    |
| `TARGET`          | `x86`               | SDK target                                |
| `SUBTARGET`       | `64`                | SDK subtarget                             |
| `HP_PKG_VERSION`  | *(unset)*           | Override `PKG_VERSION` (e.g. a tag)        |
| `OUTPUT_DIR`      | `./artifacts`       | Where the `.ipk` is copied                |

Example — build against a different point release:

```sh
OPENWRT_VERSION=24.10.1 bash .github/scripts/build.sh
```

## What the build script does

1. Resolves and downloads the exact SDK from `downloads.openwrt.org`, verifying
   the SHA-256 from the release `sha256sums`.
2. Configures feeds pinned to the `openwrt-24.10` branches (base, packages,
   luci, routing) and installs them — this provides the `po2lmo` host tool and
   makes the `sing-box` dependency resolvable.
3. Copies the pristine package into `package/luci-app-homeproxy` and removes the
   luci feed's own `luci-app-homeproxy` so there is no duplicate.
4. Applies every `patches/*.patch` (in order) to the copy only.
5. Optionally overrides `PKG_VERSION` from `HP_PKG_VERSION`.
6. Runs `make package/luci-app-homeproxy/compile` and collects the `.ipk`.

## Package metadata (verified)

| Field         | Value                          | Source                                    |
| ------------- | ------------------------------ | ----------------------------------------- |
| `PKG_VERSION` | `1.0.0` (or the release tag)   | `patches/0001-makefile-explicit-metadata.patch` |
| `PKG_RELEASE` | `1`                            | same patch                                |
| `PKGARCH`     | `all` (`LUCI_PKGARCH:=all`)    | upstream Makefile — correct for a LuCI app |
| Depends       | `sing-box`, `firewall4`, `kmod-nft-tproxy` | upstream `LUCI_DEPENDS`         |

> `PKGARCH` is intentionally `all`: this is a LuCI app (JS + ucode + shell) and
> is architecture-independent. The architecture-specific component is the
> separate `sing-box` binary.
