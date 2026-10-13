#!/usr/bin/env bash
# Si connette al desktop del PC Windows via Tailscale + VNC.
# Uso: ./mac/connect.sh [nome-host-tailscale]   (default: $REMOTE_HOST o "manustrong")
set -euo pipefail

HOST="${1:-${REMOTE_HOST:-manustrong}}"
PORT=5900

TS="$(command -v tailscale || true)"
[[ -z "$TS" && -x /Applications/Tailscale.app/Contents/MacOS/Tailscale ]] \
  && TS=/Applications/Tailscale.app/Contents/MacOS/Tailscale
if [[ -z "$TS" ]]; then
  echo "Tailscale non trovato: esegui prima ./mac/setup.sh" >&2
  exit 1
fi

if ! "$TS" status >/dev/null 2>&1; then
  echo "Tailscale non e' connesso: aprilo e fai login (stesso account del PC)." >&2
  open -a Tailscale
  exit 1
fi

IP="$("$TS" ip -4 "$HOST" 2>/dev/null | head -n1 || true)"
if [[ -z "$IP" ]]; then
  echo "Host '$HOST' non trovato nella tua rete Tailscale. Dispositivi visibili:" >&2
  "$TS" status >&2
  exit 1
fi

echo "Verifico che $HOST ($IP) sia raggiungibile..."
if ! "$TS" ping -c 1 --timeout 5s "$IP" >/dev/null 2>&1; then
  echo "$HOST non risponde: il PC e' acceso e connesso a Internet?" >&2
  exit 1
fi

echo "Apro Condivisione Schermo su vnc://$IP:$PORT (inserisci la password VNC)"
open "vnc://$IP:$PORT"
