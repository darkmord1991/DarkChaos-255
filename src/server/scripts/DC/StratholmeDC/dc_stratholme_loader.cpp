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

// Wrapper loader for the DarkChaos Stratholme clone (map 821).
// Registered once from dc_script_loader.cpp -- do NOT also list the individual
// AddSC_* entries there, or every script gets a duplicate registration path.
//
// The instance script is registered FIRST. The three boss AIs resolve their instance
// through GetStratholmeDCAI, so the instance must exist by the time a creature spawns;
// registration order also makes a name clash obvious immediately rather than at first pull.

void AddSC_instance_stratholme_dc();
void AddSC_boss_baroness_anastari_dc();
void AddSC_boss_jarien_and_sothos_dc();
void AddSC_npc_stratholme_dc_portal_trigger();

void AddDCStratholmeScripts()
{
    AddSC_instance_stratholme_dc();
    AddSC_boss_baroness_anastari_dc();
    AddSC_boss_jarien_and_sothos_dc();
    AddSC_npc_stratholme_dc_portal_trigger();
}
