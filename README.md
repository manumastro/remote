# remote

Controllo remoto del PC Windows da Mac, anche da un'altra rete, con **AnyDesk**
in modalità *accesso non presidiato*.

Non serve VPN, port forwarding né IP pubblico: AnyDesk passa dai suoi server
(funziona anche dietro CGNAT). Il PC resta raggiungibile dopo un riavvio e
anche senza che nessuno abbia fatto login.

> La versione gratuita di AnyDesk è **solo per uso personale**: se rileva un uso
> commerciale può limitare o bloccare le sessioni.

## 1. Sul PC Windows (una volta)

```powershell
git clone git@github.com:manumastro/remote.git
cd remote
powershell -ExecutionPolicy Bypass -File .\windows\setup.ps1
```

Lo script (chiede i permessi di amministratore):

1. installa AnyDesk come servizio che parte con Windows
2. chiede e imposta la password di accesso non presidiato (min 12 caratteri)
3. disattiva sospensione/ibernazione quando il PC è collegato alla corrente

Alla fine stampa l'**ID AnyDesk** del PC. Log in `windows/setup.log` (non versionato).

Consigliato: in AnyDesk sul PC → *Impostazioni* → *Sicurezza* → attiva
l'**autenticazione a due fattori** per l'accesso non presidiato.

## 2. Sul Mac (una volta)

```bash
git clone git@github.com:manumastro/remote.git
cd remote
./mac/setup.sh
```

## 3. Connettersi

```bash
./mac/connect.sh 123456789      # ID AnyDesk del PC
```

oppure apri AnyDesk e scrivi l'ID nella barra in alto. Inserisci la password di
accesso non presidiato (spunta *Accedi automaticamente in futuro* per non doverla
riscrivere). Conviene aggiungere il PC alla *Rubrica* di AnyDesk.

## Problemi comuni

| Sintomo | Soluzione |
|---|---|
| "Il client remoto non è in linea" | PC spento, in sospensione o senza Internet |
| Sul PC AnyDesk resta "offline" / ID `0` | Orologio sfasato: `w32tm /resync /force` (da admin), poi riavvia il servizio AnyDesk |
| Viene chiesto di accettare sul PC | Password non presidiata non impostata: rilancia `windows/setup.ps1` |
| Sessione chiusa dopo ~1 minuto | AnyDesk ha rilevato "uso commerciale" (licenza gratuita) |
| Cambiare password | Sul PC: AnyDesk → *Impostazioni* → *Sicurezza* → *Accesso non presidiato* |
