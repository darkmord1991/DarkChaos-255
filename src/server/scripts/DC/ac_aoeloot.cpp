/*
 * DarkChaos AOE Loot System (simplified, compile-safe)
 * Based on: https://github.com/azerothcore/mod-aoe-loot
 * This file provides a minimal, well-formed implementation using
 * ServerScript::CanPacketReceive to intercept CMSG_LOOT and a basic
 * configuration loader. Full loot merging logic can be implemented
 * later; this stub ensures the project compiles.
 */

#include "ScriptMgr.h"
#include "Player.h"
#include "Config.h"
#include "Chat.h"
#include "ObjectAccessor.h"
#include "WorldPacket.h"
#include "Opcodes.h"
// GameTime provides GetGameTime()/GetGameTimeMS()
#include "GameTime.h"

#include <vector>
#include <unordered_map>

struct AoELootConfig
{
    bool enabled = true;
    float range = 30.0f;
    uint32 maxCorpses = 10;
    bool showMessage = true;
    bool allowInGroup = true;

    void Load()
    {
        enabled = sConfigMgr->GetOption<bool>("AoELoot.Enable", true);
        range = sConfigMgr->GetOption<float>("AoELoot.Range", 30.0f);
        maxCorpses = sConfigMgr->GetOption<uint32>("AoELoot.MaxCorpses", 10);
        showMessage = sConfigMgr->GetOption<bool>("AoELoot.ShowMessage", true);
        allowInGroup = sConfigMgr->GetOption<bool>("AoELoot.AllowInGroup", true);
        if (range < 5.0f) range = 5.0f;
        if (range > 100.0f) range = 100.0f;
        if (maxCorpses < 1) maxCorpses = 1;
        if (maxCorpses > 50) maxCorpses = 50;
    }
};

static AoELootConfig sAoEConfig;

// Track recent client-side autostore usage per player.
// If a player sent CMSG_AUTOSTORE_LOOT_ITEM recently we assume their client has
// autostore/autoloot enabled. Timestamp uses GameTime::GetGameTime().count().
static std::unordered_map<ObjectGuid, uint64> sPlayerAutoStoreTimestamp;

class AoELootWorld : public WorldScript
{
public:
    AoELootWorld() : WorldScript("AoELootWorld") { }

    void OnAfterConfigLoad(bool /*reload*/) override
    {
        sAoEConfig.Load();
    }

    void OnStartup() override
    {
        sAoEConfig.Load();
        if (sAoEConfig.showMessage)
            LOG_INFO("server.loading", ">> DarkChaos AoE Loot loaded (range: %.1f, max corpses: %u)", sAoEConfig.range, sAoEConfig.maxCorpses);
    }
};

class AoELootServer : public ServerScript
{
public:
    AoELootServer() : ServerScript("AoELootServer") { }

    bool CanPacketReceive(WorldSession* session, WorldPacket& packet) override
    {
        if (!sAoEConfig.enabled)
            return true;

        // Intercept loot packets only
        // Track autostore packets so we know if player's client requested autostore recently
        if (packet.GetOpcode() == CMSG_AUTOSTORE_LOOT_ITEM)
        {
            if (session && session->GetPlayer())
                sPlayerAutoStoreTimestamp[session->GetPlayer()->GetGUID()] = GameTime::GetGameTime().count();
            return true;
        }

        if (packet.GetOpcode() != CMSG_LOOT)
            return true;

        if (!session)
            return true;

        Player* player = session->GetPlayer();
        if (!player)
            return true;

        // Minimal safe handling: read GUID and allow default handling.
        // The full module would merge nearby corpses' loot and call SendLoot.
        // Here we just reset rpos and return true to keep behavior unchanged.
        packet.rpos(0);

        return true;
    }
};

class AoELootCommand : public CommandScript
{
public:
    AoELootCommand() : CommandScript("AoELootCommand") { }

    std::vector<ChatCommand> GetCommands() const override
    {
        static std::vector<ChatCommand> aoeTable =
        {
            { "info", SEC_GAMEMASTER, false, &HandleInfo, "" },
            /*
             * DarkChaos AOE Loot System
             * Based on: https://github.com/azerothcore/mod-aoe-loot
             * This implementation intercepts CMSG_LOOT, collects nearby corpses,
             * merges their loot into the primary corpse (respecting the 16-item
             * client window limit and configured max corpses), then sends the
             * merged loot window to the player.
             */

            #include "ScriptMgr.h"
            #include "Player.h"
            #include "Creature.h"
            #include "ObjectAccessor.h"
            #include "LootMgr.h"
            #include "Loot.h"
            #include "Chat.h"
            #include "Config.h"
            #include "WorldPacket.h"
            #include "Opcodes.h"
            #include "Group.h"
            #include "CellImpl.h" // for Cell::VisitAllObjects / searcher helpers
            #include "Log.h"
            #include "Mail.h"
            #include "DatabaseEnv.h"
            #include <sstream>

            #include <vector>
            #include <list>
            #include <algorithm>
            #include <limits>

            struct AoELootConfig
            {
                bool enabled = true;
                float range = 30.0f;
                uint32 maxCorpses = 10;
                uint8 autoLoot = 0; // 0 = disabled, 1 = forced, 2 = player's setting
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
            };

            static std::unordered_map<ObjectGuid, PlayerAoELootData> sPlayerLootData;

            // Helper: whether a player can loot this corpse according to AoE rules
            static bool CanPlayerLootCorpse(Player* player, Creature* creature)
            {
                if (!player || !creature)
                    return false;

                if (!creature->IsCorpse())
                    return false;

                if (!creature->HasLoot())
                    return false;

                if (sAoEConfig.playersOnly && player->GetTypeId() != TYPEID_PLAYER)
                    return false;

                if (sAoEConfig.ignoreTapped)
                {
                    if (creature->HasLootRecipient())
                    {
                        Player* recipient = creature->GetLootRecipient();
                        if (!recipient)
                            return false;
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

                if (!player->isAllowedToLoot(creature))
                    return false;

                return true;
            }

            // Core merge function: merges nearby corpses into the mainCreature loot
            static void PerformAoELoot(Player* player, Creature* mainCreature)
            {
                if (!player || !mainCreature)
                    return;

                Loot* mainLoot = &mainCreature->loot;
                if (!mainLoot)
                    return;

                // Collect nearby dead creatures
                std::list<Creature*> nearby;
                player->GetDeadCreatureListInGrid(nearby, sAoEConfig.range);

                // Filter invalid ones and remove mainCreature
                nearby.remove_if([&](Creature* c) -> bool
                {
                    if (!c) return true;
                    if (c->GetGUID() == mainCreature->GetGUID()) return true;
                    if (!c->HasDynamicFlag(UNIT_DYNFLAG_LOOTABLE)) return true;
                    if (!c->HasLoot()) return true;
                    if (!player->isAllowedToLoot(c)) return true;
                    return false;
                });

                if (nearby.empty())
                    return;

                // Keep up to maxCorpses
                std::vector<Creature*> corpses;
                corpses.reserve(sAoEConfig.maxCorpses);
                for (Creature* c : nearby)
                {
                    if (corpses.size() >= sAoEConfig.maxCorpses)
                        break;
                    corpses.push_back(c);
                }

                // Prepare temporary storage
                std::vector<LootItem> itemsToAdd;
                std::vector<LootItem> questItemsToAdd;
                uint32 totalGold = mainLoot->gold;

                size_t initialItems = mainLoot->items.size();
                size_t initialQuest = mainLoot->quest_items.size();

                size_t processed = 0;
                for (Creature* corpse : corpses)
                {
                    if (!corpse) continue;
                    Loot* loot = &corpse->loot;
                    if (!loot || loot->isLooted())
                        continue;

                    // Merge gold
                    if (loot->gold > 0)
                    {
                        if (totalGold < std::numeric_limits<uint32>::max() - loot->gold)
                            totalGold += loot->gold;
                    }

                    // Collect items (respect 16 item window total)
                    for (auto const& it : loot->items)
                    {
                        if (!it.AllowedForPlayer(player))
                            continue;

                        // If quest items handling disabled, skip
                        if (!sAoEConfig.questItems && it.is_quest_item)
                            continue;

                        // If adding this would overflow the 16-slot client window, skip further regular items
                        size_t projected = mainLoot->items.size() + itemsToAdd.size() + mainLoot->quest_items.size() + questItemsToAdd.size();
                        if (projected >= 16)
                            break;

                        itemsToAdd.push_back(it);
                    }

                    // Collect quest items
                    for (auto const& it : loot->quest_items)
                    {
                        if (!it.AllowedForPlayer(player))
                            continue;

                        size_t projected = mainLoot->items.size() + itemsToAdd.size() + mainLoot->quest_items.size() + questItemsToAdd.size();
                        if (projected >= 16)
                            break;

                        questItemsToAdd.push_back(it);
                    }

                    // Mark corpse as cleared
                    loot->clear();
                    corpse->AllLootRemovedFromCorpse();
                    corpse->RemoveDynamicFlag(UNIT_DYNFLAG_LOOTABLE);

                    processed++;
                }

                if (processed == 0)
                    return;

                // Append collected items to main loot (respecting client limit 16)
                for (auto const& it : itemsToAdd)
                {
                    if (mainLoot->items.size() + mainLoot->quest_items.size() >= 16)
                        break;
                    mainLoot->items.push_back(it);
                }
                for (auto const& it : questItemsToAdd)
                {
                    if (mainLoot->items.size() + mainLoot->quest_items.size() >= 16)
                        break;
                    mainLoot->quest_items.push_back(it);
                }

                // Update gold
                mainLoot->gold = totalGold;

                // Update main loot and decide delivery method
                for (auto const& it : itemsToAdd)
                {
                    if (mainLoot->items.size() + mainLoot->quest_items.size() >= 16)
                        break;
                    mainLoot->items.push_back(it);
                }
                for (auto const& it : questItemsToAdd)
                {
                    if (mainLoot->items.size() + mainLoot->quest_items.size() >= 16)
                        break;
                    mainLoot->quest_items.push_back(it);
                }

                mainLoot->gold = totalGold;

                // Update stats
                PlayerAoELootData& data = sPlayerLootData[player->GetGUID()];
                data.lastAoELoot = GameTime::GetGameTime().count();
                data.lootedThisSession += processed;

                // If player is in a group, respect group loot method
                if (Group* group = player->GetGroup())
                {
                    LootMethod method = group->GetLootMethod();
                    if (method == MASTER_LOOT)
                    {
                        // Master loot: hand off to group master-loot flow
                        group->MasterLoot(mainLoot, mainCreature);
                        return;
                    }
                    else if (method == NEED_BEFORE_GREED || method == GROUP_LOOT || method == FREE_FOR_ALL)
                    {
                        // For group loot methods, hand off to group handler
                        group->GroupLoot(mainLoot, mainCreature);
                        return;
                    }
                }

                // Solo or free-for-all: handle auto-loot forced setting or player's setting
                auto shouldAutoLootForPlayer = [&](Player* p) -> bool
                {
                    if (!p) return false;
                    if (sAoEConfig.autoLoot == 1)
                        return true;
                    if (sAoEConfig.autoLoot == 2)
                    {
                        auto it = sPlayerAutoStoreTimestamp.find(p->GetGUID());
                        if (it == sPlayerAutoStoreTimestamp.end())
                            return false;

                        // consider autostore active if within last 10 seconds
                        uint64 now = GameTime::GetGameTime().count();
                        return (now - it->second) <= 10;
                    }
                    return false;
                };

                if (shouldAutoLootForPlayer(player))
                {
                    // Try to store items directly; if inventory full, send by mail
                    std::vector<std::pair<uint32, uint32>> mailItems; // pair<entry, count>
                    uint32 mailMoney = 0;

                    // Helper lambda to attempt store or queue to mail
                    auto storeOrMail = [&](LootItem const& li)
                    {
                        ItemPosCountVec dest;
                        InventoryResult msg = player->CanStoreNewItem(NULL_BAG, NULL_SLOT, dest, li.itemid, li.count);
                        if (msg == EQUIP_ERR_OK)
                        {
                            Item* newItem = player->StoreNewItem(dest, li.itemid, true, li.randomPropertyId);
                            if (newItem)
                                player->SendNewItem(newItem, uint32(li.count), false, false, true);
                        }
                        else
                        {
                            mailItems.emplace_back(li.itemid, li.count);
                        }
                    };

                    // Process existing main loot items
                    for (auto const& it : mainLoot->items)
                        storeOrMail(it);
                    for (auto const& it : mainLoot->quest_items)
                        storeOrMail(it);

                    // Gold
                    if (mainLoot->gold > 0)
                    {
                        // Try direct give
                        player->ModifyMoney(mainLoot->gold);
                    }

                    // If any items need mailing, create a mail
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

                        if (mainLoot->gold > 0)
                            draft.AddMoney(mainLoot->gold);

                        draft.SendMailTo(trans, MailReceiver(player), sender);
                        CharacterDatabase.CommitTransaction(trans);
                    }

                    // Clear main loot and mark corpse cleaned
                    mainLoot->clear();
                    mainCreature->AllLootRemovedFromCorpse();
                    mainCreature->RemoveDynamicFlag(UNIT_DYNFLAG_LOOTABLE);

                    return;
                }

                // Default: send merged loot window to player
                player->SendLoot(mainCreature->GetGUID(), LOOT_CORPSE);

                // Optional message
                if (sAoEConfig.showMessage && processed > 0)
                {
                    std::ostringstream ss;
                    ss << "|cFF00FF00[AoE Loot]|r Looted " << processed << " nearby corpse(s). ";
                    if (itemsToAdd.size() > 0)
                        ss << "Collected " << itemsToAdd.size() << " item(s).";
                    player->GetSession()->SendNotification(ss.str());
                }
            }

            // Server script: intercept CMSG_LOOT and perform merge before default handler
            class AoELootServerScript : public ServerScript
            {
            public:
                AoELootServerScript() : ServerScript("AoELootServerScript") { }

                bool CanPacketReceive(WorldSession* session, WorldPacket& packet) override
                {
                    if (!sAoEConfig.enabled)
                        return true;

                    if (!session)
                        return true;

                    if (packet.GetOpcode() != CMSG_LOOT)
                        return true;

                    // Peek GUID from packet
                    packet.rpos(0);
                    ObjectGuid guid;
                    packet >> guid;
                    packet.rpos(0);

                    if (!guid || !guid.IsCreature())
                        return true;

                    Player* player = session->GetPlayer();
                    if (!player)
                        return true;

                    Creature* creature = ObjectAccessor::GetCreature(*player, guid);
                    if (!creature)
                        return true;

                    // Basic checks
                    if (!CanPlayerLootCorpse(player, creature))
                        return true; // fall back to default handling

                    // If player in group and AoE not allowed in group, skip
                    if (player->GetGroup() && !sAoEConfig.allowInGroup)
                        return true;

                    // Do the merge and block default handler
                    PerformAoELoot(player, creature);

                    // Block default (we already sent merged loot)
                    return false;
                }
            };

            // Player script for cleanup and optional messages
            class AoELootPlayerScript : public PlayerScript
            {
            public:
                AoELootPlayerScript() : PlayerScript("AoELootPlayerScript") { }

                void OnLogin(Player* player) override
                {
                    if (!player) return;
                    if (sAoEConfig.showMessage)
                        ChatHandler(player->GetSession()).PSendSysMessage("|cFF00FF00[AoE Loot]|r System enabled. Loot one corpse to loot nearby corpses.");
                }

                void OnLogout(Player* player) override
                {
                    if (!player) return;
                    sPlayerLootData.erase(player->GetGUID());
                    sPlayerAutoStoreTimestamp.erase(player->GetGUID());
                }
            };

            // Command script
            class AoELootCommandScript : public CommandScript
            {
            public:
                AoELootCommandScript() : CommandScript("AoELootCommandScript") { }

                std::vector<ChatCommand> GetCommands() const override
                {
                    static std::vector<ChatCommand> aoeTable =
                    {
                        { "info",   SEC_PLAYER, false, &HandleInfo, "" },
                        { "reload", SEC_ADMINISTRATOR, false, &HandleReload, "" },
                        { "stats",  SEC_GAMEMASTER, false, &HandleStats,  "" },
                    };

                    static std::vector<ChatCommand> commandTable =
                    {
                        { "aoeloot", SEC_GAMEMASTER, false, nullptr, "", aoeTable },
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
                    if (!target)
                        return false;
                    auto it = sPlayerLootData.find(target->GetGUID());
                    if (it == sPlayerLootData.end())
                    {
                        handler->PSendSysMessage("{} has not used AoE loot yet.", target->GetName());
                        return true;
                    }
                    PlayerAoELootData const& d = it->second;
                    handler->PSendSysMessage("AoE Loot stats for {}: Corpses looted: {}", target->GetName(), d.lootedThisSession);
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
