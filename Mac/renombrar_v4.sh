#!/bin/bash
# renombrar_v4.sh  —  versión Mac de renombrar_v4.ps1 (mismo comportamiento)
#
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
# El _nombres_originales.csv es el mismo formato que el de Windows:
# se puede numerar en una máquina y restaurar en la otra.
#
# Uso:  renombrar_v4.sh Numerar|Restaurar [carpeta] [inicio]
#       (sin carpeta: pide arrastrarla a la ventana o elegirla en un diálogo)
#
# Compatible con el bash 3.2 que trae toda Mac. Usa perl (viene con macOS).

MODO="${1:-}"
CARPETA="${2:-}"
INICIO="${3:-1001}"

ROJO=$'\033[31m'; AMARILLO=$'\033[33m'; VERDE=$'\033[32m'; NORMAL=$'\033[0m'
rojo()     { printf '%s%s%s\n' "$ROJO" "$*" "$NORMAL"; }
amarillo() { printf '%s%s%s\n' "$AMARILLO" "$*" "$NORMAL"; }
verde()    { printf '%s%s%s\n' "$VERDE" "$*" "$NORMAL"; }

case "$MODO" in
    Numerar|Restaurar) ;;
    *) rojo "Uso: $0 Numerar|Restaurar [carpeta] [inicio]"; exit 1 ;;
esac
case "$INICIO" in
    ''|*[!0-9]*) rojo "El inicio tiene que ser un número: $INICIO"; exit 1 ;;
esac
if ! command -v perl >/dev/null 2>&1; then
    rojo "No encuentro perl en esta Mac (hace falta para sacar las tildes)."; exit 1
fi

# --- Nombre final normalizado (misma regla que Convertir-Nombre del .ps1) ---
convertir_nombre() {
    printf '%s' "$1" | perl -CSD -MUnicode::Normalize -0777 -ne '
        s/^\s+|\s+$//g;
        my ($fecha, $resto) = ("", $_);
        if (/^(\d{4})-(\d{2})-(\d{2})(.*)$/s) { $fecha = "$1$2$3"; $resto = $4; }
        $resto = NFD($resto);
        $resto =~ s/\p{Mn}//g;              # se descartan los acentos
        $resto = NFC($resto);
        $resto =~ s/[\s\-_]+/_/g;           # espacios y guiones -> un guion bajo
        $resto =~ s/^_+|_+$//g;
        print( ($fecha ne "" && $resto ne "") ? "${fecha}_$resto" : ($fecha ne "" ? $fecha : $resto) );
    '
}

# --- CSV (mismo formato que Export-Csv de PowerShell: UTF-8 con BOM, comillas, CRLF) ---
csv_campo() { printf '"%s"' "$(printf '%s' "$1" | sed 's/"/""/g')"; }
csv_cabecera() { printf '\357\273\277"Original","Nuevo","Final"\r\n' > "$1"; }
csv_fila() {   # archivo original nuevo final
    printf '%s,%s,%s\r\n' "$(csv_campo "$2")" "$(csv_campo "$3")" "$(csv_campo "$4")" >> "$1"
}
# Lee el CSV (de Mac o de Windows) y devuelve "Original<TAB>Nuevo<TAB>Final" por línea.
csv_leer() {
    perl -CSD -ne '
        s/^\x{FEFF}//; s/\r?\n\z//; next unless length;
        my @f;
        while (/\G(?:"((?:[^"]|"")*)"|([^,]*))(,|\z)/g) {
            my ($q, $s, $sep) = ($1, $2, $3);
            my $v = defined $q ? $q : $s; $v =~ s/""/"/g; push @f, $v;
            last if $sep eq "";
        }
        if (!@h) { @h = @f; next }
        my %r; @r{@h} = @f;
        print join("\t", map { defined $_ ? $_ : "" } @r{qw(Original Nuevo Final)}), "\n";
    ' "$1"
}

# --- Elegir carpeta madre ---
if [ -z "$CARPETA" ]; then
    echo "Arrastrá a esta ventana la carpeta que CONTIENE las carpetas a renombrar"
    echo "y apretá Enter (o apretá Enter solo para elegirla en una ventana):"
    # shellcheck disable=SC2162
    # read sin -r a propósito: así se deshacen las "\ " que pone la Terminal al arrastrar
    read -p "> " CARPETA
    CARPETA="${CARPETA%\"}"; CARPETA="${CARPETA#\"}"
    CARPETA="${CARPETA%\'}"; CARPETA="${CARPETA#\'}"
    if [ -z "$CARPETA" ]; then
        CARPETA=$(osascript -e 'POSIX path of (choose folder with prompt "Elegí la carpeta que CONTIENE las carpetas a renombrar")' 2>/dev/null)
        if [ -z "$CARPETA" ]; then echo "Cancelado."; exit 0; fi
    fi
fi
[ "$CARPETA" != "/" ] && CARPETA="${CARPETA%/}"
if [ ! -d "$CARPETA" ]; then
    rojo "No existe la carpeta: $CARPETA"; exit 1
fi

MAPA="$CARPETA/_nombres_originales.csv"
echo "Carpeta: $CARPETA"
echo

if [ "$MODO" = "Numerar" ]; then

    if [ -e "$MAPA" ]; then
        rojo "Ya hay un _nombres_originales.csv aca. Restaura primero antes de volver a numerar."
        exit 1
    fi

    # Subcarpetas (sin las ocultas), ordenadas sin distinguir mayúsculas, como en Windows
    shopt -s nullglob
    LISTA=$(for d in "$CARPETA"/*/; do d="${d%/}"; printf '%s\n' "${d##*/}"; done | LC_ALL=C sort -f)
    shopt -u nullglob

    N=$INICIO
    HECHOS=0
    while IFS= read -r NOMBRE; do
        [ -z "$NOMBRE" ] && continue
        case "$NOMBRE" in
            *[!0-9]*) ;;
            *) echo "Salteo (ya es numero): $NOMBRE"; continue ;;
        esac
        while [ -e "$CARPETA/$N" ]; do N=$((N + 1)); done
        NUEVO="$N"
        FINAL=$(convertir_nombre "$NOMBRE")
        [ -z "$FINAL" ] && FINAL="$NOMBRE"
        if ! ERR=$(mv -n -- "$CARPETA/$NOMBRE" "$CARPETA/$NUEVO" 2>&1) || [ ! -d "$CARPETA/$NUEVO" ]; then
            echo
            rojo "ERROR: no pude renombrar '$NOMBRE': $ERR"
            echo "Se frena aca. Se guarda el mapa de lo que SI se renombro."
            break
        fi
        # El mapa se escribe a medida que avanza: si se corta, igual queda registrado
        [ $HECHOS -eq 0 ] && csv_cabecera "$MAPA"
        csv_fila "$MAPA" "$NOMBRE" "$NUEVO" "$FINAL"
        HECHOS=$((HECHOS + 1))
        echo "$NOMBRE  ->  $NUEVO   (volvera como: $FINAL)"
        N=$((N + 1))
    done <<< "$LISTA"
    echo
    verde "$HECHOS carpetas renombradas. Mapa: $MAPA"

else

    if [ ! -e "$MAPA" ]; then
        rojo "No encuentro _nombres_originales.csv en esta carpeta. Nada para restaurar."
        exit 1
    fi

    FILAS=$(csv_leer "$MAPA")
    PEND="$MAPA.pendientes.$$"
    : > "$PEND"
    NPEND=0
    TAB=$(printf '\t')

    while IFS="$TAB" read -r ORIGINAL NUEVO FINAL; do
        [ -z "$NUEVO" ] && continue
        # Compatible con mapas viejos (sin columna Final)
        [ -z "$FINAL" ] && FINAL=$(convertir_nombre "$ORIGINAL")
        [ -z "$FINAL" ] && FINAL="$ORIGINAL"

        ACTUAL="$CARPETA/$NUEVO"
        DESTINO="$CARPETA/$FINAL"

        if [ ! -e "$ACTUAL" ]; then
            amarillo "No encuentro '$NUEVO' (iba a '$FINAL')"
            printf '%s\t%s\t%s\n' "$ORIGINAL" "$NUEVO" "$FINAL" >> "$PEND"; NPEND=$((NPEND + 1)); continue
        fi
        if [ -e "$DESTINO" ]; then
            amarillo "Ya existe '$FINAL', no piso nada. Queda como '$NUEVO'"
            printf '%s\t%s\t%s\n' "$ORIGINAL" "$NUEVO" "$FINAL" >> "$PEND"; NPEND=$((NPEND + 1)); continue
        fi
        if ERR=$(mv -n -- "$ACTUAL" "$DESTINO" 2>&1) && [ -e "$DESTINO" ]; then
            echo "$NUEVO  ->  $FINAL"
        else
            amarillo "No pude renombrar '$NUEVO': $ERR"
            printf '%s\t%s\t%s\n' "$ORIGINAL" "$NUEVO" "$FINAL" >> "$PEND"; NPEND=$((NPEND + 1))
        fi
    done <<< "$FILAS"

    if [ $NPEND -eq 0 ]; then
        BACKUP="$CARPETA/_nombres_originales_restaurado_$(date +%Y%m%d_%H%M%S).csv"
        K=2
        while [ -e "$BACKUP" ]; do
            BACKUP="$CARPETA/_nombres_originales_restaurado_$(date +%Y%m%d_%H%M%S)_$K.csv"; K=$((K + 1))
        done
        mv -- "$MAPA" "$BACKUP"
        rm -f "$PEND"
        echo
        verde "Todo restaurado. Respaldo del mapa: $BACKUP"
    else
        NUEVO_MAPA="$MAPA.nuevo.$$"
        csv_cabecera "$NUEVO_MAPA"
        while IFS="$TAB" read -r ORIGINAL NUEVO FINAL; do
            csv_fila "$NUEVO_MAPA" "$ORIGINAL" "$NUEVO" "$FINAL"
        done < "$PEND"
        mv -- "$NUEVO_MAPA" "$MAPA"
        rm -f "$PEND"
        echo
        amarillo "Quedan $NPEND sin restaurar. Cerra lo que las este usando y volve a correr Restaurar."
    fi
fi
