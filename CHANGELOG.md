# Changelog

All notable changes to the x-repo project will be documented in this file.

## [Unreleased]

### Added
- **x-scripts 0.1.0-23**: published signed (LICENSE MIT + audited deps); the
  0.1.0-22 artifact is retired.

### Fixed
- **`SHA256SUMS`**: no longer includes its own hash or its stale signature
  (self-referencing checksums made `sha256sum -c` fail every time).
- **Version alignment**: `XBUILD` releases for `x-release` (8) and `x-dev` (2)
  now match their `PKGBUILD`s.

### Changed
- **Signing**: the `[x]` repository is required on the live ISO and the
  installed target (key shipped at `/etc/pacman.d/x-repo.pub`); only the build
  host keeps `SigLevel = Never`.

## [2026-02-01]
### Added
- **xtop**: Added `xtop-git` package to `packages/xtop/`.
- **xfetch**: Added `xfetch-git` package to `packages/xfetch/`.
- **CI**: Updated `build.yml` workflow to automatically find and index `.pkg.tar.zst` files from all subdirectories in `packages/`.
- **Docs**: Added `ROADMAP.md` and `CHANGELOG.md`.
