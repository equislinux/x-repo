#!/usr/bin/env bash
set -euo pipefail

ALIASES="
# ───── X Aliases ─────
alias xs='sudo su'
alias xi='sudo -i'
alias xsh='sudo -s'
alias xzdev='zellij --layout x'
"

GIT_ALIASES=$(cat <<'GITEOF'
# ===== XCustom Git Aliases =====
alias gc="git clone"
alias ga="git add ."
alias gcom="git commit -m"
alias gp="git push"
alias gpuom="git push -u origin main"
alias gpuod="git push -u origin dev"
alias gs="git status"
alias gl="git log --oneline --graph --decorate"
alias gco="git checkout"
alias gcb="git checkout -b"
alias gd="git diff"
alias gpl="git pull"
alias gf="git fetch"
# ===== End =====
GITEOF

NAVIGATION_ALIASES=$(cat <<'NAVEOF'
# ===== XCustom Navigation Aliases =====
alias ..="cd .."
alias ...="cd ../.."
alias ....="cd ../../.."
alias ~="cd ~"
alias c="clear"
alias ll="ls -lh"
alias la="ls -A"
alias l="ls -CF"
# ===== End =====
NAVEOF

for rc in /etc/bash.bashrc /etc/zsh/zshrc; do
    if [ -f "$rc" ]; then
        grep -q "X Aliases" "$rc" 2>/dev/null || echo "$ALIASES" >> "$rc"
        grep -q "XCustom Git Aliases" "$rc" 2>/dev/null || echo "$GIT_ALIASES" >> "$rc"
        grep -q "XCustom Navigation Aliases" "$rc" 2>/dev/null || echo "$NAVIGATION_ALIASES" >> "$rc"
    fi
done
