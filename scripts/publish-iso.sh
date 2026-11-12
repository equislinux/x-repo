#!/usr/bin/env bash
# publish-iso.sh — publish a built live ISO to SourceForge and update the web
#
# Steps:
#   1. resolve the ISO (newest x/out/x-*.iso by default) and its version
#   2. SHA-256 + gpg detached signature (project key from ../../keys/env.sh)
#   3. render the release README from scripts/iso-README.template.md
#   4. upload to SourceForge FRS and delete previous x-*.iso versions
#   5. update ../web/data/releases.json (the site redeploys on push)
#
# The stable download URL is https://equislinux.github.io/web/download/latest/,
# which always redirects to releases[0].iso.url — no link edits per release.
#
# Usage:
#   scripts/publish-iso.sh [--iso PATH] [--web-dir DIR] [--dry-run]
#                          [--no-upload] [--verify]
#
# Env:
#   X_REPO_SIGN_KEY / GNUPGHOME   project signing material (keys/env.sh)
#   SF_USER      SourceForge account             (default: xscriptor)
#   SF_KEY       SSH key for frs.sourceforge.net (default: ~/.ssh/id_ed25519_sourceforge)
#   SF_PATH      remote FRS directory            (default: /home/frs/project/equislinux/iso)
set -euo pipefail

SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SELF_DIR/.." && pwd)"
WORKSPACE="$(cd "$REPO_DIR/.." && pwd)"

ISO=""
WEB_DIR="$WORKSPACE/web"
DRY_RUN=0
UPLOAD=1
VERIFY=0
SF_USER="${SF_USER:-xscriptor}"
SF_KEY="${SF_KEY:-$HOME/.ssh/id_ed25519_sourceforge}"
SF_PATH="${SF_PATH:-/home/frs/project/equislinux/iso}"

usage() {
    sed -n '2,25p' "$0" | sed 's/^# \{0,1\}//'
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --iso) ISO="$2"; shift 2 ;;
        --web-dir) WEB_DIR="$2"; shift 2 ;;
        --dry-run) DRY_RUN=1; shift ;;
        --no-upload) UPLOAD=0; shift ;;
        --verify) VERIFY=1; shift ;;
        -h|--help) usage; exit 0 ;;
        *) echo "publish-iso: unknown option '$1'" >&2; usage >&2; exit 1 ;;
    esac
done

log() { printf '[publish-iso] %s\n' "$*"; }
die() { printf '[publish-iso] error: %s\n' "$*" >&2; exit 1; }

# ── Signing material ────────────────────────────────────────────────────────
if [[ -z "${X_REPO_SIGN_KEY:-}" && -f "$WORKSPACE/keys/env.sh" ]]; then
    # shellcheck disable=SC1091
    source "$WORKSPACE/keys/env.sh"
fi
[[ -n "${X_REPO_SIGN_KEY:-}" ]] || die "X_REPO_SIGN_KEY is unset and keys/env.sh was not found"

# ── Resolve the ISO ─────────────────────────────────────────────────────────
if [[ -z "$ISO" ]]; then
    ISO="$(ls -1t "$WORKSPACE"/x/out/x-*-x86_64.iso 2>/dev/null | head -1 || true)"
fi
[[ -n "$ISO" && -f "$ISO" ]] || die "no ISO found (build one with x/xbuild.sh or pass --iso)"
ISO="$(readlink -f "$ISO")"
NAME="$(basename "$ISO")"
VERSION="$(sed -n 's/^x-\([0-9.]*\)-x86_64\.iso$/\1/p' <<<"$NAME")"
[[ -n "$VERSION" ]] || die "cannot derive the version from '$NAME'"
DATE="${X_ISO_DATE:-$(date +%Y-%m-%d)}"

PAYLOAD="$(sed -n 's/^pkgver=//p' "$WORKSPACE/scripts/packaging/PKGBUILD" | head -1)"
PKGREL="$(sed -n 's/^pkgrel=//p' "$WORKSPACE/scripts/packaging/PKGBUILD" | head -1)"
PAYLOAD="${PAYLOAD}-${PKGREL}"

log "ISO:     $ISO"
log "version: $VERSION (payload $PAYLOAD)"

# ── Stage: checksums + signatures + README ──────────────────────────────────
STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT

SHA="$(sha256sum "$ISO" | awk '{print $1}')"
printf '%s  %s\n' "$SHA" "$NAME" > "$STAGE/SHA256SUMS"
log "sha256:  $SHA"

if [[ "$DRY_RUN" == "1" ]]; then
    log "dry-run: would sign '$NAME' and SHA256SUMS with $X_REPO_SIGN_KEY"
else
    gpg --batch --yes --detach-sign -o "$STAGE/$NAME.sig" --local-user "$X_REPO_SIGN_KEY" "$ISO"
    gpg --batch --yes --detach-sign -o "$STAGE/SHA256SUMS.sig" --local-user "$X_REPO_SIGN_KEY" "$STAGE/SHA256SUMS"
    gpg --verify "$STAGE/SHA256SUMS.sig" "$STAGE/SHA256SUMS" >/dev/null 2>&1 || die "SHA256SUMS signature failed"
fi

sed -e "s/@VERSION@/$VERSION/g" -e "s/@DATE@/$DATE/g" -e "s/@PAYLOAD@/$PAYLOAD/g" \
    -e "s/@SHA256@/$SHA/g" "$SELF_DIR/iso-README.template.md" > "$STAGE/README.md"

# ── Upload to SourceForge ───────────────────────────────────────────────────
RSH=(ssh -i "$SF_KEY" -o BatchMode=yes -o StrictHostKeyChecking=accept-new)

remote_old_versions() {
    local listing
    listing="$(timeout 30 sftp -b - -i "$SF_KEY" -o BatchMode=yes "$SF_USER@frs.sourceforge.net" 2>/dev/null <<EOF
ls -1 $SF_PATH/
EOF
)"
    # shellcheck disable=SC2013
    for f in $(awk '{print $NF}' <<<"$listing" | tr -d '\r'); do
        f="$(basename "$f")"
        case "$f" in
            "$NAME"|"$NAME.sig") continue ;;
            x-*-x86_64.iso|*-x86_64.iso.sig|*-x86_64.iso)
                printf '%s\n' "$f"
                ;;
        esac
    done
}

if [[ "$DRY_RUN" == "1" || "$UPLOAD" == "0" ]]; then
    log "dry-run/no-upload: skipping upload to $SF_USER@frs.sourceforge.net:$SF_PATH"
    if [[ "$UPLOAD" == "1" ]]; then
        remote_old_versions | while read -r f; do log "  would delete remote $f"; done
    fi
else
    log "uploading ISO (this can take a few minutes)"
    rsync -e "${RSH[*]}" -h --partial --info=progress2 "$ISO" "$SF_USER@frs.sourceforge.net:$SF_PATH/"
    rsync -e "${RSH[*]}" -h "$STAGE/README.md" "$STAGE/SHA256SUMS" "$STAGE/SHA256SUMS.sig" "$STAGE/$NAME.sig" \
        "$SF_USER@frs.sourceforge.net:$SF_PATH/"
    log "deleting previous versions"
    timeout 60 sftp -b - -i "$SF_KEY" -o BatchMode=yes "$SF_USER@frs.sourceforge.net" >/dev/null 2>&1 <<EOF || true
$(remote_old_versions | sed "s#^#rm $SF_PATH/#")
EOF
fi

# ── Update the web release index ────────────────────────────────────────────
RELEASES="$WEB_DIR/data/releases.json"
if [[ ! -f "$RELEASES" ]]; then
    log "warning: $RELEASES not found; skipped link update"
else
    BASE="https://sourceforge.net/projects/equislinux/files/iso"
    if [[ "$DRY_RUN" == "1" ]]; then
        log "dry-run: would update $RELEASES to $VERSION"
    else
        jq --arg v "$VERSION" --arg d "$DATE" --arg n "$NAME" \
           --arg url "$BASE/$NAME/download" --arg sig "$BASE/$NAME.sig/download" \
           --arg sums "$BASE/SHA256SUMS/download" --arg sha "$SHA" --argjson size "$(stat -c %s "$ISO")" \
           '.releases[0] = ({version:$v,date:$d,iso:{name:$n,url:$url,size:$size,sha256:$sha,sig:$sig,checksums:$sums}}
                            + (if .releases[0].wsl then {wsl:.releases[0].wsl} else {} end))' \
           "$RELEASES" > "$RELEASES.tmp" && mv "$RELEASES.tmp" "$RELEASES"
        log "updated $RELEASES"
    fi
fi

# ── Optional: verify the public download ────────────────────────────────────
if [[ "$VERIFY" == "1" && "$DRY_RUN" != "1" && "$UPLOAD" == "1" ]]; then
    URL="https://sourceforge.net/projects/equislinux/files/iso/$NAME/download"
    log "waiting for SourceForge to publish $URL"
    ready=0
    for _ in $(seq 1 40); do
        info="$(curl -s -o /dev/null -w '%{http_code} %{redirect_url}' -I "$URL" || true)"
        code="${info%% *}"
        target="${info#* }"
        # While SourceForge is still processing the upload the URL 301s to the
        # project page; when released it 302s to a downloads.sourceforge.net
        # mirror. Never trust a 200 HTML body as the ISO.
        if [[ "$code" == "302" && "$target" == *downloads.sourceforge.net* ]]; then
            ready=1
            break
        fi
        sleep 30
    done
    [[ "$ready" == "1" ]] || die "download still not released ($code -> $target)"
    tmp="$(mktemp)"; trap 'rm -f "$tmp"' EXIT
    curl -fsSL -o "$tmp" "$URL"
    [[ "$(sha256sum "$tmp" | awk '{print $1}')" == "$SHA" ]] || die "downloaded ISO hash mismatch"
    log "public download verified: $SHA"
fi

log "done"
cat <<EOF

Next steps:
  1. commit & push the web repo (deploys automatically):
       git -C $WEB_DIR add data/releases.json && git -C $WEB_DIR commit -m "release: $VERSION" && git -C $WEB_DIR push
  2. share the stable link: https://equislinux.github.io/web/download/latest/
EOF
