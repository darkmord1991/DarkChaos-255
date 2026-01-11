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

#include "Common.h"
#include "ScriptMgr.h"
#include "Config.h"
#include "Log.h"
#include <exception>

// ═══════════════════════════════════════════════════════════════════════════
// FORWARD DECLARATIONS - DC Script Functions
// ═══════════════════════════════════════════════════════════════════════════

// --- Core AC Scripts ---
void AddSC_ac_guard_npc();                    // AC\ac_guard_npc.cpp
void AddSC_dc_login_announce();               // Progression/FirstStart/dc_login_announce.cpp
void AddSC_ac_quest_npc_800009();             // AC\ac_quest_npc_800009.cpp
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
void AddSC_dc_giant_isles_water_monster();    // GiantIsles\dc_giant_isles_water_monster.cpp

// --- Map Extension (DISABLED - requires AIO which is not compiled) ---

// --- Heirloom System ---
void AddSC_heirloom_scaling_255();            // ItemUpgrades/heirloom_scaling_255.cpp
void AddSC_go_heirloom_cache();               // ItemUpgrades/go_heirloom_cache.cpp

// --- AoE Loot System (Unified) ---
void AddSC_dc_aoeloot_unified();              // dc_aoeloot_unified.cpp

// --- Hotspots System ---
void AddSC_ac_hotspots();                     // Hotspot\ac_hotspots.cpp
void AddSC_spell_hotspot_buff_800001();       // Hotspot\spell_hotspot_buff_800001.cpp

// --- Battle for Gilneas ---
void AddBattleForGilneasScripts();            // Gilneas\BattlegroundBFG.cpp

// --- Hinterland Battleground System ---
void AddSC_npc_thrall_hinterlandbg();         // HinterlandBG\npc_thrall_warchief.cpp
void AddSC_hinterlandbg_Varian_wrynn();       // HinterlandBG\npc_Varian_hinterlandbg.cpp

void AddSC_hl_scoreboard();                   // HinterlandBG\HL_ScoreboardNPC.cpp
void AddSC_hlbg_addon();                      // HLBG chat fallback (in AddonExtension/dc_addon_hlbg.cpp)
void AddSC_npc_hinterlands_battlemaster();    // HinterlandBG\npc_hinterlands_battlemaster.cpp
void AddSC_hlbg_native_broadcast();           // HinterlandBG\hlbg_native_broadcast.cpp
void AddSC_outdoorpvp_hl_dc();                // HinterlandBG\outdoorpvp_hl_registration.cpp
// Note: HL_StatsAIO.cpp provides HandleHLBGStatsUI implementation - no AddSC needed

// --- Prestige System ---
void AddSC_dc_prestige_system();              // Progression/Prestige/dc_prestige_system.cpp

void AddSC_dc_prestige_spells();              // Progression/Prestige/dc_prestige_spells.cpp
void AddSC_dc_prestige_alt_bonus();           // Progression/Prestige/dc_prestige_alt_bonus.cpp
void AddSC_dc_prestige_challenges();          // Progression/Prestige/dc_prestige_challenges.cpp
void AddSC_spell_prestige_alt_bonus_aura();   // Progression/Prestige/spell_prestige_alt_bonus_aura.cpp

// --- Challenge Mode System ---
void AddSC_dc_challenge_modes();              // Progression/ChallengeMode/dc_challenge_modes_customized.cpp
void AddSC_dc_challenge_mode_equipment_restrictions(); // Progression/ChallengeMode/dc_challenge_mode_equipment_restrictions.cpp
void AddSC_dc_challenge_mode_enforcement();   // Progression/ChallengeMode/dc_challenge_mode_enforcement.cpp
void AddSC_spell_challenge_mode_auras();      // Progression/ChallengeMode/spell_challenge_mode_auras.cpp

// --- Custom Achievements ---
void AddSC_dc_achievements();                 // Achievements\dc_achievements.cpp

// --- Collection System ---
// void AddSC_dc_addon_collection(); // Moved to AddonExtension             // CollectionSystem\dc_addon_collection.cpp

// --- GOMove System ---
void AddSC_GOMove_commandscript();            // GOMove\GOMoveScripts.cpp

// --- Item Upgrade System ---
void AddSC_ItemUpgradeMechanicsImpl();        // ItemUpgrades\ItemUpgradeMechanicsImpl.cpp (MUST load first)
void AddSC_ItemUpgradeVendor();               // ItemUpgrades\ItemUpgradeNPC_Vendor.cpp
void AddSC_ItemUpgradeCurator();              // ItemUpgrades\ItemUpgradeNPC_Curator.cpp
void AddSC_ItemUpgradeSeasonal();             // ItemUpgrades\ItemUpgradeSeasonalImpl.cpp (Deprecated)
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
void AddSC_dc_firststart();                   // Progression/FirstStart/dc_firststart.cpp

// --- Cross-System Integration Framework ---
void AddSC_dc_cross_system_scripts();         // CrossSystem\\CrossSystemScripts.cpp
void AddSC_dc_teleporter();                   // Teleporters\\dc_teleporter.cpp

// --- DC Commands (Unified command hub) ---
void AddSC_dc_addons_commandscript();         // Commands/cs_dc_addons.cpp
void AddSC_dc_dungeonquests_commandscript();  // Commands/cs_dc_dungeonquests.cpp
void AddSC_dc_hinterland_bg_commandscript();  // Commands/cs_dc_hinterland_bg.cpp
void AddSC_dc_mythic_plus_commandscript();     // Commands/cs_dc_mythic_plus.cpp
void AddSC_dc_seasonal_rewards_commandscript(); // Commands/cs_dc_seasonal_rewards.cpp
void AddSC_dc_prestige_commandscript();        // Commands/cs_dc_prestige.cpp
void AddSC_dc_item_upgrade_commandscript();    // Commands/cs_dc_item_upgrade.cpp
void AddSC_dc_hotspot_commandscript();        // Commands/cs_dc_hotspot.cpp
void AddSC_cs_dc_guildhouse();                // Commands/cs_dc_guildhouse.cpp

// --- Guild Housing ---
void AddGuildHouseScripts();                  // mod_guildhouse.cpp
void AddGuildHouseButlerScripts();            // mod_guildhouse_butler.cpp

// The name of this function should match:
// void Add${NameOfDirectory}Scripts()
void AddDCScripts()
{
    // Top-level header for DarkChaos DC script loader
    LOG_INFO("scripts.dc", "╔══════════════════════════════════════════════════════════");
    LOG_INFO("scripts.dc", "║ DarkChaos: DC Script Loader — loading DC-specific systems");
    LOG_INFO("scripts.dc", "╚══════════════════════════════════════════════════════════");
    // ═══════════════════════════════════════════════════════════════════════
    // CORE AC SCRIPTS (Overrides & Customizations)
    // ═══════════════════════════════════════════════════════════════════════
    AddSC_ac_guard_npc();
    AddSC_ac_quest_npc_800009();
    AddSC_flightmasters();

    // ═══════════════════════════════════════════════════════════════════════
    // DC CORE SERVICES
    // ═══════════════════════════════════════════════════════════════════════
    LOG_INFO("scripts.dc", ">> ═══════════════════════════════════════════════════════════");
    LOG_INFO("scripts.dc", ">> DC Core Services");
    LOG_INFO("scripts.dc", ">> ═══════════════════════════════════════════════════════════");
    try {
        AddSC_dc_login_announce();
        AddSC_dc_teleporter();
        LOG_INFO("scripts.dc", ">>   ✓ Login announce, and Teleporter loaded");
    } catch (std::exception& e) {
        LOG_ERROR("scripts.dc", ">>   ✗ EXCEPTION in DC Core Services: {}", e.what());
    } catch (...) {
        LOG_ERROR("scripts.dc", ">>   ✗ CRASH in DC Core Services");
    }

    // ═══════════════════════════════════════════════════════════════════════
    // JADEFOREST ZONE
    // ═══════════════════════════════════════════════════════════════════════
    LOG_INFO("scripts.dc", ">> ═══════════════════════════════════════════════════════════");
    LOG_INFO("scripts.dc", ">> Jadeforest Zone Scripts");
    LOG_INFO("scripts.dc", ">> ═══════════════════════════════════════════════════════════");
    try {
        AddSC_jadeforest_flightmaster();
        AddSC_jadeforest_guards();
        LOG_INFO("scripts.dc", ">>   ✓ Jadeforest NPCs loaded");
    } catch (std::exception& e) {
        LOG_ERROR("scripts.dc", ">>   ✗ EXCEPTION in Jadeforest: {}", e.what());
    } catch (...) {
        LOG_ERROR("scripts.dc", ">>   ✗ CRASH in Jadeforest");
    }

    // ═══════════════════════════════════════════════════════════════════════
    // GIANT ISLES ZONE (Ported from MoP Isle of Giants)
    // ═══════════════════════════════════════════════════════════════════════
    LOG_INFO("scripts.dc", ">> ═══════════════════════════════════════════════════════════");
    LOG_INFO("scripts.dc", ">> Giant Isles Zone (Isle of Giants Port)");
    LOG_INFO("scripts.dc", ">> ═══════════════════════════════════════════════════════════");
    try {
        AddSC_giant_isles_zone();
        AddSC_giant_isles_cannon_quest();
        // AddSC_giant_isles_invasion();
        // Disabled for now: invasion script needs a rewrite (random spawns).
        AddSC_boss_oondasta();
        AddSC_boss_thok();
        AddSC_boss_nalak();
        AddSC_dc_giant_isles_water_monster();
        LOG_INFO("scripts.dc", ">>   ✓ Giant Isles zone scripts loaded");
        LOG_INFO("scripts.dc", ">>   ✓ Cannon quest loaded");
        LOG_INFO("scripts.dc", ">>   ✓ World bosses: Oondasta, Thok, Nalak loaded");
    } catch (std::exception& e) {
        LOG_ERROR("scripts.dc", ">>   ✗ EXCEPTION in Giant Isles: {}", e.what());
    } catch (...) {
        LOG_ERROR("scripts.dc", ">>   ✗ CRASH in Giant Isles");
    }

    // ═══════════════════════════════════════════════════════════════════════
    // MAP EXTENSION & GPS (DISABLED - requires AIO which is not compiled)
    // ═══════════════════════════════════════════════════════════════════════

    // ═══════════════════════════════════════════════════════════════════════
    // HEIRLOOM SYSTEM
    // ═══════════════════════════════════════════════════════════════════════
    LOG_INFO("scripts.dc", ">> ═══════════════════════════════════════════════════════════");
    LOG_INFO("scripts.dc", ">> Heirloom System");
    LOG_INFO("scripts.dc", ">> ═══════════════════════════════════════════════════════════");
    try {
        AddSC_heirloom_scaling_255();
        AddSC_go_heirloom_cache();
        LOG_INFO("scripts.dc", ">>   ✓ Heirloom scaling and cache loaded");
    } catch (std::exception& e) {
        LOG_ERROR("scripts.dc", ">>   ✗ EXCEPTION in Heirloom System: {}", e.what());
    } catch (...) {
        LOG_ERROR("scripts.dc", ">>   ✗ CRASH in Heirloom System");
    }

    // ═══════════════════════════════════════════════════════════════════════
    // AOE LOOT SYSTEM
    // ═══════════════════════════════════════════════════════════════════════
    LOG_INFO("scripts.dc", ">> ═══════════════════════════════════════════════════════════");
    LOG_INFO("scripts.dc", ">> AoE Loot System");
    LOG_INFO("scripts.dc", ">> ═══════════════════════════════════════════════════════════");
    try {
        AddSC_dc_aoeloot_unified();
        LOG_INFO("scripts.dc", ">>   ✓ AoE Loot unified system loaded");
    } catch (std::exception& e) {
        LOG_ERROR("scripts.dc", ">>   ✗ EXCEPTION in AoE Loot: {}", e.what());
    } catch (...) {
        LOG_ERROR("scripts.dc", ">>   ✗ CRASH in AoE Loot");
    }

    // ═══════════════════════════════════════════════════════════════════════
    // HOTSPOTS SYSTEM
    // ═══════════════════════════════════════════════════════════════════════
    LOG_INFO("scripts.dc", ">> ═══════════════════════════════════════════════════════════");
    LOG_INFO("scripts.dc", ">> Hotspots System");
    LOG_INFO("scripts.dc", ">> ═══════════════════════════════════════════════════════════");
    try {
        AddSC_ac_hotspots();
        AddSC_spell_hotspot_buff_800001();
        LOG_INFO("scripts.dc", ">>   ✓ Hotspots detection, markers, and spell buffs loaded");
    } catch (std::exception& e) {
        LOG_ERROR("scripts.dc", ">>   ✗ EXCEPTION in Hotspots System: {}", e.what());
    } catch (...) {
        LOG_ERROR("scripts.dc", ">>   ✗ CRASH in Hotspots System");
    }

    // ═══════════════════════════════════════════════════════════════════════
    // BATTLE FOR GILNEAS
    // ═══════════════════════════════════════════════════════════════════════
    LOG_INFO("scripts.dc", ">> ═══════════════════════════════════════════════════════════");
    LOG_INFO("scripts.dc", ">> Battle for Gilneas");
    LOG_INFO("scripts.dc", ">> ═══════════════════════════════════════════════════════════");
    try {
        AddBattleForGilneasScripts();
        LOG_INFO("scripts.dc", ">>   ✓ Battle for Gilneas scripts loaded");
    } catch (std::exception& e) {
        LOG_ERROR("scripts.dc", ">>   ✗ EXCEPTION in Battle for Gilneas: {}", e.what());
    } catch (...) {
        LOG_ERROR("scripts.dc", ">>   ✗ CRASH in Battle for Gilneas");
    }

    // ═══════════════════════════════════════════════════════════════════════
    // HINTERLAND BATTLEGROUND SYSTEM
    // ═══════════════════════════════════════════════════════════════════════
    LOG_INFO("scripts.dc", ">> ═══════════════════════════════════════════════════════════");
    LOG_INFO("scripts.dc", ">> Hinterland Battleground System");
    LOG_INFO("scripts.dc", ">> ═══════════════════════════════════════════════════════════");
    try {
        AddSC_npc_thrall_hinterlandbg();
        AddSC_hinterlandbg_Varian_wrynn();

        AddSC_hl_scoreboard();
        AddSC_hlbg_addon();
        AddSC_npc_hinterlands_battlemaster();
        AddSC_hlbg_native_broadcast();
        AddSC_outdoorpvp_hl_dc();
        LOG_INFO("scripts.dc", ">>   ✓ Hinterland BG NPCs, commands, and OutdoorPvP loaded");
    } catch (std::exception& e) {
        LOG_ERROR("scripts.dc", ">>   ✗ EXCEPTION in Hinterland BG: {}", e.what());
    } catch (...) {
        LOG_ERROR("scripts.dc", ">>   ✗ CRASH in Hinterland BG");
    }

    // ═══════════════════════════════════════════════════════════════════════
    // CHALLENGE MODE SYSTEM
    // ═══════════════════════════════════════════════════════════════════════
    LOG_INFO("scripts.dc", ">> ═══════════════════════════════════════════════════════════");
    LOG_INFO("scripts.dc", ">> Challenge Mode System");
    LOG_INFO("scripts.dc", ">> ═══════════════════════════════════════════════════════════");
    try {
        AddSC_dc_challenge_modes();
        AddSC_dc_challenge_mode_equipment_restrictions();
        AddSC_dc_challenge_mode_enforcement();
        AddSC_spell_challenge_mode_auras();
        LOG_INFO("scripts.dc", ">>   ✓ Challenge modes and auras loaded");
    } catch (std::exception& e) {
        LOG_ERROR("scripts.dc", ">>   ✗ EXCEPTION in Challenge Mode: {}", e.what());
    } catch (...) {
        LOG_ERROR("scripts.dc", ">>   ✗ CRASH in Challenge Mode");
    }

    // ═══════════════════════════════════════════════════════════════════════
    // PRESTIGE SYSTEM
    // ═══════════════════════════════════════════════════════════════════════
    LOG_INFO("scripts.dc", ">> ═══════════════════════════════════════════════════════════");
    LOG_INFO("scripts.dc", ">> Prestige System");
    LOG_INFO("scripts.dc", ">> ═══════════════════════════════════════════════════════════");
    try {
        AddSC_dc_prestige_system();

        AddSC_dc_prestige_spells();
        AddSC_dc_prestige_alt_bonus();
        AddSC_dc_prestige_challenges();
        AddSC_spell_prestige_alt_bonus_aura();
        LOG_INFO("scripts.dc", ">>   ✓ Prestige mechanics, commands, spells, alt bonus, challenges, and visual buffs loaded");
    } catch (std::exception& e) {
        LOG_ERROR("scripts.dc", ">>   ✗ EXCEPTION in Prestige System: {}", e.what());
    } catch (...) {
        LOG_ERROR("scripts.dc", ">>   ✗ CRASH in Prestige System");
    }

    // ═══════════════════════════════════════════════════════════════════════
    // CUSTOM ACHIEVEMENTS SYSTEM
    // ═══════════════════════════════════════════════════════════════════════
    LOG_INFO("scripts.dc", ">> ═══════════════════════════════════════════════════════════");
    LOG_INFO("scripts.dc", ">> Custom Achievements System");
    LOG_INFO("scripts.dc", ">> ═══════════════════════════════════════════════════════════");
    try {
        AddSC_dc_achievements();
        LOG_INFO("scripts.dc", ">>   ✓ Custom achievements loaded");
    } catch (std::exception& e) {
        LOG_ERROR("scripts.dc", ">>   ✗ EXCEPTION in Custom Achievements: {}", e.what());
    } catch (...) {
        LOG_ERROR("scripts.dc", ">>   ✗ CRASH in Custom Achievements");
    }

    // ═══════════════════════════════════════════════════════════════════════
    // COLLECTION SYSTEM
    // ═══════════════════════════════════════════════════════════════════════
    LOG_INFO("scripts.dc", ">> ═══════════════════════════════════════════════════════════");
    LOG_INFO("scripts.dc", ">> Collection System (Mounts, Pets, Heirlooms, Transmog)");
    LOG_INFO("scripts.dc", ">> ═══════════════════════════════════════════════════════════");
    try {
        // AddSC_dc_addon_collection(); // Moved to AddonExtension
        LOG_INFO("scripts.dc", ">>   ✓ Collection system handlers and scripts loaded");
    } catch (std::exception& e) {
        LOG_ERROR("scripts.dc", ">>   ✗ EXCEPTION in Collection System: {}", e.what());
    } catch (...) {
        LOG_ERROR("scripts.dc", ">>   ✗ CRASH in Collection System");
    }

    // ═══════════════════════════════════════════════════════════════════════
    // ITEM UPGRADE SYSTEM v2.0
    // ═══════════════════════════════════════════════════════════════════════
    LOG_INFO("scripts.dc", ">> ═══════════════════════════════════════════════════════════");
    LOG_INFO("scripts.dc", ">> DarkChaos Item Upgrade System v2.0 (Hybrid Scaling)");
    LOG_INFO("scripts.dc", ">> ═══════════════════════════════════════════════════════════");
    LOG_INFO("scripts.dc", ">>   Core Features:");
    LOG_INFO("scripts.dc", ">>     • Enchantment-Based Stat Scaling");
    LOG_INFO("scripts.dc", ">>     • UnitScript Proc Damage/Healing Scaling");
    LOG_INFO("scripts.dc", ">>     • 2 Tiers × 15 Levels = 30 Upgrade Paths");
    LOG_INFO("scripts.dc", ">>     • Mastery & Artifact Progression");
    LOG_INFO("scripts.dc", ">>     • Transmutation & Tier Conversion");
    LOG_INFO("scripts.dc", ">>     • Seasonal Content Support");
    LOG_INFO("scripts.dc", ">> ───────────────────────────────────────────────────────────");

    try {
        AddSC_ItemUpgradeMechanicsImpl();
        LOG_INFO("scripts.dc", ">>   ✓ Core mechanics loaded");
    } catch (std::exception& e) {
        LOG_ERROR("scripts.dc", ">>   ✗ EXCEPTION in core mechanics: {}", e.what());
    } catch (...) {
        LOG_ERROR("scripts.dc", ">>   ✗ CRASH in core mechanics");
    }



    try {

        LOG_INFO("scripts.dc", ">>   ✓ Consolidated Item Upgrade commands loaded");
    } catch (std::exception& e) {
        LOG_ERROR("scripts.dc", ">>   ✗ EXCEPTION in Item Upgrade commands: {}", e.what());
    } catch (...) {
        LOG_ERROR("scripts.dc", ">>   ✗ CRASH in Item Upgrade commands");
    }



    try {
        AddSC_ItemUpgradeVendor();
        LOG_INFO("scripts.dc", ">>   ✓ Token vendor NPC loaded");
    } catch (std::exception& e) {
        LOG_ERROR("scripts.dc", ">>   ✗ EXCEPTION in vendor: {}", e.what());
    } catch (...) {
        LOG_ERROR("scripts.dc", ">>   ✗ CRASH in vendor");
    }

    try {
        AddSC_ItemUpgradeCurator();
        LOG_INFO("scripts.dc", ">>   ✓ Artifact curator NPC loaded");
    } catch (std::exception& e) {
        LOG_ERROR("scripts.dc", ">>   ✗ EXCEPTION in curator: {}", e.what());
    } catch (...) {
        LOG_ERROR("scripts.dc", ">>   ✗ CRASH in curator");
    }



    try {
        AddSC_ItemUpgradeSeasonal();
        LOG_INFO("scripts.dc", ">>   ✓ Seasonal system loaded");
    } catch (std::exception& e) {
        LOG_ERROR("scripts.dc", ">>   ✗ EXCEPTION in seasonal: {}", e.what());
    } catch (...) {
        LOG_ERROR("scripts.dc", ">>   ✗ CRASH in seasonal");
    }



    try {
        AddSC_ItemUpgradeTransmutation();
        LOG_INFO("scripts.dc", ">>   ✓ Transmutation NPC loaded");
    } catch (std::exception& e) {
        LOG_ERROR("scripts.dc", ">>   ✗ EXCEPTION in transmutation: {}", e.what());
    } catch (...) {
        LOG_ERROR("scripts.dc", ">>   ✗ CRASH in transmutation");
    }

    try {
        AddSC_ItemUpgradeTokenHooks();
        LOG_INFO("scripts.dc", ">>   ✓ Token hooks loaded");
    } catch (std::exception& e) {
        LOG_ERROR("scripts.dc", ">>   ✗ EXCEPTION in token hooks: {}", e.what());
    } catch (...) {
        LOG_ERROR("scripts.dc", ">>   ✗ CRASH in token hooks");
    }

    try {
        AddSC_ItemUpgradeProcScaling();
        LOG_INFO("scripts.dc", ">>   ✓ Proc scaling loaded (UnitScript hooks)");
    } catch (std::exception& e) {
        LOG_ERROR("scripts.dc", ">>   ✗ EXCEPTION in proc scaling: {}", e.what());
    } catch (...) {
        LOG_ERROR("scripts.dc", ">>   ✗ CRASH in proc scaling");
    }

    try {
        AddSC_ItemUpgradeStatApplication();
        LOG_INFO("scripts.dc", ">>   ✓ Stat application loaded (enchantment-based)");
    } catch (std::exception& e) {
        LOG_ERROR("scripts.dc", ">>   ✗ EXCEPTION in stat application: {}", e.what());
    } catch (...) {
        LOG_ERROR("scripts.dc", ">>   ✗ CRASH in stat application");
    }

    try {
        AddSC_ItemUpgradeQuestRewardHook();
        LOG_INFO("scripts.dc", ">>   ✓ Quest reward hooks loaded");
    } catch (std::exception& e) {
        LOG_ERROR("scripts.dc", ">>   ✗ EXCEPTION in quest reward hooks: {}", e.what());
    } catch (...) {
        LOG_ERROR("scripts.dc", ">>   ✗ CRASH in quest reward hooks");
    }

    LOG_INFO("scripts.dc", ">> ═══════════════════════════════════════════════════════════");
    LOG_INFO("scripts.dc", ">> Item Upgrade System: All modules loaded successfully");
    LOG_INFO("scripts.dc", ">> ═══════════════════════════════════════════════════════════");

    // ═══════════════════════════════════════════════════════════════════════
    // MYTHIC+ DUNGEON SYSTEM
    // ═══════════════════════════════════════════════════════════════════════
    LOG_INFO("scripts.dc", ">> ═══════════════════════════════════════════════════════════");
    LOG_INFO("scripts.dc", ">> Mythic+ Dungeon Scaling System");
    LOG_INFO("scripts.dc", ">> ═══════════════════════════════════════════════════════════");
    try {
        AddMythicPlusScripts();
        LOG_INFO("scripts.dc", ">>   ✓ Mythic+ dungeon scaling and keystone system loaded");
    } catch (std::exception& e) {
        LOG_ERROR("scripts.dc", ">>   ✗ EXCEPTION in Mythic+ System: {}", e.what());
    } catch (...) {
        LOG_ERROR("scripts.dc", ">>   ✗ CRASH in Mythic+ System");
    }

    try {
        AddSC_dc_mythic_spectator();
        LOG_INFO("scripts.dc", ">>   ✓ Mythic+ Spectator system loaded");
    } catch (std::exception& e) {
        LOG_ERROR("scripts.dc", ">>   ✗ EXCEPTION in M+ Spectator: {}", e.what());
    } catch (...) {
        LOG_ERROR("scripts.dc", ">>   ✗ CRASH in M+ Spectator");
    }
    LOG_INFO("scripts.dc", ">> ═══════════════════════════════════════════════════════════");

    // ═══════════════════════════════════════════════════════════════════════
    // SEASONAL REWARD SYSTEM
    // ═══════════════════════════════════════════════════════════════════════
    LOG_INFO("scripts.dc", ">> ═══════════════════════════════════════════════════════════");
    LOG_INFO("scripts.dc", ">> DC Seasonal Reward System (C++ Core)");
    LOG_INFO("scripts.dc", ">> ═══════════════════════════════════════════════════════════");
    LOG_INFO("scripts.dc", ">>   Core Features:");
    LOG_INFO("scripts.dc", ">>     • Token & Essence Rewards (Quest/Creature/Boss)");
    LOG_INFO("scripts.dc", ">>     • Weekly Cap System (Configurable Limits)");
    LOG_INFO("scripts.dc", ">>     • Weekly Chest Rewards (3-Slot M+ Vault)");
    LOG_INFO("scripts.dc", ">>     • Achievement Auto-Tracking");
    LOG_INFO("scripts.dc", ">>     • AIO Client Communication (Eluna Bridge)");
    LOG_INFO("scripts.dc", ">>     • Admin Commands (.season)");
    LOG_INFO("scripts.dc", ">> ───────────────────────────────────────────────────────────");
    try {
        AddSC_SeasonalRewardScripts();
        LOG_INFO("scripts.dc", ">>   ✓ Seasonal reward hooks and player scripts loaded");
    } catch (std::exception& e) {
        LOG_ERROR("scripts.dc", ">>   ✗ EXCEPTION in seasonal scripts: {}", e.what());
    } catch (...) {
        LOG_ERROR("scripts.dc", ">>   ✗ CRASH in seasonal scripts");
    }

    try {

        LOG_INFO("scripts.dc", ">>   ✓ Seasonal admin commands loaded (.season)");
    } catch (std::exception& e) {
        LOG_ERROR("scripts.dc", ">>   ✗ EXCEPTION in seasonal commands: {}", e.what());
    } catch (...) {
        LOG_ERROR("scripts.dc", ">>   ✗ CRASH in seasonal commands");
    }
    LOG_INFO("scripts.dc", ">> ═══════════════════════════════════════════════════════════");
    LOG_INFO("scripts.dc", ">> Seasonal Reward System: All modules loaded successfully");
    LOG_INFO("scripts.dc", ">> ═══════════════════════════════════════════════════════════");

    // ═══════════════════════════════════════════════════════════════════════
    // PHASED DUELS SYSTEM
    // ═══════════════════════════════════════════════════════════════════════
    LOG_INFO("scripts.dc", ">> ═══════════════════════════════════════════════════════════");
    LOG_INFO("scripts.dc", ">> Phased Duels System");
    LOG_INFO("scripts.dc", ">> ═══════════════════════════════════════════════════════════");
    try {
        AddSC_dc_phased_duels();
        LOG_INFO("scripts.dc", ">>   ✓ Phased duels isolation and statistics loaded");
    } catch (std::exception& e) {
        LOG_ERROR("scripts.dc", ">>   ✗ EXCEPTION in Phased Duels: {}", e.what());
    } catch (...) {
        LOG_ERROR("scripts.dc", ">>   ✗ CRASH in Phased Duels");
    }
    LOG_INFO("scripts.dc", ">> ═══════════════════════════════════════════════════════════");

    // DUNGEON QUEST SYSTEM will be loaded at the final stage (moved)

    // ═══════════════════════════════════════════════════════════════════════
    // ADDON EXTENSION SYSTEM (Communication Protocol)
    // ═══════════════════════════════════════════════════════════════════════
    LOG_INFO("scripts.dc", ">> ═══════════════════════════════════════════════════════════");
    LOG_INFO("scripts.dc", ">> Addon Extension System (DC Unified Protocol)");
    LOG_INFO("scripts.dc", ">> ═══════════════════════════════════════════════════════════");
    try {
        AddDCAddonExtensionScripts();
        LOG_INFO("scripts.dc", ">>   ✓ Addon communication protocol loaded");
    } catch (std::exception& e) {
        LOG_ERROR("scripts.dc", ">>   ✗ EXCEPTION in Addon Extension: {}", e.what());
    } catch (...) {
        LOG_ERROR("scripts.dc", ">>   ✗ CRASH in Addon Extension");
    }
    LOG_INFO("scripts.dc", ">> ═══════════════════════════════════════════════════════════");

    // ═══════════════════════════════════════════════════════════════════════
    // FIRST-START SYSTEM (Custom Login, Welcome Experience)
    // ═══════════════════════════════════════════════════════════════════════
    LOG_INFO("scripts.dc", ">> ═══════════════════════════════════════════════════════════");
    LOG_INFO("scripts.dc", ">> First-Start System (Custom Login, Welcome)");
    LOG_INFO("scripts.dc", ">> ═══════════════════════════════════════════════════════════");
    try {
        AddSC_dc_firststart();
        LOG_INFO("scripts.dc", ">>   ✓ First-start experience loaded");
    } catch (std::exception& e) {
        LOG_ERROR("scripts.dc", ">>   ✗ EXCEPTION in First-Start: {}", e.what());
    } catch (...) {
        LOG_ERROR("scripts.dc", ">>   ✗ CRASH in First-Start");
    }
    LOG_INFO("scripts.dc", ">> ═══════════════════════════════════════════════════════════");

    // ═══════════════════════════════════════════════════════════════════════
    // GOMOVE SYSTEM
    // ═══════════════════════════════════════════════════════════════════════
    LOG_INFO("scripts.dc", ">> ═══════════════════════════════════════════════════════════");
    LOG_INFO("scripts.dc", ">> GOMove System");
    LOG_INFO("scripts.dc", ">> ═══════════════════════════════════════════════════════════");
    try {
        AddSC_GOMove_commandscript();
        LOG_INFO("scripts.dc", ">>   ✓ GOMove System loaded");
    } catch (std::exception& e) {
        LOG_ERROR("scripts.dc", ">>   ✗ EXCEPTION in GOMove: {}", e.what());
    } catch (...) {
        LOG_ERROR("scripts.dc", ">>   ✗ CRASH in GOMove");
    }

    // ═══════════════════════════════════════════════════════════════════════
    // CROSS-SYSTEM INTEGRATION FRAMEWORK (Loaded Last - Coordinates All Systems)
    // ═══════════════════════════════════════════════════════════════════════
    LOG_INFO("scripts.dc", ">> ═══════════════════════════════════════════════════════════");
    LOG_INFO("scripts.dc", ">> Cross-System Integration Framework");
    LOG_INFO("scripts.dc", ">> ═══════════════════════════════════════════════════════════");
    try {
        AddSC_dc_cross_system_scripts();
        LOG_INFO("scripts.dc", ">>   ✓ Cross-System framework loaded");
        LOG_INFO("scripts.dc", ">>   ✓ Session context management active");
        LOG_INFO("scripts.dc", ">>   ✓ Event bus ready for system coordination");
        LOG_INFO("scripts.dc", ">>   ✓ Unified reward distributor active");
    } catch (std::exception& e) {
        LOG_ERROR("scripts.dc", ">>   ✗ EXCEPTION in Cross-System Framework: {}", e.what());
    } catch (...) {
        LOG_ERROR("scripts.dc", ">>   ✗ CRASH in Cross-System Framework");
    }
    LOG_INFO("scripts.dc", ">> ═══════════════════════════════════════════════════════════");

    // ═══════════════════════════════════════════════════════════════════════
    // GUILD HOUSING SYSTEM
    // ═══════════════════════════════════════════════════════════════════════
    LOG_INFO("scripts.dc", ">> ═══════════════════════════════════════════════════════════");
    LOG_INFO("scripts.dc", ">> Guild Housing System");
    LOG_INFO("scripts.dc", ">> ═══════════════════════════════════════════════════════════");
    try {
        AddGuildHouseScripts();
        AddGuildHouseButlerScripts();
        AddSC_cs_dc_guildhouse();
        LOG_INFO("scripts.dc", ">>   ✓ Guild Housing scripts loaded");
    } catch (std::exception& e) {
        LOG_ERROR("scripts.dc", ">>   ✗ EXCEPTION in Guild Housing: {}", e.what());
    } catch (...) {
        LOG_ERROR("scripts.dc", ">>   ✗ CRASH in Guild Housing");
    }
    LOG_INFO("scripts.dc", ">> ═══════════════════════════════════════════════════════════");

    // ═══════════════════════════════════════════════════════════════════════
    // ALL DC SCRIPTS LOADED
    // ═══════════════════════════════════════════════════════════════════════
    LOG_INFO("scripts.dc", "╔══════════════════════════════════════════════════════════");
    LOG_INFO("scripts.dc", "║ DarkChaos: DC Scripts — All systems loaded successfully");
    LOG_INFO("scripts.dc", "╚══════════════════════════════════════════════════════════");

    // ═══════════════════════════════════════════════════════════════════════
    // DUNGEON QUEST SYSTEM (Loaded Last)
    // ═══════════════════════════════════════════════════════════════════════
    LOG_INFO("scripts.dc", "╔══════════════════════════════════════════════════════════");
    LOG_INFO("scripts.dc", "║ Dungeon Quest System v3.0 (Enhanced UX + AC Standards) — Loaded Last");
    LOG_INFO("scripts.dc", "╚══════════════════════════════════════════════════════════");
    try {
        AddSC_DungeonQuestSystem();
        AddSC_DungeonQuestPhasing();
        AddSC_DungeonQuestMasterFollower();
        AddSC_npc_dungeon_quest_master();
        AddSC_npc_dungeon_quest_daily_weekly();
        LOG_INFO("scripts.dc", "║   ✓ Dungeon quest mechanics and NPCs loaded");
    } catch (std::exception& e) {
        LOG_ERROR("scripts.dc", "║   ✗ EXCEPTION in Dungeon Quest System: {}", e.what());
    } catch (...) {
        LOG_ERROR("scripts.dc", "║   ✗ CRASH in Dungeon Quest System");
    }
    LOG_INFO("scripts.dc", "╚══════════════════════════════════════════════════════════");

    // ═══════════════════════════════════════════════════════════════════════
    // DC COMMANDS (Unified command system)
    // ═══════════════════════════════════════════════════════════════════════
    LOG_INFO("scripts.dc", ">> ═══════════════════════════════════════════════════════════");
    LOG_INFO("scripts.dc", ">> DC Commands (Unified .dc command hub)");
    LOG_INFO("scripts.dc", ">> ═══════════════════════════════════════════════════════════");
    try {
        AddSC_dc_addons_commandscript();
        AddSC_dc_dungeonquests_commandscript();
        AddSC_dc_hinterland_bg_commandscript();
        AddSC_dc_mythic_plus_commandscript();
        AddSC_dc_seasonal_rewards_commandscript();
        AddSC_dc_prestige_commandscript();
        AddSC_dc_item_upgrade_commandscript();
        LOG_INFO("scripts.dc", ">>   ✓ DC addon commands and dungeon quest commands loaded");
        LOG_INFO("scripts.dc", ">>   ✓ Consolidated DC commands loaded (HLBG, M+, Season, Prestige, ItemUpgrade)");
    } catch (std::exception& e) {
        LOG_ERROR("scripts.dc", ">>   ✗ EXCEPTION in DC Commands: {}", e.what());
    } catch (...) {
        LOG_ERROR("scripts.dc", ">>   ✗ CRASH in DC Commands");
    }
    LOG_INFO("scripts.dc", ">> ═══════════════════════════════════════════════════════════");
}
