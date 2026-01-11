/*
 * Copyright (C) 2016+ AzerothCore <www.azerothcore.org>
 * Released under GNU AGPL v3 License
 *
 * DarkChaos-255 Prestige Spell Scripts
 *
 * Applies configurable stat bonuses for prestige levels (800010-800019).
 *
 * SPELL_AURA_MOD_TOTAL_STAT_PERCENTAGE automatically handles all stats including armor,
 * so no manual HandleStatModifier() calls are needed.
 */

#include "Config.h"
#include "Log.h"
#include "ScriptMgr.h"
#include "SpellAuraEffects.h"
#include "SpellScript.h"

namespace
{
    // Cache the stat bonus percentage to avoid reading config on every aura calculation
    uint32 g_CachedStatBonusPercent = 0;

    // Shared aura handler that rescales the base amount using the configured bonus.
    template<uint8 PrestigeLevel>
    class PrestigeBonusAuraScript : public AuraScript
    {
        PrepareAuraScript(PrestigeBonusAuraScript);

        void CalculateAmount(AuraEffect const* /*aurEff*/, int32& amount, bool& canBeRecalculated)
        {
            canBeRecalculated = true; // allow config reloads to update active auras
            amount = static_cast<int32>(PrestigeLevel * g_CachedStatBonusPercent);
        }

        void Register() override
        {
            // Be tolerant to DBC differences: bind to any aura/effect so the handler executes.
            DoEffectCalcAmount += AuraEffectCalcAmountFn(PrestigeBonusAuraScript::CalculateAmount, EFFECT_ALL, SPELL_AURA_ANY);
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

    // WorldScript to cache config value on startup and config reload
    class PrestigeSpellConfigScript : public WorldScript
    {
    public:
        PrestigeSpellConfigScript() : WorldScript("PrestigeSpellConfigScript") { }

        void OnStartup() override
        {
            CacheConfig();
        }

        void OnAfterConfigLoad(bool /*reload*/) override
        {
            CacheConfig();
        }

    private:
        void CacheConfig()
        {
            g_CachedStatBonusPercent = sConfigMgr->GetOption<uint32>("Prestige.StatBonusPercent", 1);
            LOG_INFO("scripts.dc", "Prestige Spells: Cached StatBonusPercent = {}%", g_CachedStatBonusPercent);
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
    new PrestigeSpellConfigScript();
}
