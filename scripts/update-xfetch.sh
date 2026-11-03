#!/usr/bin/env bash
# Refresh packages/xfetch to the latest GitHub release.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PKG="$ROOT/packages/xfetch"
URL="https://github.com/xfetch-cli/xfetch"
cd "$PKG"

tag="$(curl -fsSL "https://api.github.com/repos/xfetch-cli/xfetch/releases/latest" \
    | python3 -c 'import json,sys; print(json.load(sys.stdin)["tag_name"])')"
version="${tag#v}"
asset="xfetch-${version}-x86_64-unknown-linux-gnu.tar.gz"
sums="$(curl -fsSL "$URL/releases/download/$tag/SHA256SUMS")"
sha="$(printf '%s\n' "$sums" | awk -v asset="$asset" '$2 == asset {print $1; exit}')"
[[ -n "$sha" ]] || { echo "update-xfetch: checksum for $asset not found" >&2; exit 1; }

curl -fsSLo "$asset" "$URL/releases/download/$tag/$asset"
printf '%s  %s\n' "$sha" "$asset" | sha256sum -c -
sed -i "s/^pkgver=.*/pkgver=$version/" PKGBUILD
sed -i "s/^sha256sums=.*/sha256sums=('$sha')/" PKGBUILD
find . -maxdepth 1 -name 'xfetch-*-x86_64-unknown-linux-gnu.tar.gz' ! -name "$asset" -delete
echo "update-xfetch: $version ($sha)"
