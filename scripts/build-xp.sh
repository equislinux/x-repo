#!/usr/bin/env bash
# build-xp.sh — builds the native .xp endpoint (public/x/x86_64) with xpkg.
#
# Sources:
#   - xpm, xpkg  -> sibling repos' packaging/xpkg/XBUILD
#   - x-release, x-dev, opencode-bin, xfetch-bin, xtop-git (packages/*/PKGBUILD)
#   - x-scripts  -> ../scripts/packaging/PKGBUILD
#
# Signs with the project key (../keys/env.sh) using gpg detached signatures and
# regenerates x.db / x.files (ALPM format read by xpm) plus SHA256SUMS.
# The pacman [x] repository (build-packages.sh) is untouched: this endpoint is
# a parallel channel consumed by xpm.
#
# Usage: scripts/build-xp.sh [--no-sign]
# Env:   XPKG_BIN  xpkg binary (default: xpkg in PATH, else ../xpkg/target/release/xpkg)

set -euo pipefail

SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SELF_DIR/.." && pwd)"
WS="$(cd "$REPO_DIR/.." && pwd)"
XP_DIR="$REPO_DIR/public/x/x86_64"

SIGN=1
for arg in "$@"; do
    case "$arg" in
        --no-sign) SIGN=0 ;;
        -h|--help) sed -n '2,17p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
        *) echo "build-xp: unknown option '$arg'" >&2; exit 1 ;;
    esac
done

XPKG_BIN="${XPKG_BIN:-}"
if [[ -z "$XPKG_BIN" ]]; then
    if command -v xpkg >/dev/null 2>&1; then
        XPKG_BIN="$(command -v xpkg)"
    elif [[ -x "$WS/xpkg/target/release/xpkg" ]]; then
        XPKG_BIN="$WS/xpkg/target/release/xpkg"
    else
        echo "build-xp: xpkg not found (set XPKG_BIN or build ../xpkg)" >&2
        exit 1
    fi
fi

if [[ "$SIGN" -eq 1 ]]; then
    # shellcheck disable=SC1091
    [[ -f "$WS/keys/env.sh" ]] && source "$WS/keys/env.sh"
    [[ -n "${X_REPO_SIGN_KEY:-}" ]] || { echo "build-xp: X_REPO_SIGN_KEY unset (or use --no-sign)" >&2; exit 1; }
fi

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

build_xbuild() {
    echo "  - $1 (XBUILD)"
    "$XPKG_BIN" build -f "$1" -o "$WORK"
}

build_pkgbuild() {
    echo "  - $1 (PKGBUILD)"
    "$XPKG_BIN" build --pkgbuild -f "$1" -o "$WORK"
}

echo "== Building native .xp packages =="
build_xbuild "$WS/xpm/packaging/xpkg/XBUILD"
build_xbuild "$WS/xpkg/packaging/xpkg/XBUILD"
for d in x-release x-dev opencode-bin xfetch xtop; do
    if [[ -f "$REPO_DIR/packages/$d/XBUILD" ]]; then
        build_xbuild "$REPO_DIR/packages/$d/XBUILD"
    else
        build_pkgbuild "$REPO_DIR/packages/$d/PKGBUILD"
    fi
done
build_pkgbuild "$WS/scripts/packaging/PKGBUILD"

shopt -s nullglob
pkgs=("$WORK"/*.xp)
shopt -u nullglob
[[ "${#pkgs[@]}" -gt 0 ]] || { echo "build-xp: no .xp packages were produced" >&2; exit 1; }

echo "== Assembling $XP_DIR =="
rm -rf "$XP_DIR"
mkdir -p "$XP_DIR"
for p in "${pkgs[@]}"; do
    cp "$p" "$XP_DIR/"
done

(
    cd "$XP_DIR"
    for p in *.xp; do
        "$XPKG_BIN" repo-add x.db.tar.gz "$p" >/dev/null
    done
    rm -f x.db x.files
    cp x.db.tar.gz x.db
    cp x.files.tar.gz x.files
)

if [[ "$SIGN" -eq 1 ]]; then
    echo "== Signing with $X_REPO_SIGN_KEY =="
    (
        cd "$XP_DIR"
        for f in *.xp x.db.tar.gz x.files.tar.gz history.json; do
            [[ -f "$f" ]] || continue
            rm -f "$f.sig"
            gpg --batch --yes --local-user "$X_REPO_SIGN_KEY" --detach-sign "$f"
        done
        [[ -f x.db.tar.gz.sig ]] && cp -f x.db.tar.gz.sig x.db.sig
        [[ -f x.files.tar.gz.sig ]] && cp -f x.files.tar.gz.sig x.files.sig
        gpg --batch --yes --export --armor "$X_REPO_SIGN_KEY" > signing.pub
        gpg --batch --yes --export "$X_REPO_SIGN_KEY" > trustedkeys.gpg
        sha256sum $(find . -maxdepth 1 -type f ! -name 'SHA256SUMS*' -printf '%P\n' | sort) > SHA256SUMS
        gpg --batch --yes --local-user "$X_REPO_SIGN_KEY" --detach-sign SHA256SUMS
    )
fi

echo "== Native endpoint ready =="
ls -lah "$XP_DIR"
echo
echo "Commit public/x/x86_64/ and push, then run the web deploy workflow."
