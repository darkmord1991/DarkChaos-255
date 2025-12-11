# CMakeLists.txt for DC scripts

# Prestige System scripts
set(SCRIPTS_DC_Prestige
    Prestige/dc_prestige_system.cpp
    Prestige/dc_prestige_spells.cpp
    Prestige/dc_prestige_alt_bonus.cpp
    Prestige/dc_prestige_challenges.cpp
    Prestige/spell_prestige_alt_bonus_aura.cpp
)

# Challenge Mode scripts
set(SCRIPTS_DC_ChallengeMode
    ChallengeMode/dc_challenge_modes_customized.cpp
    ChallengeMode/dc_challenge_mode_database.cpp
    ChallengeMode/spell_challenge_mode_auras.cpp
)

# Hotspot System scripts
set(SCRIPTS_DC_Hotspot
    Hotspot/ac_hotspots.cpp
    Hotspot/spell_hotspot_buff_800001.cpp
    Hotspot/spell_hotspot_xp_buff.cpp
)

# Jadeforest Zone scripts
set(SCRIPTS_DC_Jadeforest
    Jadeforest/jadeforest_flightmaster.cpp
    Jadeforest/jadeforest_guards.cpp
)

# Giant Isles Zone scripts (Ported from MoP Isle of Giants)
set(SCRIPTS_DC_GiantIsles
    GiantIsles/dc_giant_isles_zone.cpp
    GiantIsles/dc_giant_isles_invasion.cpp
    GiantIsles/boss_oondasta.cpp
    GiantIsles/boss_thok.cpp
    GiantIsles/boss_nalak.cpp
)

# AoE Loot System (Base + Extensions)
set(SCRIPTS_DC_AoELoot
    ac_aoeloot.cpp
    dc_aoeloot_extensions.cpp
)

# Phased Duels System
set(SCRIPTS_DC_PhasedDuels
    PhasedDuels/dc_phased_duels.cpp
)

# Main AC scripts
set(SCRIPTS_DC_AC
    AC/ac_guard_npc.cpp
    AC/cs_flighthelper_test.cpp
    heirloom_scaling_255.cpp
    dc_login_announce.cpp
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
    # MapExtension/cs_gps_test.cpp  # DISABLED - requires AIO which is not compiled
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

# DC Dungeon Quest System implementation
set(SCRIPTS_DC_DungeonQuests
    DungeonQuests/DungeonQuestSystem.cpp
    DungeonQuests/DungeonQuestPhasing.cpp
    DungeonQuests/npc_dungeon_quest_master.cpp
    DungeonQuests/npc_dungeon_quest_daily_weekly.cpp
)

# DC Item Upgrade System implementation
# Phase 3: Token System
set(SCRIPTS_DC_ItemUpgrade_Phase3
    ItemUpgrades/ItemUpgradeCommand.cpp
    ItemUpgrades/ItemUpgradeNPC_Vendor.cpp
    ItemUpgrades/ItemUpgradeNPC_Curator.cpp
    ItemUpgrades/ItemUpgradeTokenHooks.cpp
    ItemUpgrades/ItemUpgradeGMCommands.cpp
)

# Phase 4A: Item Upgrade Mechanics
set(SCRIPTS_DC_ItemUpgrade_Phase4A
    ItemUpgrades/ItemUpgradeManager.cpp
    ItemUpgrades/ItemUpgradeMechanicsImpl.cpp
    ItemUpgrades/ItemUpgradeMechanicsCommands.cpp
    ItemUpgrades/ItemUpgradeStatApplication.cpp
    ItemUpgrades/ItemUpgradeProcScaling.cpp
)

# Phase 4B: Progression System (Artifact Mastery)
set(SCRIPTS_DC_ItemUpgrade_Phase4B
    ItemUpgrades/ItemUpgradeProgressionImpl.cpp
)

# Phase 4C: Seasonal System
set(SCRIPTS_DC_ItemUpgrade_Phase4C
    ItemUpgrades/ItemUpgradeSeasonalImpl.cpp
)

# Phase 4D: Advanced Features (Respec, Achievements, Guild Progression)
set(SCRIPTS_DC_ItemUpgrade_Phase4D
    ItemUpgrades/ItemUpgradeAdvancedImpl.cpp
)

# Phase 4E: Client Communication
set(SCRIPTS_DC_ItemUpgrade_Phase4E
    ItemUpgrades/ItemUpgradeCommunication.cpp
    ItemUpgrades/ItemUpgradeAddonHandler.cpp
)

# Phase 4F: Transmutation System
set(SCRIPTS_DC_ItemUpgrade_Phase4F
    ItemUpgrades/ItemUpgradeSynthesisImpl.cpp
    ItemUpgrades/ItemUpgradeTierConversionImpl.cpp
    ItemUpgrades/ItemUpgradeTransmutationImpl.cpp
    ItemUpgrades/ItemUpgradeTransmutationNPC.cpp
)

# DC Seasonal System - Independent Framework
set(SCRIPTS_DC_SeasonalSystem
    Seasons/SeasonalSystem.h
    Seasons/SeasonalSystem.cpp
    Seasons/SeasonalSystemTest.cpp
    Seasons/HLBGSeasonalParticipant.cpp
)

# DC Seasonal Reward System - C++ Core Implementation
set(SCRIPTS_DC_SeasonalRewards
    Seasons/SeasonalRewardSystem.h
    Seasons/SeasonalRewardSystem.cpp
    Seasons/SeasonalRewardScripts.cpp
    Seasons/SeasonalRewardCommands.cpp
)

# DC Mythic+ System - Dungeon Scaling, Keystone System & Spectator
set(SCRIPTS_DC_MythicPlus
    MythicPlus/MythicDifficultyScaling.h
    MythicPlus/MythicDifficultyScaling.cpp
    MythicPlus/MythicPlusRunManager.h
    MythicPlus/MythicPlusRunManager.cpp
    MythicPlus/MythicPlusSeasonalIntegration.cpp
    MythicPlus/go_mythic_plus_font_of_power.cpp
    MythicPlus/npc_mythic_plus_great_vault.cpp
    MythicPlus/mythic_plus_core_scripts.cpp
    MythicPlus/mythic_plus_loader.cpp
    MythicPlus/npc_dungeon_portal_selector.cpp
    MythicPlus/dc_mythic_spectator.cpp
)

# DC Addon Extension System - Unified client/server protocol
set(SCRIPTS_DC_AddonExtension
    AddonExtension/dc_addon_extension_loader.cpp
    AddonExtension/dc_addon_protocol.cpp
    AddonExtension/dc_addon_aoeloot.cpp
    AddonExtension/dc_addon_upgrade.cpp
    AddonExtension/dc_addon_mythicplus.cpp
    AddonExtension/dc_addon_spectator.cpp
    AddonExtension/dc_addon_hotspot.cpp
    AddonExtension/dc_addon_world.cpp
    AddonExtension/dc_addon_hlbg.cpp
    AddonExtension/dc_addon_seasons.cpp
    AddonExtension/dc_addon_leaderboards.cpp
    AddonExtension/dc_addon_welcome.cpp
    AddonExtension/dc_addon_duels.cpp
    AddonExtension/dc_addon_prestige.cpp
)

# DC First Start System - First-start experience, login system
set(SCRIPTS_DC_FirstStart
    FirstStart/dc_firststart.cpp
)

# GOMove System
set(SCRIPTS_DC_GOMove
    GOMove/GOMove.cpp
    GOMove/GOMoveScripts.cpp
)

# Cross-System Integration Framework
set(SCRIPTS_DC_CrossSystem
    CrossSystem/SessionContext.cpp
    CrossSystem/EventBus.cpp
    CrossSystem/RewardDistributor.cpp
    CrossSystem/CrossSystemManager.cpp
    CrossSystem/CrossSystemScripts.cpp
)

set(SCRIPTS_DC_ItemUpgrade
    ${SCRIPTS_DC_ItemUpgrade_Phase3}
    ${SCRIPTS_DC_ItemUpgrade_Phase4A}
    ${SCRIPTS_DC_ItemUpgrade_Phase4B}
    ${SCRIPTS_DC_ItemUpgrade_Phase4C}
    ${SCRIPTS_DC_ItemUpgrade_Phase4D}
    ${SCRIPTS_DC_ItemUpgrade_Phase4E}
    ${SCRIPTS_DC_ItemUpgrade_Phase4F}
    ${SCRIPTS_DC_SeasonalSystem}
    ${SCRIPTS_DC_SeasonalRewards}
)

# Add sources to AzerothCore scripts
set(SCRIPTS_WORLD
    ${SCRIPTS_WORLD}
    ${SCRIPTS_DC_Prestige}
    ${SCRIPTS_DC_ChallengeMode}
    ${SCRIPTS_DC_Hotspot}
    ${SCRIPTS_DC_AoELoot}
    ${SCRIPTS_DC_PhasedDuels}
    ${SCRIPTS_DC_AC}
    ${SCRIPTS_DC_HinterlandBG}
    ${SCRIPTS_DC_Gilneas}
    ${SCRIPTS_DC_DungeonQuests}
    ${SCRIPTS_DC_ItemUpgrade}
    ${SCRIPTS_DC_MythicPlus}
    ${SCRIPTS_DC_DungeonEnhancement}
    ${SCRIPTS_DC_Jadeforest}
    ${SCRIPTS_DC_GiantIsles}
    ${SCRIPTS_DC_AddonExtension}
    ${SCRIPTS_DC_FirstStart}
    ${SCRIPTS_DC_GOMove}
    ${SCRIPTS_DC_CrossSystem}
)

# The DC HinterlandBG config was merged into the consolidated
# custom config (Custom/Config files/darkchaos-custom.conf.dist).
# Do not copy the legacy hinterlandbg.conf.dist here because it may
# not exist in this repository layout.
