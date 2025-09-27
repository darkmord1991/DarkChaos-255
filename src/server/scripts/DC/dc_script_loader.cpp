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

// This is where scripts' loading functions should be declared:
void AddSC_ac_guard_npc(); // location: scripts\DC\AC\ac_guard_npc.cpp
void AddSC_hinterlandbg_thrall_warchief(); // location: scripts\DC\HinterlandBG\npc_thrall_warchief.cpp
void AddSC_hinterlandbg_Varian_wrynn(); // location: scripts\DC\HinterlandBG\npc_Varian_hinterlandbg.cpp

// The name of this function should match:
// void Add${NameOfDirectory}Scripts()
void AddDCScripts()
{
    AddSC_ac_guard_npc();
    AddSC_hinterlandbg_thrall_warchief();
    AddSC_hinterlandbg_Varian_wrynn();
}
