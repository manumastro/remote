#Requires -Version 5.1
<#
  Configura questo PC Windows per essere controllato da remoto (da Mac) con AnyDesk
  in modalita' "accesso non presidiato":
    - AnyDesk installato come servizio, parte con Windows (anche senza login)
    - password per l'accesso non presidiato
    - niente sospensione/ibernazione quando collegato alla corrente

  Uso (da PowerShell, si auto-eleva ad amministratore):
    powershell -ExecutionPolicy Bypass -File .\windows\setup.ps1 [-PasswordFile <file>]
  -PasswordFile: file con la password (viene letto e poi CANCELLATO).
  Senza -PasswordFile la password viene chiesta in modo interattivo.
#>
param([string]$PasswordFile)

$ErrorActionPreference = 'Stop'

# --- Elevazione -------------------------------------------------------------
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).
    IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host 'Riavvio come amministratore...'
    $elevArgs = @('-NoExit', '-ExecutionPolicy', 'Bypass', '-File', "`"$PSCommandPath`"")
    if ($PasswordFile) { $elevArgs += @('-PasswordFile', "`"$PasswordFile`"") }
    Start-Process powershell.exe -Verb RunAs -ArgumentList $elevArgs
    exit
}

$logFile = Join-Path $PSScriptRoot 'setup.log'
Start-Transcript -Path $logFile -Append | Out-Null

$InstallDir = Join-Path ${env:ProgramFiles(x86)} 'AnyDesk'
$AnyDeskExe = Join-Path $InstallDir 'AnyDesk.exe'

try {
    # --- 1. Installazione AnyDesk come servizio -----------------------------------
    Write-Host "`n== 1/3 Installazione AnyDesk ==" -ForegroundColor Cyan
    # Con l'orologio sfasato anche di un minuto i server AnyDesk rifiutano il
    # certificato del client (ssl_a000415) e il PC resta "offline" con ID 0.
    Set-Service w32time -StartupType Automatic
    Start-Service w32time
    w32tm /config /manualpeerlist:"time.windows.com,0x9 pool.ntp.org,0x9" /syncfromflags:manual /update | Out-Null
    w32tm /resync /force | Out-Null
    Write-Host 'Orologio sincronizzato.'

    if (Test-Path $AnyDeskExe) {
        Write-Host "AnyDesk gia' installato."
    } else {
        # winget download verifica l'hash; l'installer lo lanciamo noi con i parametri giusti
        $dl = Join-Path $env:TEMP "anydesk-setup-$(Get-Random)"
        & winget download --id AnyDesk.AnyDesk --exact --download-directory $dl `
            --accept-package-agreements --accept-source-agreements | Out-Host
        if ($LASTEXITCODE -ne 0) { throw "Download di AnyDesk fallito (exit $LASTEXITCODE)" }
        $installer = Get-ChildItem $dl -Filter *.exe | Select-Object -First 1
        $p = Start-Process $installer.FullName -Wait -PassThru -ArgumentList @(
            '--install', "`"$InstallDir`"", '--start-with-win', '--create-shortcuts',
            '--create-desktop-icon', '--silent')
        Remove-Item $dl -Recurse -Force
        if ($p.ExitCode -ne 0 -or -not (Test-Path $AnyDeskExe)) {
            throw "Installazione di AnyDesk fallita (exit $($p.ExitCode))"
        }
        # il servizio impiega qualche secondo a registrarsi
        for ($i = 0; $i -lt 30 -and -not (Get-Service AnyDesk -ErrorAction SilentlyContinue); $i++) { Start-Sleep 1 }
    }
    Set-Service -Name AnyDesk -StartupType Automatic
    Start-Service -Name AnyDesk -ErrorAction SilentlyContinue
    Write-Host "Servizio AnyDesk: $((Get-Service AnyDesk).Status)"

    # --- 2. Password per l'accesso non presidiato ---------------------------------
    Write-Host "`n== 2/3 Accesso non presidiato ==" -ForegroundColor Cyan
    if ($PasswordFile) {
        $pass = (Get-Content -Raw $PasswordFile).Trim()
        Remove-Item $PasswordFile -Force
    }
    while ($pass -notmatch '^[A-Za-z0-9]{12,}$') {
        if ($pass) { Write-Host 'Password non valida, riprova.' -ForegroundColor Yellow }
        $sec = Read-Host 'Password accesso non presidiato (min 12 caratteri, solo lettere e numeri)' -AsSecureString
        $pass = [Runtime.InteropServices.Marshal]::PtrToStringAuto(
            [Runtime.InteropServices.Marshal]::SecureStringToBSTR($sec))
    }
    cmd /c "echo $pass| `"$AnyDeskExe`" --set-password" | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "Impostazione password fallita (exit $LASTEXITCODE)" }
    $pass = $null
    Write-Host 'Password impostata.'

    # --- 3. Alimentazione: niente sospensione con alimentatore collegato -----------
    Write-Host "`n== 3/3 Risparmio energetico ==" -ForegroundColor Cyan
    powercfg /change standby-timeout-ac 0
    powercfg /change hibernate-timeout-ac 0
    Write-Host 'Sospensione/ibernazione disattivate quando collegato alla corrente.'

    # --- Riepilogo ----------------------------------------------------------------
    $id = $null
    for ($i = 0; $i -lt 30 -and -not $id; $i++) {
        $id = ((& $AnyDeskExe --get-id | Out-String).Trim()) -replace '\D', ''
        if (-not $id) { Start-Sleep 2 }
    }
    Write-Host "`n=========================================" -ForegroundColor Green
    Write-Host ' Configurazione completata'
    Write-Host "  ID AnyDesk : $id"
    Write-Host "  Dal Mac    : ./mac/connect.sh $id"
    Write-Host '=========================================' -ForegroundColor Green
    Write-Host 'SETUP_DONE'
} catch {
    Write-Host "ERRORE: $_" -ForegroundColor Red
    Write-Host 'SETUP_FAILED'
    throw
} finally {
    Stop-Transcript | Out-Null
}
