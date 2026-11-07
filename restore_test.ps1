# restore_test.ps1
# Simulacro de recuperación SOLO sobre foodstore_restore_test.
# Nunca tocar foodstore.
# Uso: powershell -ExecutionPolicy Bypass -File restore_test.ps1

$ErrorActionPreference = 'Stop'

$HostName = 'localhost'
$Port = '5432'
$User = 'postgres'

$TestDb = 'foodstore_restore_test'
$SrcDb = 'foodstore'

$BackupsDir = Join-Path $PSScriptRoot 'backups'
$LogsDir = Join-Path $PSScriptRoot 'logs'
$EvDir = Join-Path $PSScriptRoot 'evidencias'

New-Item -ItemType Directory -Force -Path $LogsDir | Out-Null
New-Item -ItemType Directory -Force -Path $EvDir | Out-Null

# Verificacion de seguridad: el destino debe ser exactamente la BD de prueba.
if ($TestDb -ne 'foodstore_restore_test') {
    throw 'Base destino insegura: debe ser foodstore_restore_test'
}

# Buscar el backup mas reciente.
$dumps = Get-ChildItem -LiteralPath $BackupsDir -Filter 'foodstore_*.dump' -File -ErrorAction SilentlyContinue |
    Sort-Object LastWriteTime -Descending

if (-not $dumps -or $dumps.Count -eq 0) {
    throw "No hay .dump en $BackupsDir"
}

$Dump = $dumps[0].FullName
$BackupTime = (Get-Item -LiteralPath $Dump).LastWriteTime

# El RTO comienza inmediatamente antes de preparar la BD de recuperacion.
$Start = Get-Date

function Ev([string]$m) {
    Add-Content -LiteralPath (Join-Path $EvDir 'evidencia_restore.txt') `
        -Value $m -Encoding UTF8
    Write-Host $m
}

$EvFile = Join-Path $EvDir 'evidencia_restore.txt'

if (Test-Path -LiteralPath $EvFile) {
    Remove-Item -LiteralPath $EvFile
}

Ev "Backup usado: $Dump"
Ev "Backup creado/modificado: $($BackupTime.ToString('yyyy-MM-dd HH:mm:ss'))"
Ev "Inicio restore: $($Start.ToString('yyyy-MM-dd HH:mm:ss'))"
Ev "Destino exclusivo del simulacro: $TestDb"

# ------------------------------------------------------------
# 1. Obtener conteos originales de foodstore ANTES del restore.
# ------------------------------------------------------------

$tables = @(
    'categoria',
    'cliente',
    'producto',
    'pedido',
    'detalle_pedido'
)

$originalCounts = @{}

foreach ($t in $tables) {

    $cOrig = (& psql -h $HostName -p $Port -U $User -d $SrcDb -tAc "SELECT COUNT(*) FROM $t;").Trim()

    if ($LASTEXITCODE -ne 0) {
        throw "No se pudo obtener el conteo original de $t desde foodstore"
    }

    if ($cOrig -notmatch '^\d+$') {
        throw "Conteo invalido para $t en foodstore: '$cOrig'"
    }

    $originalCounts[$t] = [int64]$cOrig

    Ev "Conteo original $t = $($originalCounts[$t])"
}

# ------------------------------------------------------------
# 2. Crear una BD de prueba limpia.
#    SOLO se permite destruir/recrear foodstore_restore_test.
# ------------------------------------------------------------

$existsOutput = & psql -h $HostName -p $Port -U $User -d postgres -tAc `
    "SELECT 1 FROM pg_database WHERE datname='$TestDb';"

if ($LASTEXITCODE -ne 0) {
    throw 'No se pudo verificar existencia de foodstore_restore_test'
}

$exists = ($existsOutput | Out-String).Trim()

if ($exists -match '^1$') {

    Ev "foodstore_restore_test ya existia. Se eliminara SOLO esta BD de prueba."

    & dropdb -h $HostName -p $Port -U $User $TestDb

    if ($LASTEXITCODE -ne 0) {
        throw "dropdb de $TestDb fallo con codigo $LASTEXITCODE"
    }

    Ev "foodstore_restore_test eliminada correctamente"
}

& createdb -h $HostName -p $Port -U $User $TestDb

if ($LASTEXITCODE -ne 0) {
    throw "createdb de $TestDb fallo con codigo $LASTEXITCODE"
}

Ev "foodstore_restore_test creada correctamente"

# ------------------------------------------------------------
# 3. Restaurar el backup.
# ------------------------------------------------------------

& pg_restore `
    -h $HostName `
    -p $Port `
    -U $User `
    -d $TestDb `
    --no-owner `
    --no-privileges `
    $Dump 2>&1 |
    ForEach-Object {
        Ev "pg_restore: $_"
    }

if ($LASTEXITCODE -ne 0) {
    Ev "ERROR pg_restore codigo $LASTEXITCODE"
    exit 1
}

Ev "pg_restore finalizado correctamente"

# ------------------------------------------------------------
# 4. Validar conteos y exigir igualdad.
# ------------------------------------------------------------

foreach ($t in $tables) {

    $cTest = (& psql -h $HostName -p $Port -U $User -d $TestDb -tAc `
        "SELECT COUNT(*) FROM $t;").Trim()

    if ($LASTEXITCODE -ne 0) {
        throw "No se pudo obtener el conteo restaurado de $t"
    }

    if ($cTest -notmatch '^\d+$') {
        throw "Conteo restaurado invalido para $t`: '$cTest'"
    }

    $restoreCount = [int64]$cTest
    $originalCount = $originalCounts[$t]

    Ev "Conteo $t foodstore=$originalCount restore=$restoreCount"

    if ($restoreCount -ne $originalCount) {
        throw "ERROR: conteo diferente en $t. foodstore=$originalCount restore=$restoreCount"
    }
}

Ev "VALIDACION: todos los conteos coinciden con foodstore"

# ------------------------------------------------------------
# 5. Validar productos invalidos.
# ------------------------------------------------------------

$invalidProducts = (& psql -h $HostName -p $Port -U $User -d $TestDb -tAc `
    "SELECT COUNT(*) FROM producto WHERE precio < 0 OR stock < 0;").Trim()

if ($LASTEXITCODE -ne 0) {
    throw 'No se pudo validar productos_invalidos'
}

if ($invalidProducts -notmatch '^\d+$') {
    throw "Resultado invalido para productos_invalidos: '$invalidProducts'"
}

Ev "productos_invalidos=$invalidProducts"

if ([int64]$invalidProducts -ne 0) {
    throw "ERROR: existen productos invalidos"
}

# ------------------------------------------------------------
# 6. Validar detalles invalidos.
# ------------------------------------------------------------

$invalidDetails = (& psql -h $HostName -p $Port -U $User -d $TestDb -tAc `
    "SELECT COUNT(*) FROM detalle_pedido WHERE cantidad <= 0 OR precio_unitario < 0;").Trim()

if ($LASTEXITCODE -ne 0) {
    throw 'No se pudo validar detalles_invalidos'
}

if ($invalidDetails -notmatch '^\d+$') {
    throw "Resultado invalido para detalles_invalidos: '$invalidDetails'"
}

Ev "detalles_invalidos=$invalidDetails"

if ([int64]$invalidDetails -ne 0) {
    throw "ERROR: existen detalles invalidos"
}

Ev "VALIDACION: productos_invalidos=0"
Ev "VALIDACION: detalles_invalidos=0"

# ------------------------------------------------------------
# 7. Finalizar y calcular RTO/RPO.
# ------------------------------------------------------------

$End = Get-Date

$RtoSec = ($End - $Start).TotalSeconds
$RpoSec = ($Start - $BackupTime).TotalSeconds

Ev "Fin restore: $($End.ToString('yyyy-MM-dd HH:mm:ss'))"
Ev "RTO_observado_segundos=$([math]::Round($RtoSec,2))"
Ev "RPO_observado_segundos=$([math]::Round($RpoSec,2))"
Ev "RESULTADO FINAL: RESTORE Y VALIDACIONES OK"

Write-Host ""
Write-Host "=========================================="
Write-Host "RESTORE TEST OK"
Write-Host "RTO observado: $([math]::Round($RtoSec,2)) segundos"
Write-Host "RPO observado: $([math]::Round($RpoSec,2)) segundos"
Write-Host "=========================================="