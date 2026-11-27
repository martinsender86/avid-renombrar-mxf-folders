# renombrar_v4.ps1
# 1) Numerar:   renombra las subcarpetas a 1001, 1002... y guarda la tabla.
# 2) Restaurar: las devuelve con el nombre ORIGINAL NORMALIZADO:
#      "2025-11-10 Entrevista Carlos"  ->  "20251110_Entrevista_Carlos"
#    - Fecha inicial AAAA-MM-DD  -> AAAAMMDD
#    - Despues de la fecha       -> guion bajo
#    - Espacios y guiones entre palabras -> guion bajo (sin repetidos)
#      "Juan-Pablo" -> "Juan_Pablo"
#    - Sin tildes ni dieresis: "Pérez" -> "Perez", "Güemes" -> "Guemes"
#      (la ñ queda como n: "Peña" -> "Pena")
#    - Si no empieza con fecha, se aplica lo mismo al nombre entero.
# Solo toca NOMBRES de carpeta, nunca el contenido.
#
# Uso:  -Modo Numerar | Restaurar
#       -Carpeta "D:\..." (opcional; si no se pasa, abre un selector)
#       -Inicio 1001      (opcional)

param(
    [Parameter(Mandatory = $true)][ValidateSet('Numerar', 'Restaurar')][string]$Modo,
    [string]$Carpeta,
    [int]$Inicio = 1001
)
$ErrorActionPreference = 'Stop'

function Convertir-Nombre([string]$nombre) {
    $nombre = $nombre.Trim()
    $fecha  = ''
    $resto  = $nombre
    if ($nombre -match '^(\d{4})-(\d{2})-(\d{2})(.*)$') {
        $fecha = "$($matches[1])$($matches[2])$($matches[3])"
        $resto = $matches[4]
    }
    # Sacar tildes: se separa cada letra de su acento y se descarta el acento
    $resto = $resto.Normalize([Text.NormalizationForm]::FormD)
    $resto = -join ($resto.ToCharArray() | Where-Object {
        [Globalization.CharUnicodeInfo]::GetUnicodeCategory($_) -ne [Globalization.UnicodeCategory]::NonSpacingMark })
    $resto = $resto.Normalize([Text.NormalizationForm]::FormC)
    $resto = $resto -replace '[\s\-_]+', '_'           # espacios y guiones -> un guion bajo
    $resto = $resto.Trim('_')                           # sin separadores sueltos en los bordes
    if ($fecha -and $resto) { return "${fecha}_$resto" }
    if ($fecha)             { return $fecha }
    return $resto
}

# --- Elegir carpeta madre ---
if (-not $Carpeta) {
    Add-Type -AssemblyName System.Windows.Forms
    $dlg = New-Object System.Windows.Forms.FolderBrowserDialog
    $dlg.Description = "Elegi la carpeta que CONTIENE las carpetas a renombrar"
    if ($dlg.ShowDialog() -ne 'OK') { Write-Host "Cancelado."; exit }
    $Carpeta = $dlg.SelectedPath
}
if (-not (Test-Path -LiteralPath $Carpeta -PathType Container)) {
    Write-Host "No existe la carpeta: $Carpeta" -ForegroundColor Red; exit 1
}

$mapa = Join-Path $Carpeta '_nombres_originales.csv'
Write-Host "Carpeta: $Carpeta`n"

if ($Modo -eq 'Numerar') {

    if (Test-Path -LiteralPath $mapa) {
        Write-Host "Ya hay un _nombres_originales.csv aca. Restaura primero antes de volver a numerar." -ForegroundColor Red
        exit 1
    }

    $dirs     = Get-ChildItem -LiteralPath $Carpeta -Directory | Sort-Object Name
    $ocupados = @($dirs.Name)
    $hechos   = New-Object System.Collections.Generic.List[object]
    $n        = $Inicio

    try {
        foreach ($d in $dirs) {
            if ($d.Name -match '^\d+$') { Write-Host "Salteo (ya es numero): $($d.Name)"; continue }
            while ($ocupados -contains "$n") { $n++ }
            $nuevo = "$n"
            $final = Convertir-Nombre $d.Name
            Rename-Item -LiteralPath $d.FullName -NewName $nuevo
            $hechos.Add([pscustomobject]@{ Original = $d.Name; Nuevo = $nuevo; Final = $final })
            $ocupados += $nuevo
            Write-Host "$($d.Name)  ->  $nuevo   (volvera como: $final)"
            $n++
        }
    }
    catch {
        Write-Host "`nERROR: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "Se frena aca. Se guarda el mapa de lo que SI se renombro."
    }
    finally {
        if ($hechos.Count -gt 0) {
            $hechos | Export-Csv -LiteralPath $mapa -NoTypeInformation -Encoding UTF8
        }
    }
    Write-Host "`n$($hechos.Count) carpetas renombradas. Mapa: $mapa" -ForegroundColor Green
}
else {

    if (-not (Test-Path -LiteralPath $mapa)) {
        Write-Host "No encuentro _nombres_originales.csv en esta carpeta. Nada para restaurar." -ForegroundColor Red
        exit 1
    }

    $filas      = Import-Csv -LiteralPath $mapa -Encoding UTF8
    $pendientes = New-Object System.Collections.Generic.List[object]

    foreach ($f in $filas) {
        # Compatible con mapas viejos (sin columna Final)
        $final = if ($f.PSObject.Properties['Final'] -and $f.Final) { $f.Final } else { Convertir-Nombre $f.Original }

        $actual  = Join-Path $Carpeta $f.Nuevo
        $destino = Join-Path $Carpeta $final

        if (-not (Test-Path -LiteralPath $actual)) {
            Write-Host "No encuentro '$($f.Nuevo)' (iba a '$final')" -ForegroundColor Yellow
            $pendientes.Add($f); continue
        }
        if (Test-Path -LiteralPath $destino) {
            Write-Host "Ya existe '$final', no piso nada. Queda como '$($f.Nuevo)'" -ForegroundColor Yellow
            $pendientes.Add($f); continue
        }
        try {
            Rename-Item -LiteralPath $actual -NewName $final
            Write-Host "$($f.Nuevo)  ->  $final"
        }
        catch {
            Write-Host "No pude renombrar '$($f.Nuevo)': $($_.Exception.Message)" -ForegroundColor Yellow
            $pendientes.Add($f)
        }
    }

    if ($pendientes.Count -eq 0) {
        $backup = Join-Path $Carpeta ("_nombres_originales_restaurado_{0}.csv" -f (Get-Date -Format 'yyyyMMdd_HHmmss'))
        Move-Item -LiteralPath $mapa -Destination $backup
        Write-Host "`nTodo restaurado. Respaldo del mapa: $backup" -ForegroundColor Green
    }
    else {
        $pendientes | Export-Csv -LiteralPath $mapa -NoTypeInformation -Encoding UTF8
        Write-Host "`nQuedan $($pendientes.Count) sin restaurar. Cerra lo que las este usando y volve a correr Restaurar." -ForegroundColor Yellow
    }
}
