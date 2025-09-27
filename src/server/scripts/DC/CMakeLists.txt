# CMakeLists.txt for DC scripts

set(SCRIPTS_DC_AC
    AC/ac_guard_npc.cpp
    HinterlandBG/npc_thrall_warchief.cpp
    HinterlandBG/npc_Varian_hinterlandbg.cpp
    HinterlandBG/outdoorpvp_hl_registration.cpp
)

# Add sources to AzerothCore scripts
set(SCRIPTS_WORLD
    ${SCRIPTS_WORLD}
    ${SCRIPTS_DC_AC}
    ${SCRIPTS_DC_HinterlandBG}
)
