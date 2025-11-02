/*
 * Copyright (C) 2016+ AzerothCore <www.azerothcore.org>
 * Released under GNU AGPL v3 License
 *
 * DarkChaos-255 Prestige Spell Scripts
 *
 * Applies configurable stat bonuses for prestige levels (800010-800019).
 */

#include "Config.h"
#include "ScriptMgr.h"
#include "SpellAuraEffects.h"
#include "SpellScript.h"

namespace
{
    // Shared aura handler that rescales the base amount using the configured bonus.
    template<uint8 PrestigeLevel>
    class PrestigeBonusAuraScript : public AuraScript
    {
        PrepareAuraScript(PrestigeBonusAuraScript);

        void CalculateAmount(AuraEffect const* /*aurEff*/, int32& amount, bool& canBeRecalculated)
        {
            canBeRecalculated = true; // allow config reloads to update active auras
            uint32 bonusPerLevel = sConfigMgr->GetOption<uint32>("Prestige.StatBonusPercent", 1);
            amount = static_cast<int32>(PrestigeLevel * bonusPerLevel);
        }

        void AdjustArmor(AuraEffect const* aurEff, bool apply)
        {
            Unit* target = GetTarget();
            if (!target || !aurEff)
                return;

            float bonusPct = static_cast<float>(aurEff->GetAmount());
            target->HandleStatModifier(UNIT_MOD_ARMOR, TOTAL_PCT, bonusPct, apply);
        }

        void HandleArmorApply(AuraEffect const* aurEff, AuraEffectHandleModes /*mode*/)
        {
            AdjustArmor(aurEff, true);
        }

        void HandleArmorRemove(AuraEffect const* aurEff, AuraEffectHandleModes /*mode*/)
        {
            AdjustArmor(aurEff, false);
        }

        void Register() override
        {
            DoEffectCalcAmount += AuraEffectCalcAmountFn(PrestigeBonusAuraScript::CalculateAmount, EFFECT_0, SPELL_AURA_MOD_TOTAL_STAT_PERCENTAGE);
            OnEffectApply += AuraEffectApplyFn(PrestigeBonusAuraScript::HandleArmorApply, EFFECT_0, SPELL_AURA_MOD_TOTAL_STAT_PERCENTAGE, AURA_EFFECT_HANDLE_REAL);
            OnEffectRemove += AuraEffectRemoveFn(PrestigeBonusAuraScript::HandleArmorRemove, EFFECT_0, SPELL_AURA_MOD_TOTAL_STAT_PERCENTAGE, AURA_EFFECT_HANDLE_REAL);
        }
    };

    template<uint8 PrestigeLevel>
    class PrestigeBonusSpellLoader : public SpellScriptLoader
    {
    public:
        explicit PrestigeBonusSpellLoader(char const* scriptName) : SpellScriptLoader(scriptName) { }

        AuraScript* GetAuraScript() const override
        {
            return new PrestigeBonusAuraScript<PrestigeLevel>();
        }
    };
}

void AddSC_dc_prestige_spells()
{
    new PrestigeBonusSpellLoader<1>("spell_prestige_bonus_1");
    new PrestigeBonusSpellLoader<2>("spell_prestige_bonus_2");
    new PrestigeBonusSpellLoader<3>("spell_prestige_bonus_3");
    new PrestigeBonusSpellLoader<4>("spell_prestige_bonus_4");
    new PrestigeBonusSpellLoader<5>("spell_prestige_bonus_5");
    new PrestigeBonusSpellLoader<6>("spell_prestige_bonus_6");
    new PrestigeBonusSpellLoader<7>("spell_prestige_bonus_7");
    new PrestigeBonusSpellLoader<8>("spell_prestige_bonus_8");
    new PrestigeBonusSpellLoader<9>("spell_prestige_bonus_9");
    new PrestigeBonusSpellLoader<10>("spell_prestige_bonus_10");
}
