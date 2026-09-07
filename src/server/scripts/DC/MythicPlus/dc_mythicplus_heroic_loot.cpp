/*
 * Copyright (C) 2016+ AzerothCore <www.azerothcore.org>, released under GNU AGPL v3 license
 * Copyright (C) 2025+ DarkChaos-255 Custom Scripts
 *
 * Heroic / plain-Mythic dungeon loot for the Classic and TBC maps.
 *
 * WHY THIS EXISTS
 * ---------------------------------------------------------------------
 * Classic dungeons have no heroic creature templates: 0 of ~700 Vanilla
 * creature templates carry difficulty_entry_1, so Heroic and Mythic runs
 * of Deadmines roll the exact same ilvl 15-25 greens as the level-17
 * Normal run. TBC dungeons do fork, but their heroic tables cap at ilvl
 * 115. Either way a level-80 group gets nothing worth having.
 *
 * MythicPlusRunManager::GenerateBossLoot already solves this properly -
 * spec-aware personal loot, five-stage fallback, mail delivery - but it
 * returns early when state->keystoneLevel == 0, so it only ever fires on
 * keyed Mythic+ runs. Heroic and plain Mythic have no InstanceState at
 * all, so they cannot use that path.
 *
 * This script covers those two difficulties instead. It hooks
 * OnAfterLootTemplateProcess, which fires immediately after the loot
 * template has been rolled and before group rights and the quality
 * threshold are assigned - the one point where the item list can still be
 * replaced and have the result treated as ordinary group loot.
 *
 * WHAT IT DOES
 * ---------------------------------------------------------------------
 *   - drops the stock item list entirely (quest items survive: Loot keeps
 *     them in a separate vector, so dungeon quests still work)
 *   - pays essence on trash and essence + upgrade tokens on bosses
 *   - rolls gear on bosses from dc_heroic_loot_pool at the dungeon's own
 *     dc_dungeon_mythic_profile.loot_ilvl
 *
 * Gold is untouched: Loot::generateMoneyLoot runs separately in
 * Unit::Kill and is gated only on the creature's loot mode.
 *
 * WHY NOT LootMode
 * ---------------------------------------------------------------------
 * Creature::SetLootMode plus LootMode-tagged reference_loot_template rows
 * would suppress the stock drops with no C++ at all, and that was the
 * first design. It cannot distinguish quest drops, though: every stock
 * row including quest items carries LootMode 1, so suppressing mode 1
 * breaks every dungeon quest on the map. Doing it here keeps quest_items
 * intact by construction.
 */

#include "ScriptMgr.h"
#include "MiscScript.h"
#include "AllMapScript.h"
#include "Config.h"
#include "Creature.h"
#include "Group.h"
#include "Item.h"
#include "ItemTemplate.h"
#include "Log.h"
#include "LootMgr.h"
#include "Map.h"
#include "ObjectMgr.h"
#include "Player.h"
#include "Random.h"
#include "SharedDefines.h"
#include "dc_mythicplus_constants.h"
#include "dc_mythicplus_difficulty_scaling.h"
#include "dc_mythicplus_run_manager.h"
#include <algorithm>
#include <mutex>
#include <unordered_map>
#include <unordered_set>
#include <vector>

namespace
{
// DC currency items. Both are class 15 (Miscellaneous) and stack high, so
// they behave as currency rather than inventory pressure.
constexpr uint32 ITEM_UPGRADE_TOKEN  = 300311;  // "DC Item Upgrade Token"
constexpr uint32 ITEM_ARTIFACT_ESSENCE = 300312; // "DC Artifact Essence"

// Gear already dropped in this dungeon instance, keyed by instance id.
//
// Deduping inside one boss is not enough: the pool is rolled blind on every
// kill, so across a five-boss run the same helm could drop three times. This
// is instance-wide rather than per player because Heroic and plain Mythic
// gear is group loot in the corpse - nobody owns a drop until the roll.
//
// Maps update on a thread pool, so two instances can fill loot at the same
// moment. The lock is held across the whole roll rather than copying the set
// out and merging it back: it is taken once per boss kill and the work under
// it is a handful of vector scans, so the simpler shape costs nothing.
std::mutex s_instanceAwardsMutex;
std::unordered_map<uint32, std::unordered_set<uint32>> s_instanceAwards;

void ForgetInstanceAwards(uint32 instanceId)
{
    std::lock_guard<std::mutex> guard(s_instanceAwardsMutex);
    s_instanceAwards.erase(instanceId);
}

bool HeroicLootEnabled()
{
    return sConfigMgr->GetOption<bool>("MythicPlus.HeroicLoot.Enabled", true);
}

// Add one pool row to the loot as an ordinary, always-present drop.
// Chance 100 / groupid 0 because the roll already happened when we picked
// the item; this is just the delivery.
void PushLoot(Loot* loot, uint32 itemId, uint32 count)
{
    if (!itemId || !count)
        return;

    // LootStoreItem stores both counts in a uint8, so clamp before the
    // narrowing conversion rather than letting a config typo wrap to 0.
    uint8 stackCount = static_cast<uint8>(std::min<uint32>(count, 255));

    LootStoreItem storeItem(itemId, 0, 100.0f, false, LOOT_MODE_DEFAULT, 0,
                            static_cast<int32>(stackCount), stackCount);
    loot->AddItem(storeItem);
}

// Hand one currency stack straight to a player rather than putting it in
// the corpse for the group to roll on.
//
// Tokens and essence are currency, not gear: making five people roll a
// need/greed window for one stack of essence is pure friction, and the
// loser gets nothing for the same kill. Everyone present is paid the same
// amount, the way retail hands out valor.
//
// Mirrors GivePersonalLoot in dc_mythicplus_loot_generator.cpp: a full bag
// falls back to mail, and any other rejection is dropped rather than
// mailed, because mail the player can never empty is worse than nothing.
void GiveCurrency(Player* player, uint32 itemId, uint32 count)
{
    if (!player || !itemId || !count)
        return;

    ItemPosCountVec dest;
    InventoryResult storeResult = player->CanStoreNewItem(NULL_BAG, NULL_SLOT, dest, itemId, count);
    if (storeResult == EQUIP_ERR_OK)
    {
        if (Item* item = player->StoreNewItem(dest, itemId, true))
            player->SendNewItem(item, count, true, false);

        return;
    }

    if (storeResult == EQUIP_ERR_INVENTORY_FULL || storeResult == EQUIP_ERR_BAG_FULL)
    {
        player->SendItemRetrievalMail(itemId, count);
        return;
    }

    LOG_DEBUG("mythic.loot", "Currency {} rejected for player {} (InventoryResult {})",
              itemId, player->GetName(), static_cast<uint32>(storeResult));
}

// Players on this map who could actually receive the loot. Used to steer
// the gear roll so a drop is always usable by someone standing there,
// rather than handing a caster group three plate items.
std::vector<Player*> CollectEligiblePlayers(Map* map)
{
    std::vector<Player*> players;

    for (auto const& ref : map->GetPlayers())
    {
        Player* player = ref.GetSource();
        if (!player || !player->IsInWorld() || player->IsGameMaster())
            continue;

        players.push_back(player);
    }

    return players;
}
}

class MythicPlusHeroicLootScript : public MiscScript
{
public:
    MythicPlusHeroicLootScript() : MiscScript("MythicPlusHeroicLootScript",
        { MISCHOOK_ON_AFTER_LOOT_TEMPLATE_PROCESS }) { }

    void OnAfterLootTemplateProcess(Loot* loot, LootTemplate const* /*tab*/, LootStore const& store,
                                    Player* lootOwner, bool /*personal*/, bool /*noEmptyError*/,
                                    uint16 /*lootMode*/) override
    {
        // This hook fires for every loot fill on the server, so the
        // cheap structural tests come before anything that reads config
        // or takes a lock.
        if (!loot || !lootOwner || &store != &LootTemplates_Creature)
            return;

        Map* map = lootOwner->GetMap();
        if (!map || !map->IsDungeon())
            return;

        Difficulty difficulty = sMythicScaling->ResolveDungeonDifficulty(map);
        if (difficulty != DUNGEON_DIFFICULTY_HEROIC && difficulty != DUNGEON_DIFFICULTY_EPIC)
            return;

        // Only the maps that have no heroic templates of their own. WotLK
        // dungeons already fork into real ilvl 200 heroic loot tables and
        // must keep them.
        if (!sMythicScaling->UsesLegacyStatCurve(map->GetId()))
            return;

        DungeonProfile* profile = sMythicScaling->GetDungeonProfile(map->GetId());
        if (!profile)
            return;

        if (difficulty == DUNGEON_DIFFICULTY_HEROIC && !profile->heroicEnabled)
            return;
        if (difficulty == DUNGEON_DIFFICULTY_EPIC && !profile->mythicEnabled)
            return;

        // A keyed Mythic+ run delivers its own personal loot at run end
        // through GenerateBossLoot. Leave those instances alone or the
        // group is paid twice.
        if (sMythicScaling->GetKeystoneLevel(map) > 0)
            return;

        if (!HeroicLootEnabled())
            return;

        Creature* creature = map->GetCreature(loot->sourceWorldObjectGUID);
        if (!creature || creature->IsCritter() || creature->IsTrigger())
            return;

        bool isBoss = sMythicScaling->IsBossEntry(creature->GetEntry());

        // Replace, do not append. unlootedCount is rebuilt from zero
        // because at this point in FillLoot every contribution to it came
        // from the items vector we are dropping: quest items never
        // increment it, and free-for-all and conditional items are
        // counted later in FillNotNormalLootFor.
        loot->items.clear();
        loot->unlootedCount = 0;

        std::vector<Player*> players = CollectEligiblePlayers(map);

        if (isBoss)
            AwardBossLoot(loot, map, creature, profile, difficulty, players);
        else
            AwardTrashLoot(difficulty, players);
    }

private:
    void AwardTrashLoot(Difficulty difficulty, std::vector<Player*> const& players) const
    {
        uint32 chance = sConfigMgr->GetOption<uint32>("MythicPlus.HeroicLoot.TrashEssenceChance", 15);
        if (difficulty == DUNGEON_DIFFICULTY_EPIC)
            chance = sConfigMgr->GetOption<uint32>("MythicPlus.HeroicLoot.TrashEssenceChanceMythic", 25);

        if (chance == 0 || !roll_chance_i(static_cast<int32>(std::min<uint32>(chance, 100))))
            return;

        // One roll for the pull, then everyone present is paid - not a
        // roll each, which would make a five-stack group earn five times
        // the essence of a solo player for the same kill.
        for (Player* player : players)
            GiveCurrency(player, ITEM_ARTIFACT_ESSENCE, 1);
    }

    void AwardBossLoot(Loot* loot, Map* map, Creature* creature, DungeonProfile const* profile,
                       Difficulty difficulty, std::vector<Player*> const& players) const
    {
        bool isMythic = difficulty == DUNGEON_DIFFICULTY_EPIC;

        uint32 essence = sConfigMgr->GetOption<uint32>(
            isMythic ? "MythicPlus.HeroicLoot.BossEssenceMythic" : "MythicPlus.HeroicLoot.BossEssence",
            isMythic ? 3 : 2);
        uint32 tokens = sConfigMgr->GetOption<uint32>(
            isMythic ? "MythicPlus.HeroicLoot.BossTokensMythic" : "MythicPlus.HeroicLoot.BossTokens",
            isMythic ? 2 : 1);

        // Currency goes straight into each player's bags. Gear below still
        // drops into the corpse and is rolled for as group loot.
        for (Player* player : players)
        {
            GiveCurrency(player, ITEM_ARTIFACT_ESSENCE, essence);
            GiveCurrency(player, ITEM_UPGRADE_TOKEN, tokens);
        }

        uint32 itemCount = sConfigMgr->GetOption<uint32>(
            isMythic ? "MythicPlus.HeroicLoot.BossItemsMythic" : "MythicPlus.HeroicLoot.BossItems",
            2);
        if (itemCount == 0)
            return;

        // Heroic reads the dungeon's own hand-tuned loot_ilvl; plain
        // Mythic sits one tier up on the shared keystone-0 value so it
        // stays strictly better than Heroic in the same dungeon.
        uint32 targetItemLevel = isMythic
            ? MythicPlusConstants::GetItemLevelForKeystoneLevel(0)
            : MythicPlusConstants::GetHeroicItemLevel(profile->lootItemLevel);

        if (players.empty())
            return;

        // Steer each drop at a different party member where possible, so
        // both items are usable by someone actually present. Without this
        // the pool is rolled blind and a five-caster group can watch two
        // plate items drop off every boss.
        std::lock_guard<std::mutex> guard(s_instanceAwardsMutex);
        std::unordered_set<uint32>& awarded = s_instanceAwards[map->GetInstanceId()];
        size_t const awardedBefore = awarded.size();

        uint32 playerCount = static_cast<uint32>(players.size());

        for (uint32 i = 0; i < itemCount; ++i)
        {
            Player* target = players[(i + urand(0, playerCount - 1)) % playerCount];

            // Nothing this instance has already dropped, on this boss or an
            // earlier one. Excluding at selection time rather than rerolling
            // afterwards means an exhausted stage falls through to the next
            // one instead of silently paying one item short.
            uint32 itemId = 0;
            if (!sMythicRuns->SelectPooledItemForPlayer(target, targetItemLevel, itemId, &awarded))
                continue;

            if (!awarded.insert(itemId).second)
                continue;

            PushLoot(loot, itemId, 1);
        }

        LOG_DEBUG("mythic.loot",
                  "Heroic pool: {} (entry {}) on map {} difficulty {} paid {} item(s) at ilvl {}",
                  creature->GetName(), creature->GetEntry(), map->GetId(), uint32(difficulty),
                  awarded.size() - awardedBefore, targetItemLevel);
    }
};

// Drops the instance's drop ledger when the map goes away. Map::~Map fires
// this for instanced maps too, so it covers both an instance reset and a
// plain unload, and instance ids are recycled - a ledger left behind would
// suppress legitimate drops in whatever run inherits the id.
class MythicPlusHeroicLootMapScript : public AllMapScript
{
public:
    MythicPlusHeroicLootMapScript() : AllMapScript("MythicPlusHeroicLootMapScript",
        { ALLMAPHOOK_ON_DESTROY_MAP }) { }

    void OnDestroyMap(Map* map) override
    {
        if (map && map->GetInstanceId())
            ForgetInstanceAwards(map->GetInstanceId());
    }
};

void AddSC_mythic_plus_heroic_loot()
{
    new MythicPlusHeroicLootScript();
    new MythicPlusHeroicLootMapScript();
}
