/*
 * CollectionPets.cpp - DarkChaos Collection System Pets Module
 *
 * Handles companion pet detection, spell resolution, and definitions.
 * Part of the split collection system implementation.
 */

#include "CollectionCore.h"
#include "DBCStores.h"
#include "SpellAuras.h"
#include "Pet.h"

namespace DCCollection
{
    // =======================================================================
    // Companion Pet Detection
    // =======================================================================

    bool IsCompanionSpell(SpellInfo const* spellInfo)
    {
        if (!spellInfo)
            return false;

        for (uint8 i = 0; i < MAX_SPELL_EFFECTS; ++i)
        {
            if (spellInfo->Effects[i].Effect != SPELL_EFFECT_SUMMON &&
                spellInfo->Effects[i].Effect != SPELL_EFFECT_SUMMON_PET)
                continue;

            SummonPropertiesEntry const* properties = sSummonPropertiesStore.LookupEntry(spellInfo->Effects[i].MiscValueB);
            if (properties && properties->Type == SUMMON_TYPE_MINIPET)
                return true;
        }
        return false;
    }

    uint32 ResolveCompanionSummonSpellFromSpell(uint32 spellId)
    {
        if (!spellId)
            return 0;

        SpellInfo const* spellInfo = sSpellMgr->GetSpellInfo(spellId);
        if (!spellInfo)
            return 0;

        if (IsCompanionSpell(spellInfo))
            return spellId;

        // Teaching spells: follow LEARN_* effects to the taught summon spell.
        for (uint8 eff = 0; eff < MAX_SPELL_EFFECTS; ++eff)
        {
            if (spellInfo->Effects[eff].Effect != SPELL_EFFECT_LEARN_SPELL &&
                spellInfo->Effects[eff].Effect != SPELL_EFFECT_LEARN_PET_SPELL)
                continue;

            uint32 taughtSpellId = spellInfo->Effects[eff].TriggerSpell;
            if (!taughtSpellId)
                continue;

            if (SpellInfo const* taughtInfo = sSpellMgr->GetSpellInfo(taughtSpellId))
            {
                if (IsCompanionSpell(taughtInfo))
                    return taughtSpellId;
            }
        }

        return 0;
    }

    // =======================================================================
    // Pet Item/Spell Lookups
    // =======================================================================

    uint32 FindCompanionItemIdForSpell(uint32 spellId)
    {
        QueryResult r = WorldDatabase.Query(
            "SELECT MIN(entry) FROM item_template "
            "WHERE class = 15 AND subclass = 2 AND ("
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

    uint32 FindCompanionSpellIdForItem(uint32 itemId)
    {
        if (!itemId)
            return 0;

        ItemTemplate const* proto = sObjectMgr->GetItemTemplate(itemId);
        if (!proto)
            return 0;

        // Prefer an item spell that is itself the summon spell.
        for (uint8 i = 0; i < MAX_ITEM_PROTO_SPELLS; ++i)
        {
            uint32 spellId = proto->Spells[i].SpellId;
            if (!spellId)
                continue;

            SpellInfo const* spellInfo = sSpellMgr->GetSpellInfo(spellId);
            if (IsCompanionSpell(spellInfo))
                return spellId;

            // Many companion "teaching" items cast a spell that teaches the real summon spell.
            if (spellInfo)
            {
                for (uint8 eff = 0; eff < MAX_SPELL_EFFECTS; ++eff)
                {
                    if (spellInfo->Effects[eff].Effect != SPELL_EFFECT_LEARN_SPELL &&
                        spellInfo->Effects[eff].Effect != SPELL_EFFECT_LEARN_PET_SPELL)
                        continue;

                    uint32 taughtSpellId = spellInfo->Effects[eff].TriggerSpell;
                    if (!taughtSpellId)
                        continue;

                    if (SpellInfo const* taughtInfo = sSpellMgr->GetSpellInfo(taughtSpellId))
                    {
                        if (IsCompanionSpell(taughtInfo))
                            return taughtSpellId;
                    }
                }
            }
        }

        // Fallback for explicit companion items
        if (proto->Class == 15 && proto->SubClass == 2)
        {
            for (uint8 i = 0; i < MAX_ITEM_PROTO_SPELLS; ++i)
            {
                uint32 spellId = proto->Spells[i].SpellId;
                if (!spellId)
                    continue;

                if (uint32 resolved = ResolveCompanionSummonSpellFromSpell(spellId))
                    return resolved;
            }
        }

        return 0;
    }

    // =======================================================================
    // Pet Definitions Rebuild
    // =======================================================================

    void RebuildPetDefinitionsFromLocalData()
    {
        if (!WorldTableExists("dc_pet_definitions"))
        {
            LOG_WARN("module.dc", "DC-Collection: dc_pet_definitions missing; skipping pet definition rebuild.");
            return;
        }

        bool truncate = sConfigMgr->GetOption<bool>(Config::PETS_REBUILD_ON_STARTUP_TRUNCATE, false);
        if (truncate)
        {
            WorldDatabase.Execute("TRUNCATE TABLE dc_pet_definitions");
        }

        uint32 insertedOrUpdated = 0;
        uint32 skippedNoSpell = 0;

        auto rebuildFromItemId = [&](uint32 itemId)
        {
            if (!itemId)
                return;

            ItemTemplate const* itemTemplate = sObjectMgr->GetItemTemplate(itemId);
            if (!itemTemplate)
                return;

            if (itemTemplate->Class != 15 || itemTemplate->SubClass != 2)
                return;

            uint32 summonSpellId = FindCompanionSpellIdForItem(itemId);
            if (!summonSpellId)
            {
                ++skippedNoSpell;
                return;
            }

            uint32 creatureId = 0;
            uint32 displayId = 0;
            if (SpellInfo const* spellInfo = sSpellMgr->GetSpellInfo(summonSpellId))
            {
                for (uint8 i = 0; i < MAX_SPELL_EFFECTS; ++i)
                {
                    if (spellInfo->Effects[i].Effect != SPELL_EFFECT_SUMMON &&
                        spellInfo->Effects[i].Effect != SPELL_EFFECT_SUMMON_PET)
                        continue;

                    SummonPropertiesEntry const* properties = sSummonPropertiesStore.LookupEntry(spellInfo->Effects[i].MiscValueB);
                    if (!properties || properties->Type != SUMMON_TYPE_MINIPET)
                        continue;

                    creatureId = spellInfo->Effects[i].MiscValue;
                    break;
                }
            }

            if (creatureId)
            {
                if (CreatureTemplate const* cInfo = sObjectMgr->GetCreatureTemplate(creatureId))
                {
                    if (CreatureModel const* m = cInfo->GetFirstValidModel())
                        displayId = m->CreatureDisplayID;
                }
            }

            std::string name = itemTemplate->Name1;
            WorldDatabase.EscapeString(name);

            uint32 rarity = std::min<uint32>(itemTemplate->Quality, 4u);

            WorldDatabase.Execute(
                "INSERT INTO dc_pet_definitions (pet_entry, name, pet_type, pet_spell_id, rarity, display_id) "
                "VALUES ({}, '{}', 'companion', {}, {}, {}) "
                "ON DUPLICATE KEY UPDATE name = VALUES(name), pet_type = VALUES(pet_type), pet_spell_id = VALUES(pet_spell_id), rarity = VALUES(rarity), display_id = VALUES(display_id)",
                itemId, name, summonSpellId, rarity, displayId);

            ++insertedOrUpdated;
        };

        // Pull item list from DB
        QueryResult r = WorldDatabase.Query(
            "SELECT entry FROM item_template WHERE class = 15 AND subclass = 2");

        if (r)
        {
            do
            {
                uint32 itemId = r->Fetch()[0].Get<uint32>();
                rebuildFromItemId(itemId);
            } while (r->NextRow());
        }

        LOG_INFO("module.dc", "DC-Collection: Pet definition rebuild complete ({} rows inserted/updated, {} skipped).",
            insertedOrUpdated, skippedNoSpell);
    }

}  // namespace DCCollection
