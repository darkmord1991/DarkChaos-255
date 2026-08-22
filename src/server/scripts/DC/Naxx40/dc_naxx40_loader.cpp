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

// ============================================================================
// DC Naxxramas 40 ("special edition") - map 2921
//
// Ported out of `mod-vanilla-naxxramas` (sogladev) into the DC scripts tree.
// Stock WotLK Naxxramas keeps map 533 and core's `instance_naxxramas`; this
// layer owns map 2921 via `instance_naxxramas_40`.
//
// The spell/aura scripts here deliberately KEEP core's script names, so they
// replace AzerothCore's Naxxramas spell handlers globally - that is the
// "vanilla mechanics everywhere" behaviour. Each one branches internally:
// RAID_DIFFICULTY_10MAN_HEROIC (the 40-man) gets vanilla values, every other
// difficulty falls through to the WotLK behaviour. Do NOT rename them without
// re-checking those else-branches.
// ============================================================================

void AddVanillaNaxxramasScripts();
void AddSC_npc_omarion_40();
void AddSC_instance_naxxramas_40();
void AddSC_boss_anubrekhan_40();
void AddSC_boss_faerlina_40();
void AddSC_boss_four_horsemen_40();
void AddSC_boss_gluth_40();
void AddSC_boss_gothik_40();
void AddSC_boss_grobbulus_40();
void AddSC_boss_heigan_40();
void AddSC_boss_kelthuzad_40();
void AddSC_boss_loatheb_40();
void AddSC_boss_maexxna_40();
void AddSC_boss_noth_40();
void AddSC_boss_patchwerk_40();
void AddSC_boss_razuvious_40();
void AddSC_boss_sapphiron_40();
void AddSC_boss_thaddius_40();
void AddSC_custom_spells_40();
void AddSC_custom_creatures_40();
void AddSC_custom_gameobjects_40();
void AddSC_custom_scripts_40();

void AddDCNaxx40Scripts()
{
    AddVanillaNaxxramasScripts();
    AddSC_npc_omarion_40();
    AddSC_instance_naxxramas_40();
    AddSC_boss_anubrekhan_40();
    AddSC_boss_faerlina_40();
    AddSC_boss_four_horsemen_40();
    AddSC_boss_gluth_40();
    AddSC_boss_gothik_40();
    AddSC_boss_grobbulus_40();
    AddSC_boss_heigan_40();
    AddSC_boss_kelthuzad_40();
    AddSC_boss_loatheb_40();
    AddSC_boss_maexxna_40();
    AddSC_boss_noth_40();
    AddSC_boss_patchwerk_40();
    AddSC_boss_razuvious_40();
    AddSC_boss_sapphiron_40();
    AddSC_boss_thaddius_40();
    AddSC_custom_spells_40();
    AddSC_custom_creatures_40();
    AddSC_custom_gameobjects_40();
    AddSC_custom_scripts_40();
}
