# x-repo — signing the `[x]` repository

Current state: the repository is published **unsigned** and consumers use
`SigLevel = Optional TrustAll` (development mode). This runbook is the path to
required signatures. It is a local/offline procedure: no CI required.

## 0. One-time key setup (keep the secret key offline)

```bash
gpg --full-generate-key                 # RSA 4096 or ed25519, long expiry
KEYID="$(gpg --list-keys --with-colons <mail> | awk -F: '/^fpr/{print $10; exit}')"
export X_REPO_SIGN_KEY="$KEYID"
```

Store the secret key on an offline medium or hardware token. Only the public
part is published.

## 1. Sign the packages

- PKGBUILD packages: `makepkg --sign --key "$X_REPO_SIGN_KEY"` (or let
  `build-packages.sh` do it: it passes the flag when the variable is set).
- `.xp` packages: `xpkg sign` (see `xlnux/xpkg` `docs/SIGNING.md`).

Both produce a detached `.sig` next to the package.

## 2. Rebuild the database with signatures and export the keyring

```bash
X_REPO_SIGN_KEY="$KEYID" ./build-packages.sh --index-only
```

With `X_REPO_SIGN_KEY` set, the script runs `repo-add -s -k`, signs
`SHA256SUMS` and exports `trustedkeys.gpg` + `signing.pub` into
`public/repo/x86_64/`. Without it, the script keeps publishing unsigned and
prints a warning.

## 3. Consumer side (installed systems)

`/etc/pacman.conf`:

```ini
[x]
SigLevel = Required DatabaseOptional
Server = https://xlnux.github.io/x-repo/repo/x86_64
```

Keyring bootstrap (before switching to `Required`):

```bash
sudo pacman-key --init
sudo pacman-key --add signing.pub
sudo pacman-key --lsign-key "$KEYID"
```

For `xpm`: put the binary keyring at `/etc/xpm/gnupg/trustedkeys.gpg` and set
`sig_level = "required"` (documented in `xlnux/xpm`).

## 4. ISO/target integration (follow-up, P1.7)

Embed `signing.pub`/keyring in `airootfs` and in the installed target, then
switch `x/pacman.conf` and the installer `[x]` block to `Required`. Until
that lands, keep `Optional TrustAll` on the ISO.

## 5. Rotation

- Publish the new key alongside the old one, re-sign the DB and keep both in
  the keyring for at least one release cycle.
- Never delete old package signatures before clients have the new key.
- Announce the fingerprint change in the changelog.
