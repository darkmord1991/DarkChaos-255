/*
 * Dark Chaos - Wardrobe visual replication
 * ========================================
 *
 * Transmog used to be replicated by writing the fake item entry straight into the wearer's
 * PLAYER_VISIBLE_ITEM_*_ENTRYID fields. That mutated authoritative state for every observer
 * at once, so there was no way to give a viewer a "show me real gear" option, and it fought
 * the core's own Player::SetVisibleItemSlot writes.
 *
 * The fields now always hold the real equipped item. The transmog is substituted per
 * observer while the values-update block is being serialised, via the UnitScript hooks
 * ShouldTrackValuesUpdatePosByIndex / OnPatchValuesUpdate. That costs no extra packets:
 * the core builds the block once per unit, records the byte offsets of the tracked fields,
 * and we rewrite those bytes in each observer's copy.
 */

#ifndef DC_WARDROBE_VISUALS_H
#define DC_WARDROBE_VISUALS_H

#include "Define.h"
#include "ObjectGuid.h"

class Player;

namespace DCCollection::WardrobeVisuals
{
    // Sentinel stored per slot when the character has no transmog row for it. A stored 0
    // means "hide this slot", which is a real appearance choice and must be distinguishable
    // from "no row".
    constexpr uint32 NO_TRANSMOG = 0xFFFFFFFF;

    // Player setting source/index for the observer-side opt-out.
    constexpr char const* SETTING_SOURCE = "dc-wardrobe";
    constexpr uint32 SETTING_HIDE_OTHERS_TRANSMOG = 0;

    // The cache is populated on login by CollectionPlayerScript::ApplyCachedTransmogOnLogin,
    // which already reads dc_character_transmog and calls SetSlot per row, so there is no
    // separate load entry point here.

    /** Records a transmog for one slot (0 = hide) and re-dirties the field so observers refresh. */
    void SetSlot(Player* player, uint8 slot, uint32 fakeEntry);

    /** Drops the transmog for one slot and re-dirties the field. */
    void ClearSlot(Player* player, uint8 slot);

    /**
     * Records a chosen weapon-enchant visual for one slot. This is cosmetic only: it changes
     * the permanent half of the visible-item enchantment field for observers and never
     * touches the item's real enchantment, so it grants no stats, procs or charges.
     */
    void SetEnchant(Player* player, uint8 slot, uint32 enchantId);

    /** Drops the chosen enchant visual for one slot, revealing the item's real enchant again. */
    void ClearEnchant(Player* player, uint8 slot);

    /** Drops every cached slot for a character, both caches (logout, character delete). */
    void Erase(ObjectGuid guid);

    /**
     * Hot path, called once per tracked field per observer. Returns true and writes the
     * entry to send when the wearer has a transmog for that slot.
     */
    bool Lookup(ObjectGuid guid, uint8 slot, uint32& fakeEntry);

    /** Enchant-visual counterpart of Lookup. */
    bool LookupEnchant(ObjectGuid guid, uint8 slot, uint32& enchantId);

    /** True when at least one character currently has a transmog cached. */
    bool Any();

    /** True when at least one character currently has an enchant visual cached. */
    bool AnyEnchant();

    /** Registers the UnitScript. Called from AddSC_dc_addon_wardrobe(). */
    void Register();
}

#endif // DC_WARDROBE_VISUALS_H
