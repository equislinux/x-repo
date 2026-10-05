# X Linux — x-@VERSION@

Date: @DATE@ · Arch: x86_64 · Live ISO

## Includes

- Text installer (BIOS/UEFI) with autoinstall (`xauto=1` + a `cidata` disk).
- btrfs generations: bootable snapshot + manifest, rollback, granular restore,
  export/import and quotas.
- Signed `[x]` repository (`SigLevel = Required` on the live medium and the
  installed target) with an embedded keyring.
- Offline provisioning payload `x-scripts @PAYLOAD@`, including the Hyprland /
  equisdots desktop snapshot and the `x agent` command.
- Optional AI tooling: `agents=yes` in the install JSON installs the official
  `opencode` CLI (`opencode-bin` from `[x]`) and the Xscriptor AI bundle for
  the target user.
- X system tools `xfetch` and `xtop` installed in the base system.

## Verify

Download `x-@VERSION@-x86_64.iso`, `SHA256SUMS`, `SHA256SUMS.sig`, the ISO
detached signature and `signing.pub`:

```bash
curl -LO https://xlnux.github.io/x-repo/repo/x86_64/signing.pub
gpg --import signing.pub
gpg --verify x-@VERSION@-x86_64.iso.sig x-@VERSION@-x86_64.iso
gpg --verify SHA256SUMS.sig SHA256SUMS
sha256sum -c SHA256SUMS
```

Stable download page (always points to the newest release):
<https://xlnux.github.io/web/download/latest/>

SHA-256: `@SHA256@`
