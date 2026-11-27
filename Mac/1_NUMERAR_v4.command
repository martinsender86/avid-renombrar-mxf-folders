#!/bin/bash
# 1_NUMERAR_v4.command  —  versión Mac de 1_NUMERAR_v4.bat
# Doble clic: pide la carpeta (arrastrarla a la ventana o elegirla en un diálogo).
cd "$(dirname "$0")" || exit 1
/bin/bash ./renombrar_v4.sh Numerar "$@"
echo
read -r -p "Apretá Enter para cerrar esta ventana..." _
