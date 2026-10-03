#!/usr/bin/env bash
set -euo pipefail

# Build the X packages locally and publish them to the local repo.
# Run from the x-repo root. Packages are committed and served via GitHub Pages.
#
# Usage: ./build-packages.sh [--index-only]
#
#   (no flags)    rebuild every PKGBUILD package (x-release, x-dev), import the
#                 sibling x-scripts build when present, regenerate the database.
#   --index-only  skip the local builds and only import/regenerate the repo
#                 (use when an external artifact changed, e.g. x-scripts).
#
# Signing (optional, recommended): export X_REPO_SIGN_KEY=<gpg-keyid>. With it
# the packages are signed, repo-add runs with -s, SHA256SUMS is signed and the
# keyring (trustedkeys.gpg + signing.pub) is exported. Without it the repo is
# published unsigned and a warning is printed. See docs/en/signing.md.
#
# x-scripts lives in the sibling `scripts` repo (scripts/packaging/). When a
# fresh `../scripts/packaging/x-scripts-*.pkg.tar.zst` exists it is imported
# automatically and removed from the build directory.
#
# The native .xp endpoint (public/x) is out of scope here; see
# docs/build-x-native-workflow.md.

SELF="$(readlink -f "$0")"
cd "$(dirname "$SELF")"

REPO_DIR="public/repo/x86_64"
XPM_DIR="public/x/x86_64"
OUT_DIR="$(mktemp -d)"
trap 'rm -rf "$OUT_DIR"' EXIT

# Optional GPG key id for signing (see docs/en|es/signing.md).
SIGN_KEY="${X_REPO_SIGN_KEY:-}"

BUILD=1
for arg in "$@"; do
    case "$arg" in
        --index-only) BUILD=0 ;;
        -h|--help)
            sed -n '2,17p' "$SELF" | sed 's/^# \{0,1\}//'
            exit 0
            ;;
        *)
            echo "build-packages: unknown argument '$arg' (see --help)" >&2
            exit 1
            ;;
    esac
done

# Packages built with PKGBUILD (makepkg) -> pacman .pkg.tar.zst
build_pkgbuild() {
    local dir="$1"
    echo "  - building $dir"
    if [[ -n "$SIGN_KEY" ]]; then
        (cd "packages/$dir" && makepkg -cf --noconfirm --sign --key "$SIGN_KEY")
    else
        (cd "packages/$dir" && makepkg -cf --noconfirm)
    fi
}

# Packages built with XBUILD (xpkg) -> xpm .xp
build_xbuild() {
    local dir="$1"
    echo "  - building $dir"
    # xpkg build -f packages/$dir/XBUILD -o "$OUT_DIR"
}

# --- pacman-facing packages (committed to public/repo) ---
if [[ "$BUILD" == "1" ]]; then
    echo "== Building packages locally =="
    build_pkgbuild x-release
    build_pkgbuild x-dev
else
    echo "== Skipping local builds (--index-only) =="
fi

echo "== Importing externally built packages =="
# x-scripts is built in the sibling scripts repo; import the newest tarball.
for pkg in ../scripts/packaging/x-scripts-*.pkg.tar.zst; do
    [ -f "$pkg" ] || continue
    echo "  + $(basename "$pkg") (x-scripts from ../scripts/packaging)"
    cp -f "$pkg" "$REPO_DIR/"
    rm -f "$pkg"
done

echo "== Copying built packages to repo =="
# Only the freshly built outputs move into the repo. The committed leftovers
# under packages/xpm, packages/xpkg, packages/xfetch and packages/xtop are NOT
# touched; import those explicitly if you ever want them in [x].
if [[ "$BUILD" == "1" ]]; then
    for dir in x-release x-dev; do
        for pkg in packages/$dir/*.pkg.tar.zst; do
            [ -f "$pkg" ] || continue
            echo "  + $pkg"
            cp "$pkg" "$REPO_DIR/"
            rm -f "$pkg"
        done
    done
else
    echo "  (nothing to copy: --index-only)"
fi

echo "== Regenerating pacman database =="
# Full rebuild from the tarballs present in the directory: this also drops
# entries for packages that no longer exist (repo-add -n would keep them).
cd "$REPO_DIR"
rm -f x.db x.files x.db.tar.gz x.files.tar.gz x.db.tar.gz.old x.files.tar.gz.old
if [[ -n "$SIGN_KEY" ]]; then
    # Sign every package payload too (makepkg --sign only covers the locally
    # built ones; imported packages like x-scripts need this).
    echo "  signing package files with key $SIGN_KEY"
    for p in *.pkg.tar.zst; do
        rm -f "$p.sig"
        gpg --batch --yes --local-user "$SIGN_KEY" --detach-sign "$p"
    done
fi
REPO_ADD=(repo-add -R)
if [[ -n "$SIGN_KEY" ]]; then
    echo "  signing database with key $SIGN_KEY"
    REPO_ADD+=(-s -k "$SIGN_KEY")
else
    echo "  WARNING: X_REPO_SIGN_KEY unset; publishing an UNSIGNED repo (the ISO/target expect [x] signed with the project key)"
fi
"${REPO_ADD[@]}" x.db.tar.gz *.pkg.tar.zst
rm -f x.db x.files
cp x.db.tar.gz x.db
cp x.files.tar.gz x.files
# pacman fetches x.db / x.db.sig: mirror the repo-add signature to that name.
# x.db may be a symlink to x.db.tar.gz, in which case they are the same file.
if [[ -n "$SIGN_KEY" && -f x.db.tar.gz.sig ]]; then
    cp -f x.db.tar.gz.sig x.db.sig 2>/dev/null || true
fi
if [[ -n "$SIGN_KEY" && -f x.files.tar.gz.sig ]]; then
    cp -f x.files.tar.gz.sig x.files.sig 2>/dev/null || true
fi
# Hash the publishable artifacts. Never include SHA256SUMS itself (or its
# stale signature): a self-referencing checksum can never verify.
rm -f SHA256SUMS SHA256SUMS.sig
sha256sum $(find . -maxdepth 1 -type f ! -name 'SHA256SUMS*' -printf '%P\n' | sort) > SHA256SUMS
rm -f x.db.tar.gz.old x.files.tar.gz.old

if [[ -n "$SIGN_KEY" ]]; then
    rm -f SHA256SUMS.sig trustedkeys.gpg signing.pub
    gpg --batch --yes --local-user "$SIGN_KEY" --detach-sign SHA256SUMS
    gpg --batch --yes --export "$SIGN_KEY" > trustedkeys.gpg
    gpg --batch --yes --armor --export "$SIGN_KEY" > signing.pub
    echo "  exported keyring: trustedkeys.gpg + signing.pub (+ SHA256SUMS.sig)"
fi

echo "== Done =="
echo "Commit public/repo/x86_64/ and push, then run the deploy workflow."
