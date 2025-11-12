/*
 * ============================================================================
 * Dungeon Enhancement System - Grievous Affix
 * ============================================================================
 * Tier: 3 (M+7)
 * Type: Debuff
 * Effect: Players below 90% HP suffer stacking damage over time until healed above 90%
 * ============================================================================
 */

#include "MythicAffixHandler.h"
#include "Creature.h"
#include "Player.h"
#include "Map.h"
#include "SpellAuras.h"

using namespace DungeonEnhancement;

// Grievous Wound debuff spell ID (would need to be created in spell_dbc)
#define GRIEVOUS_WOUND_SPELL_ID 800012

class Affix_Grievous : public MythicAffixHandler
{
private:
    uint32 _lastTickTime = 0;
    const uint32 GRIEVOUS_TICK_INTERVAL = 3000; // Check every 3 seconds

public:
    Affix_Grievous(AffixData* affixData) : MythicAffixHandler(affixData) {}

    // ========================================================================
    // Periodic tick: Apply/stack Grievous to players below 90% HP
    // ========================================================================
    void OnPeriodicTick(Map* map) override
    {
        if (!map)
            return;

        uint32 currentTime = GameTime::GetGameTimeMS();
        if (currentTime - _lastTickTime < GRIEVOUS_TICK_INTERVAL)
            return;

        _lastTickTime = currentTime;

        // Get all players in the instance
        Map::PlayerList const& players = map->GetPlayers();
        if (players.isEmpty())
            return;

        for (Map::PlayerList::const_iterator itr = players.begin(); itr != players.end(); ++itr)
        {
            Player* player = itr->GetSource();
            if (!player || !player->IsAlive())
                continue;

            // Check if player is below 90% HP
            float healthPct = (static_cast<float>(player->GetHealth()) / static_cast<float>(player->GetMaxHealth())) * 100.0f;

            if (healthPct < 90.0f)
            {
                ApplyGrievousWound(player);
            }
            else
            {
                RemoveGrievousWound(player);
            }
        }
    }

    // ========================================================================
    // Apply or stack Grievous Wound debuff
    // ========================================================================
    void ApplyGrievousWound(Player* player)
    {
        if (!player)
            return;

        // Check if player already has Grievous Wound
        Aura* grievousAura = player->GetAura(GRIEVOUS_WOUND_SPELL_ID);

        if (grievousAura)
        {
            // Stack existing aura (up to 10 stacks)
            uint8 currentStacks = grievousAura->GetStackAmount();
            if (currentStacks < 10)
            {
                grievousAura->SetStackAmount(currentStacks + 1);
                
                LOG_DEBUG("dungeon.enhancement.affixes",
                          "Grievous Wound stacks increased to {} on player {}",
                          currentStacks + 1, player->GetName());
            }
        }
        else
        {
            // Apply new Grievous Wound (1 stack)
            // Note: This requires the spell to exist in spell_dbc with:
            // - Periodic damage (e.g., 2% max HP per stack per tick)
            // - Removed when player reaches >90% HP
            
            if (_affixData && _affixData->spellId > 0)
            {
                player->CastSpell(player, _affixData->spellId, true);
                
                LOG_DEBUG("dungeon.enhancement.affixes",
                          "Applied Grievous Wound (1 stack) to player {}",
                          player->GetName());
            }
        }
    }

    // ========================================================================
    // Remove Grievous Wound when player reaches >90% HP
    // ========================================================================
    void RemoveGrievousWound(Player* player)
    {
        if (!player)
            return;

        Aura* grievousAura = player->GetAura(GRIEVOUS_WOUND_SPELL_ID);
        if (grievousAura)
        {
            player->RemoveAura(GRIEVOUS_WOUND_SPELL_ID);
            
            LOG_DEBUG("dungeon.enhancement.affixes",
                      "Removed Grievous Wound from player {} (healed above 90%)",
                      player->GetName());
        }
    }
};

// Factory function
MythicAffixHandler* CreateGrievousHandler(AffixData* data)
{
    return new Affix_Grievous(data);
}
