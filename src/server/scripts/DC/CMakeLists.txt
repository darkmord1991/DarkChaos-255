# CMakeLists.txt for DC scripts (Updated to force re-scan)

# Prestige System scripts
set(SCRIPTS_DC_Prestige
    Prestige/dc_prestige_system.cpp
    Prestige/dc_prestige_system.cpp
    # Prestige/dc_prestige_chat.cpp (Moved to Commands)
    Prestige/dc_prestige_spells.cpp
    Prestige/dc_prestige_spells.cpp
    Prestige/dc_prestige_alt_bonus.cpp
    Prestige/dc_prestige_challenges.cpp
    Prestige/spell_prestige_alt_bonus_aura.cpp
)

set(SCRIPTS_DC_ChallengeMode
    Progression/ChallengeMode/dc_challenge_modes_customized.cpp
    Progression/ChallengeMode/ChallengeModeScripts.cpp
    Progression/ChallengeMode/dc_challenge_mode_database.cpp
    Progression/ChallengeMode/dc_challenge_mode_equipment_restrictions.cpp
    Progression/ChallengeMode/dc_challenge_mode_enforcement.cpp
    Progression/ChallengeMode/spell_challenge_mode_auras.cpp
)

# Hotspot System scripts
set(SCRIPTS_DC_Hotspot
    Hotspot/ac_hotspots.cpp
    Hotspot/HotspotDefines.cpp
    Hotspot/HotspotGrid.cpp
    Hotspot/HotspotMgr.cpp
    Hotspot/HotspotScripts.cpp
    Commands/HotspotCommands.cpp
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

# AoE Loot System (Unified)
set(SCRIPTS_DC_AoELoot
    dc_aoeloot_unified.cpp
)

# Phased Duels System
set(SCRIPTS_DC_PhasedDuels
    PhasedDuels/dc_phased_duels.cpp
)

# Main AC scripts
set(SCRIPTS_DC_AC
    dc_script_loader.cpp
    AC/ac_guard_npc.cpp
    AC/ac_flightmasters.cpp
    AC/ac_quest_npc_800009.cpp
    HinterlandBG/npc_thrall_warchief.cpp
    HinterlandBG/npc_Varian_hinterlandbg.cpp
    HinterlandBG/outdoorpvp_hl_registration.cpp
    HinterlandBG/npc_hinterlands_battlemaster.cpp
    # HinterlandBG/hlbg_addon.cpp (moved into AddonExtension/dc_addon_hlbg.cpp)
    HinterlandBG/hlbg_native_broadcast.cpp
    HinterlandBG/HL_ScoreboardNPC.cpp
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
    HinterlandBG/OutdoorPvPHL_Admin.cpp
    HinterlandBG/OutdoorPvPHL_Queue.cpp
    HinterlandBG/OutdoorPvPHL_Commands.cpp
    HinterlandBG/OutdoorPvPHL_StateMachine.cpp
    HinterlandBG/OutdoorPvPHL_Utils.cpp
    HinterlandBG/OutdoorPvPHL_Performance.cpp
    HinterlandBG/OutdoorPvPHL_Affixes.cpp
    # HinterlandBG/cs_hl_bg.cpp (Moved to Commands)
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
    ItemUpgrades/ItemUpgradeNPC_Vendor.cpp
    ItemUpgrades/ItemUpgradeNPC_Curator.cpp
    ItemUpgrades/ItemUpgradeTokenHooks.cpp
)

# Phase 4A: Item Upgrade Mechanics
set(SCRIPTS_DC_ItemUpgrade_Phase4A
    ItemUpgrades/ItemUpgradeManager.cpp
    ItemUpgrades/ItemUpgradeMechanicsImpl.cpp
    ItemUpgrades/ItemUpgradeStatApplication.cpp
    ItemUpgrades/ItemUpgradeProcScaling.cpp
    ItemUpgrades/ItemUpgradeProcScaling.cpp
    # ItemUpgrades/dc_item_upgrade_commands.cpp (Moved to Commands)
    ItemUpgrades/heirloom_scaling_255.cpp
    ItemUpgrades/go_heirloom_cache.cpp
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
    # ItemUpgrades/ItemUpgradeCommunication.cpp (Removed)
    # ItemUpgrades/ItemUpgradeAddonHandler.cpp (Removed)
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
    # Seasons/SeasonalRewardCommands.cpp (Moved to Commands)
)

# DC Mythic+ System - Dungeon Scaling, Keystone System & Spectator
set(SCRIPTS_DC_MythicPlus
    MythicPlus/MythicDifficultyScaling.h
    MythicPlus/MythicDifficultyScaling.cpp
    MythicPlus/MythicPlusRunManager.h
    MythicPlus/MythicPlusRunManager.cpp
    MythicPlus/MythicPlusSeasonalIntegration.cpp
    MythicPlus/go_mythic_plus_font_of_power.cpp
    MythicPlus/npc_mythic_token_vendor.cpp
    MythicPlus/mythic_plus_core_scripts.cpp
    MythicPlus/mythic_plus_loader.cpp
    MythicPlus/npc_dungeon_portal_selector.cpp
    MythicPlus/dc_mythic_spectator.cpp
)

# DC Great Vault System
set(SCRIPTS_DC_GreatVault
    GreatVault/GreatVault.h
    GreatVault/GreatVault.cpp
    GreatVault/GreatVaultUtils.h
    GreatVault/npc_great_vault.cpp
)

# DC Addon Extension System - Unified client/server protocol
    AddonExtension/dc_addon_extension_loader.cpp
    AddonExtension/dc_addon_protocol.cpp
    AddonExtension/dc_addon_aoeloot.cpp
    AddonExtension/dc_addon_upgrade.cpp
    AddonExtension/dc_addon_transmutation.cpp
    AddonExtension/dc_addon_mythicplus.cpp
    AddonExtension/dc_addon_spectator.cpp
    AddonExtension/dc_addon_hotspot.cpp
    AddonExtension/dc_addon_world.cpp
    AddonExtension/dc_addon_death_markers.cpp
    AddonExtension/dc_addon_hlbg.cpp
    AddonExtension/dc_addon_seasons.cpp
    AddonExtension/dc_addon_leaderboards.cpp
    AddonExtension/dc_addon_welcome.cpp
    AddonExtension/dc_addon_duels.cpp
    AddonExtension/dc_addon_prestige.cpp
    AddonExtension/dc_addon_groupfinder.cpp
    AddonExtension/dc_addon_groupfinder_mgr.cpp
    AddonExtension/dc_addon_groupfinder_npc.cpp
    AddonExtension/dc_addon_collection.cpp
    AddonExtension/dc_addon_wardrobe.cpp
)

# DC Collection System - Retail-like collection management (Split Structure)
set(SCRIPTS_DC_CollectionSystem
    CollectionSystem/CollectionCore.cpp
    CollectionSystem/CollectionMounts.cpp
    CollectionSystem/CollectionPets.cpp
    CollectionSystem/CollectionHeirlooms.cpp
    CollectionSystem/CollectionTitles.cpp
)

set(SCRIPTS_DC_FirstStart
    Progression/FirstStart/dc_firststart.cpp
    Progression/FirstStart/dc_login_announce.cpp
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
    CrossSystem/DCSpawnResolver.cpp
    CrossSystem/WorldBossMgr.cpp
)

# DC Commands - Unified command hub
set(SCRIPTS_DC_Commands
    Commands/cs_dc_addons.cpp
    Commands/cs_dc_dungeonquests.cpp
    Commands/cs_hl_bg.cpp
    Commands/mythic_plus_commands.cpp
    Commands/SeasonalRewardCommands.cpp
    Commands/dc_prestige_chat.cpp
    Commands/dc_item_upgrade_commands.cpp
    Commands/cs_dc_guildhouse.cpp
    Commands/cs_dc_perftest.cpp
)

# DC Guild Housing
set(SCRIPTS_DC_GuildHousing
    GuildHousing/mod_guildhouse.cpp
    GuildHousing/mod_guildhouse_npcs.cpp
    GuildHousing/mod_guildhouse_butler.cpp
    GuildHousing/guildhouse_manager.cpp
)

# DC Teleporters
set(SCRIPTS_DC_Teleporters
    Teleporters/dc_teleporter.cpp
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
    ${SCRIPTS_DC_GreatVault}
    ${SCRIPTS_DC_DungeonEnhancement}
    ${SCRIPTS_DC_Jadeforest}
    ${SCRIPTS_DC_GiantIsles}
    ${SCRIPTS_DC_AddonExtension}
    ${SCRIPTS_DC_CollectionSystem}
    ${SCRIPTS_DC_FirstStart}
    ${SCRIPTS_DC_GOMove}
    ${SCRIPTS_DC_CrossSystem}
    ${SCRIPTS_DC_Commands}
    ${SCRIPTS_DC_GuildHousing}
    ${SCRIPTS_DC_Teleporters}
)

# The DC HinterlandBG config was merged into the consolidated
# custom config (Custom/Config files/darkchaos-custom.conf.dist).
# Do not copy the legacy hinterlandbg.conf.dist here because it may
# not exist in this repository layout.
