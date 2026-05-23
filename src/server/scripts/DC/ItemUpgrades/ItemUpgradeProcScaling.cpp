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
#include "SpellInfo.h"
#include "SpellMgr.h"
#include "Unit.h"
#include "DatabaseEnv.h"
#include "DC/CrossSystem/SeasonResolver.h"
#include "ItemUpgradeManager.h"
#include "ItemUpgradeProcScaling.h"
#include "Log.h"
#include "Chat.h"
#include <unordered_map>
#include <unordered_set>
#include <vector>
#include <algorithm>
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
    private:
        // Map: SpellID -> List of ItemIDs that use this spell
        static std::unordered_map<uint32, std::vector<uint32>> _procSpellMap;
        static bool _initialized;

        static bool AddSpellAssociation(uint32 spellId, uint32 itemId)
        {
            std::vector<uint32>& items = _procSpellMap[spellId];
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

        static void IndexSpellPayloads(uint32 spellId, uint32 itemId, uint32& count,
            std::unordered_set<uint32>& visited)
        {
            if (spellId == 0 || !visited.insert(spellId).second)
                return;

            if (AddSpellAssociation(spellId, itemId))
                ++count;

            SpellInfo const* spellInfo = sSpellMgr->GetSpellInfo(spellId);
            if (!spellInfo)
                return;

            for (SpellEffectInfo const& effect : spellInfo->Effects)
            {
                if (!effect.TriggerSpell || !ShouldFollowTriggeredSpell(effect))
                    continue;

                IndexSpellPayloads(effect.TriggerSpell, itemId, count, visited);
            }
        }

    public:
        static void Initialize()
        {
            if (_initialized)
                return;

            LOG_INFO("scripts.dc", "ItemUpgrade: Initializing Proc Spell Registry...");
            uint32 count = 0;
            uint32 indexedItems = 0;

            uint32 season = GetCurrentSeasonId();
            std::vector<uint32> eligibleEntries;
            QueryResult eligibleResult = WorldDatabase.Query(
                "SELECT item_id FROM dc_item_templates_upgrade "
                "WHERE season = {} AND is_active = 1",
                season);

            if (eligibleResult)
            {
                do
                {
                    Field* fields = eligibleResult->Fetch();
                    eligibleEntries.push_back(fields[0].Get<uint32>());
                } while (eligibleResult->NextRow());
            }

            if (eligibleEntries.empty())
            {
                _initialized = true;
                LOG_WARN("scripts.dc", "ItemUpgrade: No upgrade-eligible base items found for season {}; proc registry remains empty.", season);
                return;
            }

            // Index only the upgrade-eligible base item templates.
            ItemTemplateContainer const* items = sObjectMgr->GetItemTemplateStore();
            if (!items)
            {
                _initialized = true;
                LOG_WARN("scripts.dc", "ItemUpgrade: ItemTemplate store unavailable; proc registry remains empty.");
                return;
            }

            for (uint32 itemId : eligibleEntries)
            {
                auto itemItr = items->find(itemId);
                if (itemItr == items->end())
                    continue;

                ItemTemplate const& itemTemplate = itemItr->second;
                indexedItems++;

                // Check all 5 possible item spells
                for (auto const& itemSpell : itemTemplate.Spells)
                {
                    if (itemSpell.SpellId > 0)
                    {
                        // We care about:
                        // - ITEM_SPELLTRIGGER_ON_USE (Use:)
                        // - ITEM_SPELLTRIGGER_ON_EQUIP (Equip:) - usually passive auras, but can be procs
                        // - ITEM_SPELLTRIGGER_CHANCE_ON_HIT (Chance on hit:)
                        // - ITEM_SPELLTRIGGER_SOULSTONE (Soulstone)
                        // - ITEM_SPELLTRIGGER_ON_NO_DELAY_USE (Use with no delay)
                        // - ITEM_SPELLTRIGGER_LEARN_SPELL_ID (Learn) - Ignored

                        if (itemSpell.SpellTrigger == ITEM_SPELLTRIGGER_LEARN_SPELL_ID)
                            continue;

                        std::unordered_set<uint32> visited;
                        IndexSpellPayloads(itemSpell.SpellId, itemTemplate.ItemId, count, visited);
                    }
                }
            }

            _initialized = true;
            LOG_INFO("scripts.dc", "ItemUpgrade: Indexed {} upgrade-eligible base items and mapped {} proc associations.", indexedItems, count);
        }

        static const std::vector<uint32>* GetItemsForSpell(uint32 spellId)
        {
            if (!_initialized)
                Initialize();

            auto it = _procSpellMap.find(spellId);
            if (it != _procSpellMap.end())
                return &it->second;

            return nullptr;
        }
    };

    std::unordered_map<uint32, std::vector<uint32>> ProcSpellRegistry::_procSpellMap;
    bool ProcSpellRegistry::_initialized = false;

    // =====================================================================
    // Helper: Find Source Item
    // =====================================================================

    static Item* FindSourceItem(Player* player, uint32 spellId)
    {
        const std::vector<uint32>* potentialItems = ProcSpellRegistry::GetItemsForSpell(spellId);
        if (!potentialItems)
            return nullptr;

        // Check equipped items
        for (uint8 slot = EQUIPMENT_SLOT_START; slot < EQUIPMENT_SLOT_END; ++slot)
        {
            Item* item = player->GetItemByPos(INVENTORY_SLOT_BAG_0, slot);
            if (!item)
                continue;

            // Does this equipped item match one of the source IDs for the spell?
            for (uint32 sourceId : *potentialItems)
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

        ItemUpgradeState* state = mgr->GetItemUpgradeState(sourceItem->GetGUID().GetCounter());
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

    // =====================================================================
    // Public API
    // =====================================================================

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

            ItemUpgradeState* state = mgr->GetItemUpgradeState(item->GetGUID().GetCounter());
            if (state && state->upgrade_level > 0 && state->stat_multiplier > 1.0f)
            {
                // Check if this item has any procs
                const ItemTemplate* temp = item->GetTemplate();
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
            if (multiplier > 1.0f)
                amount = static_cast<int32>(amount * multiplier);
        }
    };

    // =====================================================================
    // Player Script (Login Notification)
    // =====================================================================

    class ItemUpgradeProcPlayerScript : public PlayerScript
    {
    public:
        ItemUpgradeProcPlayerScript() : PlayerScript("ItemUpgradeProcPlayerScript") {}

        void OnPlayerLogin(Player* player) override
        {
            if (!player) return;

            // Check if player has any upgraded items with procs
            std::string info = GetPlayerProcScalingInfo(player);
            if (info.find("bonus to procs") != std::string::npos)
            {
                ChatHandler(player->GetSession()).SendSysMessage("|cff00ff00[Item Upgrade]|r Your item procs are currently scaled by your upgrades. Type .upgrade mech procs to see details.");
            }
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
            // Initialize the registry when the server starts
            ProcSpellRegistry::Initialize();
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
