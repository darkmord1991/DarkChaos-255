/*
 * DarkChaos Item Upgrade - Proc Scaling System
 *
 * Header for proc scaling functionality.
 *
 * Author: DarkChaos Development Team
 * Date: December 17, 2025
 */

#pragma once

#include "Define.h"
#include <string>
#include <vector>

class Item;
class Player;

namespace DarkChaos
{
    namespace ItemUpgrade
    {
        // Returns a formatted string describing the player's currently scaled procs
        std::string GetPlayerProcScalingInfo(Player* player);

        // True when the proc registry maps spellId back to itemEntry, i.e. when the
        // combat hooks WILL scale that spell for that item. The tooltip builder pairs
        // this with the hovered item's own multiplier -- asking "is this spell
        // scaled?" separately from "by how much?" keeps the printed number tied to
        // the item being inspected rather than to whatever happens to be equipped.
        bool IsProcScalingIndexed(uint32 itemEntry, uint32 spellId);

        // The item's scaling Equip:/Use:/Chance-on-hit sentences rendered at
        // `multiplier`, one string per item spell. Only spells the combat hooks really
        // scale are included, and only when scaling changes the text -- an aura with
        // no numbers in its description is the same sentence at every level.
        //
        // Defined in dc_addon_qos.cpp, next to the description renderer it shares with
        // the native item tooltip, so the upgrade window and the tooltip print the
        // same numbers by construction rather than by two implementations agreeing.
        std::vector<std::string> BuildScaledItemProcLines(Player* player,
            uint32 itemEntry, float multiplier);

        // Random-enchant counterpart of BuildScaledItemProcLines: the stat lines the
        // item's random-enchant slots (PROP_ENCHANTMENT_SLOT_0..4) grant at
        // `multiplier`, limited to the ones an upgrade actually changes.
        std::vector<std::string> BuildScaledRandomEnchantLines(Item* item,
            float multiplier);

        // What one random-enchant line (PROP_ENCHANTMENT_SLOT_0 + line) prints at
        // `multiplier`: the rows the item tooltip shows for it, whether or not an upgrade
        // changes them. The reroll window uses it so a line reads as it does on the item.
        std::vector<std::string> BuildRandomEnchantLineText(Item* item, uint8 line,
            float multiplier);

        // True when spellId is an "equip spell" whose aura amounts the upgrade hooks
        // scale -- i.e. it applies at least one aura that is not itself a proc/periodic
        // trigger. "+33 Frost Spell Damage" (enchant 2253 -> spell 17895) is the
        // typical case. Lets the tooltip decide whether scaling the number printed in
        // an enchant's description would be telling the truth.
        bool IsUpgradeScaledEquipSpell(uint32 spellId);

        // Re-index the spell -> source-item map. Called at startup and again on a
        // season start, because the season decides which tier an item level maps to
        // and therefore which items are upgrade-eligible at all.
        void RebuildProcSpellRegistry();

    } // namespace ItemUpgrade
} // namespace DarkChaos
