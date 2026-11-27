# Renombrar MXF Folders — v4

Scripts para preparar carpetas de media para **Avid Media Composer** (Windows y Mac).

## Qué hace

Dos pasos, de ida y vuelta:

1. **Numerar**: renombra las subcarpetas de una carpeta a `1001`, `1002`… (el formato numérico que Avid espera en `Avid MediaFiles/MXF`) y guarda una tabla `_nombres_originales.csv` con los nombres originales.
2. **Restaurar**: les devuelve el nombre **original normalizado**:
   - `2025-11-10 Entrevista Carlos` → `20251110_Entrevista_Carlos`
   - Fecha inicial `AAAA-MM-DD` → `AAAAMMDD`
   - Espacios y guiones → guion bajo (sin repetidos): `Juan-Pablo` → `Juan_Pablo`
   - Sin tildes ni diéresis: `Pérez` → `Perez`, `Güemes` → `Guemes`, `Peña` → `Pena`

Solo toca **nombres de carpeta**, nunca el contenido. La tabla es compatible entre Windows y Mac: se puede numerar en una máquina y restaurar en la otra.

## Requisitos

Nada: usa PowerShell en Windows y bash en Mac.

## Cómo se usa

- **Windows:** doble clic en `Windows/1_NUMERAR_v4.bat` o `Windows/2_RESTAURAR_v4.bat` y elegí la carpeta que **contiene** las carpetas a renombrar.
  Por consola: `renombrar_v4.ps1 -Modo Numerar|Restaurar [-Carpeta "D:\..."] [-Inicio 1001]`
- **Mac:** doble clic en `Mac/1_NUMERAR_v4.command` o `Mac/2_RESTAURAR_v4.command` y arrastrá la carpeta (o Enter para elegirla en una ventana). Ver `Mac/LEEME.txt` para habilitar los scripts la primera vez.
