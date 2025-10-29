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
void AddSC_hl_stats_aio(); // location: scripts\DC\HinterlandBG\HL_StatsAIO.cpp
void AddSC_ac_hotspots(); // location: scripts\DC\AC\ac_hotspots.cpp
void AddSC_ac_aoeloot(); // location: scripts\DC\AC\ac_aoeloot.cpp
void AddBattleForGilneasScripts(); // location: scripts\DC\Gilneas\BattlegroundBFG.cpp

// The name of this function should match:
// void Add${NameOfDirectory}Scripts()
void AddDCScripts()
{
    AddSC_ac_guard_npc();
    AddSC_flighthelper_test();
    AddSC_npc_thrall_hinterlandbg();
    AddSC_hinterlandbg_Varian_wrynn();
    AddSC_hlbg_commandscript();
    AddSC_dc_login_announce();
    AddSC_ac_quest_npc_800009();
    AddSC_aio_bridge();
    AddSC_flightmasters();
    AddSC_hl_scoreboard();
    AddSC_hlbg_addon();
    AddSC_hl_stats_aio();
    AddSC_ac_hotspots();
    AddSC_ac_aoeloot();
    AddBattleForGilneasScripts();
}
