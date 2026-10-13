#!/usr/bin/env bash
# Installa Tailscale sul Mac (via Homebrew) e avvia il login.
set -euo pipefail

if [[ -d /Applications/Tailscale.app ]]; then
  echo "Tailscale gia' installato."
elif command -v brew >/dev/null 2>&1; then
  echo "Installo Tailscale con Homebrew..."
  brew install --cask tailscale-app 2>/dev/null || brew install --cask tailscale
else
  echo "Homebrew non trovato. Installa Tailscale dall'App Store o da https://tailscale.com/download/mac"
  open "https://tailscale.com/download/mac"
  exit 1
fi

open -a Tailscale
cat <<'EOF'

Tailscale e' aperto: dall'icona nella barra dei menu fai "Log in"
con lo STESSO account usato sul PC Windows.

Poi connettiti con:  ./mac/connect.sh
EOF
