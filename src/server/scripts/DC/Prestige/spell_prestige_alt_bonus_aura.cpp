/*
 * Copyright (C) 2016+ AzerothCore <www.azerothcore.org>
 * Released under GNU AGPL v3 License
 *
 * DarkChaos-255 Alt Bonus Visual Aura
 *
 * Provides a visible buff showing the XP bonus from account alts
 * Spell IDs: 800040-800044 (5%, 10%, 15%, 20%, 25%)
 */

#include "ScriptMgr.h"
#include "SpellAuraEffects.h"
#include "SpellScript.h"

namespace
{
    // Alt Bonus Aura Spell IDs (must match DBC entries)
    // Note: These spell IDs are used by the system but not directly referenced in this aura script
    // constexpr uint32 SPELL_ALT_BONUS_5  = 800020;  // 5% bonus (1 max-level char)
    // constexpr uint32 SPELL_ALT_BONUS_10 = 800021;  // 10% bonus (2 max-level chars)
    // constexpr uint32 SPELL_ALT_BONUS_15 = 800022;  // 15% bonus (3 max-level chars)
    // constexpr uint32 SPELL_ALT_BONUS_20 = 800023;  // 20% bonus (4 max-level chars)
    // constexpr uint32 SPELL_ALT_BONUS_25 = 800024;  // 25% bonus (5+ max-level chars)
    
    // Base aura script for all alt bonus spells
    template<uint8 BonusPercent>
    class AltBonusAuraScript : public AuraScript
    {
        PrepareAuraScript(AltBonusAuraScript);
        
        void HandleApply(AuraEffect const* /*aurEff*/, AuraEffectHandleModes /*mode*/)
        {
            // Aura is purely visual - actual XP bonus is handled in dc_prestige_alt_bonus.cpp
            // This just shows players they have the bonus active
        }
        
        void Register() override
        {
            OnEffectApply += AuraEffectApplyFn(AltBonusAuraScript::HandleApply, EFFECT_0, SPELL_AURA_DUMMY, AURA_EFFECT_HANDLE_REAL);
        }
    };
    
    // Spell loaders for each bonus tier
    template<uint8 BonusPercent>
    class AltBonusSpellLoader : public SpellScriptLoader
    {
    public:
        explicit AltBonusSpellLoader(char const* scriptName) : SpellScriptLoader(scriptName) { }
        
        AuraScript* GetAuraScript() const override
        {
            return new AltBonusAuraScript<BonusPercent>();
        }
    };
}

void AddSC_spell_prestige_alt_bonus_aura()
{
    new AltBonusSpellLoader<5>("spell_alt_bonus_5");
    new AltBonusSpellLoader<10>("spell_alt_bonus_10");
    new AltBonusSpellLoader<15>("spell_alt_bonus_15");
    new AltBonusSpellLoader<20>("spell_alt_bonus_20");
    new AltBonusSpellLoader<25>("spell_alt_bonus_25");
}
