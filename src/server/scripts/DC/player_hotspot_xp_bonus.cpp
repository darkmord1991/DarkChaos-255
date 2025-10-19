/*
 * DarkChaos Hotspot XP Bonus Player Script
 * 
 * Applies XP bonus to players while they have the hotspot buff aura active.
 * This script hooks into the GainXP event and multiplies XP by the configured bonus.
 */

#include "ScriptMgr.h"
#include "Player.h"
#include "Config.h"

// Forward declaration - will be available from ac_hotspots.cpp
extern uint32 GetHotspotXPBonusPercentage();
extern bool IsPlayerInHotspot(Player* player);
extern uint32 GetHotspotBuffSpellId();

class PlayerHotspotXPBonus : public PlayerScript
{
public:
    PlayerHotspotXPBonus() : PlayerScript("PlayerHotspotXPBonus") { }

    void OnGiveXP(Player* player, uint32& amount, Unit* /*victim*/) override
    {
        if (!player)
            return;

        // Check if player has the hotspot buff aura
        uint32 buffSpellId = GetHotspotBuffSpellId();
        if (!player->HasAura(buffSpellId))
            return;

        // Apply XP bonus
        uint32 bonusPercent = GetHotspotXPBonusPercentage();
        if (bonusPercent > 0)
        {
            uint32 bonus = (amount * bonusPercent) / 100;
            amount += bonus;
            
            // Optional: log for debugging
            LOG_DEBUG("scripts", "Hotspot XP Bonus: Player {} gained +{} XP ({}% of {})", 
                    player->GetName(), bonus, bonusPercent, amount - bonus);
        }
    }
};

void AddSC_PlayerHotspotXPBonus()
{
    new PlayerHotspotXPBonus();
}
