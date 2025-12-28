#!/bin/bash
function Base {
    echo "Extract Base"
    rm -rf dbc maps Cameras
    ./map_extractor
    Menu
}

function VMaps {
    echo "Extract VMaps"
    mkdir -p Buildings vmaps
    rm -rf Buildings/* vmaps/*
    ./vmap4_extractor
    ./vmap4_assembler Buildings vmaps
    rmdir -rf Buildings
    Menu
}

function MMaps {
    echo "This may take a few hours to complete. Please be patient."
    mkdir -p mmaps
    rm -rf mmaps/*
    ./mmaps_generator
    Menu
}

function All {
    echo "This may take a few hours to complete. Please be patient."
    rm -rf dbc maps Cameras
    mkdir -p Buildings vmaps mmaps
    rm -rf Buildings/* vmaps/* mmaps/*
    ./map_extractor
    ./vmap4_extractor
    ./vmap4_assembler Buildings vmaps
    rmdir -rf Buildings
    ./mmaps_generator
    Menu
}

function SingleMap {
    read -rp "Enter Map ID: " MAP_ID
    if [[ -z "$MAP_ID" ]]; then
        echo "No Map ID entered."
        Menu
        return
    fi
    echo "Extracting Map $MAP_ID..."
    
    # Base
    # Note: map_extractor handles its own optional cleaning if specific map?? 
    # Actually, for single map, we probably SHOULD NOT delete everything
    # But current extractor tools overwrite anyway.
    # We should NOT run 'rm -rf' here.
    
    ./map_extractor -m "$MAP_ID"
    
    # VMaps
    echo "Extracting VMaps for Map $MAP_ID..."
    mkdir -p Buildings vmaps
    ./vmap4_extractor -m "$MAP_ID"
    ./vmap4_assembler Buildings vmaps "$MAP_ID"
    # Don't delete Buildings folder as it might contain other maps' data if not cleaned?
    # Or cleaner to just let it be.
    
    # MMaps
    echo "Extracting MMaps for Map $MAP_ID..."
    mkdir -p mmaps
    ./mmaps_generator "$MAP_ID"
    
    Menu
}

function Menu {
echo ""
echo "..............................................."
echo "AzerothCore dbc, maps, vmaps, mmaps extractor"
echo "..............................................."
echo "PRESS 1, 2, 3, 4 OR 6 to select your task, or 5 to EXIT."
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
echo "Press 1, 2, 3, 4 or 6 to start extracting or 5 to exit."
echo "1 - Extract base files (NEEDED) and cameras."
echo "2 - Extract vmaps (needs maps to be extracted before you run this) (OPTIONAL, highly recommended)"
echo "3 - Extract mmaps (needs vmaps to be extracted before you run this, may take hours) (OPTIONAL, highly recommended)"
echo "4 - Extract all (may take hours)"
echo "5 - EXIT"
echo "6 - Extract Specific Map (Maps, VMaps, MMaps)"
echo ""

read -rp "Type 1-6 then press ENTER: " choice

case $choice in
    1) Base ;;
    2) VMaps ;;
    3) MMaps ;;
    4) All ;;
    5) exit 0;;
    6) SingleMap ;;
    *) echo "Invalid choice."; read -rp "Type 1-6 then press ENTER: " choice ;;
esac
}

if [ -d "./Data" ] && [ -f "map_extractor" ] && [ -f "vmap4_extractor" ] && [ -f "vmap4_assembler" ] && [ -f "mmaps_generator" ]; then
    echo "The required files and folder exist in the current directory."
    chmod +x map_extractor vmap4_extractor vmap4_assembler mmaps_generator
    Menu
else
    echo "One or more of the required files or folder is missing from the current directory."
    echo "Place map_extractor vmap4_extractor vmap4_assembler mmaps_generator"
    echo "In your WoW folder with WoW.exe"
fi
