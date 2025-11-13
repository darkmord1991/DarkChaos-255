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


void AddSC_ac_guard_npc(); // location: scripts\DC\AC\ac_guard_npc.cpp (C++ linkage)
void AddSC_flighthelper_test(); // location: scripts\DC\AC\cs_flighthelper_test.cpp
void AddSC_npc_thrall_hinterlandbg(); // location: scripts\DC\HinterlandBG\npc_thrall_warchief.cpp
void AddSC_hinterlandbg_Varian_wrynn(); // location: scripts\DC\HinterlandBG\npc_Varian_hinterlandbg.cpp
void AddSC_hlbg_commandscript(); // location: scripts\DC\HinterlandBG\hlbg_commandscript.cpp (C++ linkage)
void AddSC_dc_login_announce(); // location: scripts\DC\dc_login_announce.cpp
void AddSC_ac_quest_npc_800009(); // location: scripts\DC\AC\ac_quest_npc_800009.cpp
void AddSC_aio_bridge(); // location: scripts\DC\AIO\aio_bridge.cpp
void AddSC_flightmasters(); // location: scripts\DC\AC\ac_flightmasters.cpp
void AddSC_hl_scoreboard(); // location: scripts\DC\HinterlandBG\HL_ScoreboardNPC.cpp
void AddSC_hlbg_addon(); // location: scripts\DC\HinterlandBG\hlbg_addon.cpp
void AddSC_npc_hinterlands_battlemaster(); // location: scripts\DC\HinterlandBG\npc_hinterlands_battlemaster.cpp
// HL_StatsAIO.cpp provides HandleHLBGStatsUI implementation - no AddSC needed
void AddSC_ac_hotspots(); // location: scripts\DC\AC\ac_hotspots.cpp
void AddSC_spell_hotspot_buff_800001(); // location: scripts\DC\Hotspot\spell_hotspot_buff_800001.cpp
void AddSC_ac_aoeloot(); // location: scripts\DC\AC\ac_aoeloot.cpp
void AddSC_heirloom_scaling_255(); // location: scripts\DC\heirloom_scaling_255.cpp
void AddBattleForGilneasScripts(); // location: scripts\DC\Gilneas\BattlegroundBFG.cpp
// GPS broadcaster removed - Using Eluna instead (Custom/Eluna scripts/DC_MapGPS.lua)
void AddSC_cs_gps_test(); // location: scripts\DC\MapExtension\cs_gps_test.cpp
void AddSC_PlayerScript_MapExtension(); // location: scripts\DC\MapExtension\PlayerScript_MapExtension.cpp
void AddSC_dc_prestige_system(); // location: scripts\DC\dc_prestige_system.cpp
void AddSC_dc_prestige_spells(); // location: scripts\DC\dc_prestige_spells.cpp
void AddSC_dc_prestige_alt_bonus(); // location: scripts\DC\Prestige\dc_prestige_alt_bonus.cpp
void AddSC_dc_prestige_challenges(); // location: scripts\DC\Prestige\dc_prestige_challenges.cpp
void AddSC_spell_prestige_alt_bonus_aura(); // location: scripts\DC\Prestige\spell_prestige_alt_bonus_aura.cpp
void AddSC_dc_challenge_modes(); // location: scripts\DC\dc_challenge_modes_customized.cpp
void AddSC_spell_challenge_mode_auras(); // location: scripts\DC\ChallengeMode\spell_challenge_mode_auras.cpp
void AddSC_dc_achievements(); // location: scripts\DC\Achievements\dc_achievements.cpp
void AddSC_DungeonQuestSystem(); // location: scripts\DC\DungeonQuests\DungeonQuestSystem.cpp
void AddSC_DungeonQuestPhasing(); // location: scripts\DC\DungeonQuests\DungeonQuestPhasing.cpp
void AddSC_DungeonQuestMasterFollower(); // location: scripts\DC\DungeonQuests\DungeonQuestMasterFollower.cpp
void AddSC_npc_dungeon_quest_master(); // location: scripts\DC\DungeonQuests\npc_dungeon_quest_master.cpp
void AddSC_npc_dungeon_quest_daily_weekly(); // location: scripts\DC\DungeonQuests\npc_dungeon_quest_daily_weekly.cpp
void AddItemUpgradeGMCommandScript();  // GM admin commands - renamed from AddItemUpgradeCommandScript
void AddSC_ItemUpgradeMechanicsImpl(); // Core mechanics implementation (must load FIRST)
void AddSC_ItemUpgradeAddonHandler();  // Addon communication handler - renamed from AddSC_ItemUpgradeCommands
// ItemUpgrade addon communication moved to Eluna: Custom/Eluna scripts/itemupgrade_communication.lua
void AddSC_ItemUpgradeVendor(); // location: scripts\DC\ItemUpgrades\ItemUpgradeNPC_Vendor.cpp
void AddSC_ItemUpgradeCurator(); // location: scripts\DC\ItemUpgrades\ItemUpgradeNPC_Curator.cpp
void AddSC_ItemUpgradeProgression(); // location: scripts\DC\ItemUpgrades\ItemUpgradeProgressionImpl.cpp
void AddSC_ItemUpgradeSeasonal(); // location: scripts\DC\ItemUpgrades\ItemUpgradeSeasonalImpl.cpp
void AddSC_ItemUpgradeAdvanced(); // location: scripts\DC\ItemUpgrades\ItemUpgradeAdvancedImpl.cpp
void AddSC_ItemUpgradeTransmutation(); // location: scripts\DC\ItemUpgrades\ItemUpgradeTransmutationNPC.cpp
void AddSC_ItemUpgradeTokenHooks(); // location: scripts\DC\ItemUpgrades\ItemUpgradeTokenHooks.cpp
void AddSC_ItemUpgradeProcScaling(); // location: scripts\DC\ItemUpgrades\ItemUpgradeProcScaling.cpp
void AddSC_ItemUpgradeStatApplication(); // location: scripts\DC\ItemUpgrades\ItemUpgradeStatApplication.cpp
void AddSC_mythicplus_commandscript(); // location: scripts\DC\DungeonEnhancement\Commands\mythicplus_commandscript.cpp
void AddSC_difficulty_level_scaling(); // location: scripts\DC\DungeonEnhancements\DifficultyLevelScaling.cpp
void AddSC_difficulty_commandscript(); // location: scripts\DC\DungeonEnhancements\Commands\difficulty_commandscript.cpp
void AddSC_DungeonEnhancement_CreatureScript(); // location: scripts\DC\DungeonEnhancement\Hooks\DungeonEnhancement_CreatureScript.cpp
void AddSC_DungeonEnhancement_PlayerScript(); // location: scripts\DC\DungeonEnhancement\Hooks\DungeonEnhancement_PlayerScript.cpp
void AddSC_npc_mythic_plus_dungeon_teleporter(); // location: scripts\DC\DungeonEnhancement\NPCs\npc_mythic_plus_dungeon_teleporter.cpp
void AddSC_npc_keystone_master(); // location: scripts\DC\DungeonEnhancement\NPCs\npc_keystone_master.cpp
void AddSC_go_mythic_plus_great_vault(); // location: scripts\DC\DungeonEnhancement\GameObjects\go_mythic_plus_great_vault.cpp
void AddSC_go_mythic_plus_font_of_power(); // location: scripts\DC\DungeonEnhancement\GameObjects\go_mythic_plus_font_of_power.cpp

// The name of this function should match:
// void Add${NameOfDirectory}Scripts()
void AddDCScripts()
{
    // Core AC Scripts
    AddSC_ac_guard_npc();
    AddSC_flighthelper_test();
    AddSC_dc_login_announce();
    AddSC_ac_quest_npc_800009();
    AddSC_aio_bridge();
    AddSC_flightmasters();
    AddSC_ac_aoeloot();
    AddSC_heirloom_scaling_255();
    AddBattleForGilneasScripts();
    AddSC_cs_gps_test();
    AddSC_PlayerScript_MapExtension();

    // Hinterland BG System
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
        LOG_INFO("scripts", ">>   ✓ Hinterland BG NPCs and commands loaded");
    } catch (std::exception& e) {
        LOG_ERROR("scripts", ">>   ✗ EXCEPTION in Hinterland BG: {}", e.what());
    } catch (...) {
        LOG_ERROR("scripts", ">>   ✗ CRASH in Hinterland BG");
    }

    // Challenge Mode System
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

    // Prestige System
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

    // Dungeon Quest System
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

    // Hotspots System
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

    // Custom Achievements System
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

    // Dungeon Enhancement System (Mythic & Mythic+)
    LOG_INFO("scripts", ">> ═══════════════════════════════════════════════════════════");
    LOG_INFO("scripts", ">> Dungeon Enhancement System (Mythic & Mythic+)");
    LOG_INFO("scripts", ">> ═══════════════════════════════════════════════════════════");
    try {
        AddSC_difficulty_level_scaling();
        AddSC_difficulty_commandscript();
        AddSC_DungeonEnhancement_CreatureScript();
        AddSC_DungeonEnhancement_PlayerScript();
        AddSC_npc_mythic_plus_dungeon_teleporter();
        AddSC_npc_keystone_master();
        AddSC_go_mythic_plus_great_vault();
        AddSC_go_mythic_plus_font_of_power();
        AddSC_mythicplus_commandscript();
        LOG_INFO("scripts", ">>   ✓ Dungeon Enhancement hooks, NPCs, commands, and scaling loaded");
    } catch (std::exception& e) {
        LOG_ERROR("scripts", ">>   ✗ EXCEPTION in Dungeon Enhancement: {}", e.what());
    } catch (...) {
        LOG_ERROR("scripts", ">>   ✗ CRASH in Dungeon Enhancement module");
    }

    // Item Upgrade System (Loaded Last)
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
        AddSC_ItemUpgradeMechanicsImpl();     // Core mechanics (MUST load first - provides static functions)
        LOG_INFO("scripts", ">>   ✓ Core mechanics loaded");
    } catch (std::exception& e) {
        LOG_ERROR("scripts", ">>   ✗ EXCEPTION in core mechanics: {}", e.what());
    } catch (...) {
        LOG_ERROR("scripts", ">>   ✗ CRASH in core mechanics");
    }

    try {
        AddItemUpgradeGMCommandScript();      // GM commands (.upgrade token add/remove/set)
        LOG_INFO("scripts", ">>   ✓ GM commands loaded");
    } catch (std::exception& e) {
        LOG_ERROR("scripts", ">>   ✗ EXCEPTION in GM commands: {}", e.what());
    } catch (...) {
        LOG_ERROR("scripts", ">>   ✗ CRASH in GM commands");
    }

    try {
        AddSC_ItemUpgradeAddonHandler();      // Addon communication (.dcupgrade init/query/upgrade)
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

    LOG_INFO("scripts", ">> ═══════════════════════════════════════════════════════════");
    LOG_INFO("scripts", ">> Item Upgrade System: All modules loaded successfully");
    LOG_INFO("scripts", ">> ═══════════════════════════════════════════════════════════");
}
