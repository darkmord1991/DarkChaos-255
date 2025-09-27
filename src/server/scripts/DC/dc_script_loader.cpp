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
void AddSC_npc_thrall_hinterlandbg(); // location: scripts\DC\HinterlandBG\npc_thrall_warchief.cpp
void AddSC_hinterlandbg_Varian_wrynn(); // location: scripts\DC\HinterlandBG\npc_Varian_hinterlandbg.cpp
void AddSC_hlbg_commandscript(); // location: scripts\DC\HinterlandBG\hlbg_commandscript.cpp (C++ linkage)

// The name of this function should match:
// void Add${NameOfDirectory}Scripts()
void AddDCScripts()
{
    AddSC_ac_guard_npc();
    AddSC_npc_thrall_hinterlandbg();
    AddSC_hinterlandbg_Varian_wrynn();
    AddSC_hlbg_commandscript();
}
