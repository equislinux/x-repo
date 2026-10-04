# x-repo — signing the `[x]` repository

Current state: the repository is published **signed** and the live ISO and the
installed target trust the project key (`SigLevel = Required`; the key lives at
`/etc/pacman.d/x-repo.pub` and is imported + locally signed by
`customize_airootfs.sh` and `install.sh`). The build host (`x/pacman.conf`,
used by `mkarchiso`) uses `SigLevel = Never` for `[x]` because the host keyring
may not have the project key. This is a local/offline procedure: no CI
required.

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

## 4. ISO/target integration (done)

The ISO ships `airootfs/etc/pacman.d/x-repo.pub`. The live keyring lives on a
tmpfs recreated by `pacman-init.service`, so `x-keyring.service` re-adds and
locally signs the key after it at every boot; `install.sh` repeats the steps
idempotently (live + target keyrings) before `pacstrap`, which verifies the
signed `[x]` database against the live keyring. The target gets its own
keyring (`--gpgdir /mnt/etc/pacman.d/gnupg`) and `SigLevel = Required`.
Re-run `x/tests/e2e-autoinstall.py` after key rotation to re-validate the
unattended install against the signed repository.

## 5. Rotation

- Publish the new key alongside the old one, re-sign the DB and keep both in
  the keyring for at least one release cycle.
- Never delete old package signatures before clients have the new key.
- Announce the fingerprint change in the changelog.

## 6. Changing the key (planned or emergency)

Keys are not forever; a change is a normal maintenance operation if you plan
for it:

1. **At creation**: keep an offline backup of the secret key **and a
   revocation certificate** (`gpg --gen-revoke "$KEYID" > revoke.asc`, stored
   separately). Losing the key *without* a revocation certificate is the only
   really messy scenario.
2. **Planned change**: generate the new key, **cross-sign** it with the old
   one (proves continuity to clients that trust the old key), publish both in
   `trustedkeys.gpg`, re-sign the DB/packages with the new key and keep the
   old key in the keyring for at least one release cycle before dropping it.
3. **Compromise**: publish the old key's revocation certificate, publish the
   new key, re-sign everything and distribute the updated keyring as in (2).
   Consumers on `Optional` are unaffected; `Required` consumers need the
   keyring update before the first new-key package.
4. **Lost (not compromised)**: same as a planned change; old signatures stay
   valid, you just cannot sign new updates until the new key is distributed.

Because signatures are published while `[x]` stays `Optional` during
development, a key change breaks nobody. Flip to `Required` only when the
keyring distribution path (ISO + an updatable `x-keyring` package) is in
place.
