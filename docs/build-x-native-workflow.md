# Native Package Manager Workflow (Pending)

This document preserves the former `build-x-native.yml` workflow. It is kept for
future reference and is **not** used right now.

## Status

- **Pending**: to be re-enabled when the native package manager (`xpm`/`xpkg`)
  is ready for production.
- Packages for the `[x]` pacman repository are currently built locally and
  committed to `public/repo/x86_64/`. See `build-packages.sh`.
- The website deploy workflow (`build.yml`) publishes the committed files to
  GitHub Pages without rebuilding packages.

## Original Workflow

Name: Build X Native Repo & Deploy Web

Triggers on `workflow_dispatch`. It builds native `.xp` packages from source
(`xpm`, `xpkg`, `xfetch`, `xclock`), publishes them to `public/x/x86_64/`,
and deploys the website to GitHub Pages.

```yaml
name: Build X Native Repo & Deploy Web

on:
  workflow_dispatch:

permissions:
  contents: read
  pages: write
  id-token: write

concurrency:
  group: "pages-x-native"
  cancel-in-progress: false

jobs:
  build-x-native:
    runs-on: ubuntu-latest
    container: archlinux:base-devel
    steps:
      - name: Checkout x-repo
        uses: actions/checkout@v4
        with:
          persist-credentials: false

      - name: Install build toolchain
        run: |
          set -euo pipefail
          pacman -Sy --noconfirm --needed rust cargo git openssl pkgconf
          cargo install --git https://github.com/equislinux/xpkg --locked xpkg

      - name: Clone source repositories
        run: |
          set -euo pipefail
          mkdir -p /tmp/x-native-src

          git clone --depth 1 https://github.com/equislinux/xpm.git /tmp/x-native-src/xpm
          git clone --depth 1 https://github.com/equislinux/xpkg.git /tmp/x-native-src/xpkg
          git clone --depth 1 https://github.com/xfetch-cli/xfetch.git /tmp/x-native-src/xfetch
          git clone --depth 1 https://github.com/xscriptor/xclock.git /tmp/x-native-src/xclock

      - name: Build native .xp packages (xpm, xpkg, xfetch, xclock)
        run: |
          set -euo pipefail
          mkdir -p /tmp/x-native-out

          for project in xpm xpkg xfetch xclock; do
            ~/.cargo/bin/xpkg build \
              -f "/tmp/x-native-src/${project}/packaging/xpkg/XBUILD" \
              -o /tmp/x-native-out
          done

          ls -lah /tmp/x-native-out

      - name: Create x native repository endpoint
        run: |
          set -euo pipefail

          mkdir -p public/x/x86_64
          rm -f public/x/x86_64/*

          for pkg in /tmp/x-native-out/*.xp; do
            [ -e "$pkg" ] || { echo "No .xp packages were produced"; exit 1; }
            cp "$pkg" public/x/x86_64/
          done

          (
            cd public/x/x86_64
            rm -f x.db* x.files* || true
            repo-add -n -R x.db.tar.gz *.xp
            rm -f x.db x.files
            cp x.db.tar.gz x.db
            cp x.files.tar.gz x.files
          )

          (
            cd public/x/x86_64
            rm -f SHA256SUMS SHA256SUMS.sig
sha256sum $(find . -maxdepth 1 -type f ! -name 'SHA256SUMS*' -printf '%P\n' | sort) > SHA256SUMS
          )

      - name: Upload x endpoint artifact
        uses: actions/upload-artifact@v4
        with:
          name: x-native-files
          path: public

  deploy-web:
    needs: build-x-native
    runs-on: ubuntu-latest
    steps:
      - name: Checkout x-repo
        uses: actions/checkout@v4

      - name: Download x endpoint artifact
        uses: actions/download-artifact@v4
        with:
          name: x-native-files
          path: public

      - name: Setup Node
        uses: actions/setup-node@v4
        with:
          node-version: "22"

      - name: Install and build website
        run: |
          npm ci
          npm run build

      - name: Upload Pages artifact
        uses: actions/upload-pages-artifact@v3
        with:
          path: ./out

      - name: Deploy to GitHub Pages
        uses: actions/deploy-pages@v4
```

## Notes

- Both the native workflow and the website workflow deploy to GitHub Pages.
- Do not re-enable this workflow while the website deploy workflow is active,
  or they may overwrite each other's Pages deployment.
