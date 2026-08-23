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

// Wrapper loader for the DarkChaos Scholomance clone (map 822).
// Registered once from dc_script_loader.cpp -- do NOT also list the individual
// AddSC_* entries there, or every script gets a duplicate registration path.
//
// The instance script is registered FIRST. The boss AIs resolve their instance through
// GetScholomanceDCAI, so the instance must exist by the time a creature spawns; registering
// it first also makes a name clash obvious immediately rather than at first pull.
//
// NOTE the spell/aura scripts from the upstream files are deliberately NOT here. They bind
// to SPELL ids through spell_script_names, and Spell.dbc is shared with stock Scholomance,
// so the stock registrations already cover this map -- cloning them would attach two
// scripts to the same spells.

void AddSC_instance_scholomance_dc();
void AddSC_boss_darkmaster_gandling_dc();
void AddSC_boss_kirtonos_the_herald_dc();
void AddSC_boss_kormok_dc();
void AddSC_npc_scholomance_dc_portal_trigger();

void AddDCScholomanceScripts()
{
    AddSC_instance_scholomance_dc();
    AddSC_boss_darkmaster_gandling_dc();
    AddSC_boss_kirtonos_the_herald_dc();
    AddSC_boss_kormok_dc();
    AddSC_npc_scholomance_dc_portal_trigger();
}
