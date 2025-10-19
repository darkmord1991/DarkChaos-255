/*
 * DarkChaos Hotspot XP Buff Spell Script
 * 
 * Spell ID: 800001 (Custom hotspot buff)
 * 
 * This spell script handles the XP bonus for players inside hotspots.
 * When the aura is active, all experience gained is multiplied by the hotspot XP bonus percentage.
 */

#include "ScriptMgr.h"
#include "Player.h"
#include "SpellScript.h"
#include "SpellAuraEffects.h"
#include "Config.h"

// Forward declarations - these are defined in ac_hotspots.cpp
extern uint32 GetHotspotXPBonusPercentage();
extern uint32 GetHotspotBuffSpellId();

// Spell Script: Apply XP multiplier while aura is active
class spell_hotspot_buff_800001 : public SpellScript
{
    PrepareSpellScript(spell_hotspot_buff_800001);

    void Register() override
    {
        // This spell script doesn't modify the spell cast itself,
        // instead we use the Aura Effect script below
    }
};

// Aura Effect Script: Handle the XP bonus application
class spell_hotspot_buff_800001_aura : public AuraScript
{
    PrepareAuraScript(spell_hotspot_buff_800001_aura);

    void OnApply(AuraEffect const* /*aurEff*/, AuraEffectHandleModes /*mode*/)
    {
        Player* player = GetTarget()->ToPlayer();
        if (player)
        {
            LOG_DEBUG("scripts.spell", "Hotspot XP Buff (800001) applied to player {}",
                    player->GetName());
        }
    }

    void OnRemove(AuraEffect const* /*aurEff*/, AuraEffectHandleModes /*mode*/)
    {
        Player* player = GetTarget()->ToPlayer();
        if (player)
        {
            LOG_DEBUG("scripts.spell", "Hotspot XP Buff (800001) removed from player {}",
                    player->GetName());
        }
    }

    void Register() override
    {
        OnEffectApply += AuraEffectApplyFn(spell_hotspot_buff_800001_aura::OnApply, 0, SPELL_AURA_DUMMY, AURA_EFFECT_HANDLE_REAL);
        OnEffectRemove += AuraEffectRemoveFn(spell_hotspot_buff_800001_aura::OnRemove, 0, SPELL_AURA_DUMMY, AURA_EFFECT_HANDLE_REAL);
    }
};

// Register the scripts
void AddSC_spell_hotspot_buff_800001()
{
    RegisterSpellScript(spell_hotspot_buff_800001);
    RegisterAuraScript(spell_hotspot_buff_800001_aura);
}
