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
 * You should have received a copy of the GNU Affero General Public License along
 * with this program. If not, see <http://www.gnu.org/licenses/>.
 */

// Wrapper loader for the Cataclysm Shadowfang Keep downport (clone map 825).
// Registered once from dc_script_loader.cpp -- do NOT also list the individual
// AddSC_* entries there, or every script gets a duplicate registration path.

void AddSC_boss_baron_ashbury();
void AddSC_boss_baron_silverlaine();
void AddSC_boss_commander_springvale();
void AddSC_boss_lord_walden();
void AddSC_boss_lord_godfrey();
void AddSC_instance_sfk_cata();
void AddSC_npc_sfk_cata_portal_trigger();

void AddDCShadowfangKeepCataScripts()
{
    AddSC_instance_sfk_cata();
    AddSC_boss_baron_ashbury();
    AddSC_boss_baron_silverlaine();
    AddSC_boss_commander_springvale();
    AddSC_boss_lord_walden();
    AddSC_boss_lord_godfrey();
    AddSC_npc_sfk_cata_portal_trigger();
}
