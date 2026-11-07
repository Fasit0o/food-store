# backup_foodstore.ps1 — Respaldo diario de foodstore (PostgreSQL 16+)
# Uso manual: powershell -ExecutionPolicy Bypass -File backup_foodstore.ps1
# Sin contrasena hardcodeada: usa autenticacion normal del entorno.

$ErrorActionPreference = 'Stop'

$HostName = 'localhost'
$Port = '5432'
$User = 'postgres'
$Db = 'foodstore'
$BackupsDir = Join-Path $PSScriptRoot 'backups'
$LogsDir = Join-Path $PSScriptRoot 'logs'

New-Item -ItemType Directory -Force -Path $BackupsDir | Out-Null
New-Item -ItemType Directory -Force -Path $LogsDir | Out-Null

$Start = Get-Date
$Stamp = $Start.ToString('yyyyMMdd_HHmmss')
$DumpFile = Join-Path $BackupsDir ("foodstore_{0}.dump" -f $Stamp)
$LogFile = Join-Path $LogsDir ("backup_{0}.log" -f $Stamp)

function Write-Log([string]$Msg) {
    $line = "[{0}] {1}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Msg
    Add-Content -LiteralPath $LogFile -Value $line -Encoding UTF8
    Write-Host $line
}

Write-Log "INICIO backup base=$Db host=$HostName puerto=$Port usuario=$User"
Write-Log "Archivo destino: $DumpFile"

try {
    & pg_dump -h $HostName -p $Port -U $User -Fc -f $DumpFile $Db 2>&1 | ForEach-Object { Write-Log "pg_dump: $_" }
    if ($LASTEXITCODE -ne 0) { throw "pg_dump salio con codigo $LASTEXITCODE" }
    if (-not (Test-Path -LiteralPath $DumpFile)) { throw 'No se genero el archivo .dump' }
    $Size = (Get-Item -LiteralPath $DumpFile).Length
    $End = Get-Date
    Write-Log "FIN backup OK inicio=$($Start.ToString('yyyy-MM-dd HH:mm:ss')) fin=$($End.ToString('yyyy-MM-dd HH:mm:ss')) tamanio_bytes=$Size archivo=$DumpFile"
    exit 0
} catch {
    Write-Log "ERROR: $($_.Exception.Message)"
    exit 1
}
