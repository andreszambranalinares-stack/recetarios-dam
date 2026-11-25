# Copia los recetarios desde Google Drive a este repo y, si alguno ha cambiado,
# hace commit y push. GitHub Pages publica la web sola tras cada push.
# Lo lanza la tarea programada "Recetarios DAM sync" (via sync.vbs, sin ventana).
# A mano: powershell -ExecutionPolicy Bypass -File sync.ps1

$ErrorActionPreference = 'Stop'
$repo = $PSScriptRoot
$log  = Join-Path $repo 'sync.log'

function Write-Log($msg) {
    "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')  $msg" | Out-File -FilePath $log -Append -Encoding utf8
}

$dam = 'G:\Mi unidad\2º DAM'
$recetarios = [ordered]@{
    'recetario-pmdm.html'  = "$dam\Programacion Multimedia\Recetario\recetario-pmdm.html"
    'recetario-psp.html'   = "$dam\Programacion de Servicios y Procesos\Recetario\recetario-psp.html"
    'recetario-deint.html' = "$dam\Desarrollo de Interfaces\Recetario\recetario-deint.html"
    'recetario-python.html' = "$dam\Sistemas de Gestion Empresarial\Recetario\recetario-python.html"
    'esquema-mvvm-adopta.html' = "$dam\Desarrollo de Interfaces\Recetario\esquema-mvvm-adopta.html"
}

$git = 'C:\Program Files\Git\cmd\git.exe'
if (-not (Test-Path $git)) { $git = 'git' }

try {
    if (-not (Test-Path $dam)) { Write-Log 'Google Drive (G:) no disponible; no hago nada.'; exit 0 }

    # Trae primero lo que se haya subido desde otro equipo, para que el push no choque
    Set-Location $repo
    $ErrorActionPreference = 'Continue'
    & $git pull -q --rebase --autostash 2>&1 | Out-Null
    if ($LASTEXITCODE -ne 0) { Write-Log 'Pull fallido (¿sin red o conflicto?); sigo con la copia local.' }
    $ErrorActionPreference = 'Stop'

    $cambiados = @()
    foreach ($destino in $recetarios.Keys) {
        $origen = $recetarios[$destino]
        if (-not (Test-Path $origen)) { Write-Log "No existe $origen"; continue }
        $dst = Join-Path $repo $destino
        if (-not (Test-Path $dst) -or
            (Get-FileHash $origen).Hash -ne (Get-FileHash $dst).Hash) {
            Copy-Item $origen $dst -Force
            $cambiados += $destino
        }
    }

    Set-Location $repo
    $ErrorActionPreference = 'Continue'   # git escribe avisos por stderr: que no corten el script
    & $git add -A
    $pendiente = & $git status --porcelain
    if ($pendiente) {
        $nombres = if ($cambiados) { $cambiados -join ', ' } else { 'repo' }
        & $git commit -q -m "Actualiza $nombres"
        Write-Log "Commit: $nombres"
    }

    # Empuja si hay commits sin subir (también los que fallaron antes por no haber red)
    $sinSubir = & $git rev-list --count '@{u}..HEAD' 2>$null
    if ($LASTEXITCODE -ne 0 -or [int]$sinSubir -gt 0) {
        & $git push -q 2>&1 | Out-Null
        if ($LASTEXITCODE -eq 0) { Write-Log 'Push hecho.' } else { Write-Log 'Push fallido (¿sin red?); se reintenta en la próxima pasada.' }
    }
}
catch {
    Write-Log "ERROR: $_"
    exit 1
}
