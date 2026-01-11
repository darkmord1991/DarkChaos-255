/*
 * DarkChaos Item Upgrade - Proc Scaling System
 * =============================================
 *
 * Implements "True Proc Scaling" by dynamically mapping spells to their source items.
 *
 * LOGIC:
 * 1. On startup, scans all ItemTemplates to build a `SpellID -> [ItemID]` map.
 * 2. Hooks Unit::ModifySpellDamageTaken and Unit::ModifyHealReceived.
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
#include "SpellInfo.h"
#include "SpellMgr.h"
#include "Unit.h"
#include "ItemUpgradeManager.h"
#include "ItemUpgradeProcScaling.h"
#include "Log.h"
#include "Chat.h"
#include <unordered_map>
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

    public:
        static void Initialize()
        {
            if (_initialized)
                return;

            LOG_INFO("scripts.dc", "ItemUpgrade: Initializing Proc Spell Registry...");
            uint32 count = 0;

            // Iterate over all item templates
            ItemTemplateContainer const* items = sObjectMgr->GetItemTemplateStore();
            if (!items)
                return;

            for (auto const& pair : *items)
            {
                ItemTemplate const& itemTemplate = pair.second;

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

                        _procSpellMap[itemSpell.SpellId].push_back(itemTemplate.ItemId);
                        count++;
                    }
                }
            }

            _initialized = true;
            LOG_INFO("scripts.dc", "ItemUpgrade: Mapped {} proc associations.", count);
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

            // 1. Check if this spell is a known item proc
            Item* sourceItem = FindSourceItem(player, spellInfo->Id);
            if (!sourceItem)
                return;

            // 2. Check if the item is upgraded
            UpgradeManager* mgr = GetUpgradeManager();
            if (!mgr)
                return;

            ItemUpgradeState* state = mgr->GetItemUpgradeState(sourceItem->GetGUID().GetCounter());
            if (!state || state->upgrade_level == 0)
                return;

            // 3. Apply scaling
            // We use the item's stat multiplier (e.g., 1.05x, 1.10x)
            // This scales the proc damage exactly as much as the stats are scaled.
            float multiplier = state->stat_multiplier;

            if (multiplier > 1.0f)
            {
                // int32 oldDamage = damage;
                damage = static_cast<int32>(damage * multiplier);

                // Debug log (optional, can be spammy)
                // LOG_DEBUG("scripts.dc", "ItemUpgrade: Scaled proc {} from item {} by {:.2f}x ({} -> {})",
                //     spellInfo->Id, sourceItem->GetEntry(), multiplier, oldDamage, damage);
            }
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

            Item* sourceItem = FindSourceItem(player, spellInfo->Id);
            if (!sourceItem)
                return;

            UpgradeManager* mgr = GetUpgradeManager();
            if (!mgr)
                return;

            ItemUpgradeState* state = mgr->GetItemUpgradeState(sourceItem->GetGUID().GetCounter());
            if (!state || state->upgrade_level == 0)
                return;

            float multiplier = state->stat_multiplier;

            if (multiplier > 1.0f)
            {
                gain = static_cast<uint32>(gain * multiplier);
            }
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
