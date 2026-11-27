#!/bin/bash

LOG_FILE="extractor_$(date +%Y%m%d_%H%M%S).log"

log() {
    local ts
    ts="$(date +%H:%M:%S)"
    echo "[$ts] $*" | tee -a "$LOG_FILE"
}

run_tool() {
    local tool="$1"; shift
    log "--- START: $tool $* ---"
    { "./$tool" "$@" 2>&1; } | tee -a "$LOG_FILE"
    local rc="${PIPESTATUS[0]}"
    if [ "$rc" -ne 0 ]; then
        log "!!! $tool exited with code $rc !!!"
    else
        log "--- DONE:  $tool (exit 0) ---"
    fi
    return "$rc"
}

function Base {
    log "=== Extract Base ==="
    rm -rf dbc maps Cameras
    run_tool map_extractor
    Menu
}

function VMaps {
    log "=== Extract VMaps ==="
    mkdir -p Buildings vmaps
    rm -rf Buildings/* vmaps/*
    run_tool vmap4_extractor || { log "Aborting: vmap4_extractor failed, skipping assembler."; Menu; return; }
    run_tool vmap4_assembler Buildings vmaps
    rm -rf Buildings
    Menu
}

function MMaps {
    log "=== Extract MMaps (this may take a few hours) ==="
    mkdir -p mmaps
    rm -rf mmaps/*
    run_tool mmaps_generator
    Menu
}

function All {
    log "=== Extract All (this may take a few hours) ==="
    rm -rf dbc maps Cameras
    mkdir -p Buildings vmaps mmaps
    rm -rf Buildings/* vmaps/* mmaps/*
    run_tool map_extractor || { log "Aborting: map_extractor failed."; Menu; return; }
    run_tool vmap4_extractor || { log "Aborting: vmap4_extractor failed, skipping assembler/mmaps."; Menu; return; }
    run_tool vmap4_assembler Buildings vmaps || { log "Aborting: vmap4_assembler failed, skipping mmaps."; Menu; return; }
    rm -rf Buildings
    run_tool mmaps_generator
    log "=== All extractions complete ==="
    Menu
}

function Menu {
echo ""
echo "..............................................."
echo "AzerothCore dbc, maps, vmaps, mmaps extractor"
echo "..............................................."
echo "PRESS 1, 2, 3 OR 4 to select your task, or 5 to EXIT."
echo "..............................................."
echo ""
echo "WARNING! when extracting the vmaps extractor will"
echo "output the text below, it's intended and not an error:"
echo ".........................................."
echo "Extracting World\Wmo\Band\Final_Stage.wmo"
echo "No such file."
echo "Couldn't open RootWmo!!!"
echo "Done!"
echo " .........................................."
echo ""
echo "Press 1, 2, 3 or 4 to start extracting or 5 to exit."
echo "1 - Extract base files (NEEDED) and cameras."
echo "2 - Extract vmaps (needs maps to be extracted before you run this) (OPTIONAL, highly recommended)"
echo "3 - Extract mmaps (needs vmaps to be extracted before you run this, may take hours) (OPTIONAL, highly recommended)"
echo "4 - Extract all (may take hours)"
echo "5 - EXIT"
echo ""
echo "Log file: $LOG_FILE"
echo ""

read -rp "Type 1, 2, 3, 4 or 5 then press ENTER: " choice

case $choice in
    1) Base ;;
    2) VMaps ;;
    3) MMaps ;;
    4) All ;;
    5) log "Session ended."; exit 0;;
    *) echo "Invalid choice."; read -rp "Type 1, 2, 3, 4 or 5 then press ENTER: " choice ;;
esac
}

if [ -d "./Data" ] && [ -f "map_extractor" ] && [ -f "vmap4_extractor" ] && [ -f "vmap4_assembler" ] && [ -f "mmaps_generator" ]; then
    log "Extractor started. Log: $LOG_FILE"
    echo "The required files and folder exist in the current directory."
    chmod +x map_extractor vmap4_extractor vmap4_assembler mmaps_generator
    Menu
else
    echo "One or more of the required files or folder is missing from the current directory."
    echo "Place map_extractor vmap4_extractor vmap4_assembler mmaps_generator"
    echo "In your WoW folder with WoW.exe"
fi
