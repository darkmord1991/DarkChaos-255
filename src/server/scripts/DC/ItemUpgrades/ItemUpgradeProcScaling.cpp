/*
 * DarkChaos Item Upgrade - Proc Scaling System
 * =============================================
 *
 * Implements "True Proc Scaling" by dynamically mapping spells to their source items.
 *
 * LOGIC:
 * 1. On startup, indexes only upgrade-eligible base ItemTemplates to build
 *    a `SpellID -> [ItemID]` map.
 * 2. Hooks Unit::ModifySpellDamageTaken, Unit::ModifyPeriodicDamageAurasTick,
 *    and Unit::ModifyHealReceived.
 * 3. When a registered proc spell is cast:
 *    a. Checks if the caster has the source item equipped.
 *    b. Fetches the specific item's upgrade level.
 *    c. Scales the spell effect by the item's stat multiplier.
 *
 * Author: DarkChaos Development Team
 * Date: December 17, 2025
 */

#include "ScriptMgr.h"
#include "Player.h"
#include "Item.h"
#include "ItemTemplate.h"
#include "SpellAuraEffects.h"
#include "SpellAuras.h"
#include "DBCStores.h"
#include "SpellInfo.h"
#include "SpellMgr.h"
#include "Unit.h"
#include "DatabaseEnv.h"
#include "DC/CrossSystem/SeasonResolver.h"
#include "ItemUpgradeManager.h"
#include "ItemUpgradeProcScaling.h"
#include "Log.h"
#include "Chat.h"
#include "ObjectAccessor.h"
#include <unordered_map>
#include <unordered_set>
#include <vector>
#include <algorithm>
#include <chrono>
#include <cmath>
#include <memory>
#include <mutex>
#include <shared_mutex>
#include <sstream>
#include <iomanip>

namespace DarkChaos
{
namespace ItemUpgrade
{
    // =====================================================================
    // Proc Spell Registry
    // =====================================================================
    // Maps Spell IDs to the Item IDs that trigger them.

    class ProcSpellRegistry
    {
    public:
        // SpellID -> the item entries that can produce it.
        using SpellItemMap = std::unordered_map<uint32, std::vector<uint32>>;

    private:
        // Published as an immutable snapshot behind a shared_ptr. The combat hooks
        // read it from map-update worker threads while a season rollover can
        // republish it from the world thread; readers copy the shared_ptr under a
        // shared lock and then work off their own reference, so a republish can
        // never pull the map out from under an in-flight lookup.
        static std::shared_mutex _mapMutex;
        static std::shared_ptr<SpellItemMap const> _publishedMap;

        static bool AddSpellAssociation(SpellItemMap& map, uint32 spellId, uint32 itemId)
        {
            std::vector<uint32>& items = map[spellId];
            if (std::find(items.begin(), items.end(), itemId) != items.end())
                return false;

            items.push_back(itemId);
            return true;
        }

        static bool ShouldFollowTriggeredSpell(SpellEffectInfo const& effect)
        {
            switch (effect.ApplyAuraName)
            {
                case SPELL_AURA_PROC_TRIGGER_SPELL:
                case SPELL_AURA_PROC_TRIGGER_DAMAGE:
                case SPELL_AURA_PERIODIC_TRIGGER_SPELL:
                case SPELL_AURA_PERIODIC_TRIGGER_SPELL_FROM_CLIENT:
                case SPELL_AURA_PERIODIC_TRIGGER_SPELL_WITH_VALUE:
                case SPELL_AURA_PROC_TRIGGER_SPELL_WITH_VALUE:
                    return true;
                default:
                    break;
            }

            switch (effect.Effect)
            {
                case SPELL_EFFECT_TRIGGER_SPELL:
                case SPELL_EFFECT_TRIGGER_SPELL_WITH_VALUE:
                case SPELL_EFFECT_TRIGGER_SPELL_2:
                    return true;
                default:
                    return false;
            }
        }

        static void IndexSpellPayloads(SpellItemMap& map, uint32 spellId, uint32 itemId,
            uint32& count, std::unordered_set<uint32>& visited)
        {
            if (spellId == 0 || !visited.insert(spellId).second)
                return;

            if (AddSpellAssociation(map, spellId, itemId))
                ++count;

            SpellInfo const* spellInfo = sSpellMgr->GetSpellInfo(spellId);
            if (!spellInfo)
                return;

            for (SpellEffectInfo const& effect : spellInfo->Effects)
            {
                if (!effect.TriggerSpell || !ShouldFollowTriggeredSpell(effect))
                    continue;

                IndexSpellPayloads(map, effect.TriggerSpell, itemId, count, visited);
            }
        }

        // The upgrade system's own eligibility test, mirrored: the tier comes from
        // the item's level via dc_item_upgrade_tiers (UpgradeManager::GetItemTier),
        // and only weapons/armor of uncommon or better can be upgraded at all.
        //
        // This deliberately does NOT read dc_item_upgrade_item_overrides. That table
        // is a per-item tier PIN, not an eligibility list -- it held 2 rows, so
        // sourcing eligibility from it left the registry with a single association
        // while ~890 distinct upgraded item entries carried procs.
        static bool IsProcScalingEligible(UpgradeManager* mgr,
            ItemTemplate const& itemTemplate)
        {
            if (itemTemplate.Class != ITEM_CLASS_WEAPON
                && itemTemplate.Class != ITEM_CLASS_ARMOR)
            {
                return false;
            }

            if (itemTemplate.Quality < ITEM_QUALITY_UNCOMMON)
                return false;

            return mgr->GetItemTier(itemTemplate.ItemId) != TIER_INVALID;
        }

        static bool HasIndexableSpell(ItemTemplate const& itemTemplate)
        {
            for (auto const& itemSpell : itemTemplate.Spells)
            {
                if (itemSpell.SpellId > 0
                    && itemSpell.SpellTrigger != ITEM_SPELLTRIGGER_LEARN_SPELL_ID)
                {
                    return true;
                }
            }

            return false;
        }

    public:
        // Rebuild from the current ItemTemplate store and tier definitions, then
        // publish. Safe to call again -- a season rollover changes which tiers an
        // ilvl maps to, so the eligible set can change without the item data moving.
        static void Rebuild()
        {
            LOG_INFO("scripts.dc", "ItemUpgrade: Building Proc Spell Registry...");

            auto map = std::make_shared<SpellItemMap>();
            uint32 count = 0;
            uint32 indexedItems = 0;
            uint32 candidates = 0;

            UpgradeManager* mgr = GetUpgradeManager();
            ItemTemplateContainer const* items = sObjectMgr->GetItemTemplateStore();

            if (!mgr || !items)
            {
                Publish(std::move(map));
                LOG_WARN("scripts.dc",
                    "ItemUpgrade: {} unavailable; proc registry published empty.",
                    mgr ? "ItemTemplate store" : "UpgradeManager");
                return;
            }

            for (auto const& itemPair : *items)
            {
                ItemTemplate const& itemTemplate = itemPair.second;

                // Spell check first: it is a handful of integer compares and it
                // discards ~99% of the store, so GetItemTier (which walks the tier
                // definitions) only runs on the few thousand items that could ever
                // contribute an association.
                if (!HasIndexableSpell(itemTemplate))
                    continue;

                ++candidates;

                if (!IsProcScalingEligible(mgr, itemTemplate))
                    continue;

                ++indexedItems;

                for (auto const& itemSpell : itemTemplate.Spells)
                {
                    if (itemSpell.SpellId <= 0)
                        continue;

                    // Every trigger except Learn can carry a scalable payload:
                    // On Use, On Equip, Chance on Hit, Soulstone, Use-no-delay.
                    if (itemSpell.SpellTrigger == ITEM_SPELLTRIGGER_LEARN_SPELL_ID)
                        continue;

                    std::unordered_set<uint32> visited;
                    IndexSpellPayloads(*map, itemSpell.SpellId, itemTemplate.ItemId,
                        count, visited);
                }
            }

            std::size_t const spellCount = map->size();
            Publish(std::move(map));

            LOG_INFO("scripts.dc",
                "ItemUpgrade: Indexed {} upgrade-eligible base items of {} spell-bearing "
                "candidates; mapped {} proc associations across {} spells.",
                indexedItems, candidates, count, spellCount);
        }

        static std::shared_ptr<SpellItemMap const> GetSnapshot()
        {
            std::shared_lock<std::shared_mutex> lock(_mapMutex);
            return _publishedMap;
        }

    private:
        static void Publish(std::shared_ptr<SpellItemMap>&& map)
        {
            std::unique_lock<std::shared_mutex> lock(_mapMutex);
            _publishedMap = std::move(map);
        }
    };

    std::shared_mutex ProcSpellRegistry::_mapMutex;
    std::shared_ptr<ProcSpellRegistry::SpellItemMap const> ProcSpellRegistry::_publishedMap;

    void RebuildProcSpellRegistry()
    {
        ProcSpellRegistry::Rebuild();
    }

    // =====================================================================
    // Helper: Find Source Item
    // =====================================================================

    static Item* FindSourceItem(Player* player, uint32 spellId)
    {
        // The snapshot is kept alive for the whole lookup by this local
        // shared_ptr, so a concurrent republish cannot invalidate potentialItems.
        std::shared_ptr<ProcSpellRegistry::SpellItemMap const> snapshot =
            ProcSpellRegistry::GetSnapshot();
        if (!snapshot)
            return nullptr;

        auto itr = snapshot->find(spellId);
        if (itr == snapshot->end())
            return nullptr;

        std::vector<uint32> const& potentialItems = itr->second;

        // Check equipped items
        for (uint8 slot = EQUIPMENT_SLOT_START; slot < EQUIPMENT_SLOT_END; ++slot)
        {
            Item* item = player->GetItemByPos(INVENTORY_SLOT_BAG_0, slot);
            if (!item)
                continue;

            // Does this equipped item match one of the source IDs for the spell?
            for (uint32 sourceId : potentialItems)
            {
                if (item->GetEntry() == sourceId)
                    return item;
            }
        }

        return nullptr;
    }

    static bool IsPeriodicDamageAuraSpell(SpellInfo const* spellInfo)
    {
        if (!spellInfo)
            return false;

        for (SpellEffectInfo const& effect : spellInfo->Effects)
        {
            switch (effect.ApplyAuraName)
            {
                case SPELL_AURA_PERIODIC_DAMAGE:
                case SPELL_AURA_PERIODIC_DAMAGE_PERCENT:
                    return true;
                default:
                    break;
            }
        }

        return false;
    }

    static float GetProcScalingMultiplier(Player* player, uint32 spellId)
    {
        if (!player)
            return 1.0f;

        Item* sourceItem = FindSourceItem(player, spellId);
        if (!sourceItem)
            return 1.0f;

        UpgradeManager* mgr = GetUpgradeManager();
        if (!mgr)
            return 1.0f;

        // Cache-only on purpose: these hooks run per combat event on map-worker
        // threads, where a blocking SELECT is forbidden (see the contract on
        // GetCachedItemUpgradeState in ItemUpgradeManager.h). The equipped set --
        // including items WITHOUT an upgrade row, as negative entries -- is warmed
        // by PrefetchItemStatesAsync at login and on equip, so a miss here means
        // the warm is still in flight and the proc simply goes unscaled once.
        ItemUpgradeState* state = mgr->GetCachedItemUpgradeState(sourceItem->GetGUID().GetCounter());
        if (!state || state->upgrade_level == 0 || state->stat_multiplier <= 1.0f)
            return 1.0f;

        return state->stat_multiplier;
    }

    static bool IsDirectProcAura(AuraType auraType)
    {
        switch (auraType)
        {
            case SPELL_AURA_PERIODIC_DAMAGE:
            case SPELL_AURA_PERIODIC_DAMAGE_PERCENT:
            case SPELL_AURA_PERIODIC_HEAL:
            case SPELL_AURA_PERIODIC_LEECH:
            case SPELL_AURA_PERIODIC_HEALTH_FUNNEL:
            case SPELL_AURA_PERIODIC_MANA_LEECH:
            case SPELL_AURA_PERIODIC_ENERGIZE:
            case SPELL_AURA_PROC_TRIGGER_SPELL:
            case SPELL_AURA_PROC_TRIGGER_DAMAGE:
            case SPELL_AURA_PERIODIC_TRIGGER_SPELL_FROM_CLIENT:
            case SPELL_AURA_PERIODIC_TRIGGER_SPELL:
            case SPELL_AURA_PERIODIC_TRIGGER_SPELL_WITH_VALUE:
            case SPELL_AURA_PROC_TRIGGER_SPELL_WITH_VALUE:
                return true;
            default:
                return false;
        }
    }

    // Random enchants whose effect is an EQUIP SPELL rather than a flat stat --
    // "+33 Frost Spell Damage" is enchant 2253 casting passive spell 17895. The stat
    // hook in ItemUpgradeStatApplication.cpp cannot reach those (the core only fires
    // it for ITEM_ENCHANTMENT_TYPE_STAT), so their aura amount is scaled here.
    //
    // Identified by provenance, not by spell id: the aura has to have been cast by an
    // item this player has equipped, and that item has to carry the spell in one of
    // its random-enchant slots. That keeps a player-applied enchant or a gem that
    // happens to use the same spell out of it.
    static float GetRandomEnchantAuraMultiplier(Player* player, AuraEffect const* aurEff)
    {
        Aura const* aura = aurEff->GetBase();
        if (!aura)
            return 1.0f;

        ObjectGuid const castItemGuid = aura->GetCastItemGUID();
        if (!castItemGuid)
            return 1.0f;

        Item* item = player->GetItemByGuid(castItemGuid);
        if (!item || !item->IsEquipped())
            return 1.0f;

        uint32 const spellId = aurEff->GetId();
        bool fromRandomEnchant = false;
        for (uint32 slot = PROP_ENCHANTMENT_SLOT_0;
             slot <= PROP_ENCHANTMENT_SLOT_4 && !fromRandomEnchant; ++slot)
        {
            SpellItemEnchantmentEntry const* enchant = sSpellItemEnchantmentStore.LookupEntry(
                item->GetEnchantmentId(EnchantmentSlot(slot)));
            if (!enchant)
                continue;

            for (uint32 i = 0; i < MAX_SPELL_ITEM_ENCHANTMENT_EFFECTS; ++i)
            {
                if (enchant->type[i] == ITEM_ENCHANTMENT_TYPE_EQUIP_SPELL
                    && enchant->spellid[i] == spellId)
                {
                    fromRandomEnchant = true;
                    break;
                }
            }
        }

        if (!fromRandomEnchant)
            return 1.0f;

        UpgradeManager* mgr = GetUpgradeManager();
        if (!mgr)
            return 1.0f;

        // Cache-only, same contract as GetProcScalingMultiplier. A cold miss at login
        // applies the aura unscaled; ForcePlayerStatUpdate then removes and re-casts
        // every equip spell with the cache warm, so it corrects itself.
        ItemUpgradeState* state = mgr->GetCachedItemUpgradeState(item->GetGUID().GetCounter());
        if (!state || state->upgrade_level == 0 || state->stat_multiplier <= 1.0f)
            return 1.0f;

        return state->stat_multiplier;
    }

    // =====================================================================
    // Public API
    // =====================================================================

    bool IsUpgradeScaledEquipSpell(uint32 spellId)
    {
        SpellInfo const* spellInfo = sSpellMgr->GetSpellInfo(spellId);
        if (!spellInfo)
            return false;

        for (SpellEffectInfo const& effect : spellInfo->Effects)
        {
            if (effect.ApplyAuraName != SPELL_AURA_NONE
                && !IsDirectProcAura(AuraType(effect.ApplyAuraName)))
            {
                return true;
            }
        }

        return false;
    }

    bool IsProcScalingIndexed(uint32 itemEntry, uint32 spellId)
    {
        if (!itemEntry || !spellId)
            return false;

        std::shared_ptr<ProcSpellRegistry::SpellItemMap const> snapshot =
            ProcSpellRegistry::GetSnapshot();
        if (!snapshot)
            return false;

        auto itr = snapshot->find(spellId);
        if (itr == snapshot->end())
            return false;

        std::vector<uint32> const& sources = itr->second;
        return std::find(sources.begin(), sources.end(), itemEntry) != sources.end();
    }

    std::string GetPlayerProcScalingInfo(Player* player)
    {
        if (!player)
            return "Invalid player.";

        UpgradeManager* mgr = GetUpgradeManager();
        if (!mgr)
            return "Upgrade Manager not available.";

        std::ostringstream ss;
        ss << "Active Proc Scaling:\n";
        bool found = false;

        // Scan equipped items
        for (uint8 slot = EQUIPMENT_SLOT_START; slot < EQUIPMENT_SLOT_END; ++slot)
        {
            Item* item = player->GetItemByPos(INVENTORY_SLOT_BAG_0, slot);
            if (!item)
                continue;

            // Cache-only: the login hint below runs after the equipped-set
            // prefetch, and the GM command path tolerates a cold miss (the row
            // just doesn't show until the async warm lands).
            ItemUpgradeState* state = mgr->GetCachedItemUpgradeState(item->GetGUID().GetCounter());
            if (state && state->upgrade_level > 0 && state->stat_multiplier > 1.0f)
            {
                // Check if this item has any procs
                ItemTemplate const* temp = item->GetTemplate();
                bool hasProc = false;
                for (auto const& spell : temp->Spells)
                {
                    if (spell.SpellId > 0 && spell.SpellTrigger != ITEM_SPELLTRIGGER_LEARN_SPELL_ID)
                    {
                        hasProc = true;
                        break;
                    }
                }

                if (hasProc)
                {
                    found = true;
                    ss << "- " << item->GetTemplate()->Name1 << ": "
                       << std::fixed << std::setprecision(1) << ((state->stat_multiplier - 1.0f) * 100.0f)
                       << "% bonus to procs\n";
                }
            }
        }

        if (!found)
            ss << "No upgraded items with procs equipped.";

        return ss.str();
    }

    // =====================================================================
    // UnitScript Hook
    // =====================================================================

    class ItemUpgradeProcScript : public UnitScript
    {
    public:
        ItemUpgradeProcScript() : UnitScript("ItemUpgradeProcScript") {}

        // Hook: Spell Damage Calculation
        // Note: Signature depends on Core version. Assuming standard AC/TC hook.
        void ModifySpellDamageTaken(Unit* target, Unit* attacker, int32& damage, SpellInfo const* spellInfo) override
        {
            (void)target;
            if (!attacker || !spellInfo || damage <= 0)
                return;

            Player* player = attacker->ToPlayer();
            if (!player)
                return;

            float multiplier = GetProcScalingMultiplier(player, spellInfo->Id);

            if (multiplier > 1.0f)
            {
                damage = static_cast<int32>(damage * multiplier);
            }
        }

        void ModifyPeriodicDamageAurasTick(Unit* target, Unit* attacker, uint32& damage, SpellInfo const* spellInfo) override
        {
            (void)target;
            if (!attacker || !spellInfo || damage == 0)
                return;

            if (!IsPeriodicDamageAuraSpell(spellInfo))
                return;

            Player* player = attacker->ToPlayer();
            if (!player)
                return;

            float multiplier = GetProcScalingMultiplier(player, spellInfo->Id);
            if (multiplier > 1.0f)
                damage = static_cast<uint32>(damage * multiplier);
        }

        // Hook: Healing Calculation
        void ModifyHealReceived(Unit* target, Unit* healer, uint32& gain, SpellInfo const* spellInfo) override
        {
            (void)target;
            if (!healer || !spellInfo || gain <= 0)
                return;

            Player* player = healer->ToPlayer();
            if (!player)
                return;

            float multiplier = GetProcScalingMultiplier(player, spellInfo->Id);

            if (multiplier > 1.0f)
            {
                gain = static_cast<uint32>(gain * multiplier);
            }
        }

        void ModifyAuraEffectAmount(Unit* target, Unit* caster, AuraEffect const* aurEff, int32& amount, bool& canBeRecalculated) override
        {
            (void)target;
            (void)canBeRecalculated;
            if (!caster || !aurEff || amount == 0)
                return;

            if (IsDirectProcAura(aurEff->GetAuraType()))
                return;

            Player* player = caster->ToPlayer();
            if (!player)
                return;

            float multiplier = GetProcScalingMultiplier(player, aurEff->GetId());
            if (multiplier <= 1.0f)
                multiplier = GetRandomEnchantAuraMultiplier(player, aurEff);

            // lround, not truncation: these are stat auras the player can read off the
            // character sheet, and the tooltip rounds the same value. Truncating here
            // showed "+38 Frost Spell Damage" on an item that granted 37.
            if (multiplier > 1.0f)
                amount = static_cast<int32>(std::lround(
                    static_cast<double>(amount) * static_cast<double>(multiplier)));
        }
    };

    // =====================================================================
    // Player Script (Login Notification)
    // =====================================================================

    // Warm the state cache for every equipped item. Unlike
    // PrefetchPlayerItemStatesAsync (which only loads rows that exist in
    // dc_item_upgrades), PrefetchItemStatesAsync also inserts NEGATIVE entries
    // for items without an upgrade row -- without those, every proc from an
    // un-upgraded item would miss the cache forever.
    static void PrefetchEquippedItemStates(Player* player)
    {
        UpgradeManager* mgr = GetUpgradeManager();
        if (!mgr)
            return;

        std::vector<std::pair<uint32, uint32>> equipped;
        equipped.reserve(EQUIPMENT_SLOT_END - EQUIPMENT_SLOT_START);
        for (uint8 slot = EQUIPMENT_SLOT_START; slot < EQUIPMENT_SLOT_END; ++slot)
        {
            if (Item* item = player->GetItemByPos(INVENTORY_SLOT_BAG_0, slot))
                equipped.emplace_back(item->GetGUID().GetCounter(), item->GetEntry());
        }

        if (!equipped.empty())
            mgr->PrefetchItemStatesAsync(std::move(equipped), player->GetGUID().GetCounter());
    }

    class ItemUpgradeProcPlayerScript : public PlayerScript
    {
    public:
        ItemUpgradeProcPlayerScript() : PlayerScript("ItemUpgradeProcPlayerScript",
            { PLAYERHOOK_ON_LOAD_FROM_DB, PLAYERHOOK_ON_LOGIN, PLAYERHOOK_ON_EQUIP }) {}

        void OnPlayerLoadFromDB(Player* player) override
        {
            if (!player) return;

            UpgradeManager* mgr = GetUpgradeManager();
            if (!mgr)
                return;

            // Warm the per-item upgrade-state cache with ONE async query, issued as early
            // in the load as possible.
            //
            // Why here and not OnPlayerLogin: the core applies item stats synchronously
            // inside LoadFromDB (_LoadInventory -> _ApplyAllItemMods), which runs BEFORE
            // OnPlayerLogin fires. Warming at login was therefore always too late -- every
            // equipped item took a blocking cache-miss SELECT during the stat pass, ~19
            // per player, all on the world thread and all at once during a post-restart
            // login wave.
            //
            // The inventory does not exist yet at this point, so the prefetch keys off
            // player_guid instead of the in-memory item list. The stat hooks are
            // cache-only and simply apply base stats while it is in flight; the
            // continuation calls ForcePlayerStatUpdate to fold the multipliers in.
            mgr->PrefetchPlayerItemStatesAsync(player->GetGUID().GetCounter());
        }

        void OnPlayerEquip(Player* player, Item* item, uint8 /*bag*/, uint8 /*slot*/, bool /*update*/) override
        {
            // Skip the per-item equips replayed during _LoadInventory (player not
            // in world yet) -- the OnPlayerLogin batch below covers those in one
            // query instead of ~19.
            if (!player || !item || !player->IsInWorld())
                return;

            UpgradeManager* mgr = GetUpgradeManager();
            if (!mgr)
                return;

            mgr->PrefetchItemStatesAsync({ { item->GetGUID().GetCounter(), item->GetEntry() } },
                player->GetGUID().GetCounter());
        }

        void OnPlayerLogin(Player* player) override
        {
            if (!player) return;

            if (!GetUpgradeManager())
                return;

            // Batch-warm the full equipped set (with negative entries) so the
            // combat hooks' cache-only lookups are servable before first combat.
            PrefetchEquippedItemStates(player);

            // Defer the informational hint until the prefetch has landed so
            // the scan below is served entirely from cache.
            player->m_Events.AddEventAtOffset([guid = player->GetGUID()]()
            {
                Player* player = ObjectAccessor::FindPlayer(guid);
                if (!player || !player->GetSession())
                    return;

                std::string info = GetPlayerProcScalingInfo(player);
                if (info.find("bonus to procs") != std::string::npos)
                {
                    ChatHandler(player->GetSession()).SendSysMessage("|cff00ff00[Item Upgrade]|r Your item procs are currently scaled by your upgrades. Type .upgrade mech procs to see details.");
                }
            }, std::chrono::milliseconds(3000));
        }
    };

    // =====================================================================
    // WorldScript for Initialization
    // =====================================================================

    class ItemUpgradeProcWorldScript : public WorldScript
    {
    public:
        ItemUpgradeProcWorldScript() : WorldScript("ItemUpgradeProcWorldScript") {}

        void OnStartup() override
        {
            // Runs after ItemUpgradeInitWorldScript (registered earlier in
            // dc_script_loader.cpp) has loaded the tier definitions, which
            // GetItemTier needs to classify anything.
            ProcSpellRegistry::Rebuild();
        }
    };

} // namespace ItemUpgrade
} // namespace DarkChaos

// =====================================================================
// Registration
// =====================================================================

void AddSC_ItemUpgradeProcScaling()
{
    new DarkChaos::ItemUpgrade::ItemUpgradeProcScript();
    new DarkChaos::ItemUpgrade::ItemUpgradeProcPlayerScript();
    new DarkChaos::ItemUpgrade::ItemUpgradeProcWorldScript();
}
