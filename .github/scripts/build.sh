#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-only
#
# Build luci-app-homeproxy (iStoreOS edition) against the official OpenWrt SDK.
#
# It downloads the pinned OpenWrt SDK, drops this package into it *unmodified*,
# applies every patch under patches/, and produces a versioned .ipk. No files
# in the source tree are edited in place, so the tree stays rebaseable onto
# upstream.
#
# Overridable via environment:
#   OPENWRT_VERSION   OpenWrt release to build against   (default 24.10.2)
#   TARGET            SDK target                          (default x86)
#   SUBTARGET         SDK subtarget                       (default 64)
#   HP_PKG_VERSION    override PKG_VERSION (e.g. from a git tag)   (optional)
#   OUTPUT_DIR        where the .ipk is copied            (default ./artifacts)
set -euo pipefail

OPENWRT_VERSION="${OPENWRT_VERSION:-24.10.2}"
TARGET="${TARGET:-x86}"
SUBTARGET="${SUBTARGET:-64}"
PKG_NAME="luci-app-homeproxy"

REPO_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
OUTPUT_DIR="${OUTPUT_DIR:-$REPO_DIR/artifacts}"
WORK_DIR="${WORK_DIR:-$REPO_DIR/.build}"

log() { printf '\033[1;32m==>\033[0m %s\n' "$*"; }

# --- 1. Resolve the exact SDK file name from the release checksums --------------
BASE_URL="https://downloads.openwrt.org/releases/${OPENWRT_VERSION}/targets/${TARGET}/${SUBTARGET}"
log "Resolving SDK for OpenWrt ${OPENWRT_VERSION} (${TARGET}/${SUBTARGET})"
SDK_FILE="$(curl -fsSL "${BASE_URL}/sha256sums" | awk '/openwrt-sdk-.*\.tar\.(zst|xz)$/ {sub(/^\*/,"",$2); print $2}' | head -n1)"
[ -n "${SDK_FILE}" ] || { echo "ERROR: could not find SDK in ${BASE_URL}/sha256sums" >&2; exit 1; }
log "SDK: ${SDK_FILE}"

# --- 2. Download + verify + extract -------------------------------------------
mkdir -p "${WORK_DIR}"
cd "${WORK_DIR}"
if [ ! -f "${SDK_FILE}" ]; then
	curl -fSL -o "${SDK_FILE}" "${BASE_URL}/${SDK_FILE}"
fi
curl -fsSL "${BASE_URL}/sha256sums" | grep -F "${SDK_FILE}" | sha256sum -c -

SDK_DIR="${WORK_DIR}/sdk"
rm -rf "${SDK_DIR}"
mkdir -p "${SDK_DIR}"
case "${SDK_FILE}" in
	*.tar.zst) tar -I zstd -xf "${SDK_FILE}" -C "${SDK_DIR}" --strip-components=1 ;;
	*.tar.xz)  tar -xJf         "${SDK_FILE}" -C "${SDK_DIR}" --strip-components=1 ;;
esac

# --- 3. Feeds (provides luci-base host tools + the sing-box dependency) --------
cd "${SDK_DIR}"
cat > feeds.conf <<-EOF
	src-git base https://git.openwrt.org/openwrt/openwrt.git;openwrt-24.10
	src-git packages https://git.openwrt.org/feed/packages.git;openwrt-24.10
	src-git luci https://git.openwrt.org/project/luci.git;openwrt-24.10
	src-git routing https://git.openwrt.org/feed/routing.git;openwrt-24.10
EOF
log "Updating feeds"
./scripts/feeds update -a >/dev/null
./scripts/feeds install -a >/dev/null

# --- 4. Drop this package in (pristine) and apply our patches -----------------
DEST="${SDK_DIR}/package/${PKG_NAME}"
rm -rf "${DEST}"
mkdir -p "${DEST}"
# Copy tracked sources only; never the build/output/git dirs.
for item in Makefile htdocs root po LICENSE; do
	[ -e "${REPO_DIR}/${item}" ] && cp -a "${REPO_DIR}/${item}" "${DEST}/"
done

# The upstream luci feed ships its own luci-app-homeproxy; drop it so ours is
# the only package with this name (a duplicate would break `make defconfig`).
rm -f "${SDK_DIR}/package/feeds/luci/${PKG_NAME}"

log "Applying patches"
shopt -s nullglob
for p in "${REPO_DIR}"/patches/*.patch; do
	log "  $(basename "$p")"
	patch -p1 -d "${DEST}" < "$p"
done
shopt -u nullglob

# Optional version override (e.g. from a git tag). Keeps the patch generic.
if [ -n "${HP_PKG_VERSION:-}" ]; then
	log "Overriding PKG_VERSION -> ${HP_PKG_VERSION}"
	sed -i "s/^PKG_VERSION:=.*/PKG_VERSION:=${HP_PKG_VERSION}/" "${DEST}/Makefile"
fi

# --- 5. Build -----------------------------------------------------------------
log "Configuring"
make defconfig >/dev/null
echo "CONFIG_PACKAGE_${PKG_NAME}=y" >> .config
make defconfig >/dev/null

log "Compiling ${PKG_NAME}"
make "package/${PKG_NAME}/compile" -j"$(nproc)" V=s

# --- 6. Collect ---------------------------------------------------------------
mkdir -p "${OUTPUT_DIR}"
found=0
while IFS= read -r ipk; do
	cp -v "${ipk}" "${OUTPUT_DIR}/"
	found=1
done < <(find "${SDK_DIR}/bin" -name "${PKG_NAME}_*.ipk")
[ "${found}" -eq 1 ] || { echo "ERROR: no .ipk produced" >&2; exit 1; }

log "Done. Artifacts in ${OUTPUT_DIR}:"
ls -l "${OUTPUT_DIR}"/*.ipk
