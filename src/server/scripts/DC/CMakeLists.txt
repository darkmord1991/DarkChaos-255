# CMakeLists.txt for DC scripts

# Prestige System scripts
set(SCRIPTS_DC_Prestige
    Prestige/dc_prestige_system.cpp
    Prestige/dc_prestige_spells.cpp
)

# Challenge Mode scripts
set(SCRIPTS_DC_ChallengeMode
    ChallengeMode/dc_challenge_modes_customized.cpp
    ChallengeMode/dc_challenge_mode_database.cpp
    ChallengeMode/dc_challenge_mode_gameobject.cpp
    ChallengeMode/spell_challenge_mode_auras.cpp
)

# Hotspot System scripts
set(SCRIPTS_DC_Hotspot
    Hotspot/ac_hotspots.cpp
    Hotspot/spell_hotspot_buff_800001.cpp
    Hotspot/spell_hotspot_xp_buff.cpp
)

# Main AC scripts
set(SCRIPTS_DC_AC
    AC/ac_guard_npc.cpp
    AC/cs_flighthelper_test.cpp
    heirloom_scaling_255.cpp
    dc_login_announce.cpp
    ac_aoeloot.cpp
    AC/ac_flightmasters.cpp
    AC/ac_flightmasters_data.cpp
    AC/ac_flightmasters_path.cpp
    AC/ac_quest_npc_800009.cpp
    HinterlandBG/npc_thrall_warchief.cpp
    HinterlandBG/npc_Varian_hinterlandbg.cpp
    HinterlandBG/outdoorpvp_hl_registration.cpp
    HinterlandBG/npc_hinterlands_battlemaster.cpp
    HinterlandBG/hlbg_addon.cpp
    HinterlandBG/hlbg_native_broadcast.cpp
    HinterlandBG/HL_StatsAIO.cpp
    HinterlandBG/HL_ScoreboardNPC.cpp
    HinterlandBG/HLBG_Integration_Helper.cpp
    HinterlandBG/HLBG_Queue_AIO_Extension.cpp
    HinterlandBG/HLBG_AIO_Handlers.cpp
    AIO/aio_bridge.cpp
    MapExtension/cs_gps_test.cpp
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
    HinterlandBG/OutdoorPvPHL_Queue.cpp
    HinterlandBG/OutdoorPvPHL_Commands.cpp
    HinterlandBG/OutdoorPvPHL_StateMachine.cpp
    HinterlandBG/OutdoorPvPHL_Utils.cpp
    HinterlandBG/OutdoorPvPHL_Performance.cpp
    HinterlandBG/OutdoorPvPHL_Affixes.cpp
)

# DC Gilneas Battle for Gilneas implementation
set(SCRIPTS_DC_Gilneas
    Gilneas/BattlegroundBFG.cpp
)

# Add sources to AzerothCore scripts
set(SCRIPTS_WORLD
    ${SCRIPTS_WORLD}
    ${SCRIPTS_DC_Prestige}
    ${SCRIPTS_DC_ChallengeMode}
    ${SCRIPTS_DC_Hotspot}
    ${SCRIPTS_DC_AC}
    ${SCRIPTS_DC_HinterlandBG}
    ${SCRIPTS_DC_Gilneas}
)

# The DC HinterlandBG config was merged into the consolidated
# custom config (Custom/Config files/darkchaos-custom.conf.dist).
# Do not copy the legacy hinterlandbg.conf.dist here because it may
# not exist in this repository layout.
