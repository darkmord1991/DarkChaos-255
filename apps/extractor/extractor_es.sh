#!/bin/bash

LOG_FILE="extractor_$(date +%Y%m%d_%H%M%S).log"

log() {
    local ts
    ts="$(date +%H:%M:%S)"
    echo "[$ts] $*" | tee -a "$LOG_FILE"
}

run_tool() {
    local tool="$1"; shift
    log "--- INICIO: $tool $* ---"
    { "./$tool" "$@" 2>&1; } | tee -a "$LOG_FILE"
    local rc="${PIPESTATUS[0]}"
    if [ "$rc" -ne 0 ]; then
        log "!!! $tool terminó con código $rc !!!"
    else
        log "--- FIN:    $tool (exit 0) ---"
    fi
    return "$rc"
}

function Base {
    log "=== Extrayendo archivos base ==="
    rm -rf dbc maps Cameras
    run_tool map_extractor
    Menu
}

function VMaps {
    log "=== Extrayendo VMaps ==="
    mkdir -p Buildings vmaps
    rm -rf Buildings/* vmaps/*
    run_tool vmap4_extractor || { log "Abortando: vmap4_extractor falló, se omite el ensamblador."; Menu; return; }
    run_tool vmap4_assembler Buildings vmaps
    rm -rf Buildings
    Menu
}

function MMaps {
    log "=== Extrayendo MMaps (esto puede tardar varias horas) ==="
    mkdir -p mmaps
    rm -rf mmaps/*
    run_tool mmaps_generator
    Menu
}

function All {
    log "=== Extrayendo todo (esto puede tardar varias horas) ==="
    rm -rf dbc maps Cameras
    mkdir -p Buildings vmaps mmaps
    rm -rf Buildings/* vmaps/* mmaps/*
    run_tool map_extractor || { log "Abortando: map_extractor falló."; Menu; return; }
    run_tool vmap4_extractor || { log "Abortando: vmap4_extractor falló, se omiten ensamblador/mmaps."; Menu; return; }
    run_tool vmap4_assembler Buildings vmaps || { log "Abortando: vmap4_assembler falló, se omiten mmaps."; Menu; return; }
    rm -rf Buildings
    run_tool mmaps_generator
    log "=== Todas las extracciones completadas ==="
    Menu
}

function Menu {
echo ""
echo "..............................................."
echo "Extractor de dbc, maps, vmaps, mmaps de AzerothCore"
echo "..............................................."
echo "PRESIONE 1, 2, 3 O 4 para seleccionar su tarea, o 5 para SALIR."
echo "..............................................."
echo ""
echo "ADVERTENCIA: al extraer los vmaps del extractor"
echo "la salida del texto de abajo, es intencional y no un error:"
echo ".........................................."
echo "Extracting World\Wmo\Band\Final_Stage.wmo"
echo "No such file."
echo "Couldn't open RootWmo!!!"
echo "Done!"
echo ".........................................."
echo ""
echo "Presione 1, 2, 3 o 4 para iniciar la extracción o 5 para salir."
echo "1 - Extraer los archivos base (NECESARIOS) y las cámaras."
echo "2 - Extraer vmaps (necesita que los mapas se extraigan antes de ejecutar esto) (OPCIONAL, muy recomendable)"
echo "3 - Extraer mmaps (necesita que los vmaps se extraigan antes de ejecutar esto, puede llevar horas) (OPCIONAL, muy recomendable)"
echo "4 - Extraer todo (puede llevar varias horas)"
echo "5 - SALIR"
echo ""
echo "Archivo de log: $LOG_FILE"
echo ""

read -rp "Escriba 1, 2, 3, 4 o 5 y pulse ENTER: " choice

case $choice in
    1) Base ;;
    2) VMaps ;;
    3) MMaps ;;
    4) All ;;
    5) log "Sesión finalizada."; exit 0;;
    *) echo "Opción inválida."; read -rp "Escriba 1, 2, 3, 4 o 5 y presione ENTER: " choice ;;
esac
}

if [ -d "./Data" ] && [ -f "map_extractor" ] && [ -f "vmap4_extractor" ] && [ -f "vmap4_assembler" ] && [ -f "mmaps_generator" ]; then
    log "Extractor iniciado. Log: $LOG_FILE"
    echo "Los archivos y carpetas requeridos existen en el directorio actual."
    chmod +x map_extractor vmap4_extractor vmap4_assembler mmaps_generator
    Menu
else
    echo "Uno o más archivos o carpetas requeridos no se encuentran en el directorio actual."
    echo "Coloque map_extractor vmap4_extractor vmap4_assembler mmaps_generator"
    echo "en su directorio de WoW junto con WoW.exe"
fi
