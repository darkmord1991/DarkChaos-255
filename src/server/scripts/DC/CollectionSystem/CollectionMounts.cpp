/*
 * CollectionMounts.cpp - DarkChaos Collection System Mounts Module
 *
 * Handles mount detection, speed bonuses, and mount summoning.
 * Part of the split collection system implementation.
 */

#include "CollectionCore.h"
#include "SpellAuras.h"

namespace DCCollection
{
    // =======================================================================
    // Mount Detection
    // =======================================================================

    uint32 FindMountItemIdForSpell(uint32 spellId)
    {
        QueryResult r = WorldDatabase.Query(
            "SELECT MIN(entry) FROM item_template "
            "WHERE class = 15 AND subclass = 5 AND ("
            "  spellid_1 = {} OR spellid_2 = {} OR spellid_3 = {} OR spellid_4 = {} OR spellid_5 = {}"
            ")",
            spellId, spellId, spellId, spellId, spellId);

        if (!r)
            return 0;

        Field* f = r->Fetch();
        if (f[0].IsNull())
            return 0;
        return f[0].Get<uint32>();
    }

    bool IsMountSpell(SpellInfo const* spellInfo)
    {
        if (!spellInfo)
            return false;

        for (uint8 i = 0; i < MAX_SPELL_EFFECTS; ++i)
        {
            if (spellInfo->Effects[i].Effect == SPELL_EFFECT_APPLY_AURA &&
                (spellInfo->Effects[i].ApplyAuraName == SPELL_AURA_MOUNTED ||
                 spellInfo->Effects[i].ApplyAuraName == SPELL_AURA_MOD_INCREASE_MOUNTED_FLIGHT_SPEED))
            {
                return true;
            }
        }
        return false;
    }

    // =======================================================================
    // Mount Speed Bonuses
    // =======================================================================

    void UpdateMountSpeedBonuses(Player* player)
    {
        if (!player)
            return;

        if (!sConfigMgr->GetOption<bool>(Config::MOUNT_BONUSES_ENABLED, true))
            return;

        // Count collected mounts from account
        uint32 accountId = player->GetSession() ? player->GetSession()->GetAccountId() : 0;
        if (!accountId)
            return;

        uint32 mountCount = 0;
        QueryResult r = CharacterDatabase.Query(
            "SELECT COUNT(*) FROM dc_collection_items "
            "WHERE account_id = {} AND collection_type = {} AND unlocked = 1",
            accountId, static_cast<uint8>(CollectionType::MOUNT));

        if (r)
            mountCount = r->Fetch()[0].Get<uint32>();

        // Remove all existing mount speed bonuses
        player->RemoveAura(SPELL_MOUNT_SPEED_TIER1);
        player->RemoveAura(SPELL_MOUNT_SPEED_TIER2);
        player->RemoveAura(SPELL_MOUNT_SPEED_TIER3);
        player->RemoveAura(SPELL_MOUNT_SPEED_TIER4);

        // Apply appropriate tier
        if (mountCount >= MOUNT_THRESHOLD_TIER4)
            player->CastSpell(player, SPELL_MOUNT_SPEED_TIER4, true);
        else if (mountCount >= MOUNT_THRESHOLD_TIER3)
            player->CastSpell(player, SPELL_MOUNT_SPEED_TIER3, true);
        else if (mountCount >= MOUNT_THRESHOLD_TIER2)
            player->CastSpell(player, SPELL_MOUNT_SPEED_TIER2, true);
        else if (mountCount >= MOUNT_THRESHOLD_TIER1)
            player->CastSpell(player, SPELL_MOUNT_SPEED_TIER1, true);
    }

    // =======================================================================
    // Mount Summoning
    // =======================================================================

    void HandleSummonMount(Player* player, uint32 spellId, bool random)
    {
        if (!player)
            return;

        if (random)
        {
            // Get random mount from collection
            uint32 accountId = player->GetSession() ? player->GetSession()->GetAccountId() : 0;
            if (!accountId)
                return;

            std::string const& entryCol = GetCharEntryColumn("dc_collection_items");
            if (entryCol.empty())
                return;

            QueryResult r = CharacterDatabase.Query(
                "SELECT {} FROM dc_collection_items "
                "WHERE account_id = {} AND collection_type = {} AND unlocked = 1 "
                "ORDER BY RAND() LIMIT 1",
                entryCol, accountId, static_cast<uint8>(CollectionType::MOUNT));

            if (!r)
            {
                ChatHandler(player->GetSession()).PSendSysMessage("You have no mounts in your collection.");
                return;
            }

            spellId = r->Fetch()[0].Get<uint32>();
        }

        if (!spellId)
            return;

        SpellInfo const* spellInfo = sSpellMgr->GetSpellInfo(spellId);
        if (!spellInfo)
        {
            ChatHandler(player->GetSession()).PSendSysMessage("Invalid mount spell.");
            return;
        }

        // Dismount first if already mounted
        if (player->IsMounted())
            player->Dismount();

        player->CastSpell(player, spellId, true);
    }

}  // namespace DCCollection
