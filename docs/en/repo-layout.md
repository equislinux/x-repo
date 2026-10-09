# Repository Layout

## Top level

```
app/                  Next.js page (layout, page and styles)
packages/             Package sources and build artifacts
public/               Static content served on GitHub Pages
  repo/x86_64/        [x] pacman repository (db + .pkg.tar.zst tarballs)
  x/x86_64/           Native endpoint (.xp packages) used by xpm
  images/, fonts/     Website assets
build-packages.sh     Local build + repo-add script
docs/                 Documentation
.github/workflows/    CI/CD workflows
```

## packages/

One directory per package. Each may contain a `PKGBUILD`, an `XBUILD`, or both, plus
package-local files.

- `PKGBUILD` — Arch-compatible source descriptor. Built with `makepkg`, produces a
  `.pkg.tar.zst` for the **pacman** repository.
- `XBUILD` — native descriptor for the **xpkg/xpm** path, produces an `.xp` package.
  Built and published by `scripts/build-xp.sh` (see `docs/build-x-native-workflow.md`).

The README notes that while `PKGBUILD` is kept for legacy Arch tooling, `XBUILD` is the
native path for `xpkg`/`xpm`.

### Buildable packages (PKGBUILD)

- **`x-release`** — X Linux identity and branding (PKGBUILD `1.0-8`). Ships the
  `os-release` template, GRUB defaults, distributor logo, wallpapers and the
  `x-release-apply` tool, plus pacman hooks (`99-x-os-release.hook`,
  `99-x-grub.hook`) that re-apply branding after `filesystem`/`grub` upgrades.
- **`x-dev`** — development environment package (PKGBUILD `1.0-2`). Installs
  `/usr/bin/x-dev-env` and helpers under `/usr/share/x-dev/` (shell aliases,
  NVIDIA/QEMU/Node setup scripts). Depends on `zsh git base-devel curl wget`.
  `install=x-dev.install` runs the post-install logic.
- **`opencode-bin`** — official prebuilt binary of the opencode CLI
  (`anomalyco/opencode`, `1.18.34`), redistributed so `agents=yes` and
  `x agent` users get a working agent without AUR. `provides`/`conflicts`
  `opencode`; the tarball is checksummed in the PKGBUILD.

These packages are built by `build-packages.sh` from their `PKGBUILD` today.

### x-scripts: imported artifact, no source here

`x-scripts` is **not** built in this repository. Its `PKGBUILD` lives in the sibling
repo `equislinux/scripts` under `scripts/packaging/` and packages the whole provisioning
payload (phases, CLI `x`, configs). The resulting tarball is built there and **imported**
into this repo, committed under `public/repo/x86_64/` (currently
`x-scripts-0.1.0-23-any.pkg.tar.zst`).

- There is no `packages/x-scripts/` source directory here.
- The published artifact and the `PKGBUILD` in `scripts/packaging/` are aligned at
  `0.1.0-23` (the equisdots desktop snapshot). `build-packages.sh` imports the
  sibling build automatically; re-run it when republishing the payload.

### Recipes only

`packages/*/` hold build recipes (`PKGBUILD`, `XBUILD` and helper files); built
binaries live only in the generated repositories (`public/repo/x86_64` for pacman,
`public/x/x86_64` for xpm).

## public/repo/x86_64/ — the [x] pacman repository

This directory is the pacman-facing repository. Files present:

| File | Role |
|---|---|
| `x.db`, `x.db.tar.gz` | Package database (`x.db` is the uncompressed copy of `x.db.tar.gz`). |
| `x.files`, `x.files.tar.gz` | File-list database for `pacman -F`. |
| `*.pkg.tar.zst` | The packages: `x-release-1.0-8`, `x-dev-1.0-2`, `x-scripts-0.1.0-23`, `xpm-0.1.0-3`. |
| `SHA256SUMS` | Checksums over every file in the directory. |
| `signing.pub`, `trustedkeys.gpg` | Signing/trust material consumed by the native endpoint. |

Clients configure the repository in `pacman.conf` as:

```
[x]
Server = https://equislinux.github.io/x-repo/repo/x86_64
```

### How the database is updated (repo-add)

The database is never edited by hand. `build-packages.sh` regenerates it with
`repo-add`:

```bash
cd public/repo/x86_64
rm -f x.db x.files x.db.tar.gz x.files.tar.gz x.db.tar.gz.old x.files.tar.gz.old
repo-add -R x.db.tar.gz *.pkg.tar.zst
rm -f x.db x.files
cp x.db.tar.gz x.db
cp x.files.tar.gz x.files
rm -f SHA256SUMS SHA256SUMS.sig
sha256sum $(find . -maxdepth 1 -type f ! -name 'SHA256SUMS*' -printf '%P\n' | sort) > SHA256SUMS
```

- `repo-add` creates `x.db.tar.gz` and `x.files.tar.gz` from the `.pkg.tar.zst` files.
- The database is rebuilt from scratch from the tarballs present in the directory,
  so entries for packages that no longer exist are dropped too.
- `x.db`/`x.files` are plain copies of the `.tar.gz` files so pacman can read them
  directly.
- No signing flag is passed today, so the database is regenerated unsigned.
- `SHA256SUMS` is regenerated from every file in the directory.

## public/x/x86_64/ — native .xp endpoint

Companion endpoint for `xpm`. It holds `.xp` packages (xpm, xpkg, x-release, x-dev,
xfetch-bin, xtop-git, opencode-bin, x-scripts), its own database (`x.db.tar.gz`,
`x.files.tar.gz` plus `x.db`/`x.files` copies), per-file signatures, `history.json`,
`signing.pub`/`trustedkeys.gpg` and a `SHA256SUMS`. Regenerate it with
`scripts/build-xp.sh`; it deploys with the same Pages workflow. Served at
`https://equislinux.github.io/x-repo/x/x86_64/`. The documented `xpm` repository URL is
`https://equislinux.github.io/x-repo/x/$arch`.

## build-packages.sh

Local script (run from the repo root, requires an Arch-like environment with
`makepkg` and `repo-add`). It:

1. Builds the configured PKGBUILD packages in place (`build_pkgbuild x-release`,
   `build_pkgbuild x-dev`) using `makepkg -cf --noconfirm`. The `build_xbuild` helper
   for the native path is present but commented out.
2. Imports `../scripts/packaging/x-scripts-*.pkg.tar.zst` when present, copies the
   freshly built `x-release`/`x-dev` tarballs into `public/repo/x86_64/` and removes
   the build artifacts afterwards (the committed leftovers under the other
   `packages/*` directories are not touched).
3. Regenerates the pacman database and `SHA256SUMS` as shown above.
4. Prints the closing reminder:

```
Commit public/repo/x86_64/ and push, then run the deploy workflow.
```

To add a new PKGBUILD package to the flow, add its directory to `build_pkgbuild`
calls. Externally built packages (such as `x-scripts`) are imported automatically
from `../scripts/packaging/`; you can also drop a `.pkg.tar.zst` directly into
`public/repo/x86_64/` before running `./build-packages.sh --index-only`.
