/*
 * DarkChaos AoE Loot System
 * Consolidated single-file implementation (clean, no nested includes).
 */

#include "ScriptMgr.h"
#include "Player.h"
#include "Creature.h"
#include "Config.h"
#include "Chat.h"
#include "ObjectAccessor.h"
#include "WorldPacket.h"
#include "Opcodes.h"
#include "GameTime.h"
#include "LootMgr.h"
#include "Group.h"
#include "CellImpl.h"
#include "Log.h"
#include "Mail.h"
#include "DatabaseEnv.h"
#include "Item.h"

#include <vector>
#include <list>
#include <unordered_map>
#include <sstream>
#include <limits>

using namespace Acore::ChatCommands;

// Helper to format copper amount into Gold/Silver/Copper string
static std::string formatCoins(uint32 copper)
{
    uint32 g = copper / 10000;
    uint32 s = (copper % 10000) / 100;
    uint32 c = copper % 100;
    std::ostringstream ss;
    if (g > 0) ss << g << " Gold ";
    if (s > 0) ss << s << " Silver ";
    ss << c << " Copper";
    return ss.str();
}

struct AoELootConfig
{
    bool enabled = true;
    float range = 30.0f;
    uint32 maxCorpses = 10;
    uint8 maxMergeSlots = 15; // default safe client window (leave one slot spare)
    bool autoCreditGold = true;
    uint8 autoLoot = 0; // 0 = disabled, 1 = forced, 2 = player's setting
    uint32 autoStoreWindowSeconds = 5; // window to consider a recent client autostore (seconds)
    bool allowInGroup = true;
    bool showMessage = true;
    bool playersOnly = true;
    bool ignoreTapped = true;
    bool questItems = true;

    void Load()
    {
        enabled = sConfigMgr->GetOption<bool>("AoELoot.Enable", true);
        range = sConfigMgr->GetOption<float>("AoELoot.Range", 30.0f);
        maxCorpses = sConfigMgr->GetOption<uint32>("AoELoot.MaxCorpses", 10);
        autoLoot = sConfigMgr->GetOption<uint8>("AoELoot.AutoLoot", 0);
        allowInGroup = sConfigMgr->GetOption<bool>("AoELoot.AllowInGroup", true);
        showMessage = sConfigMgr->GetOption<bool>("AoELoot.ShowMessage", true);
        playersOnly = sConfigMgr->GetOption<bool>("AoELoot.PlayersOnly", true);
        ignoreTapped = sConfigMgr->GetOption<bool>("AoELoot.IgnoreTapped", true);
        questItems = sConfigMgr->GetOption<bool>("AoELoot.QuestItems", true);
        maxMergeSlots = sConfigMgr->GetOption<uint8>("AoELoot.MaxMergeSlots", 15u);
    autoCreditGold = sConfigMgr->GetOption<bool>("AoELoot.AutoCreditGold", true);
    autoStoreWindowSeconds = sConfigMgr->GetOption<uint32>("AoELoot.AutoStoreWindowSeconds", 5u);

        if (range < 5.0f) range = 5.0f;
        if (range > 100.0f) range = 100.0f;
        if (maxCorpses < 1) maxCorpses = 1;
        if (maxCorpses > 50) maxCorpses = 50;
    }
};

static AoELootConfig sAoEConfig;

struct PlayerAoELootData
{
    uint64 lastAoELoot = 0;
    uint32 lootedThisSession = 0;
    uint32 lastCreditedGold = 0; // in copper
};

static std::unordered_map<ObjectGuid, PlayerAoELootData> sPlayerLootData;
static std::unordered_map<ObjectGuid, uint64> sPlayerAutoStoreTimestamp;

static bool CanPlayerLootCorpse(Player* player, Creature* creature)
{
    if (!player || !creature) return false;
    // Creature::HasLoot() does not exist in this repo; check the loot container instead
    if (creature->loot.empty()) return false;
    if (sAoEConfig.playersOnly && player->GetTypeId() != TYPEID_PLAYER) return false;
    if (sAoEConfig.ignoreTapped)
    {
    if (creature->hasLootRecipient())
        {
            Player* recipient = creature->GetLootRecipient();
            if (!recipient) return false;
            if (recipient->GetGUID() != player->GetGUID())
            {
                if (Group* group = player->GetGroup())
                {
                    if (!group->IsMember(recipient->GetGUID()))
                        return false;
                }
                else
                    return false;
            }
        }
    }
    if (!player->isAllowedToLoot(creature)) return false;
    return true;
}

// Return true if we handled the loot packet (sent loot window / auto-looted / mailed),
// false to let normal packet processing continue.
static bool PerformAoELoot(Player* player, Creature* mainCreature)
{
    if (!player || !mainCreature) return false;
    Loot* mainLoot = &mainCreature->loot;
    if (!mainLoot) return false;

    std::list<Creature*> nearby;
    player->GetDeadCreatureListInGrid(nearby, sAoEConfig.range);

    LOG_DEBUG("scripts", "AoELoot: found {} nearby dead creatures within range {:.1f} for player {}", nearby.size(), sAoEConfig.range, player->GetGUID().ToString());

    nearby.remove_if([&](Creature* c) -> bool
    {
    if (!c) return true;
    if (c->GetGUID() == mainCreature->GetGUID()) return true;
    if (!c->HasDynamicFlag(UNIT_DYNFLAG_LOOTABLE)) return true;
    // Creature::HasLoot() does not exist here; check loot container state
    if (c->loot.empty()) return true;
    if (!player->isAllowedToLoot(c)) return true;
        return false;
    });

    // Debug: list remaining nearby corpses after filtering
    LOG_DEBUG("scripts", "AoELoot: after filter nearby corpses count = {}", nearby.size());
    for (Creature* c : nearby)
    {
        if (!c) continue;
        LOG_DEBUG("scripts", "AoELoot: nearby corpse GUID={} entry={} loot_items={} quest_items={} gold={}", c->GetGUID().ToString(), c->GetEntry(), c->loot.items.size(), c->loot.quest_items.size(), c->loot.gold);
    }

    if (nearby.empty())
    {
        LOG_DEBUG("scripts", "AoELoot: no nearby corpses to merge for player {}", player->GetGUID().ToString());
        if (sAoEConfig.showMessage)
            ChatHandler(player->GetSession()).PSendSysMessage("AoE Loot: no nearby corpses found");
        return false;
    }

    std::vector<Creature*> corpses;
    corpses.reserve(sAoEConfig.maxCorpses);
    for (Creature* c : nearby)
    {
        if (corpses.size() >= sAoEConfig.maxCorpses) break;
        corpses.push_back(c);
    }

    std::vector<LootItem> itemsToAdd;
    std::vector<LootItem> questItemsToAdd;
    uint32 totalGold = mainLoot->gold;

    // Limit merge slots (configurable; default 15 to avoid overflowing client 16-slot window)
    const size_t MAX_MERGE_SLOTS = sAoEConfig.maxMergeSlots;

    size_t processed = 0;
    for (Creature* corpse : corpses)
    {
        if (!corpse) continue;
        Loot* loot = &corpse->loot;
        if (!loot || loot->isLooted()) continue;

        if (loot->gold > 0)
        {
            if (totalGold < std::numeric_limits<uint32>::max() - loot->gold)
                totalGold += loot->gold;
        }

        for (auto const& it : loot->items)
        {
            if (!it.AllowedForPlayer(player, corpse->GetGUID())) continue;
            if (!sAoEConfig.questItems && it.needs_quest) continue;
            size_t projected = mainLoot->items.size() + itemsToAdd.size() + mainLoot->quest_items.size() + questItemsToAdd.size();
            if (projected >= MAX_MERGE_SLOTS) break;
            itemsToAdd.push_back(it);
        }
        for (auto const& it : loot->quest_items)
        {
            if (!it.AllowedForPlayer(player, corpse->GetGUID())) continue;
            size_t projected = mainLoot->items.size() + itemsToAdd.size() + mainLoot->quest_items.size() + questItemsToAdd.size();
            if (projected >= MAX_MERGE_SLOTS) break;
            questItemsToAdd.push_back(it);
        }

        loot->clear();
        corpse->AllLootRemovedFromCorpse();
        corpse->RemoveDynamicFlag(UNIT_DYNFLAG_LOOTABLE);
        processed++;
    }

    if (processed == 0)
    {
        LOG_DEBUG("scripts", "AoELoot: processed == 0 after scanning {} corpses for player {}", corpses.size(), player->GetGUID().ToString());
        if (sAoEConfig.showMessage)
            ChatHandler(player->GetSession()).PSendSysMessage("AoE Loot: found nearby corpses but none were eligible for merging");
        return false;
    }

    for (auto const& it : itemsToAdd)
    {
        if (mainLoot->items.size() + mainLoot->quest_items.size() >= MAX_MERGE_SLOTS) break;
        mainLoot->items.push_back(it);
    }
    for (auto const& it : questItemsToAdd)
    {
        if (mainLoot->items.size() + mainLoot->quest_items.size() >= MAX_MERGE_SLOTS) break;
        mainLoot->quest_items.push_back(it);
    }

    mainLoot->gold = totalGold;

    PlayerAoELootData& data = sPlayerLootData[player->GetGUID()];
    data.lastAoELoot = GameTime::GetGameTime().count();
    data.lootedThisSession += processed;

    if (Group* group = player->GetGroup())
    {
        LootMethod method = group->GetLootMethod();
        if (method == MASTER_LOOT)
        {
            group->MasterLoot(mainLoot, mainCreature);
            return true;
        }
        else if (method == NEED_BEFORE_GREED || method == GROUP_LOOT || method == FREE_FOR_ALL)
        {
            group->GroupLoot(mainLoot, mainCreature);
            return true;
        }
    }

    auto shouldAutoLootForPlayer = [&](Player* p) -> bool
    {
        if (!p) return false;
        if (sAoEConfig.autoLoot == 1) return true;
        if (sAoEConfig.autoLoot == 2)
        {
            auto it = sPlayerAutoStoreTimestamp.find(p->GetGUID());
            if (it == sPlayerAutoStoreTimestamp.end()) return false;
            uint64 now = GameTime::GetGameTime().count();
            return (now - it->second) <= sAoEConfig.autoStoreWindowSeconds;
        }
        return false;
    };

    if (shouldAutoLootForPlayer(player))
    {
    std::vector<std::pair<uint32, uint32>> mailItems;

        auto storeOrMail = [&](LootItem const& li)
        {
            ItemPosCountVec dest;
            InventoryResult msg = player->CanStoreNewItem(NULL_BAG, NULL_SLOT, dest, li.itemid, li.count);
            if (msg == EQUIP_ERR_OK)
            {
                Item* newItem = player->StoreNewItem(dest, li.itemid, true, li.randomPropertyId);
                if (newItem) player->SendNewItem(newItem, uint32(li.count), false, false, true);
            }
            else
                mailItems.emplace_back(li.itemid, li.count);
        };

        for (auto const& it : mainLoot->items) storeOrMail(it);
        for (auto const& it : mainLoot->quest_items) storeOrMail(it);

        if (mainLoot->gold > 0) player->ModifyMoney(mainLoot->gold);

        if (!mailItems.empty())
        {
            CharacterDatabaseTransaction trans = CharacterDatabase.BeginTransaction();
            MailSender sender(mainCreature);
            MailDraft draft("Recovered Items", "Some items could not fit in your bags and have been mailed to you.");

            for (auto const& p : mailItems)
            {
                if (Item* mailItem = Item::CreateItem(p.first, p.second))
                {
                    mailItem->SaveToDB(trans);
                    draft.AddItem(mailItem);
                }
            }

            if (mainLoot->gold > 0) draft.AddMoney(mainLoot->gold);
            draft.SendMailTo(trans, MailReceiver(player), sender);
            CharacterDatabase.CommitTransaction(trans);
        }

        mainLoot->clear();
        mainCreature->AllLootRemovedFromCorpse();
        mainCreature->RemoveDynamicFlag(UNIT_DYNFLAG_LOOTABLE);
        return true;
    }

    // Auto-credit merged gold to solo looter (leave items for the player to pick).
    // If in a group, leave gold in the loot so group/master-loot logic can distribute it.
    if (mainLoot->gold > 0 && !player->GetGroup())
    {
        uint32 credited = mainLoot->gold;
    player->ModifyMoney(credited);
    mainLoot->gold = 0;
    // record for stats
    PlayerAoELootData& pdata = sPlayerLootData[player->GetGUID()];
    pdata.lastCreditedGold = credited;
        // convert copper to g/s/c
        uint32 g = credited / 10000;
        uint32 s = (credited % 10000) / 100;
        uint32 c = credited % 100;
        LOG_INFO("scripts", "AoELoot: credited {}c ({}g {}s {}c) to player {} (solo merged gold)", credited, g, s, c, player->GetGUID().ToString());
        if (sAoEConfig.showMessage)
        {
            if (g > 0)
                ChatHandler(player->GetSession()).PSendSysMessage("AoE Loot: credited %u Gold %u Silver %u Copper from merged corpses.", g, s, c);
            else if (s > 0)
                ChatHandler(player->GetSession()).PSendSysMessage("AoE Loot: credited %u Silver %u Copper from merged corpses.", s, c);
            else
                ChatHandler(player->GetSession()).PSendSysMessage("AoE Loot: credited %u Copper from merged corpses.", c);
        }
    }

    player->SendLoot(mainCreature->GetGUID(), LOOT_CORPSE);

        if (sAoEConfig.showMessage && processed > 0)
    {
        std::ostringstream ss;
        ss << "|cFF00FF00[AoE Loot]|r Looted " << processed << " nearby corpse(s). ";
        if (itemsToAdd.size() > 0) ss << "Collected " << itemsToAdd.size() << " item(s).";
        ChatHandler(player->GetSession()).SendNotification(ss.str());
        LOG_INFO("scripts", "AoELoot: player {} merged {} corpses (items added: {}, gold: {})", player->GetGUID().ToString(), processed, itemsToAdd.size(), mainLoot->gold);
        if (sAoEConfig.showMessage)
            ChatHandler(player->GetSession()).PSendSysMessage("AoE Loot: merged {} corpses (items: {}, gold: {})", processed, itemsToAdd.size(), mainLoot->gold);
    }
    return true;
}

class AoELootServerScript : public ServerScript
{
public:
    AoELootServerScript() : ServerScript("AoELootServerScript") { }

    bool CanPacketReceive(WorldSession* session, WorldPacket& packet) override
    {
        if (!sAoEConfig.enabled) return true;
        if (!session) return true;

        if (packet.GetOpcode() == CMSG_AUTOSTORE_LOOT_ITEM)
        {
            if (session->GetPlayer()) 
            {
                auto guid = session->GetPlayer()->GetGUID();
                sPlayerAutoStoreTimestamp[guid] = GameTime::GetGameTime().count();
                LOG_DEBUG("scripts", "AoELoot: recorded autostore opcode for player {}", guid.ToString());
            }
            return true;
        }

        if (packet.GetOpcode() != CMSG_LOOT) return true;

        Player* player = session->GetPlayer();
        if (!player) return true;

        packet.rpos(0);
        ObjectGuid guid;
        packet >> guid;
        packet.rpos(0);

    if (!guid || !guid.IsCreature()) return true;

        Creature* creature = ObjectAccessor::GetCreature(*player, guid);
    if (!creature) return true;

    LOG_DEBUG("scripts", "AoELoot: player {} looting creature {} (entry {}). Will attempt AoE merge.", player->GetGUID().ToString(), creature->GetGUID().ToString(), creature->GetEntry());
    if (sAoEConfig.showMessage)
    {
        ChatHandler(player->GetSession()).PSendSysMessage("AoE Loot: attempting to merge nearby corpses...");
    }

            // Ensure the main target is lootable (dynamic flag present) before attempting AoE merge
            if (!creature->HasDynamicFlag(UNIT_DYNFLAG_LOOTABLE)) return true;
            if (!CanPlayerLootCorpse(player, creature)) return true;
        if (player->GetGroup() && !sAoEConfig.allowInGroup) return true;

        bool handled = PerformAoELoot(player, creature);
        return handled ? false : true; // if handled -> block original packet (we already sent loot), otherwise let packet continue
    }
};

class AoELootPlayerScript : public PlayerScript
{
public:
    AoELootPlayerScript() : PlayerScript("AoELootPlayerScript") { }

    void OnLogin(Player* player)
    {
        if (!player) return;
        if (sAoEConfig.showMessage)
            ChatHandler(player->GetSession()).PSendSysMessage("|cFF00FF00[AoE Loot]|r System enabled. Loot one corpse to loot nearby corpses.");
    }

    void OnLogout(Player* player)
    {
        if (!player) return;
        sPlayerLootData.erase(player->GetGUID());
        sPlayerAutoStoreTimestamp.erase(player->GetGUID());
    }
};

class AoELootCommandScript : public CommandScript
{
public:
    AoELootCommandScript() : CommandScript("AoELootCommandScript") { }

    ChatCommandTable GetCommands() const override
    {
        static ChatCommandTable aoeTable =
        {
            ChatCommandBuilder("info",   HandleInfo,   SEC_PLAYER,        Console::No),
            ChatCommandBuilder("reload", HandleReload, SEC_ADMINISTRATOR, Console::No),
            ChatCommandBuilder("stats",  HandleStats,  SEC_GAMEMASTER,    Console::No),
            ChatCommandBuilder("force",  HandleForce,  SEC_GAMEMASTER,    Console::No),
        };

        static ChatCommandTable commandTable =
        {
            ChatCommandBuilder("aoeloot", aoeTable)
        };

        return commandTable;
    }

    static bool HandleInfo(ChatHandler* handler, char const* /*args*/)
    {
        handler->PSendSysMessage("AoE Loot: {}", sAoEConfig.enabled ? "Enabled" : "Disabled");
        if (sAoEConfig.enabled)
        {
            handler->PSendSysMessage("  Range: {:.1f} yards", sAoEConfig.range);
            handler->PSendSysMessage("  Max Corpses: {}", sAoEConfig.maxCorpses);
            handler->PSendSysMessage("  Auto-Loot: {}", sAoEConfig.autoLoot == 0 ? "Disabled" : sAoEConfig.autoLoot == 1 ? "Forced" : "Player Setting");
            handler->PSendSysMessage("  Max Merge Slots: {}", sAoEConfig.maxMergeSlots);
            handler->PSendSysMessage("  Auto Credit Gold: {}", sAoEConfig.autoCreditGold ? "Enabled" : "Disabled");
        }
        return true;
    }

    static bool HandleReload(ChatHandler* handler, char const* /*args*/)
    {
        sAoEConfig.Load();
        handler->SendSysMessage("AoE Loot configuration reloaded.");
        return true;
    }

    static bool HandleStats(ChatHandler* handler, char const* /*args*/)
    {
        Player* target = handler->getSelectedPlayerOrSelf();
        if (!target) return false;
        auto it = sPlayerLootData.find(target->GetGUID());
            if (it == sPlayerLootData.end())
            {
                handler->PSendSysMessage("{} has not used AoE loot yet.", target->GetName());
                return true;
            }
            PlayerAoELootData const& d = it->second;
            handler->PSendSysMessage("AoE Loot stats for {}: Corpses looted: {}", target->GetName(), d.lootedThisSession);
            if (d.lastCreditedGold > 0)
            {
                handler->PSendSysMessage("  Last credited: {}", formatCoins(d.lastCreditedGold));
            }
        return true;
    }

    static bool HandleForce(ChatHandler* handler, char const* args)
    {
        Player* plr = handler->getSelectedPlayerOrSelf();
        if (!plr) return false;

        Creature* target = nullptr;
        if (args && *args)
        {
            if (Optional<uint64> maybe = Acore::StringTo<uint64>(args))
            {
                ObjectGuid guid(*maybe);
                target = ObjectAccessor::GetCreature(*plr, guid);
            }
        }

        if (!target)
            target = handler->getSelectedCreature();

        if (!target)
        {
            handler->PSendSysMessage("No creature selected or valid GUID provided.");
            return true;
        }

        bool handled = PerformAoELoot(plr, target);
        if (handled)
            handler->PSendSysMessage("AoE Loot: merge attempted and handled for creature %s (entry %u).", target->GetGUID().ToString().c_str(), target->GetEntry());
        else
            handler->PSendSysMessage("AoE Loot: merge attempted but nothing was merged for creature %s (entry %u).", target->GetGUID().ToString().c_str(), target->GetEntry());

        return true;
    }
};

void AddSC_ac_aoeloot()
{
    sAoEConfig.Load();
    new AoELootServerScript();
    new AoELootPlayerScript();
    new AoELootCommandScript();
}

