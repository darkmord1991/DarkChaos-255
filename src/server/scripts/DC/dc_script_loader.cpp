/*
 * This file is part of the AzerothCore Project. See AUTHORS file for
 * Copyright information.
 *
 * This program is free software; you can redistribute it and/or modify it
 * under the terms of the GNU Affero General Public License as published by the
 * Free Software Foundation; either version 3 of the License, or (at your
 * option) any later version.
 *
 * This program is distributed in the hope that it will be useful, but WITHOUT
 * ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
 * FITNESS FOR A PARTICULAR PURPOSE. See the GNU Affero General Public License
 * for more details.
 *
 * You should have received a copy of the GNU General Public License along
 * with this program. If not, see <http://www.gnu.org/licenses/>.
 */

#include "Common.h"
#include "Log.h"
#include "ScriptMgr.h"

#include <exception>
#include <utility>

// ============================================================================
// Forward Declarations - DC Script Entry Points
// ============================================================================

// --- Core AC scripts ---
void AddSC_ac_guard_npc();                    // AC/ac_guard_npc.cpp
void AddSC_dc_login_announce();               // Progression/FirstStart/dc_login_announce.cpp
void AddSC_ac_quest_npc_800009();             // AC/ac_quest_npc_800009.cpp
void AddSC_flightmasters();                   // AC/ac_flightmasters.cpp

// --- Jadeforest zone ---
void AddSC_jadeforest_flightmaster();         // Jadeforest/jadeforest_flightmaster.cpp
void AddSC_jadeforest_guards();               // Jadeforest/jadeforest_guards.cpp
void AddSC_jadeforest_training_grounds();     // Jadeforest/jadeforest_training_grounds.cpp

// --- Giant Isles zone ---
void AddSC_giant_isles_zone();                // GiantIsles/dc_giant_isles_zone.cpp
void AddSC_giant_isles_cannon_quest();        // GiantIsles/dc_giant_isles_cannon_quest.cpp
void AddSC_giant_isles_invasion();            // GiantIsles/dc_giant_isles_invasion.cpp
void AddSC_boss_oondasta();                   // GiantIsles/boss_oondasta.cpp
void AddSC_boss_thok();                       // GiantIsles/boss_thok.cpp
void AddSC_boss_nalak();                      // GiantIsles/boss_nalak.cpp
void AddSC_dc_giant_isles_water_monster();    // GiantIsles/dc_giant_isles_water_monster.cpp

// --- Heirloom system ---
void AddSC_heirloom_scaling_255();            // ItemUpgrades/heirloom_scaling_255.cpp
void AddSC_go_heirloom_cache();               // ItemUpgrades/go_heirloom_cache.cpp

// --- AoE loot system ---
void AddSC_dc_aoeloot_unified();              // dc_aoeloot_unified.cpp

// --- Hotspots system ---
void AddSC_ac_hotspots();                     // Hotspot/ac_hotspots.cpp
void AddSC_spell_hotspot_buff_800001();       // Hotspot/spell_hotspot_buff_800001.cpp

// --- Battle for Gilneas ---
void AddBattleForGilneasScripts();            // Gilneas/BattlegroundBFG.cpp

// --- Hinterland battleground system ---
void AddSC_npc_thrall_hinterlandbg();         // HinterlandBG/hlbg_npc_thrall_warchief.cpp
void AddSC_hinterlandbg_Varian_wrynn();       // HinterlandBG/hlbg_npc_varian.cpp
void AddSC_hl_scoreboard();                   // HinterlandBG/hlbg_scoreboard_npc.cpp
void AddSC_hlbg_addon();                      // AddonExtension/dc_addon_hlbg.cpp
void AddSC_npc_hinterlands_battlemaster();    // HinterlandBG/hlbg_npc_battlemaster.cpp
void AddSC_hlbg_battlemaster_hook();          // HinterlandBG/hlbg_battlemaster_hook.cpp
void AddSC_hlbg_native_broadcast();           // HinterlandBG/hlbg_native_broadcast.cpp
void AddSC_outdoorpvp_hl_dc();                // HinterlandBG/outdoorpvp_hl_registration.cpp

// --- Prestige system ---
void AddSC_dc_prestige_system();              // Progression/Prestige/dc_prestige_system.cpp
void AddSC_dc_prestige_spells();              // Progression/Prestige/dc_prestige_spells.cpp
void AddSC_dc_prestige_alt_bonus();           // Progression/Prestige/dc_prestige_alt_bonus.cpp
void AddSC_dc_prestige_challenges();          // Progression/Prestige/dc_prestige_challenges.cpp
void AddSC_spell_prestige_alt_bonus_aura();   // Progression/Prestige/spell_prestige_alt_bonus_aura.cpp

// --- Challenge mode system ---
void AddSC_dc_challenge_modes();              // Progression/ChallengeMode/dc_challenge_modes_customized.cpp
void AddSC_challenge_mode_scripts();          // Progression/ChallengeMode/ChallengeModeScripts.cpp
void AddSC_dc_challenge_mode_equipment_restrictions();
// Progression/ChallengeMode/dc_challenge_mode_equipment_restrictions.cpp
void AddSC_dc_challenge_mode_enforcement();   // Progression/ChallengeMode/dc_challenge_mode_enforcement.cpp
void AddSC_spell_challenge_mode_auras();      // Progression/ChallengeMode/spell_challenge_mode_auras.cpp

// --- Custom achievements ---
void AddSC_dc_achievements();                 // Achievements/dc_achievements.cpp

// --- GOMove system ---
void AddSC_GOMove_commandscript();            // GOMove/GOMoveScripts.cpp

// --- Item upgrade system ---
void AddSC_ItemUpgradeMechanicsImpl();        // ItemUpgrades/ItemUpgradeMechanicsImpl.cpp
void AddSC_ItemUpgradeProgression();          // ItemUpgrades/ItemUpgradeProgressionImpl.cpp
void AddSC_ItemUpgradeAdvanced();             // ItemUpgrades/ItemUpgradeAdvancedImpl.cpp
void AddSC_ItemUpgradeVendor();               // ItemUpgrades/ItemUpgradeNPC_Vendor.cpp
void AddSC_ItemUpgradeCurator();              // ItemUpgrades/ItemUpgradeNPC_Curator.cpp
void AddSC_ItemUpgradeSeasonal();             // ItemUpgrades/ItemUpgradeSeasonalImpl.cpp
void AddSC_ItemUpgradeExchange();             // ItemUpgrades/ItemUpgradeExchangeNPC.cpp
void AddSC_ItemUpgradeTokenHooks();           // ItemUpgrades/ItemUpgradeTokenHooks.cpp
void AddSC_ItemUpgradeProcScaling();          // ItemUpgrades/ItemUpgradeProcScaling.cpp
void AddSC_ItemUpgradeStatApplication();      // ItemUpgrades/ItemUpgradeStatApplication.cpp

// --- Mythic+ dungeon system ---
void AddMythicPlusScripts();                  // MythicPlus/dc_mythicplus_loader.cpp
void AddSC_dc_mythic_spectator();             // MythicPlus/dc_mythicplus_spectator.cpp

// --- Seasonal reward system ---
void AddSC_SeasonalRewardScripts();           // Seasons/SeasonalRewardScripts.cpp
void AddSC_DCWeeklyResetHub();                // Seasons/DCWeeklyResetHub.cpp

// --- Phased duels system ---
void AddSC_dc_phased_duels();                 // PhasedDuels/dc_phased_duels.cpp

// --- Dungeon quest system ---
void AddSC_DungeonQuestSystem();              // DungeonQuests/DungeonQuestSystem.cpp
void AddSC_DungeonQuestMasterFollower();      // DungeonQuests/DungeonQuestMasterFollower.cpp
void AddSC_npc_dungeon_quest_daily_weekly();  // DungeonQuests/npc_dungeon_quest_daily_weekly.cpp
void AddSC_npc_universal_quest_master();      // DungeonQuests/npc_universal_quest_master.cpp

// --- Addon extension system ---
void AddDCAddonExtensionScripts();            // AddonExtension/dc_addon_extension_loader.cpp

// --- Integration system (first-start/account-wide) ---
void AddSC_dc_firststart();                   // Progression/FirstStart/dc_firststart.cpp
void AddSC_dc_accountwide_reputation();       // Progression/Accountwide/dc_accountwide_reputation.cpp
void AddSC_dc_accountwide_friendlist();       // Progression/Accountwide/dc_accountwide_friendlist.cpp
void AddSC_dc_accountwide_achievements();     // Progression/Accountwide/dc_accountwide_achievements.cpp

// --- Cross-system integration framework ---
void AddSC_dc_cross_system_scripts();         // CrossSystem/CrossSystemScripts.cpp
void AddSC_dc_teleporter();                   // Teleporters/dc_teleporter.cpp
void AddSC_dc_fake_players();                 // FakePlayers/dc_fake_players.cpp

// --- DC commands (unified command hub) ---
void AddSC_dc_addons_commandscript();         // Commands/cs_dc_addons.cpp
void AddSC_dc_dungeonquests_commandscript();  // Commands/cs_dc_dungeonquests.cpp
void AddSC_dc_hinterland_bg_commandscript();  // Commands/cs_dc_hinterland_bg.cpp
void AddSC_dc_mythic_plus_commandscript();    // Commands/cs_dc_mythic_plus.cpp
void AddSC_dc_seasonal_rewards_commandscript();
// Commands/cs_dc_seasonal_rewards.cpp
void AddSC_dc_prestige_commandscript();       // Commands/cs_dc_prestige.cpp
void AddSC_dc_item_upgrade_commandscript();   // Commands/cs_dc_item_upgrade.cpp
void AddSC_cs_dc_guildhouse();                // Commands/cs_dc_guildhouse.cpp
void AddSC_dc_stresstest();                   // Commands/cs_dc_stresstest.cpp
void AddSC_dc_challenge_modes_commandscript();
// Commands/cs_dc_challenge_modes.cpp

// --- Guild housing ---
void AddGuildHouseScripts();                  // GuildHousing/dc_guildhouse.cpp
void AddGuildHouseButlerScripts();            // GuildHousing/dc_guildhouse_butler.cpp
void AddSC_dc_dalaran_guard();                // GuildHousing/dc_dalaran_guard.cpp

// ============================================================================
// Script Loader Helpers
// ============================================================================

template <typename Func>
inline bool TryLoadScript(char const* name, Func&& loader)
{
    try
    {
        loader();
        LOG_INFO("scripts.dc", ">>   [OK] {}", name);
        return true;
    }
    catch (std::exception const& e)
    {
        LOG_ERROR("scripts.dc", ">>   [EXCEPTION] {}: {}", name, e.what());
    }
    catch (...)
    {
        LOG_ERROR("scripts.dc", ">>   [CRASH] {}: unknown exception", name);
    }

    return false;
}

inline void LogSection(char const* title)
{
    LOG_INFO("scripts.dc", ">> ===========================================================");
    LOG_INFO("scripts.dc", ">> {}", title);
    LOG_INFO("scripts.dc", ">> ===========================================================");
}

template <typename Func>
inline void LoadAndCount(
    char const* name,
    Func&& loader,
    uint32& loadedCount,
    uint32& failedCount)
{
    if (TryLoadScript(name, std::forward<Func>(loader)))
        ++loadedCount;
    else
        ++failedCount;
}

// The name of this function should match:
// void Add${NameOfDirectory}Scripts()
void AddDCScripts()
{
    uint32 loadedCount = 0;
    uint32 failedCount = 0;

    auto load = [&](char const* name, auto&& loader)
    {
        LoadAndCount(
            name,
            std::forward<decltype(loader)>(loader),
            loadedCount,
            failedCount);
    };

#define DC_LOAD(script) load(#script, []() { script(); })

    LOG_INFO("scripts.dc", "==============================================================");
    LOG_INFO("scripts.dc", "DarkChaos: DC script loader starting");
    LOG_INFO("scripts.dc", "==============================================================");

    LogSection("Core AC Scripts (overrides and customizations)");
    DC_LOAD(AddSC_ac_guard_npc);
    DC_LOAD(AddSC_ac_quest_npc_800009);
    DC_LOAD(AddSC_flightmasters);

    LogSection("DC Core Services");
    DC_LOAD(AddSC_dc_login_announce);
    DC_LOAD(AddSC_dc_teleporter);

    LogSection("Fake Players System");
    DC_LOAD(AddSC_dc_fake_players);

    LogSection("Jadeforest Zone Scripts");
    DC_LOAD(AddSC_jadeforest_flightmaster);
    DC_LOAD(AddSC_jadeforest_guards);
    DC_LOAD(AddSC_jadeforest_training_grounds);

    LogSection("Giant Isles Zone");
    DC_LOAD(AddSC_giant_isles_zone);
    DC_LOAD(AddSC_giant_isles_cannon_quest);
    DC_LOAD(AddSC_giant_isles_invasion);
    DC_LOAD(AddSC_boss_oondasta);
    DC_LOAD(AddSC_boss_thok);
    DC_LOAD(AddSC_boss_nalak);
    DC_LOAD(AddSC_dc_giant_isles_water_monster);

    LogSection("Heirloom System");
    DC_LOAD(AddSC_heirloom_scaling_255);
    DC_LOAD(AddSC_go_heirloom_cache);

    LogSection("AoE Loot System");
    DC_LOAD(AddSC_dc_aoeloot_unified);

    LogSection("Hotspots System");
    // AddSC_ac_hotspots also registers hotspot command handlers.
    DC_LOAD(AddSC_ac_hotspots);
    DC_LOAD(AddSC_spell_hotspot_buff_800001);

    LogSection("Battle for Gilneas");
    DC_LOAD(AddBattleForGilneasScripts);

    LogSection("Hinterland Battleground System");
    DC_LOAD(AddSC_npc_thrall_hinterlandbg);
    DC_LOAD(AddSC_hinterlandbg_Varian_wrynn);
    DC_LOAD(AddSC_hl_scoreboard);
    DC_LOAD(AddSC_hlbg_addon);
    DC_LOAD(AddSC_npc_hinterlands_battlemaster);
    DC_LOAD(AddSC_hlbg_battlemaster_hook);
    DC_LOAD(AddSC_hlbg_native_broadcast);
    DC_LOAD(AddSC_outdoorpvp_hl_dc);

    LogSection("Challenge Mode System");
    DC_LOAD(AddSC_dc_challenge_modes);
    DC_LOAD(AddSC_challenge_mode_scripts);
    DC_LOAD(AddSC_dc_challenge_mode_equipment_restrictions);
    DC_LOAD(AddSC_dc_challenge_mode_enforcement);
    DC_LOAD(AddSC_spell_challenge_mode_auras);

    LogSection("Prestige System");
    DC_LOAD(AddSC_dc_prestige_system);
    DC_LOAD(AddSC_dc_prestige_spells);
    DC_LOAD(AddSC_dc_prestige_alt_bonus);
    DC_LOAD(AddSC_dc_prestige_challenges);
    DC_LOAD(AddSC_spell_prestige_alt_bonus_aura);

    LogSection("Custom Achievements System");
    DC_LOAD(AddSC_dc_achievements);

    LogSection("Item Upgrade System");
    DC_LOAD(AddSC_ItemUpgradeMechanicsImpl);
    // Currently no-op placeholders in their modules, kept here for completeness.
    DC_LOAD(AddSC_ItemUpgradeProgression);
    DC_LOAD(AddSC_ItemUpgradeAdvanced);
    DC_LOAD(AddSC_ItemUpgradeVendor);
    DC_LOAD(AddSC_ItemUpgradeCurator);
    DC_LOAD(AddSC_ItemUpgradeSeasonal);
    DC_LOAD(AddSC_ItemUpgradeExchange);
    DC_LOAD(AddSC_ItemUpgradeTokenHooks);
    DC_LOAD(AddSC_ItemUpgradeProcScaling);
    DC_LOAD(AddSC_ItemUpgradeStatApplication);

    LogSection("Mythic+ Dungeon System");
    // AddMythicPlusScripts loads core, portal, vault, vendors, and keystone item.
    DC_LOAD(AddMythicPlusScripts);
    DC_LOAD(AddSC_dc_mythic_spectator);

    LogSection("Seasonal Reward System");
    DC_LOAD(AddSC_SeasonalRewardScripts);
    DC_LOAD(AddSC_DCWeeklyResetHub);

    LogSection("Phased Duels System");
    DC_LOAD(AddSC_dc_phased_duels);

    LogSection("Addon Extension System");
    // Includes collection, teleports, QoS, group-finder, and module handlers.
    DC_LOAD(AddDCAddonExtensionScripts);

    LogSection("First-Start and Account-Wide Systems");
    DC_LOAD(AddSC_dc_firststart);
    DC_LOAD(AddSC_dc_accountwide_reputation);
    DC_LOAD(AddSC_dc_accountwide_friendlist);
    DC_LOAD(AddSC_dc_accountwide_achievements);

    LogSection("GOMove System");
    DC_LOAD(AddSC_GOMove_commandscript);

    LogSection("Cross-System Integration Framework");
    DC_LOAD(AddSC_dc_cross_system_scripts);

    LogSection("Guild Housing System");
    // AddGuildHouseScripts also loads AddGuildHouseNpcScripts internally.
    DC_LOAD(AddGuildHouseScripts);
    DC_LOAD(AddGuildHouseButlerScripts);
    DC_LOAD(AddSC_dc_dalaran_guard);

    LogSection("Dungeon Quest System (late-load stage)");
    DC_LOAD(AddSC_DungeonQuestSystem);
    DC_LOAD(AddSC_DungeonQuestMasterFollower);
    DC_LOAD(AddSC_npc_dungeon_quest_daily_weekly);
    DC_LOAD(AddSC_npc_universal_quest_master);

    LogSection("DC Commands (unified .dc command hub)");
    DC_LOAD(AddSC_dc_addons_commandscript);
    DC_LOAD(AddSC_dc_dungeonquests_commandscript);
    DC_LOAD(AddSC_dc_hinterland_bg_commandscript);
    DC_LOAD(AddSC_dc_mythic_plus_commandscript);
    DC_LOAD(AddSC_dc_seasonal_rewards_commandscript);
    DC_LOAD(AddSC_dc_prestige_commandscript);
    DC_LOAD(AddSC_dc_item_upgrade_commandscript);
    DC_LOAD(AddSC_cs_dc_guildhouse);
    // Hotspot commands are loaded in AddSC_ac_hotspots.
    DC_LOAD(AddSC_dc_stresstest);
    DC_LOAD(AddSC_dc_challenge_modes_commandscript);

#undef DC_LOAD

    LOG_INFO("scripts.dc", "==============================================================");
    LOG_INFO(
        "scripts.dc",
        "DarkChaos: DC script loader complete (loaded: {}, failed: {})",
        loadedCount,
        failedCount);
    LOG_INFO("scripts.dc", "==============================================================");
}
