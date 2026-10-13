#Requires -Version 5.1
<#
  Configura questo PC Windows per essere controllato da remoto (da Mac) via:
    - Tailscale  : VPN mesh (WireGuard), nessuna porta da aprire sul router
    - TightVNC   : server VNC (Windows Home non ha il server RDP)

  Il server VNC accetta connessioni SOLO dalla rete Tailscale (100.64.0.0/10),
  sia tramite firewall di Windows sia tramite il filtro IP di TightVNC.

  Uso (da PowerShell, si auto-eleva ad amministratore):
    powershell -ExecutionPolicy Bypass -File .\windows\setup.ps1 [-VncPassword <6-8 caratteri>]
  Senza -VncPassword la password viene chiesta in modo interattivo.
#>
param([string]$VncPassword)

$ErrorActionPreference = 'Stop'

# --- Elevazione -------------------------------------------------------------
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).
    IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host 'Riavvio come amministratore...'
    $elevArgs = @('-NoExit', '-ExecutionPolicy', 'Bypass', '-File', "`"$PSCommandPath`"")
    if ($VncPassword) { $elevArgs += @('-VncPassword', $VncPassword) }
    Start-Process powershell.exe -Verb RunAs -ArgumentList $elevArgs
    exit
}

$logFile = Join-Path $PSScriptRoot 'setup.log'
Start-Transcript -Path $logFile -Append | Out-Null

$TailscaleCidr = '100.64.0.0/10'
$VncPort = 5900
$TailscaleExe = Join-Path $env:ProgramFiles 'Tailscale\tailscale.exe'

function Test-WingetPackage([string]$Id) {
    [bool](winget list --id $Id --exact --accept-source-agreements 2>$null | Select-String -SimpleMatch $Id)
}

function Install-WingetPackage([string]$Id, [string]$Override) {
    if (Test-WingetPackage $Id) {
        Write-Host "$Id gia' installato."
        return
    }
    $wingetArgs = @('install', '--id', $Id, '--exact', '--silent',
        '--accept-package-agreements', '--accept-source-agreements')
    if ($Override) { $wingetArgs += @('--override', $Override) }
    & winget @wingetArgs | Out-Host
    if ($LASTEXITCODE -ne 0) { throw "Installazione di $Id fallita (exit $LASTEXITCODE)" }
}

try {
    # --- 1. Tailscale (installazione; il login e' l'ultimo passo) ----------------
    Write-Host "`n== 1/5 Installazione Tailscale ==" -ForegroundColor Cyan
    Install-WingetPackage 'Tailscale.Tailscale'

    # --- 2. TightVNC (server come servizio) ---------------------------------------
    Write-Host "`n== 2/5 TightVNC server ==" -ForegroundColor Cyan
    if (Test-WingetPackage 'GlavSoft.TightVNC') {
        Write-Host "TightVNC gia' installato: per cambiare la password usa 'TightVNC Service - Configuration'."
    } else {
        $vncPass = $VncPassword
        while ($vncPass -notmatch '^[^\s"]{6,8}$') {
            if ($vncPass) { Write-Host 'Password non valida, riprova.' -ForegroundColor Yellow }
            $sec = Read-Host 'Scegli la password VNC (6-8 caratteri, niente spazi o virgolette)' -AsSecureString
            $vncPass = [Runtime.InteropServices.Marshal]::PtrToStringAuto(
                [Runtime.InteropServices.Marshal]::SecureStringToBSTR($sec))
        }

        # Consenti solo IP Tailscale (0 = allow), nega tutto il resto (1 = deny)
        $ipAcl = '100.64.0.0-100.127.255.255:0,0.0.0.0-255.255.255.255:1'
        $msiProps = @(
            '/quiet', '/norestart',
            'ADDLOCAL=Server',
            'SERVER_REGISTER_AS_SERVICE=1',
            'SERVER_ADD_FIREWALL_EXCEPTION=0',
            'SERVER_ALLOW_SAS=1',
            'SET_USEVNCAUTHENTICATION=1', 'VALUE_OF_USEVNCAUTHENTICATION=1',
            'SET_PASSWORD=1', "VALUE_OF_PASSWORD=$vncPass",
            'SET_USECONTROLAUTHENTICATION=1', 'VALUE_OF_USECONTROLAUTHENTICATION=1',
            'SET_CONTROLPASSWORD=1', "VALUE_OF_CONTROLPASSWORD=$vncPass",
            'SET_ACCEPTHTTPCONNECTIONS=1', 'VALUE_OF_ACCEPTHTTPCONNECTIONS=0',
            'SET_IPACCESSCONTROL=1', "VALUE_OF_IPACCESSCONTROL=$ipAcl"
        ) -join ' '
        Install-WingetPackage 'GlavSoft.TightVNC' $msiProps
        $vncPass = $null
    }
    Set-Service -Name tvnserver -StartupType Automatic
    Start-Service -Name tvnserver -ErrorAction SilentlyContinue
    Write-Host "Servizio tvnserver: $((Get-Service tvnserver).Status)"

    # --- 3. Firewall: VNC raggiungibile solo dalla rete Tailscale ------------------
    Write-Host "`n== 3/5 Firewall ==" -ForegroundColor Cyan
    $ruleName = 'VNC via Tailscale'
    Get-NetFirewallRule -DisplayName $ruleName -ErrorAction SilentlyContinue | Remove-NetFirewallRule
    New-NetFirewallRule -DisplayName $ruleName -Direction Inbound -Action Allow `
        -Protocol TCP -LocalPort $VncPort -RemoteAddress $TailscaleCidr -Profile Any | Out-Null
    Write-Host "Regola '$ruleName' creata (TCP $VncPort solo da $TailscaleCidr)."

    # --- 4. Alimentazione: niente sospensione con alimentatore collegato -----------
    Write-Host "`n== 4/5 Risparmio energetico ==" -ForegroundColor Cyan
    powercfg /change standby-timeout-ac 0
    powercfg /change hibernate-timeout-ac 0
    Write-Host 'Sospensione/ibernazione disattivate quando collegato alla corrente.'

    # --- 5. Login Tailscale --------------------------------------------------------
    # --unattended: Tailscale resta attivo anche a utente disconnesso / dopo riavvio
    Write-Host "`n== 5/5 Login Tailscale ==" -ForegroundColor Cyan
    Write-Host 'Apri il link che compare qui sotto e accedi con il tuo account.'
    cmd /c "`"$TailscaleExe`" up --unattended 2>&1" | ForEach-Object { Write-Host $_ }
    if ($LASTEXITCODE -ne 0) { throw 'tailscale up fallito' }

    # --- Riepilogo ----------------------------------------------------------------
    $status = & $TailscaleExe status --json | ConvertFrom-Json
    $ip = (& $TailscaleExe ip -4 | Select-Object -First 1)
    $dns = $status.Self.DNSName.TrimEnd('.')

    Write-Host "`n=========================================" -ForegroundColor Green
    Write-Host ' Configurazione completata'
    Write-Host "  Nome Tailscale : $($status.Self.HostName)"
    Write-Host "  MagicDNS       : $dns"
    Write-Host "  IP Tailscale   : $ip"
    Write-Host "  Dal Mac        : ./mac/connect.sh $($status.Self.HostName)"
    Write-Host "                   (oppure: open vnc://${ip}:$VncPort)"
    Write-Host '=========================================' -ForegroundColor Green
    Write-Host 'Consiglio: nella console Tailscale (login.tailscale.com/admin/machines)'
    Write-Host "disattiva 'Key expiry' per questo PC, altrimenti tra ~6 mesi va rifatto il login."
    Write-Host 'SETUP_DONE'
} catch {
    Write-Host "ERRORE: $_" -ForegroundColor Red
    Write-Host 'SETUP_FAILED'
    throw
} finally {
    Stop-Transcript | Out-Null
}
