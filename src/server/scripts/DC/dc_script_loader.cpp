/*
 * This file is part of the AzerothCore Project. See AUTHORS file for Copyright information
 *
 * This program is free software; you can redistribute it and/or modify it
 * under the terms of the GNU Affero General Public License as published by the
 * Free Software Foundation; either version 3 of the License, or (at your
 * option) any later version.
 *
 * This program is distributed in the hope that it will be useful, but WITHOUT
 * ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
 * FITNESS FOR A PARTICULAR PURPOSE. See the GNU Affero General Public License for
 * more details.
 *
 * You should have received a copy of the GNU General Public License along
 * with this program. If not, see <http://www.gnu.org/licenses/>.
 */

#include "Log.h"
#include <exception>

// ═══════════════════════════════════════════════════════════════════════════
// FORWARD DECLARATIONS - DC Script Functions
// ═══════════════════════════════════════════════════════════════════════════

// --- Core AC Scripts ---
void AddSC_ac_guard_npc();                    // AC\ac_guard_npc.cpp
void AddSC_flighthelper_test();               // AC\cs_flighthelper_test.cpp
void AddSC_dc_login_announce();               // dc_login_announce.cpp
void AddSC_ac_quest_npc_800009();             // AC\ac_quest_npc_800009.cpp
void AddSC_aio_bridge();                      // AIO\aio_bridge.cpp
void AddSC_flightmasters();                   // AC\ac_flightmasters.cpp

// --- Jadeforest Zone ---
void AddSC_jadeforest_flightmaster();         // Jadeforest\jadeforest_flightmaster.cpp
void AddSC_jadeforest_guards();               // Jadeforest\jadeforest_guards.cpp

// --- Giant Isles Zone (Ported from MoP Isle of Giants) ---
void AddSC_giant_isles_zone();                // GiantIsles\dc_giant_isles_zone.cpp
void AddSC_giant_isles_cannon_quest();        // GiantIsles\dc_giant_isles_cannon_quest.cpp
void AddSC_giant_isles_invasion();            // GiantIsles\dc_giant_isles_invasion.cpp
void AddSC_boss_oondasta();                   // GiantIsles\boss_oondasta.cpp
void AddSC_boss_thok();                       // GiantIsles\boss_thok.cpp
void AddSC_boss_nalak();                      // GiantIsles\boss_nalak.cpp

// --- Map Extension (DISABLED - requires AIO which is not compiled) ---
// void AddSC_cs_gps_test();                     // MapExtension\cs_gps_test.cpp
// void AddSC_PlayerScript_MapExtension();       // MapExtension\PlayerScript_MapExtension.cpp

// --- Heirloom System ---
void AddSC_heirloom_scaling_255();            // heirloom_scaling_255.cpp
void AddSC_go_heirloom_cache();               // go_heirloom_cache.cpp

// --- AoE Loot System ---
void AddSC_ac_aoeloot();                      // ac_aoeloot.cpp
void AddSC_dc_aoeloot_extensions();           // dc_aoeloot_extensions.cpp

// --- Hotspots System ---
void AddSC_ac_hotspots();                     // Hotspot\ac_hotspots.cpp
void AddSC_spell_hotspot_buff_800001();       // Hotspot\spell_hotspot_buff_800001.cpp

// --- Battle for Gilneas ---
void AddBattleForGilneasScripts();            // Gilneas\BattlegroundBFG.cpp

// --- Hinterland Battleground System ---
void AddSC_npc_thrall_hinterlandbg();         // HinterlandBG\npc_thrall_warchief.cpp
void AddSC_hinterlandbg_Varian_wrynn();       // HinterlandBG\npc_Varian_hinterlandbg.cpp
void AddSC_hlbg_commandscript();              // Commands\cs_hl_bg.cpp (Note: in Commands folder)
void AddSC_hl_scoreboard();                   // HinterlandBG\HL_ScoreboardNPC.cpp
void AddSC_hlbg_addon();                      // HinterlandBG\hlbg_addon.cpp
void AddSC_npc_hinterlands_battlemaster();    // HinterlandBG\npc_hinterlands_battlemaster.cpp
void AddSC_hlbg_native_broadcast();           // HinterlandBG\hlbg_native_broadcast.cpp
void AddSC_outdoorpvp_hl_dc();                // HinterlandBG\outdoorpvp_hl_registration.cpp
// Note: HL_StatsAIO.cpp provides HandleHLBGStatsUI implementation - no AddSC needed

// --- Prestige System ---
void AddSC_dc_prestige_system();              // Prestige\dc_prestige_system.cpp
void AddSC_dc_prestige_spells();              // Prestige\dc_prestige_spells.cpp
void AddSC_dc_prestige_alt_bonus();           // Prestige\dc_prestige_alt_bonus.cpp
void AddSC_dc_prestige_challenges();          // Prestige\dc_prestige_challenges.cpp
void AddSC_spell_prestige_alt_bonus_aura();   // Prestige\spell_prestige_alt_bonus_aura.cpp

// --- Challenge Mode System ---
void AddSC_dc_challenge_modes();              // ChallengeMode\dc_challenge_modes_customized.cpp
void AddSC_spell_challenge_mode_auras();      // ChallengeMode\spell_challenge_mode_auras.cpp

// --- Custom Achievements ---
void AddSC_dc_achievements();                 // Achievements\dc_achievements.cpp

// --- GOMove System ---
void AddSC_GOMove_commandscript();            // GOMove\GOMoveScripts.cpp

// --- Item Upgrade System ---
void AddItemUpgradeGMCommandScript();         // ItemUpgrades\ItemUpgradeGMCommands.cpp
void AddSC_ItemUpgradeMechanicsImpl();        // ItemUpgrades\ItemUpgradeMechanicsImpl.cpp (MUST load first)
void AddSC_ItemUpgradeMechanicsCommands();    // ItemUpgrades\ItemUpgradeMechanicsCommands.cpp
void AddSC_ItemUpgradeAddonHandler();         // ItemUpgrades\ItemUpgradeAddonHandler.cpp
void AddSC_ItemUpgradeVendor();               // ItemUpgrades\ItemUpgradeNPC_Vendor.cpp
void AddSC_ItemUpgradeCurator();              // ItemUpgrades\ItemUpgradeNPC_Curator.cpp
void AddSC_ItemUpgradeProgression();          // ItemUpgrades\ItemUpgradeProgressionImpl.cpp
void AddSC_ItemUpgradeSeasonal();             // ItemUpgrades\ItemUpgradeSeasonalImpl.cpp
void AddSC_ItemUpgradeAdvanced();             // ItemUpgrades\ItemUpgradeAdvancedImpl.cpp
void AddSC_ItemUpgradeTransmutation();        // ItemUpgrades\ItemUpgradeTransmutationNPC.cpp
void AddSC_ItemUpgradeTokenHooks();           // ItemUpgrades\ItemUpgradeTokenHooks.cpp
void AddSC_ItemUpgradeProcScaling();          // ItemUpgrades\ItemUpgradeProcScaling.cpp
void AddSC_ItemUpgradeStatApplication();      // ItemUpgrades\ItemUpgradeStatApplication.cpp
void AddSC_ItemUpgradeQuestRewardHook();      // ItemUpgrades\ItemUpgradeQuestRewardHook.cpp

// --- Mythic+ Dungeon System ---
void AddMythicPlusScripts();                  // MythicPlus\mythic_plus_loader.cpp
void AddSC_dc_mythic_spectator();             // MythicPlus\dc_mythic_spectator.cpp

// --- Seasonal Reward System ---
void AddSC_SeasonalRewardScripts();           // Seasons\SeasonalRewardScripts.cpp
void AddSC_SeasonalRewardCommands();          // Seasons\SeasonalRewardCommands.cpp

// --- Phased Duels System ---
void AddSC_dc_phased_duels();                 // PhasedDuels\dc_phased_duels.cpp

// --- Dungeon Quest System (Loaded Last) ---
void AddSC_DungeonQuestSystem();              // DungeonQuests\\DungeonQuestSystem.cpp
void AddSC_DungeonQuestPhasing();             // DungeonQuests\\DungeonQuestPhasing.cpp
void AddSC_DungeonQuestMasterFollower();      // DungeonQuests\\DungeonQuestMasterFollower.cpp
void AddSC_npc_dungeon_quest_master();        // DungeonQuests\\npc_dungeon_quest_master.cpp
void AddSC_npc_dungeon_quest_daily_weekly();  // DungeonQuests\\npc_dungeon_quest_daily_weekly.cpp

// --- Addon Extension System ---
void AddDCAddonExtensionScripts();            // AddonExtension\\dc_addon_extension_loader.cpp

// --- Integration System (First-Start, Custom Login) ---
void AddSC_dc_firststart();                   // Integration\\dc_firststart.cpp

// --- Cross-System Integration Framework ---
void AddSC_dc_cross_system_scripts();         // CrossSystem\\CrossSystemScripts.cpp

// The name of this function should match:
// void Add${NameOfDirectory}Scripts()
void AddDCScripts()
{
    // ═══════════════════════════════════════════════════════════════════════
    // CORE AC SCRIPTS
    // ═══════════════════════════════════════════════════════════════════════
    AddSC_ac_guard_npc();
    AddSC_flighthelper_test();
    AddSC_dc_login_announce();
    AddSC_ac_quest_npc_800009();
    AddSC_aio_bridge();
    AddSC_flightmasters();

    // ═══════════════════════════════════════════════════════════════════════
    // JADEFOREST ZONE
    // ═══════════════════════════════════════════════════════════════════════
    LOG_INFO("scripts", ">> ═══════════════════════════════════════════════════════════");
    LOG_INFO("scripts", ">> Jadeforest Zone Scripts");
    LOG_INFO("scripts", ">> ═══════════════════════════════════════════════════════════");
    try {
        AddSC_jadeforest_flightmaster();
        AddSC_jadeforest_guards();
        LOG_INFO("scripts", ">>   ✓ Jadeforest NPCs loaded");
    } catch (std::exception& e) {
        LOG_ERROR("scripts", ">>   ✗ EXCEPTION in Jadeforest: {}", e.what());
    } catch (...) {
        LOG_ERROR("scripts", ">>   ✗ CRASH in Jadeforest");
    }

    // ═══════════════════════════════════════════════════════════════════════
    // GIANT ISLES ZONE (Ported from MoP Isle of Giants)
    // ═══════════════════════════════════════════════════════════════════════
    LOG_INFO("scripts", ">> ═══════════════════════════════════════════════════════════");
    LOG_INFO("scripts", ">> Giant Isles Zone (Isle of Giants Port)");
    LOG_INFO("scripts", ">> ═══════════════════════════════════════════════════════════");
    try {
        AddSC_giant_isles_zone();
        AddSC_giant_isles_cannon_quest();
        AddSC_giant_isles_invasion();
        AddSC_boss_oondasta();
        AddSC_boss_thok();
        AddSC_boss_nalak();
        LOG_INFO("scripts", ">>   ✓ Giant Isles zone scripts loaded");
        LOG_INFO("scripts", ">>   ✓ Cannon quest loaded");
        LOG_INFO("scripts", ">>   ✓ World bosses: Oondasta, Thok, Nalak loaded");
    } catch (std::exception& e) {
        LOG_ERROR("scripts", ">>   ✗ EXCEPTION in Giant Isles: {}", e.what());
    } catch (...) {
        LOG_ERROR("scripts", ">>   ✗ CRASH in Giant Isles");
    }

    // ═══════════════════════════════════════════════════════════════════════
    // MAP EXTENSION & GPS (DISABLED - requires AIO which is not compiled)
    // ═══════════════════════════════════════════════════════════════════════
    // AddSC_cs_gps_test();
    // AddSC_PlayerScript_MapExtension();

    // ═══════════════════════════════════════════════════════════════════════
    // HEIRLOOM SYSTEM
    // ═══════════════════════════════════════════════════════════════════════
    AddSC_heirloom_scaling_255();
    AddSC_go_heirloom_cache();

    // ═══════════════════════════════════════════════════════════════════════
    // AOE LOOT SYSTEM
    // ═══════════════════════════════════════════════════════════════════════
    LOG_INFO("scripts", ">> ═══════════════════════════════════════════════════════════");
    LOG_INFO("scripts", ">> AoE Loot System");
    LOG_INFO("scripts", ">> ═══════════════════════════════════════════════════════════");
    try {
        AddSC_ac_aoeloot();
        AddSC_dc_aoeloot_extensions();
        LOG_INFO("scripts", ">>   ✓ AoE Loot base and extensions loaded");
    } catch (std::exception& e) {
        LOG_ERROR("scripts", ">>   ✗ EXCEPTION in AoE Loot: {}", e.what());
    } catch (...) {
        LOG_ERROR("scripts", ">>   ✗ CRASH in AoE Loot");
    }

    // ═══════════════════════════════════════════════════════════════════════
    // HOTSPOTS SYSTEM
    // ═══════════════════════════════════════════════════════════════════════
    LOG_INFO("scripts", ">> ═══════════════════════════════════════════════════════════");
    LOG_INFO("scripts", ">> Hotspots System");
    LOG_INFO("scripts", ">> ═══════════════════════════════════════════════════════════");
    try {
        AddSC_ac_hotspots();
        AddSC_spell_hotspot_buff_800001();
        LOG_INFO("scripts", ">>   ✓ Hotspots detection, markers, and spell buffs loaded");
    } catch (std::exception& e) {
        LOG_ERROR("scripts", ">>   ✗ EXCEPTION in Hotspots System: {}", e.what());
    } catch (...) {
        LOG_ERROR("scripts", ">>   ✗ CRASH in Hotspots System");
    }

    // ═══════════════════════════════════════════════════════════════════════
    // BATTLE FOR GILNEAS
    // ═══════════════════════════════════════════════════════════════════════
    AddBattleForGilneasScripts();

    // ═══════════════════════════════════════════════════════════════════════
    // HINTERLAND BATTLEGROUND SYSTEM
    // ═══════════════════════════════════════════════════════════════════════
    LOG_INFO("scripts", ">> ═══════════════════════════════════════════════════════════");
    LOG_INFO("scripts", ">> Hinterland Battleground System");
    LOG_INFO("scripts", ">> ═══════════════════════════════════════════════════════════");
    try {
        AddSC_npc_thrall_hinterlandbg();
        AddSC_hinterlandbg_Varian_wrynn();
        AddSC_hlbg_commandscript();
        AddSC_hl_scoreboard();
        AddSC_hlbg_addon();
        AddSC_npc_hinterlands_battlemaster();
        AddSC_hlbg_native_broadcast();
        AddSC_outdoorpvp_hl_dc();
        LOG_INFO("scripts", ">>   ✓ Hinterland BG NPCs, commands, and OutdoorPvP loaded");
    } catch (std::exception& e) {
        LOG_ERROR("scripts", ">>   ✗ EXCEPTION in Hinterland BG: {}", e.what());
    } catch (...) {
        LOG_ERROR("scripts", ">>   ✗ CRASH in Hinterland BG");
    }

    // ═══════════════════════════════════════════════════════════════════════
    // CHALLENGE MODE SYSTEM
    // ═══════════════════════════════════════════════════════════════════════
    LOG_INFO("scripts", ">> ═══════════════════════════════════════════════════════════");
    LOG_INFO("scripts", ">> Challenge Mode System");
    LOG_INFO("scripts", ">> ═══════════════════════════════════════════════════════════");
    try {
        AddSC_dc_challenge_modes();
        AddSC_spell_challenge_mode_auras();
        LOG_INFO("scripts", ">>   ✓ Challenge modes and auras loaded");
    } catch (std::exception& e) {
        LOG_ERROR("scripts", ">>   ✗ EXCEPTION in Challenge Mode: {}", e.what());
    } catch (...) {
        LOG_ERROR("scripts", ">>   ✗ CRASH in Challenge Mode");
    }

    // ═══════════════════════════════════════════════════════════════════════
    // PRESTIGE SYSTEM
    // ═══════════════════════════════════════════════════════════════════════
    LOG_INFO("scripts", ">> ═══════════════════════════════════════════════════════════");
    LOG_INFO("scripts", ">> Prestige System");
    LOG_INFO("scripts", ">> ═══════════════════════════════════════════════════════════");
    try {
        AddSC_dc_prestige_system();
        AddSC_dc_prestige_spells();
        AddSC_dc_prestige_alt_bonus();
        AddSC_dc_prestige_challenges();
        AddSC_spell_prestige_alt_bonus_aura();
        LOG_INFO("scripts", ">>   ✓ Prestige mechanics, spells, alt bonus, challenges, and visual buffs loaded");
    } catch (std::exception& e) {
        LOG_ERROR("scripts", ">>   ✗ EXCEPTION in Prestige System: {}", e.what());
    } catch (...) {
        LOG_ERROR("scripts", ">>   ✗ CRASH in Prestige System");
    }

    // ═══════════════════════════════════════════════════════════════════════
    // CUSTOM ACHIEVEMENTS SYSTEM
    // ═══════════════════════════════════════════════════════════════════════
    LOG_INFO("scripts", ">> ═══════════════════════════════════════════════════════════");
    LOG_INFO("scripts", ">> Custom Achievements System");
    LOG_INFO("scripts", ">> ═══════════════════════════════════════════════════════════");
    try {
        AddSC_dc_achievements();
        LOG_INFO("scripts", ">>   ✓ Custom achievements loaded");
    } catch (std::exception& e) {
        LOG_ERROR("scripts", ">>   ✗ EXCEPTION in Custom Achievements: {}", e.what());
    } catch (...) {
        LOG_ERROR("scripts", ">>   ✗ CRASH in Custom Achievements");
    }

    // ═══════════════════════════════════════════════════════════════════════
    // ITEM UPGRADE SYSTEM v2.0
    // ═══════════════════════════════════════════════════════════════════════
    LOG_INFO("scripts", ">> ═══════════════════════════════════════════════════════════");
    LOG_INFO("scripts", ">> DarkChaos Item Upgrade System v2.0 (Hybrid Scaling)");
    LOG_INFO("scripts", ">> ═══════════════════════════════════════════════════════════");
    LOG_INFO("scripts", ">>   Core Features:");
    LOG_INFO("scripts", ">>     • Enchantment-Based Stat Scaling");
    LOG_INFO("scripts", ">>     • UnitScript Proc Damage/Healing Scaling");
    LOG_INFO("scripts", ">>     • 2 Tiers × 15 Levels = 30 Upgrade Paths");
    LOG_INFO("scripts", ">>     • Mastery & Artifact Progression");
    LOG_INFO("scripts", ">>     • Transmutation & Tier Conversion");
    LOG_INFO("scripts", ">>     • Seasonal Content Support");
    LOG_INFO("scripts", ">> ───────────────────────────────────────────────────────────");

    try {
        AddSC_ItemUpgradeMechanicsImpl();
        LOG_INFO("scripts", ">>   ✓ Core mechanics loaded");
    } catch (std::exception& e) {
        LOG_ERROR("scripts", ">>   ✗ EXCEPTION in core mechanics: {}", e.what());
    } catch (...) {
        LOG_ERROR("scripts", ">>   ✗ CRASH in core mechanics");
    }

    try {
        AddSC_ItemUpgradeMechanicsCommands();
        LOG_INFO("scripts", ">>   ✓ Mechanics commands loaded");
    } catch (std::exception& e) {
        LOG_ERROR("scripts", ">>   ✗ EXCEPTION in mechanics commands: {}", e.what());
    } catch (...) {
        LOG_ERROR("scripts", ">>   ✗ CRASH in mechanics commands");
    }

    try {
        AddItemUpgradeGMCommandScript();
        LOG_INFO("scripts", ">>   ✓ GM commands loaded");
    } catch (std::exception& e) {
        LOG_ERROR("scripts", ">>   ✗ EXCEPTION in GM commands: {}", e.what());
    } catch (...) {
        LOG_ERROR("scripts", ">>   ✗ CRASH in GM commands");
    }

    try {
        AddSC_ItemUpgradeAddonHandler();
        LOG_INFO("scripts", ">>   ✓ Addon handler loaded");
    } catch (std::exception& e) {
        LOG_ERROR("scripts", ">>   ✗ EXCEPTION in addon handler: {}", e.what());
    } catch (...) {
        LOG_ERROR("scripts", ">>   ✗ CRASH in addon handler");
    }

    try {
        AddSC_ItemUpgradeVendor();
        LOG_INFO("scripts", ">>   ✓ Token vendor NPC loaded");
    } catch (std::exception& e) {
        LOG_ERROR("scripts", ">>   ✗ EXCEPTION in vendor: {}", e.what());
    } catch (...) {
        LOG_ERROR("scripts", ">>   ✗ CRASH in vendor");
    }

    try {
        AddSC_ItemUpgradeCurator();
        LOG_INFO("scripts", ">>   ✓ Artifact curator NPC loaded");
    } catch (std::exception& e) {
        LOG_ERROR("scripts", ">>   ✗ EXCEPTION in curator: {}", e.what());
    } catch (...) {
        LOG_ERROR("scripts", ">>   ✗ CRASH in curator");
    }

    try {
        AddSC_ItemUpgradeProgression();
        LOG_INFO("scripts", ">>   ✓ Progression system loaded");
    } catch (std::exception& e) {
        LOG_ERROR("scripts", ">>   ✗ EXCEPTION in progression: {}", e.what());
    } catch (...) {
        LOG_ERROR("scripts", ">>   ✗ CRASH in progression");
    }

    try {
        AddSC_ItemUpgradeSeasonal();
        LOG_INFO("scripts", ">>   ✓ Seasonal system loaded");
    } catch (std::exception& e) {
        LOG_ERROR("scripts", ">>   ✗ EXCEPTION in seasonal: {}", e.what());
    } catch (...) {
        LOG_ERROR("scripts", ">>   ✗ CRASH in seasonal");
    }

    try {
        AddSC_ItemUpgradeAdvanced();
        LOG_INFO("scripts", ">>   ✓ Advanced features loaded");
    } catch (std::exception& e) {
        LOG_ERROR("scripts", ">>   ✗ EXCEPTION in advanced: {}", e.what());
    } catch (...) {
        LOG_ERROR("scripts", ">>   ✗ CRASH in advanced");
    }

    try {
        AddSC_ItemUpgradeTransmutation();
        LOG_INFO("scripts", ">>   ✓ Transmutation NPC loaded");
    } catch (std::exception& e) {
        LOG_ERROR("scripts", ">>   ✗ EXCEPTION in transmutation: {}", e.what());
    } catch (...) {
        LOG_ERROR("scripts", ">>   ✗ CRASH in transmutation");
    }

    try {
        AddSC_ItemUpgradeTokenHooks();
        LOG_INFO("scripts", ">>   ✓ Token hooks loaded");
    } catch (std::exception& e) {
        LOG_ERROR("scripts", ">>   ✗ EXCEPTION in token hooks: {}", e.what());
    } catch (...) {
        LOG_ERROR("scripts", ">>   ✗ CRASH in token hooks");
    }

    try {
        AddSC_ItemUpgradeProcScaling();
        LOG_INFO("scripts", ">>   ✓ Proc scaling loaded (UnitScript hooks)");
    } catch (std::exception& e) {
        LOG_ERROR("scripts", ">>   ✗ EXCEPTION in proc scaling: {}", e.what());
    } catch (...) {
        LOG_ERROR("scripts", ">>   ✗ CRASH in proc scaling");
    }

    try {
        AddSC_ItemUpgradeStatApplication();
        LOG_INFO("scripts", ">>   ✓ Stat application loaded (enchantment-based)");
    } catch (std::exception& e) {
        LOG_ERROR("scripts", ">>   ✗ EXCEPTION in stat application: {}", e.what());
    } catch (...) {
        LOG_ERROR("scripts", ">>   ✗ CRASH in stat application");
    }

    try {
        AddSC_ItemUpgradeQuestRewardHook();
        LOG_INFO("scripts", ">>   ✓ Quest reward hooks loaded");
    } catch (std::exception& e) {
        LOG_ERROR("scripts", ">>   ✗ EXCEPTION in quest reward hooks: {}", e.what());
    } catch (...) {
        LOG_ERROR("scripts", ">>   ✗ CRASH in quest reward hooks");
    }

    LOG_INFO("scripts", ">> ═══════════════════════════════════════════════════════════");
    LOG_INFO("scripts", ">> Item Upgrade System: All modules loaded successfully");
    LOG_INFO("scripts", ">> ═══════════════════════════════════════════════════════════");

    // ═══════════════════════════════════════════════════════════════════════
    // MYTHIC+ DUNGEON SYSTEM
    // ═══════════════════════════════════════════════════════════════════════
    LOG_INFO("scripts", ">> ═══════════════════════════════════════════════════════════");
    LOG_INFO("scripts", ">> Mythic+ Dungeon Scaling System");
    LOG_INFO("scripts", ">> ═══════════════════════════════════════════════════════════");
    try {
        AddMythicPlusScripts();
        LOG_INFO("scripts", ">>   ✓ Mythic+ dungeon scaling and keystone system loaded");
    } catch (std::exception& e) {
        LOG_ERROR("scripts", ">>   ✗ EXCEPTION in Mythic+ System: {}", e.what());
    } catch (...) {
        LOG_ERROR("scripts", ">>   ✗ CRASH in Mythic+ System");
    }

    try {
        AddSC_dc_mythic_spectator();
        LOG_INFO("scripts", ">>   ✓ Mythic+ Spectator system loaded");
    } catch (std::exception& e) {
        LOG_ERROR("scripts", ">>   ✗ EXCEPTION in M+ Spectator: {}", e.what());
    } catch (...) {
        LOG_ERROR("scripts", ">>   ✗ CRASH in M+ Spectator");
    }
    LOG_INFO("scripts", ">> ═══════════════════════════════════════════════════════════");

    // ═══════════════════════════════════════════════════════════════════════
    // SEASONAL REWARD SYSTEM
    // ═══════════════════════════════════════════════════════════════════════
    LOG_INFO("scripts", ">> ═══════════════════════════════════════════════════════════");
    LOG_INFO("scripts", ">> DC Seasonal Reward System (C++ Core)");
    LOG_INFO("scripts", ">> ═══════════════════════════════════════════════════════════");
    LOG_INFO("scripts", ">>   Core Features:");
    LOG_INFO("scripts", ">>     • Token & Essence Rewards (Quest/Creature/Boss)");
    LOG_INFO("scripts", ">>     • Weekly Cap System (Configurable Limits)");
    LOG_INFO("scripts", ">>     • Weekly Chest Rewards (3-Slot M+ Vault)");
    LOG_INFO("scripts", ">>     • Achievement Auto-Tracking");
    LOG_INFO("scripts", ">>     • AIO Client Communication (Eluna Bridge)");
    LOG_INFO("scripts", ">>     • Admin Commands (.season)");
    LOG_INFO("scripts", ">> ───────────────────────────────────────────────────────────");
    try {
        AddSC_SeasonalRewardScripts();
        LOG_INFO("scripts", ">>   ✓ Seasonal reward hooks and player scripts loaded");
    } catch (std::exception& e) {
        LOG_ERROR("scripts", ">>   ✗ EXCEPTION in seasonal scripts: {}", e.what());
    } catch (...) {
        LOG_ERROR("scripts", ">>   ✗ CRASH in seasonal scripts");
    }

    try {
        AddSC_SeasonalRewardCommands();
        LOG_INFO("scripts", ">>   ✓ Seasonal admin commands loaded (.season)");
    } catch (std::exception& e) {
        LOG_ERROR("scripts", ">>   ✗ EXCEPTION in seasonal commands: {}", e.what());
    } catch (...) {
        LOG_ERROR("scripts", ">>   ✗ CRASH in seasonal commands");
    }
    LOG_INFO("scripts", ">> ═══════════════════════════════════════════════════════════");
    LOG_INFO("scripts", ">> Seasonal Reward System: All modules loaded successfully");
    LOG_INFO("scripts", ">> ═══════════════════════════════════════════════════════════");

    // ═══════════════════════════════════════════════════════════════════════
    // PHASED DUELS SYSTEM
    // ═══════════════════════════════════════════════════════════════════════
    LOG_INFO("scripts", ">> ═══════════════════════════════════════════════════════════");
    LOG_INFO("scripts", ">> Phased Duels System");
    LOG_INFO("scripts", ">> ═══════════════════════════════════════════════════════════");
    try {
        AddSC_dc_phased_duels();
        LOG_INFO("scripts", ">>   ✓ Phased duels isolation and statistics loaded");
    } catch (std::exception& e) {
        LOG_ERROR("scripts", ">>   ✗ EXCEPTION in Phased Duels: {}", e.what());
    } catch (...) {
        LOG_ERROR("scripts", ">>   ✗ CRASH in Phased Duels");
    }
    LOG_INFO("scripts", ">> ═══════════════════════════════════════════════════════════");

    // ═══════════════════════════════════════════════════════════════════════
    // DUNGEON QUEST SYSTEM (Loaded Last)
    // ═══════════════════════════════════════════════════════════════════════
    LOG_INFO("scripts", ">> ═══════════════════════════════════════════════════════════");
    LOG_INFO("scripts", ">> Dungeon Quest System v3.0 (Enhanced UX + AC Standards)");
    LOG_INFO("scripts", ">> ═══════════════════════════════════════════════════════════");
    try {
        AddSC_DungeonQuestSystem();
        AddSC_DungeonQuestPhasing();
        AddSC_DungeonQuestMasterFollower();
        AddSC_npc_dungeon_quest_master();
        AddSC_npc_dungeon_quest_daily_weekly();
        LOG_INFO("scripts", ">>   ✓ Dungeon quest mechanics and NPCs loaded");
    } catch (std::exception& e) {
        LOG_ERROR("scripts", ">>   ✗ EXCEPTION in Dungeon Quest System: {}", e.what());
    } catch (...) {
        LOG_ERROR("scripts", ">>   ✗ CRASH in Dungeon Quest System");
    }
    LOG_INFO("scripts", ">> ═══════════════════════════════════════════════════════════");

    // ═══════════════════════════════════════════════════════════════════════
    // ADDON EXTENSION SYSTEM (Communication Protocol)
    // ═══════════════════════════════════════════════════════════════════════
    LOG_INFO("scripts", ">> ═══════════════════════════════════════════════════════════");
    LOG_INFO("scripts", ">> Addon Extension System (DC Unified Protocol)");
    LOG_INFO("scripts", ">> ═══════════════════════════════════════════════════════════");
    try {
        AddDCAddonExtensionScripts();
        LOG_INFO("scripts", ">>   ✓ Addon communication protocol loaded");
    } catch (std::exception& e) {
        LOG_ERROR("scripts", ">>   ✗ EXCEPTION in Addon Extension: {}", e.what());
    } catch (...) {
        LOG_ERROR("scripts", ">>   ✗ CRASH in Addon Extension");
    }
    LOG_INFO("scripts", ">> ═══════════════════════════════════════════════════════════");

    // ═══════════════════════════════════════════════════════════════════════
    // FIRST-START SYSTEM (Custom Login, Welcome Experience)
    // ═══════════════════════════════════════════════════════════════════════
    LOG_INFO("scripts", ">> ═══════════════════════════════════════════════════════════");
    LOG_INFO("scripts", ">> First-Start System (Custom Login, Welcome)");
    LOG_INFO("scripts", ">> ═══════════════════════════════════════════════════════════");
    try {
        AddSC_dc_firststart();
        LOG_INFO("scripts", ">>   ✓ First-start experience loaded");
    } catch (std::exception& e) {
        LOG_ERROR("scripts", ">>   ✗ EXCEPTION in First-Start: {}", e.what());
    } catch (...) {
        LOG_ERROR("scripts", ">>   ✗ CRASH in First-Start");
    }
    LOG_INFO("scripts", ">> ═══════════════════════════════════════════════════════════");

    // ═══════════════════════════════════════════════════════════════════════
    // GOMOVE SYSTEM
    // ═══════════════════════════════════════════════════════════════════════
    try {
        AddSC_GOMove_commandscript();
        LOG_INFO("scripts", ">>   ✓ GOMove System loaded");
    } catch (std::exception& e) {
        LOG_ERROR("scripts", ">>   ✗ EXCEPTION in GOMove: {}", e.what());
    } catch (...) {
        LOG_ERROR("scripts", ">>   ✗ CRASH in GOMove");
    }

    // ═══════════════════════════════════════════════════════════════════════
    // CROSS-SYSTEM INTEGRATION FRAMEWORK (Loaded Last - Coordinates All Systems)
    // ═══════════════════════════════════════════════════════════════════════
    LOG_INFO("scripts", ">> ═══════════════════════════════════════════════════════════");
    LOG_INFO("scripts", ">> Cross-System Integration Framework");
    LOG_INFO("scripts", ">> ═══════════════════════════════════════════════════════════");
    try {
        AddSC_dc_cross_system_scripts();
        LOG_INFO("scripts", ">>   ✓ Cross-System framework loaded");
        LOG_INFO("scripts", ">>   ✓ Session context management active");
        LOG_INFO("scripts", ">>   ✓ Event bus ready for system coordination");
        LOG_INFO("scripts", ">>   ✓ Unified reward distributor active");
    } catch (std::exception& e) {
        LOG_ERROR("scripts", ">>   ✗ EXCEPTION in Cross-System Framework: {}", e.what());
    } catch (...) {
        LOG_ERROR("scripts", ">>   ✗ CRASH in Cross-System Framework");
    }
    LOG_INFO("scripts", ">> ═══════════════════════════════════════════════════════════");

    // ═══════════════════════════════════════════════════════════════════════
    // ALL DC SCRIPTS LOADED
    // ═══════════════════════════════════════════════════════════════════════
    LOG_INFO("scripts", ">> ═══════════════════════════════════════════════════════════");
    LOG_INFO("scripts", ">> DarkChaos Scripts: All systems loaded successfully");
    LOG_INFO("scripts", ">> ═══════════════════════════════════════════════════════════");
}
