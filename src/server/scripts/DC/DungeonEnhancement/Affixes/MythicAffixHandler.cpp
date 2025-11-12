/*
 * ============================================================================
 * Dungeon Enhancement System - Affix Handler Base Class Implementation
 * ============================================================================
 * Purpose: Base class implementation for all affix handlers
 * Location: src/server/scripts/DC/DungeonEnhancement/Affixes/
 * ============================================================================
 */

#include "MythicAffixHandler.h"
#include "DungeonEnhancementManager.h"
#include "Creature.h"
#include "Player.h"
#include "SpellInfo.h"
#include "SpellAuras.h"
#include "Map.h"
#include "GridNotifiers.h"
#include "GridNotifiersImpl.h"
#include "CellImpl.h"

namespace DungeonEnhancement
{
    // ========================================================================
    // HELPER METHODS
    // ========================================================================

    bool MythicAffixHandler::ShouldAffectCreature(Creature* creature) const
    {
        if (!creature || !_affixData)
            return false;

        // Check if creature is in a Mythic+ dungeon
        Map* map = creature->GetMap();
        if (!map || !map->IsDungeon())
            return false;

        // Check affix type
        if (_affixData->affixType == "Boss")
            return IsBoss(creature);
        else if (_affixData->affixType == "Trash")
            return IsTrash(creature);
        else if (_affixData->affixType == "Environmental" || _affixData->affixType == "Debuff")
            return false;  // These affect players, not creatures

        return true;  // Default: affect all creatures
    }

    bool MythicAffixHandler::IsBossOnlyAffix() const
    {
        return _affixData && _affixData->affixType == "Boss";
    }

    bool MythicAffixHandler::IsTrashOnlyAffix() const
    {
        return _affixData && _affixData->affixType == "Trash";
    }

    std::string MythicAffixHandler::GetAffixName() const
    {
        return _affixData ? _affixData->affixName : "";
    }

    std::string MythicAffixHandler::GetAffixDescription() const
    {
        return _affixData ? _affixData->description : "";
    }

    std::string MythicAffixHandler::GetAffixType() const
    {
        return _affixData ? _affixData->affixType : "";
    }

    uint8 MythicAffixHandler::GetMinKeystoneLevel() const
    {
        return _affixData ? _affixData->minKeystoneLevel : 0;
    }

    uint32 MythicAffixHandler::GetAffixSpellId() const
    {
        return _affixData ? _affixData->spellId : 0;
    }

    bool MythicAffixHandler::ApplyAffixAura(Unit* target) const
    {
        if (!target || !_affixData || _affixData->spellId == 0)
            return false;

        // Check if target already has the aura
        if (target->HasAura(_affixData->spellId))
            return false;

        // Apply the aura
        target->AddAura(_affixData->spellId, target);
        return true;
    }

    void MythicAffixHandler::RemoveAffixAura(Unit* target) const
    {
        if (!target || !_affixData || _affixData->spellId == 0)
            return;

        target->RemoveAurasDueToSpell(_affixData->spellId);
    }

    // ========================================================================
    // UTILITY METHODS
    // ========================================================================

    bool MythicAffixHandler::IsBoss(Creature* creature) const
    {
        if (!creature)
            return false;

        CreatureTemplate const* cInfo = creature->GetCreatureTemplate();
        if (!cInfo)
            return false;

        return (cInfo->rank == CREATURE_ELITE_WORLDBOSS || 
                cInfo->rank == CREATURE_ELITE_RARE);
    }

    bool MythicAffixHandler::IsTrash(Creature* creature) const
    {
        return creature && !IsBoss(creature);
    }

    std::list<Creature*> MythicAffixHandler::GetNearbyFriendlyCreatures(Creature* creature, float range) const
    {
        std::list<Creature*> creatures;
        
        if (!creature)
            return creatures;

        Trinity::AllCreaturesOfEntryInRange check(creature, 0, range);
        Trinity::CreatureListSearcher<Trinity::AllCreaturesOfEntryInRange> searcher(creature, creatures, check);
        Cell::VisitGridObjects(creature, searcher, range);

        // Filter to only friendly creatures
        creatures.remove_if([creature](Creature* c) {
            return !creature->IsFriendlyTo(c);
        });

        return creatures;
    }

    std::list<Player*> MythicAffixHandler::GetNearbyEnemyPlayers(Creature* creature, float range) const
    {
        std::list<Player*> players;
        
        if (!creature)
            return players;

        Trinity::AnyPlayerInObjectRangeCheck check(creature, range);
        Trinity::PlayerListSearcher<Trinity::AnyPlayerInObjectRangeCheck> searcher(creature, players, check);
        Cell::VisitWorldObjects(creature, searcher, range);

        // Filter to only enemy players
        players.remove_if([creature](Player* p) {
            return !creature->IsHostileTo(p);
        });

        return players;
    }

    void MythicAffixHandler::BroadcastToInstance(Creature* creature, const std::string& message, uint32 color) const
    {
        if (!creature)
            return;

        Map* map = creature->GetMap();
        if (!map || !map->IsDungeon())
            return;

        // Broadcast to all players in the instance
        Map::PlayerList const& players = map->GetPlayers();
        for (auto itr = players.begin(); itr != players.end(); ++itr)
        {
            Player* player = itr->GetSource();
            if (player)
            {
                ChatHandler(player->GetSession()).PSendSysMessage("%s", message.c_str());
            }
        }
    }

} // namespace DungeonEnhancement
