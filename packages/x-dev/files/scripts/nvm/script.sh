#!/usr/bin/env bash
set -euo pipefail

log() { echo -e "\033[1;32m[XOs]\033[0m $1"; }

log "Installing FNM (Fast Node Manager) + Node.js..."

if ! command -v fnm &>/dev/null; then
    curl -fsSL https://fnm.vercel.app/install | bash -s -- --skip-shell
fi

FNM_PATH="$HOME/.local/share/fnm"
SHELL_CONFIG=""
case "$SHELL" in
    */zsh) SHELL_CONFIG="$HOME/.zshrc" ;;
    */bash) SHELL_CONFIG="$HOME/.bashrc" ;;
    */fish) SHELL_CONFIG="$HOME/.config/fish/config.fish" ;;
esac

if [ -n "$SHELL_CONFIG" ] && [ -f "$SHELL_CONFIG" ] && ! grep -q "fnm env" "$SHELL_CONFIG"; then
    echo "" >> "$SHELL_CONFIG"
    echo "# fnm" >> "$SHELL_CONFIG"
    echo 'export PATH="'"$FNM_PATH"':$PATH"' >> "$SHELL_CONFIG"
    echo 'eval "$(fnm env --use-on-cd)"' >> "$SHELL_CONFIG"
    log "fnm added to $SHELL_CONFIG"
fi

export PATH="$FNM_PATH:$PATH"
eval "$(fnm env --use-on-cd)"

log "Installing Node.js LTS..."
fnm install --lts
fnm use --lts

log "Installing global packages..."
npm install -g npm@latest yarn pnpm typescript ts-node

log "Node $(node -v) — npm $(npm -v)"
log "Restart your shell to apply changes."
