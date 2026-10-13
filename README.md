# remote

Controllo remoto del PC Windows (Windows 11 Home) da Mac, anche da un'altra rete.

## Come funziona

```
 Mac  ──(Tailscale VPN, cifrata WireGuard)──►  PC Windows
 Condivisione Schermo (vnc://)                 TightVNC server :5900
```

- **Tailscale**: VPN mesh gratuita. Niente server VPN da gestire, niente porte da aprire
  sul router, funziona anche dietro NAT/4G. Mac e PC vedono un IP `100.x.y.z`.
- **TightVNC**: server VNC. Serve perché **Windows Home non include il server RDP**.
  Sul Mac si usa l'app integrata *Condivisione Schermo* (nessun client da installare).
- La porta VNC è accessibile **solo dalla rete Tailscale** (regola firewall + filtro IP
  di TightVNC): da Internet non è raggiungibile.

## 1. Sul PC Windows (una volta)

```powershell
git clone git@github.com:manumastro/remote.git
cd remote
powershell -ExecutionPolicy Bypass -File .\windows\setup.ps1
```

Lo script (chiede i permessi di amministratore):

1. installa Tailscale e fa il login (si apre il browser) in modalità *unattended*,
   così resta attivo anche dopo un riavvio
2. installa TightVNC come servizio e chiede la password VNC (6-8 caratteri)
3. crea la regola firewall `VNC via Tailscale` (TCP 5900 solo da `100.64.0.0/10`)
4. disattiva sospensione/ibernazione quando il PC è collegato alla corrente

Alla fine stampa nome e IP Tailscale del PC. Log in `windows/setup.log` (non versionato).

**Consigliato**: in <https://login.tailscale.com/admin/machines> → menu del PC →
*Disable key expiry*, altrimenti tra ~6 mesi il PC si scollega finché non rifai login.

## 2. Sul Mac (una volta)

```bash
git clone git@github.com:manumastro/remote.git
cd remote
chmod +x mac/*.sh
./mac/setup.sh
```

Installa Tailscale (Homebrew, o ti apre la pagina di download) e lo avvia:
fai login con **lo stesso account** usato sul PC.

## 3. Connettersi

```bash
./mac/connect.sh            # host di default: manustrong
./mac/connect.sh altro-pc   # oppure: REMOTE_HOST=altro-pc ./mac/connect.sh
```

Verifica che Tailscale sia attivo e il PC raggiungibile, poi apre *Condivisione Schermo*
su `vnc://<ip-tailscale>:5900`. Inserisci la password VNC scelta in fase di setup.

In alternativa, a mano: Finder → *Vai* → *Connessione al server…* → `vnc://manustrong`.

## Problemi comuni

| Sintomo | Soluzione |
|---|---|
| `Host non trovato` | Il PC non è nella stessa rete Tailscale: stesso account? `tailscale status` |
| `non risponde` | PC spento/in sospensione o senza Internet |
| Condivisione Schermo non si connette / schermo nero | Usa RealVNC Viewer: `brew install --cask vnc-viewer`, host `<ip>:5900` |
| Cambiare password VNC | Sul PC: menu Start → *TightVNC Service - Configuration* |
| Lento | In Condivisione Schermo: *Vista* → qualità *Adattiva*; oppure ridurre la risoluzione del PC |
