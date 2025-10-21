# CMakeLists.txt for DC scripts

set(SCRIPTS_DC_AC
    AC/ac_guard_npc.cpp
    AC/cs_flighthelper_test.cpp
    HinterlandBG/npc_thrall_warchief.cpp
    HinterlandBG/npc_Varian_hinterlandbg.cpp
    HinterlandBG/outdoorpvp_hl_registration.cpp
)

# DC HinterlandBG split implementations (config, rewards, reset, afk)
set(SCRIPTS_DC_HinterlandBG
    HinterlandBG/OutdoorPvPHL_Config.cpp
    HinterlandBG/OutdoorPvPHL_Rewards.cpp
    HinterlandBG/OutdoorPvPHL_Reset.cpp
    HinterlandBG/OutdoorPvPHL_AFK.cpp
    HinterlandBG/OutdoorPvPHL_Announce.cpp
    HinterlandBG/OutdoorPvPHL_Groups.cpp
    HinterlandBG/OutdoorPvPHL_JoinLeave.cpp
    HinterlandBG/OutdoorPvPHL_Thresholds.cpp
    HinterlandBG/OutdoorPvPHL_Worldstates.cpp
    HinterlandBG/OutdoorPvPHL_Admin.cpp
)

# DC Gilneas Battle for Gilneas implementation
set(SCRIPTS_DC_Gilneas
    Gilneas/BattlegroundBFG.cpp
)

# Add sources to AzerothCore scripts
set(SCRIPTS_WORLD
    ${SCRIPTS_WORLD}
    ${SCRIPTS_DC_AC}
    ${SCRIPTS_DC_HinterlandBG}
    ${SCRIPTS_DC_Gilneas}
)

# Expose module config to the modules installer
set(MODULE_CONFIG_PATH ${CMAKE_CURRENT_SOURCE_DIR}/HinterlandBG)
set(configFileName hinterlandbg.conf.dist)
CopyModuleConfig("${MODULE_CONFIG_PATH}/${configFileName}")
