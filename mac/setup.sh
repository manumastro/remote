#!/usr/bin/env bash
# Installa AnyDesk sul Mac (via Homebrew).
set -euo pipefail

if [[ -d /Applications/AnyDesk.app ]]; then
  echo "AnyDesk gia' installato."
elif command -v brew >/dev/null 2>&1; then
  echo "Installo AnyDesk con Homebrew..."
  brew install --cask anydesk
else
  echo "Homebrew non trovato. Scarica AnyDesk da https://anydesk.com/it/downloads/mac-os"
  open "https://anydesk.com/it/downloads/mac-os"
  exit 1
fi

cat <<'EOF'

AnyDesk installato. Connettiti con:  ./mac/connect.sh <ID-AnyDesk-del-PC>
(oppure apri AnyDesk e scrivi l'ID nella barra in alto)
EOF
