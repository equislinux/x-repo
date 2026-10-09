# Native .xp endpoint workflow

The `.xp` endpoint (`public/x/x86_64/`) is the native package channel consumed by
`xpm`. It is a **parallel** channel to the pacman `[x]` repository: the distro keeps
installing from `[x]`, while `xpm` can install the X packages as native `.xp`.

## Generate it

```bash
# from x-repo/, after a package change or release
scripts/build-xp.sh            # build + sign + repo-add
scripts/build-xp.sh --no-sign  # unsigned smoke build
```

Requirements: an `xpkg` binary (`XPKG_BIN`, `xpkg` in `PATH`, or
`../xpkg/target/release/xpkg`) and, for signing, `../keys/env.sh`
(`X_REPO_SIGN_KEY`, `GNUPGHOME`).

The script builds:

- `xpm`, `xpkg` — from their repos' `packaging/xpkg/XBUILD`
- `x-release`, `x-dev` — from `packages/*/XBUILD`
- `opencode-bin`, `xfetch-bin`, `xtop-git` — from `packages/*/PKGBUILD`
- `x-scripts` — from `../scripts/packaging/PKGBUILD`

then assembles `public/x/x86_64/`: `.xp` + `.sig` per package, `x.db.tar.gz` /
`x.files.tar.gz` via `xpkg repo-add` (plus flat `x.db`/`x.files` copies), `history.json`,
`signing.pub`, `trustedkeys.gpg` and a signed `SHA256SUMS`.

## Publish

Commit `public/x/x86_64/` and push, then run the Pages deploy workflow
(`build.yml`, `workflow_dispatch`). The endpoint is served at
`https://equislinux.github.io/x-repo/x/x86_64/`.

## Consume with xpm

```ini
[[repo]]
name = "x"
server = ["https://equislinux.github.io/x-repo/x/$arch"]
```

```bash
xpm sync
xpm search x-release
xpm install x-release
```

## History

The endpoint was originally produced by a `build-x-native.yml` GitHub workflow
(`workflow_dispatch`, `archlinux:base-devel` container, `cargo install --git` of
`xpkg`, `repo-add`, Pages deploy) that built xpm/xpkg/xfetch/xclock. It was disabled
when the native tooling moved to the local `build-xp.sh` flow; the original workflow
definition is preserved in this file's git history.
