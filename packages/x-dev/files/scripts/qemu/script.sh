#!/usr/bin/env bash
set -euo pipefail

log() { echo -e "\033[1;32m[XOs]\033[0m $1"; }

run() {
    if command -v x &>/dev/null; then
        x "$@"
    elif [ "$EUID" -ne 0 ]; then
        sudo "$@"
    else
        "$@"
    fi
}

log "Installing Virtualization Stack (QEMU + Libvirt)..."

PKGS=(
    qemu-desktop libvirt virt-manager virt-viewer dnsmasq vde2
    bridge-utils openbsd-netcat edk2-ovmf swtpm iptables-nft guestfs-tools
)

run pacman -S --needed --noconfirm "${PKGS[@]}"
run systemctl enable --now libvirtd.service virtlogd.socket virtlockd.socket

CURRENT_USER=$(whoami)
run usermod -aG libvirt,kvm,input "$CURRENT_USER"

if [ -f /usr/share/libvirt/networks/default.xml ]; then
    run virsh net-define /usr/share/libvirt/networks/default.xml 2>/dev/null || true
fi
run virsh net-autostart default || true
run virsh net-start default || true

log "Done! Log out/in to apply group permissions, then run virt-manager."
