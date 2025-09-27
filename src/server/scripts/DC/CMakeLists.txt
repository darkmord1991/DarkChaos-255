# CMakeLists.txt for DC scripts

set(SCRIPTS_DC_AC
    AC/ac_guard_npc.cpp
)

# Add sources to AzerothCore scripts
set(SCRIPTS_WORLD
    ${SCRIPTS_WORLD}
    ${SCRIPTS_DC_AC}
)
