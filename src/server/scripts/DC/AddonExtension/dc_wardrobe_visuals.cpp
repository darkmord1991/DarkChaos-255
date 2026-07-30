/*
 * Dark Chaos - Wardrobe visual replication
 * ========================================
 *
 * See dc_wardrobe_visuals.h for why this exists.
 */

#include "dc_wardrobe_visuals.h"

#include "Player.h"
#include "PlayerAppearanceOverride.h"
#include "ScriptMgr.h"
#include "UpdateFields.h"

#include <array>
#include <atomic>
#include <shared_mutex>
#include <unordered_map>

namespace
{
    constexpr uint8 SLOT_COUNT = EQUIPMENT_SLOT_END;

    using SlotArray = std::array<uint32, SLOT_COUNT>;

    std::shared_mutex g_mutex;
    std::unordered_map<ObjectGuid, SlotArray> g_bySlot;

    // Chosen weapon-enchant visuals, same keying and sentinel as g_bySlot. Kept separate so
    // a character with only a transmog costs nothing in the enchant path and vice versa.
    std::unordered_map<ObjectGuid, SlotArray> g_enchantBySlot;

    // Let the per-observer hook short-circuit with one relaxed load while nobody on the realm
    // has anything applied, instead of taking the shared lock per field.
    std::atomic<size_t> g_populated{0};
    std::atomic<size_t> g_enchantPopulated{0};

    SlotArray MakeEmpty()
    {
        SlotArray slots;
        slots.fill(DCCollection::WardrobeVisuals::NO_TRANSMOG);

        return slots;
    }

    /** Field index for a slot's visible-item entry. Entry/enchantment fields interleave. */
    uint16 EntryFieldIndex(uint8 slot)
    {
        return static_cast<uint16>(PLAYER_VISIBLE_ITEM_1_ENTRYID + (slot * 2));
    }

    /** Field index for a slot's visible-item enchantment (perm in the low half, temp in the high). */
    uint16 EnchantFieldIndex(uint8 slot)
    {
        return static_cast<uint16>(PLAYER_VISIBLE_ITEM_1_ENCHANTMENT + (slot * 2));
    }

    /**
     * The real field value does not change when a transmog is applied, so without this the
     * dirty bit is never set and observers already in range keep the old appearance until
     * something unrelated re-sends the field.
     */
    void RedirtySlot(Player* player, uint8 slot)
    {
        player->ForceValuesUpdateAtIndex(EntryFieldIndex(slot));
    }

    void RedirtyEnchantSlot(Player* player, uint8 slot)
    {
        player->ForceValuesUpdateAtIndex(EnchantFieldIndex(slot));
    }

    /** Shared body for the two caches; returns true when the slot's stored value changed. */
    bool StoreSlot(std::unordered_map<ObjectGuid, SlotArray>& target, std::atomic<size_t>& counter,
        ObjectGuid guid, uint8 slot, uint32 value)
    {
        bool wasEmpty = false;

        {
            std::unique_lock<std::shared_mutex> lock(g_mutex);

            auto it = target.find(guid);
            if (it == target.end())
                it = target.emplace(guid, MakeEmpty()).first;

            wasEmpty = it->second[slot] == DCCollection::WardrobeVisuals::NO_TRANSMOG;
            it->second[slot] = value;
        }

        if (wasEmpty)
            counter.fetch_add(1, std::memory_order_relaxed);

        return true;
    }

    bool DropSlot(std::unordered_map<ObjectGuid, SlotArray>& target, std::atomic<size_t>& counter,
        ObjectGuid guid, uint8 slot)
    {
        bool cleared = false;

        {
            std::unique_lock<std::shared_mutex> lock(g_mutex);

            auto it = target.find(guid);
            if (it != target.end() && it->second[slot] != DCCollection::WardrobeVisuals::NO_TRANSMOG)
            {
                it->second[slot] = DCCollection::WardrobeVisuals::NO_TRANSMOG;
                cleared = true;
            }
        }

        if (cleared)
            counter.fetch_sub(1, std::memory_order_relaxed);

        return cleared;
    }

    bool FetchSlot(std::unordered_map<ObjectGuid, SlotArray> const& source, ObjectGuid guid,
        uint8 slot, uint32& out)
    {
        std::shared_lock<std::shared_mutex> lock(g_mutex);

        auto it = source.find(guid);
        if (it == source.end())
            return false;

        uint32 const stored = it->second[slot];
        if (stored == DCCollection::WardrobeVisuals::NO_TRANSMOG)
            return false;

        out = stored;

        return true;
    }
}

namespace DCCollection::WardrobeVisuals
{
    void SetSlot(Player* player, uint8 slot, uint32 fakeEntry)
    {
        if (!player || slot >= SLOT_COUNT)
            return;

        StoreSlot(g_bySlot, g_populated, player->GetGUID(), slot, fakeEntry);
        RedirtySlot(player, slot);
    }

    void ClearSlot(Player* player, uint8 slot)
    {
        if (!player || slot >= SLOT_COUNT)
            return;

        DropSlot(g_bySlot, g_populated, player->GetGUID(), slot);
        RedirtySlot(player, slot);
    }

    void SetEnchant(Player* player, uint8 slot, uint32 enchantId)
    {
        if (!player || slot >= SLOT_COUNT)
            return;

        StoreSlot(g_enchantBySlot, g_enchantPopulated, player->GetGUID(), slot, enchantId);
        RedirtyEnchantSlot(player, slot);
    }

    void ClearEnchant(Player* player, uint8 slot)
    {
        if (!player || slot >= SLOT_COUNT)
            return;

        DropSlot(g_enchantBySlot, g_enchantPopulated, player->GetGUID(), slot);
        RedirtyEnchantSlot(player, slot);
    }

    void Erase(ObjectGuid guid)
    {
        size_t held = 0;
        size_t enchantHeld = 0;

        {
            std::unique_lock<std::shared_mutex> lock(g_mutex);

            if (auto it = g_bySlot.find(guid); it != g_bySlot.end())
            {
                for (uint32 entry : it->second)
                    if (entry != NO_TRANSMOG)
                        ++held;

                g_bySlot.erase(it);
            }

            if (auto it = g_enchantBySlot.find(guid); it != g_enchantBySlot.end())
            {
                for (uint32 entry : it->second)
                    if (entry != NO_TRANSMOG)
                        ++enchantHeld;

                g_enchantBySlot.erase(it);
            }
        }

        if (held)
            g_populated.fetch_sub(held, std::memory_order_relaxed);

        if (enchantHeld)
            g_enchantPopulated.fetch_sub(enchantHeld, std::memory_order_relaxed);
    }

    bool Lookup(ObjectGuid guid, uint8 slot, uint32& fakeEntry)
    {
        if (slot >= SLOT_COUNT)
            return false;

        return FetchSlot(g_bySlot, guid, slot, fakeEntry);
    }

    bool LookupEnchant(ObjectGuid guid, uint8 slot, uint32& enchantId)
    {
        if (slot >= SLOT_COUNT)
            return false;

        return FetchSlot(g_enchantBySlot, guid, slot, enchantId);
    }

    bool Any()
    {
        return g_populated.load(std::memory_order_relaxed) != 0;
    }

    bool AnyEnchant()
    {
        return g_enchantPopulated.load(std::memory_order_relaxed) != 0;
    }
}

namespace
{
    /**
     * Substitutes each observer's copy of the wearer's visible-item entries.
     *
     * The core serialises a unit's values block once and caches the byte offset of every
     * field ShouldTrackValuesUpdatePosByIndex claimed; OnPatchValuesUpdate then rewrites
     * those bytes per observer. No extra packet is produced.
     */
    class dc_wardrobe_visual_script : public UnitScript
    {
    public:
        dc_wardrobe_visual_script() : UnitScript("dc_wardrobe_visual_script", true,
            { UNITHOOK_SHOULD_TRACK_VALUES_UPDATE_POS_BY_INDEX, UNITHOOK_ON_PATCH_VALUES_UPDATE }) { }

        [[nodiscard]] bool ShouldTrackValuesUpdatePosByIndex(Unit const* unit, uint8 /*updateType*/, uint16 index) override
        {
            if (!unit->IsPlayer())
                return false;

            if (index < PLAYER_VISIBLE_ITEM_1_ENTRYID || index > PLAYER_VISIBLE_ITEM_19_ENCHANTMENT)
                return false;

            // Entry and enchantment fields interleave; entries sit at the even offsets from
            // the first entry field, enchantments at the odd ones.
            bool const isEntryField = ((index - PLAYER_VISIBLE_ITEM_1_ENTRYID) % 2) == 0;

            return isEntryField ? DCCollection::WardrobeVisuals::Any()
                                : DCCollection::WardrobeVisuals::AnyEnchant();
        }

        void OnPatchValuesUpdate(Unit const* unit, ByteBuffer& valuesUpdateBuf,
            BuildValuesCachePosPointers& posPointers, Player* target) override
        {
            // The core guarantees target is non-null here, but this hook is cheap insurance
            // against that contract changing under us.
            if (!target || !unit || !unit->IsPlayer())
                return;

            if (posPointers.other.empty())
                return;

            if (!DCCollection::WardrobeVisuals::Any() && !DCCollection::WardrobeVisuals::AnyEnchant())
                return;

            ObjectGuid const wearer = unit->GetGUID();

            // Observer-side opt-out: show real gear instead. Never applies to your own
            // character -- opting out of other people's transmog must not hide your own.
            if (wearer != target->GetGUID()
                && target->GetPlayerSetting(DCCollection::WardrobeVisuals::SETTING_SOURCE,
                       DCCollection::WardrobeVisuals::SETTING_HIDE_OTHERS_TRANSMOG).value)
            {
                return;
            }

            for (auto const& [index, pos] : posPointers.other)
            {
                if (index < PLAYER_VISIBLE_ITEM_1_ENTRYID || index > PLAYER_VISIBLE_ITEM_19_ENCHANTMENT)
                    continue;

                uint16 const offset = static_cast<uint16>(index - PLAYER_VISIBLE_ITEM_1_ENTRYID);
                uint8 const slot = static_cast<uint8>(offset / 2);

                if ((offset % 2) == 0)
                {
                    uint32 fakeEntry = 0;
                    if (!DCCollection::WardrobeVisuals::Lookup(wearer, slot, fakeEntry))
                        continue;

                    valuesUpdateBuf.put(pos, fakeEntry);
                    continue;
                }

                uint32 enchantId = 0;
                if (!DCCollection::WardrobeVisuals::LookupEnchant(wearer, slot, enchantId))
                    continue;

                // The field packs two uint16s: permanent enchant low, temporary high. Only the
                // permanent half is substituted -- dropping the temporary half would strip the
                // visual of any sharpening stone / poison the wearer actually has applied.
                uint32 const realPacked = unit->GetUInt32Value(index);
                uint32 const tempEnchant = (realPacked >> 16) & 0xFFFF;

                valuesUpdateBuf.put(pos, (enchantId & 0xFFFF) | (tempEnchant << 16));
            }
        }
    };
}

namespace
{
    /**
     * Resolver for the consumers that read PLAYER_VISIBLE_ITEM_*_ENTRYID directly and never
     * go through the per-observer path: the character-select equipmentCache blob and the
     * Dancing Rune Weapon copy. Same cache, same answer as the world sees.
     */
    uint32 ResolveAppearanceEntry(Player const* player, uint8 slot, uint32 realEntry)
    {
        if (!player || !DCCollection::WardrobeVisuals::Any())
            return realEntry;

        uint32 fakeEntry = 0;
        if (!DCCollection::WardrobeVisuals::Lookup(player->GetGUID(), slot, fakeEntry))
            return realEntry;

        return fakeEntry;
    }
}

namespace DCCollection::WardrobeVisuals
{
    void Register()
    {
        new dc_wardrobe_visual_script();

        Acore::AppearanceOverride::SetResolver(&ResolveAppearanceEntry);
    }
}
