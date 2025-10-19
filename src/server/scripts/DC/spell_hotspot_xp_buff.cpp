/*
 * DarkChaos Hotspot XP Buff Spell Script
 * 
 * Custom spell script that applies XP bonus when a player is in a hotspot.
 * This script modifies XP gained from kills while the hotspot buff is active.
 */

#include "ScriptMgr.h"
#include "Player.h"
#include "SpellScript.h"
#include "Config.h"

// Reference to hotspots config for XP bonus percentage
extern uint32 GetHotspotXPBonus(); // To be defined in ac_hotspots.cpp

class spell_hotspot_xp_buff : public SpellScript
{
    PrepareSpellScript(spell_hotspot_xp_buff);

    void Register() override
    {
        // This spell script doesn't modify the spell itself; instead,
        // it serves as a marker aura that the GainXP hook checks for.
        // The actual XP bonus is applied in the Player::GainXP overload.
    }
};

// Register the spell script
void AddSC_spell_hotspot_xp_buff()
{
    new spell_hotspot_xp_buff();
}
