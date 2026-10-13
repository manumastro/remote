#!/usr/bin/env bash
# Si connette al PC Windows con AnyDesk.
# Uso: ./mac/connect.sh <ID-AnyDesk>   (oppure: ANYDESK_ID=123456789 ./mac/connect.sh)
set -euo pipefail

ID="${1:-${ANYDESK_ID:-}}"
if [[ -z "$ID" ]]; then
  echo "Uso: $0 <ID-AnyDesk-del-PC>" >&2
  exit 1
fi

APP=/Applications/AnyDesk.app
if [[ ! -d "$APP" ]]; then
  echo "AnyDesk non trovato: esegui prima ./mac/setup.sh" >&2
  exit 1
fi

echo "Connessione a $ID (inserisci la password di accesso non presidiato)"
open -a "$APP" --args "$ID"
