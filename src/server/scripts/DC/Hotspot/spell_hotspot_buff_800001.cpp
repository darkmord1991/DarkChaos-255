/*
 * DarkChaos Hotspot XP Buff Spell Script
 *
 * Spell ID: 800001 (Custom hotspot buff)
 *
 * This is the visible aura players carry while a hotspot buff is active; it only
 * logs apply/remove. The actual XP multiplier is applied server-side in
 * HotspotMgr::OnPlayerGiveXP (which checks HasAura(800001)), not here.
 */

#include "ScriptMgr.h"
#include "Player.h"
#include "SpellScript.h"
#include "SpellAuraEffects.h"
#include "Config.h"

// Aura Effect Script: Handle the XP bonus application
class spell_hotspot_buff_800001_aura : public AuraScript
{
    PrepareAuraScript(spell_hotspot_buff_800001_aura);

    void OnApply(AuraEffect const* /*aurEff*/, AuraEffectHandleModes /*mode*/)
    {
        Player* player = GetTarget()->ToPlayer();
        if (player)
        {
            LOG_DEBUG("scripts.spell", "Hotspot XP Buff (800001) applied to player {}", player->GetName());
        }
    }

    void OnRemove(AuraEffect const* /*aurEff*/, AuraEffectHandleModes /*mode*/)
    {
        Player* player = GetTarget()->ToPlayer();
        if (player)
        {
            LOG_DEBUG("scripts.spell", "Hotspot XP Buff (800001) removed from player {}", player->GetName());
        }
    }

    void Register() override
    {
        // Be tolerant to DBC differences: bind to any aura/effect so the handler executes.
        OnEffectApply += AuraEffectApplyFn(spell_hotspot_buff_800001_aura::OnApply, EFFECT_ALL, SPELL_AURA_ANY, AURA_EFFECT_HANDLE_REAL);
        OnEffectRemove += AuraEffectRemoveFn(spell_hotspot_buff_800001_aura::OnRemove, EFFECT_ALL, SPELL_AURA_ANY, AURA_EFFECT_HANDLE_REAL);
    }
};

// Registration function
void AddSC_spell_hotspot_buff_800001()
{
    RegisterSpellScript(spell_hotspot_buff_800001_aura);
}
