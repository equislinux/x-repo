# Changelog

All notable changes to the x-repo project will be documented in this file.

## [Unreleased]

### Changed
- **Repository cleanup (2026-11-09)**: retired the `xfetch-bin` and `xtop-git`
  packages from `[x]` and the native `.xp` endpoint; X installs
  `xfetch-core-bin`/`xtop-bin` from the AUR through `xpm-aur`. Removed debug
  split packages, stale `*.pkg.tar.zst`/`*.xp` builds and `*.old.sig` files.
- **xpm 0.1.0-27**: resolver now prefers an exact package name over `provides`,
  supports `repo/name`, reports substitutions and checks installed/target
  conflicts; dead code and unused dependencies removed.
- **xpm-aur 0.1.3-9**: unused dependencies and dead code removed; rebuilt
  against xpm 27.
- **x-scripts 0.1.0-48**: generation reasons follow the invoking package
  manager (`xpm`/`xpm-pre` or `pacman`/`pacman-pre`); installer network phase
  is English.
- **x-wallpapers 1.0-2** and **x-kde-settings 1.0-2**: new default wallpaper
  (optimized PNG/JPEG) aligned with the current desktop.

### Added
- **x-wallpapers 1.0-1**: desktop wallpapers split out of `x-release`, so
  headless installs (e.g. WSL) can install the X identity without the images.
  `x-release` lists it as an optdepend.
- **xfetch-git / xtop-git**: first signed publication of the X system tools
  (`xscriptordev/xfetch`, `xscriptordev/xtop`); installed by the X base.
- **x-scripts 0.1.0-23**: published signed (LICENSE MIT + audited deps); the
  0.1.0-22 artifact is retired.

### Changed
- **x-release 1.0-9**: GRUB defaults and `99-x-grub.hook` only touch the system
  when `/boot/grub` exists, so installing it on a headless system (WSL) no
  longer writes `/etc/default/grub`. systemd-boot entry branding is unchanged.


### Fixed
- **`SHA256SUMS`**: no longer includes its own hash or its stale signature
  (self-referencing checksums made `sha256sum -c` fail every time).
- **Version alignment**: `XBUILD` releases for `x-release` (8) and `x-dev` (2)
  now match their `PKGBUILD`s.

### Added
- **x-kde-settings**: X Plasma branding package with the `XDark` color scheme,
  `org.x.desktop` look-and-feel, X wallpaper package and the static X SDDM
  theme. Published as 1.0-1 to the signed `[x]` repository.

### Changed
- **x-kde-settings 1.0-2**: ships `/etc/skel/.config/kdeglobals` and a
  first-login Plasma autostart that applies the X global theme; bundled in the
  desktop test ISO (not published yet).
- **build-packages.sh**: builds `x-kde-settings` alongside `x-release` and
  `x-dev`.
- **Signing**: the `[x]` repository is required on the live ISO and the
  installed target (key shipped at `/etc/pacman.d/x-repo.pub`); only the build
  host keeps `SigLevel = Never`.

## [2026-02-01]
### Added
- **xtop**: Added `xtop-git` package to `packages/xtop/`.
- **xfetch**: Added `xfetch-git` package to `packages/xfetch/`.
- **CI**: Updated `build.yml` workflow to automatically find and index `.pkg.tar.zst` files from all subdirectories in `packages/`.
- **Docs**: Added `ROADMAP.md` and `CHANGELOG.md`.
