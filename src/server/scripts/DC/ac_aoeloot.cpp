/*/*

 * Copyright (C) 2016+ AzerothCore <www.azerothcore.org>, released under GNU AGPL v3 license * Copyright (C) 2016+ AzerothCore <www.azerothcore.org>, released under GNU AGPL v3 license

 *  * 

 * DarkChaos AOE Loot System * DarkChaos AOE Loot System

 *  * 

 * Allows players to loot all nearby corpses with a single click by merging * Allows players to loot all nearby corpses with a single click.

 * their loot into the initial corpse's loot window. * When a player loots one corpse, the system automatically collects loot

 *  * from all nearby corpses within configured range and merges them into

 * Based on: https://github.com/azerothcore/mod-aoe-loot * a single loot window.

 * Uses packet interception to merge loot before the loot window opens. * 

 */ * Based on: https://github.com/azerothcore/mod-aoe-loot

 * Inspired by retail WoW's AoE looting feature.

#include "ScriptMgr.h" */

#include "Player.h"

#include "Config.h"#include "ScriptMgr.h"

#include "Creature.h"#include "Player.h"

#include "LootMgr.h"#include "Config.h"

#include "Chat.h"#include "Creature.h"

#include "Group.h"#include "GameObject.h"

#include "Log.h"#include "LootMgr.h"

#include "WorldPacket.h"#include "Chat.h"

#include "Opcodes.h"#include "ObjectAccessor.h"

#include <vector>#include "Group.h"

#include <list>#include "Log.h"

#include <algorithm>#include <vector>

#include <limits>#include <list>

#include <algorithm>

// Configuration#include <limits>

struct AoELootConfig

{// Configuration cache

    bool enabled = true;struct AoELootConfig

    bool showMessage = true;{

    bool allowInGroup = true;    bool enabled = true;

    float range = 30.0f;    float range = 30.0f;

    uint32 maxCorpses = 10;    uint32 maxCorpses = 10;

    bool showMessage = true;

    void Load()    bool allowInGroup = true;

    {};

        enabled = sConfigMgr->GetOption<bool>("AoELoot.Enable", true);

        showMessage = sConfigMgr->GetOption<bool>("AoELoot.ShowMessage", true);static AoELootConfig sAoELootConfig;

        allowInGroup = sConfigMgr->GetOption<bool>("AoELoot.AllowInGroup", true);

        range = sConfigMgr->GetOption<float>("AoELoot.Range", 30.0f);// Load configuration

        maxCorpses = sConfigMgr->GetOption<uint32>("AoELoot.MaxCorpses", 10);static void LoadAoELootConfig()

{

        // Validate    sAoELootConfig.enabled = sConfigMgr->GetOption<bool>("AoELoot.Enable", true);

        if (range < 5.0f) range = 5.0f;    sAoELootConfig.range = sConfigMgr->GetOption<float>("AoELoot.Range", 30.0f);

        if (range > 100.0f) range = 100.0f;    sAoELootConfig.maxCorpses = sConfigMgr->GetOption<uint32>("AoELoot.MaxCorpses", 10);

        if (maxCorpses < 1) maxCorpses = 1;    sAoELootConfig.showMessage = sConfigMgr->GetOption<bool>("AoELoot.ShowMessage", true);

        if (maxCorpses > 50) maxCorpses = 50;    sAoELootConfig.allowInGroup = sConfigMgr->GetOption<bool>("AoELoot.AllowInGroup", true);

    }

};    // Validate range

    if (sAoELootConfig.range < 5.0f)

static AoELootConfig sConfig;        sAoELootConfig.range = 5.0f;

    if (sAoELootConfig.range > 100.0f)

// World script: config loading + login message        sAoELootConfig.range = 100.0f;

class AoELootWorld : public WorldScript

{    // Validate max corpses

public:    if (sAoELootConfig.maxCorpses < 1)

    AoELootWorld() : WorldScript("AoELootWorld") { }        sAoELootConfig.maxCorpses = 1;

    if (sAoELootConfig.maxCorpses > 50)

    void OnAfterConfigLoad(bool /*reload*/) override        sAoELootConfig.maxCorpses = 50;

    {}

        sConfig.Load();

    }// Helper: check if corpse can be looted by player

static bool CanPlayerLootCorpse(Player* player, Creature* creature)

    void OnStartup() override{

    {    if (!player || !creature)

        sConfig.Load();        return false;

        if (sConfig.enabled)

        {    // Must be a corpse

            LOG_INFO("server.loading", ">> DarkChaos AOE Loot System loaded");    if (!creature->IsCorpse())

            LOG_INFO("server.loading", ">> - Range: {:.1f} yards", sConfig.range);        return false;

            LOG_INFO("server.loading", ">> - Max Corpses: {}", sConfig.maxCorpses);

        }    // Must have loot

    }    if (!creature->HasLoot())

};        return false;



// Player script: login message    // Check if already looted by this player

class AoELootPlayer : public PlayerScript    if (creature->HasLootRecipient())

{    {

public:        // If ignore tapped is enabled, only loot own kills

    AoELootPlayer() : PlayerScript("AoELootPlayer") { }        if (sAoELootConfig.ignoreTapped)

        {

    void OnLogin(Player* player) override            Player* recipient = creature->GetLootRecipient();

    {            if (!recipient)

        if (!sConfig.enabled || !sConfig.showMessage || !player)                return false;

            return;

            // Check if player or player's group is the recipient

        ChatHandler(player->GetSession()).PSendSysMessage(            if (recipient->GetGUID() != player->GetGUID())

            "|cFF00FF00[AoE Loot]|r System enabled! Loot one corpse to loot all nearby corpses."            {

        );                if (Group* group = player->GetGroup())

    }                {

};                    if (!group->IsMember(recipient->GetGUID()))

                        return false;

// Server script: packet interception for CMSG_LOOT                }

class AoELootServer : public ServerScript                else

{                {

public:                    return false;

    AoELootServer() : ServerScript("AoELootServer") { }                }

            }

    bool CanPacketReceive(WorldSession* session, WorldPacket& packet) override        }

    {    }

        // Only intercept CMSG_LOOT packets

        if (packet.GetOpcode() != CMSG_LOOT)    // Check distance

            return true;    if (!player->IsWithinDist(creature, sAoELootConfig.range))

        return false;

        if (!sConfig.enabled || !session)

            return true;    // Check line of sight if required

    if (sAoELootConfig.requireLineOfSight)

        Player* player = session->GetPlayer();    {

        if (!player)        if (!player->IsWithinLOSInMap(creature))

            return true;            return false;

    }

        // Check group settings

        if (player->GetGroup() && !sConfig.allowInGroup)    return true;

            return true;}



        // Read target GUID from packet (don't consume it, just peek)// Helper: collect items from a single corpse

        ObjectGuid targetGuid;static bool LootCorpse(Player* player, Creature* creature, uint32& itemCount, uint32& moneyGained)

        packet.rpos(0); // Reset read position{

        packet >> targetGuid;    if (!player || !creature)

        packet.rpos(0); // Reset again so normal handler can read it        return false;



        if (!targetGuid || !targetGuid.IsCreature())    Loot* loot = &creature->loot;

            return true;    if (!loot)

        return false;

        // Get the main creature

        Creature* mainCreature = player->GetMap()->GetCreature(targetGuid);    uint32 itemsBefore = itemCount;

        if (!mainCreature || !mainCreature->HasDynamicFlag(UNIT_DYNFLAG_LOOTABLE))    uint32 moneyBefore = moneyGained;

            return true;

    // Loot money

        // Get nearby corpses    if (sAoELootConfig.money && loot->gold > 0)

        std::list<Creature*> nearbyCorpses;    {

        player->GetDeadCreatureListInGrid(nearbyCorpses, sConfig.range);        player->ModifyMoney(loot->gold);

        player->UpdateAchievementCriteria(ACHIEVEMENT_CRITERIA_TYPE_LOOT_MONEY, loot->gold);

        // Filter: remove invalid corpses        moneyGained += loot->gold;

        nearbyCorpses.remove_if([&](Creature* c)        loot->gold = 0;

        {    }

            return !c ||

                   c->GetGUID() == targetGuid ||    // Determine auto-loot setting

                   !c->HasDynamicFlag(UNIT_DYNFLAG_LOOTABLE) ||    bool autoLoot = false;

                   !player->isAllowedToLoot(c);    if (sAoELootConfig.autoLoot == 1)

        });        autoLoot = true;

    else if (sAoELootConfig.autoLoot == 2)

        // If no nearby corpses, process normally        autoLoot = player->GetSession()->HasPermission(rbac::RBAC_PERM_AUTO_LOOT_ITEM);

        if (nearbyCorpses.empty())

        {    // Loot items

            player->SendLoot(targetGuid, LOOT_CORPSE);    for (auto& item : loot->items)

            return false;    {

        }        // Skip if already looted

        if (item.is_looted)

        // Merge loot            continue;

        Loot* mainLoot = &mainCreature->loot;

        uint32 totalGold = mainLoot->gold;        // Skip quest items if disabled

        std::vector<LootItem> itemsToAdd;        if (!sAoELootConfig.questItems && item.is_quest_item)

        std::vector<LootItem> questItemsToAdd;            continue;

        size_t processedCorpses = 0;

        // Skip if conditions not met

        for (Creature* creature : nearbyCorpses)        if (!item.AllowedForPlayer(player))

        {            continue;

            if (processedCorpses >= sConfig.maxCorpses)

                break;        // Check if player can receive the item

        ItemPosCountVec dest;

            Loot* loot = &creature->loot;        InventoryResult msg = player->CanStoreNewItem(NULL_BAG, NULL_SLOT, dest, item.itemid, item.count);

            if (loot->isLooted())

                continue;        if (msg == EQUIP_ERR_OK)

        {

            // Collect gold            Item* newItem = player->StoreNewItem(dest, item.itemid, true, item.randomPropertyId);

            if (loot->gold > 0)            if (newItem)

            {            {

                if (totalGold < (std::numeric_limits<uint32>::max() - loot->gold))                player->SendNewItem(newItem, item.count, false, false, true);

                    totalGold += loot->gold;                itemCount++;

            }                item.is_looted = true;

            }

            // Collect regular items (max 16 items in loot window)        }

            for (size_t i = 0; i < loot->items.size(); ++i)        else if (autoLoot)

            {        {

                if ((mainLoot->items.size() + itemsToAdd.size() +             // If auto-loot and inventory full, send to mail

                     mainLoot->quest_items.size() + questItemsToAdd.size()) >= 16)            player->SendEquipError(msg, nullptr, nullptr, item.itemid);

                    break;        }

                itemsToAdd.push_back(loot->items[i]);    }

            }

    // Mark as looted if all items taken

            // Collect quest items    bool allLooted = true;

            for (size_t i = 0; i < loot->quest_items.size(); ++i)    for (auto const& item : loot->items)

            {    {

                if ((mainLoot->items.size() + itemsToAdd.size() +         if (!item.is_looted && item.AllowedForPlayer(player))

                     mainLoot->quest_items.size() + questItemsToAdd.size()) >= 16)        {

                    break;            allLooted = false;

                questItemsToAdd.push_back(loot->quest_items[i]);            break;

            }        }

    }

            // Clear and mark as looted

            loot->clear();    if (allLooted)

            creature->AllLootRemovedFromCorpse();    {

            creature->RemoveDynamicFlag(UNIT_DYNFLAG_LOOTABLE);        loot->clear();

        creature->RemoveDynamicFlag(UNIT_DYNFLAG_LOOTABLE);

            processedCorpses++;        creature->AllLootRemovedFromCorpse();

        }    }



        // Update main loot with collected items    return (itemCount > itemsBefore) || (moneyGained > moneyBefore);

        mainLoot->gold = totalGold;}



        for (const auto& item : itemsToAdd)// Main AOE loot handler

        {static void PerformAoELoot(Player* player, Creature* initialTarget)

            if (mainLoot->items.size() < 16){

                mainLoot->items.push_back(item);    if (!sAoELootConfig.enabled || !player || !initialTarget)

        }        return;



        for (const auto& item : questItemsToAdd)    // Sanity: players only

        {    if (sAoELootConfig.playersOnly && player->GetTypeId() != TYPEID_PLAYER)

            if (mainLoot->quest_items.size() < 16)        return;

                mainLoot->quest_items.push_back(item);

        }    // Get nearby creatures

    std::vector<Creature*> nearbyCorpses;

        // Send merged loot window

        player->SendLoot(targetGuid, LOOT_CORPSE);    Acore::AnyDeadUnitInObjectRangeCheck check(player, sAoELootConfig.range);

    Acore::CreatureListSearcher<Acore::AnyDeadUnitInObjectRangeCheck> searcher(player, nearbyCorpses, check);

        return false; // Block packet from going to default handler    Cell::VisitAllObjects(player, searcher, sAoELootConfig.range);

    }

};    // Filter lootable corpses

    std::vector<Creature*> lootableCorpses;

// GM commands    for (Creature* creature : nearbyCorpses)

class AoELootCommand : public CommandScript    {

{        if (CanPlayerLootCorpse(player, creature))

public:        {

    AoELootCommand() : CommandScript("AoELootCommand") { }            lootableCorpses.push_back(creature);



    std::vector<ChatCommand> GetCommands() const override            if (lootableCorpses.size() >= sAoELootConfig.maxCorpses)

    {                break;

        static std::vector<ChatCommand> aoelootCommandTable =        }

        {    }

            { "info",   SEC_PLAYER, false, &HandleAoELootInfoCommand,   "" },

            { "reload", SEC_ADMINISTRATOR, false, &HandleAoELootReloadCommand, "" },    // If only one corpse (the initial target), just loot normally

        };    if (lootableCorpses.size() <= 1)

        return;

        static std::vector<ChatCommand> commandTable =

        {    // Perform AOE loot

            { "aoeloot", SEC_PLAYER, false, nullptr, "", aoelootCommandTable },    uint32 itemCount = 0;

        };    uint32 moneyGained = 0;

    uint32 corpsesLooted = 0;

        return commandTable;

    }    for (Creature* creature : lootableCorpses)

    {

    static bool HandleAoELootInfoCommand(ChatHandler* handler, char const* /*args*/)        if (LootCorpse(player, creature, itemCount, moneyGained))

    {        {

        handler->PSendSysMessage("AOE Loot System: {}", sConfig.enabled ? "|cFF00FF00Enabled|r" : "|cFFFF0000Disabled|r");            corpsesLooted++;

        if (sConfig.enabled)        }

        {

            handler->PSendSysMessage("  Range: {:.1f} yards", sConfig.range);        // Small delay to prevent server lag

            handler->PSendSysMessage("  Max Corpses: {}", sConfig.maxCorpses);        if (sAoELootConfig.lootDelay > 0)

            handler->PSendSysMessage("  Allow in Group: {}", sConfig.allowInGroup ? "Yes" : "No");        {

        }            // Note: In production, you'd use a proper async timer

        return true;            // For now, this is a simple delay placeholder

    }        }

    }

    static bool HandleAoELootReloadCommand(ChatHandler* handler, char const* /*args*/)

    {    // Report results

        sConfig.Load();    if (sAoELootConfig.showCount && corpsesLooted > 0)

        handler->SendSysMessage("Reloaded AOE Loot configuration.");    {

        return true;        std::ostringstream ss;

    }        ss << "|cFF00FF00[AoE Loot]|r Looted " << corpsesLooted << " corpse(s)";

};

        if (itemCount > 0)

void AddSC_ac_aoeloot()            ss << " (" << itemCount << " item" << (itemCount != 1 ? "s" : "") << ")";

{

    new AoELootWorld();        if (moneyGained > 0)

    new AoELootPlayer();        {

    new AoELootServer();            uint32 gold = moneyGained / GOLD;

    new AoELootCommand();            uint32 silver = (moneyGained % GOLD) / SILVER;

}            uint32 copper = moneyGained % SILVER;


            ss << " (";
            if (gold > 0) ss << gold << "g ";
            if (silver > 0) ss << silver << "s ";
            if (copper > 0) ss << copper << "c";
            ss << ")";
        }

        ChatHandler(player->GetSession()).SendSysMessage(ss.str());
    }

    // Update tracking
    PlayerAoELootData& data = sPlayerLootData[player->GetGUID()];
    data.lastAoELoot = GameTime::GetGameTime();
    data.lootedThisSession += corpsesLooted;
}

// World script for config loading
class AoELootWorldScript : public WorldScript
{
public:
    AoELootWorldScript() : WorldScript("AoELootWorldScript") { }

    void OnAfterConfigLoad(bool /*reload*/) override
    {
        LoadAoELootConfig();
    }

    void OnStartup() override
    {
        LoadAoELootConfig();

        if (sAoELootConfig.enabled)
        {
            LOG_INFO("server.loading", ">> DarkChaos AOE Loot System loaded");
            LOG_INFO("server.loading", ">> - Range: {:.1f} yards", sAoELootConfig.range);
            LOG_INFO("server.loading", ">> - Max Corpses: {}", sAoELootConfig.maxCorpses);
        }
    }
};

// Player script to intercept loot events
class AoELootPlayerScript : public PlayerScript
{
public:
    AoELootPlayerScript() : PlayerScript("AoELootPlayerScript") { }

    void OnLootItem(Player* player, Item* /*item*/, uint32 /*count*/, ObjectGuid lootguid) override
    {
        if (!sAoELootConfig.enabled || !player)
            return;

        // Check if looting a creature
        if (lootguid.IsCreature())
        {
            if (Creature* creature = ObjectAccessor::GetCreature(*player, lootguid))
            {
                // Trigger AOE loot
                PerformAoELoot(player, creature);
            }
        }
    }

    void OnLogout(Player* player) override
    {
        if (!player)
            return;

        // Clean up player data
        sPlayerLootData.erase(player->GetGUID());
    }
};

// Alternative: hook into the loot start event
class AoELootCreatureScript : public CreatureScript
{
public:
    AoELootCreatureScript() : CreatureScript("AoELootCreatureScript") { }

    struct AoELootCreatureAI : public ScriptedAI
    {
        AoELootCreatureAI(Creature* creature) : ScriptedAI(creature) { }

        void JustDied(Unit* /*killer*/) override
        {
            // Mark creature as lootable - the loot event will trigger AOE
            if (me->GetLoot())
            {
                me->SetDynamicFlag(UNIT_DYNFLAG_LOOTABLE);
            }
        }
    };

    CreatureAI* GetAI(Creature* creature) const override
    {
        return new AoELootCreatureAI(creature);
    }
};

// GM commands
class AoELootCommandScript : public CommandScript
{
public:
    AoELootCommandScript() : CommandScript("AoELootCommandScript") { }

    std::vector<ChatCommand> GetCommands() const override
    {
        static std::vector<ChatCommand> aoelootCommandTable =
        {
            { "info",   SEC_PLAYER, false, &HandleAoELootInfoCommand,   "" },
            { "reload", SEC_ADMINISTRATOR, false, &HandleAoELootReloadCommand, "" },
            { "stats",  SEC_GAMEMASTER, false, &HandleAoELootStatsCommand,  "" },
        };

        static std::vector<ChatCommand> commandTable =
        {
            { "aoeloot", SEC_PLAYER, false, nullptr, "", aoelootCommandTable },
        };

        return commandTable;
    }

    static bool HandleAoELootInfoCommand(ChatHandler* handler, char const* /*args*/)
    {
        handler->PSendSysMessage("AOE Loot System: {}", sAoELootConfig.enabled ? "Enabled" : "Disabled");
        if (sAoELootConfig.enabled)
        {
            handler->PSendSysMessage("  Range: {:.1f} yards", sAoELootConfig.range);
            handler->PSendSysMessage("  Max Corpses: {}", sAoELootConfig.maxCorpses);
            handler->PSendSysMessage("  Auto-Loot: {}", 
                sAoELootConfig.autoLoot == 0 ? "Disabled" :
                sAoELootConfig.autoLoot == 1 ? "Forced" : "Player Setting");
        }
        return true;
    }

    static bool HandleAoELootReloadCommand(ChatHandler* handler, char const* /*args*/)
    {
        LoadAoELootConfig();
        handler->SendSysMessage("Reloaded AOE Loot configuration.");
        return true;
    }

    static bool HandleAoELootStatsCommand(ChatHandler* handler, char const* args)
    {
        Player* target = handler->getSelectedPlayerOrSelf();
        if (!target)
        {
            handler->SendSysMessage("No player selected.");
            return false;
        }

        auto it = sPlayerLootData.find(target->GetGUID());
        if (it == sPlayerLootData.end())
        {
            handler->PSendSysMessage("{} has not used AOE loot yet.", target->GetName());
            return true;
        }

        PlayerAoELootData const& data = it->second;
        handler->PSendSysMessage("AOE Loot Stats for {}:", target->GetName());
        handler->PSendSysMessage("  Corpses Looted: {}", data.lootedThisSession);
        handler->PSendSysMessage("  Last Use: {} seconds ago", 
            GameTime::GetGameTime() - data.lastAoELoot);

        return true;
    }
};

void AddSC_ac_aoeloot()
{
    new AoELootWorldScript();
    new AoELootPlayerScript();
    new AoELootCommandScript();
}
