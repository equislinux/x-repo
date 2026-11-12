#!/usr/bin/env bash
set -euo pipefail

log()    { echo -e "\033[1;32m[XOs]\033[0m $1"; }
warn()   { echo -e "\033[1;33m[WARNING]\033[0m $1"; }
error()  { echo -e "\033[1;31m[ERROR]\033[0m $1"; exit 1; }

run() {
    if command -v x &>/dev/null; then
        x "$@"
    elif [ "$EUID" -ne 0 ]; then
        sudo "$@"
    else
        "$@"
    fi
}

log "Starting proprietary NVIDIA driver installation..."

MULTILIB_ENABLED=false
grep -q "^\[multilib\]" /etc/pacman.conf && MULTILIB_ENABLED=true

if pacman -Q vulkan-nouveau xf86-video-nouveau &>/dev/null; then
    log "Removing open-source drivers (nouveau)..."
    run pacman -Rns --noconfirm vulkan-nouveau xf86-video-nouveau || true
fi

PACKAGES="nvidia nvidia-utils nvidia-settings opencl-nvidia egl-wayland"
[ "$MULTILIB_ENABLED" = true ] && PACKAGES="$PACKAGES lib32-nvidia-utils lib32-opencl-nvidia"

log "Installing NVIDIA packages: $PACKAGES"
run pacman -S --noconfirm --needed $PACKAGES

MKINIT_CONF="/etc/mkinitcpio.conf"
if [ -f "$MKINIT_CONF" ] && ! grep -q "nvidia_drm" "$MKINIT_CONF"; then
    run cp "$MKINIT_CONF" "${MKINIT_CONF}.bak"
    run sed -i 's/^MODULES=(\(.*\))/MODULES=(nvidia nvidia_modeset nvidia_uvm nvidia_drm \1)/' "$MKINIT_CONF"
    run mkinitcpio -P
fi

KERNEL_PARAMS="nvidia-drm.modeset=1 nvidia-drm.fbdev=1"

if command -v bootctl &>/dev/null && bootctl is-installed &>/dev/null; then
    for entry in /boot/loader/entries/*.conf; do
        [ -f "$entry" ] || continue
        grep -q "nvidia-drm.modeset=1" "$entry" || run sed -i '/^options/ s/$/ nvidia-drm.modeset=1/' "$entry"
        grep -q "nvidia-drm.fbdev=1" "$entry" || run sed -i '/^options/ s/$/ nvidia-drm.fbdev=1/' "$entry"
    done
elif [ -f /boot/grub/grub.cfg ]; then
    GRUB_CONF="/etc/default/grub"
    CURRENT_PARAMS=$(grep "^GRUB_CMDLINE_LINUX_DEFAULT=" "$GRUB_CONF" | cut -d'"' -f2)
    NEW_PARAMS="$CURRENT_PARAMS"
    [[ "$CURRENT_PARAMS" != *"nvidia-drm.modeset=1"* ]] && NEW_PARAMS="$NEW_PARAMS nvidia-drm.modeset=1"
    [[ "$CURRENT_PARAMS" != *"nvidia-drm.fbdev=1"* ]] && NEW_PARAMS="$NEW_PARAMS nvidia-drm.fbdev=1"
    if [ "$CURRENT_PARAMS" != "$NEW_PARAMS" ]; then
        run sed -i "s/^GRUB_CMDLINE_LINUX_DEFAULT=\".*\"/GRUB_CMDLINE_LINUX_DEFAULT=\"$NEW_PARAMS\"/" "$GRUB_CONF"
        run grub-mkconfig -o /boot/grub/grub.cfg
    fi
fi

run bash -c 'echo "options nvidia_drm modeset=1 fbdev=1" > /etc/modprobe.d/nvidia.conf'
run systemctl enable --now nvidia-suspend.service nvidia-hibernate.service nvidia-resume.service nvidia-powerd.service || true

log "Installation complete! Please REBOOT."
