/*
 * Copyright (C) 2016+ AzerothCore <www.azerothcore.org>
 * Released under GNU AGPL v3 License
 *
 * DarkChaos-255 Prestige Spell Scripts
 * 
 * Handles prestige bonus aura spells (800002-800011)
 * Provides configurable stat bonuses for all 5 primary stats
 */

#include "ScriptMgr.h"
#include "Player.h"
#include "SpellScript.h"
#include "SpellAuraEffects.h"
#include "Config.h"

// Prestige spell IDs
enum PrestigeSpells
{
    SPELL_PRESTIGE_BONUS_1  = 800010,
    SPELL_PRESTIGE_BONUS_2  = 800011,
    SPELL_PRESTIGE_BONUS_3  = 800012,
    SPELL_PRESTIGE_BONUS_4  = 800013,
    SPELL_PRESTIGE_BONUS_5  = 800014,
    SPELL_PRESTIGE_BONUS_6  = 800015,
    SPELL_PRESTIGE_BONUS_7  = 800016,
    SPELL_PRESTIGE_BONUS_8  = 800017,
    SPELL_PRESTIGE_BONUS_9  = 800018,
    SPELL_PRESTIGE_BONUS_10 = 800019
};

// Base class for all prestige bonus spells
class PrestigeBonusSpellScript : public AuraScript
{
    PrepareAuraScript(PrestigeBonusSpellScript);

protected:
    uint32 prestigeLevel;

    // Calculate stat bonus based on prestige level and config
    int32 CalculateStatBonus() const
    {
        // Get bonus percent from config (default 1% per prestige level)
        uint32 bonusPercentPerLevel = sConfigMgr->GetOption<uint32>("Prestige.StatBonusPercent", 1);
        
        // Calculate total bonus: prestige level * bonus percent
        return static_cast<int32>(prestigeLevel * bonusPercentPerLevel);
    }

    // Apply stat bonuses to all 5 primary stats
    void HandleApply(AuraEffect const* /*aurEff*/, AuraEffectHandleModes /*mode*/)
    {
        Unit* target = GetTarget();
        if (!target || !target->ToPlayer())
            return;

        int32 bonusPercent = CalculateStatBonus();
        
        // Apply percentage bonuses to all 5 stats
        // SPELL_AURA_MOD_TOTAL_STAT_PERCENTAGE = 137
        target->HandleStatModifier(UNIT_MOD_STAT_STRENGTH, TOTAL_PCT, static_cast<float>(bonusPercent), true);
        target->HandleStatModifier(UNIT_MOD_STAT_AGILITY, TOTAL_PCT, static_cast<float>(bonusPercent), true);
        target->HandleStatModifier(UNIT_MOD_STAT_STAMINA, TOTAL_PCT, static_cast<float>(bonusPercent), true);
        target->HandleStatModifier(UNIT_MOD_STAT_INTELLECT, TOTAL_PCT, static_cast<float>(bonusPercent), true);
        target->HandleStatModifier(UNIT_MOD_STAT_SPIRIT, TOTAL_PCT, static_cast<float>(bonusPercent), true);
    }

    void HandleRemove(AuraEffect const* /*aurEff*/, AuraEffectHandleModes /*mode*/)
    {
        Unit* target = GetTarget();
        if (!target || !target->ToPlayer())
            return;

        int32 bonusPercent = CalculateStatBonus();
        
        // Remove percentage bonuses from all 5 stats
        target->HandleStatModifier(UNIT_MOD_STAT_STRENGTH, TOTAL_PCT, static_cast<float>(bonusPercent), false);
        target->HandleStatModifier(UNIT_MOD_STAT_AGILITY, TOTAL_PCT, static_cast<float>(bonusPercent), false);
        target->HandleStatModifier(UNIT_MOD_STAT_STAMINA, TOTAL_PCT, static_cast<float>(bonusPercent), false);
        target->HandleStatModifier(UNIT_MOD_STAT_INTELLECT, TOTAL_PCT, static_cast<float>(bonusPercent), false);
        target->HandleStatModifier(UNIT_MOD_STAT_SPIRIT, TOTAL_PCT, static_cast<float>(bonusPercent), false);
    }

    void Register() override
    {
        OnEffectApply += AuraEffectApplyFn(PrestigeBonusSpellScript::HandleApply, EFFECT_0, SPELL_AURA_DUMMY, AURA_EFFECT_HANDLE_REAL);
        OnEffectRemove += AuraEffectRemoveFn(PrestigeBonusSpellScript::HandleRemove, EFFECT_0, SPELL_AURA_DUMMY, AURA_EFFECT_HANDLE_REAL);
    }

public:
    PrestigeBonusSpellScript(uint32 level) : prestigeLevel(level) { }
};

// Individual spell scripts for each prestige level
class spell_prestige_bonus_1 : public AuraScript
{
    PrepareAuraScript(spell_prestige_bonus_1);

    void HandleApply(AuraEffect const* /*aurEff*/, AuraEffectHandleModes /*mode*/)
    {
        Unit* target = GetTarget();
        if (!target) return;
        
        uint32 bonusPercent = sConfigMgr->GetOption<uint32>("Prestige.StatBonusPercent", 1);
        float bonus = static_cast<float>(1 * bonusPercent);
        
        target->HandleStatModifier(UNIT_MOD_STAT_STRENGTH, TOTAL_PCT, bonus, true);
        target->HandleStatModifier(UNIT_MOD_STAT_AGILITY, TOTAL_PCT, bonus, true);
        target->HandleStatModifier(UNIT_MOD_STAT_STAMINA, TOTAL_PCT, bonus, true);
        target->HandleStatModifier(UNIT_MOD_STAT_INTELLECT, TOTAL_PCT, bonus, true);
        target->HandleStatModifier(UNIT_MOD_STAT_SPIRIT, TOTAL_PCT, bonus, true);
        
        // DEBUG: Log when aura is applied
        if (Player* player = target->ToPlayer())
        {
            ChatHandler(player->GetSession()).PSendSysMessage("|cFF00FF00Prestige Level 1 aura applied! Bonus: %d%%|r", (1 * bonusPercent));
        }
    }

    void HandleRemove(AuraEffect const* /*aurEff*/, AuraEffectHandleModes /*mode*/)
    {
        Unit* target = GetTarget();
        if (!target) return;
        
        uint32 bonusPercent = sConfigMgr->GetOption<uint32>("Prestige.StatBonusPercent", 1);
        float bonus = static_cast<float>(1 * bonusPercent);
        
        target->HandleStatModifier(UNIT_MOD_STAT_STRENGTH, TOTAL_PCT, bonus, false);
        target->HandleStatModifier(UNIT_MOD_STAT_AGILITY, TOTAL_PCT, bonus, false);
        target->HandleStatModifier(UNIT_MOD_STAT_STAMINA, TOTAL_PCT, bonus, false);
        target->HandleStatModifier(UNIT_MOD_STAT_INTELLECT, TOTAL_PCT, bonus, false);
        target->HandleStatModifier(UNIT_MOD_STAT_SPIRIT, TOTAL_PCT, bonus, false);
    }

    void Register() override
    {
        OnEffectApply += AuraEffectApplyFn(spell_prestige_bonus_1::HandleApply, EFFECT_0, SPELL_AURA_DUMMY, AURA_EFFECT_HANDLE_REAL);
        OnEffectRemove += AuraEffectRemoveFn(spell_prestige_bonus_1::HandleRemove, EFFECT_0, SPELL_AURA_DUMMY, AURA_EFFECT_HANDLE_REAL);
    }
};

// Prestige Level 2-10 scripts (using macro for brevity)
#define DEFINE_PRESTIGE_SPELL(NUM) \
class spell_prestige_bonus_##NUM : public AuraScript \
{ \
    PrepareAuraScript(spell_prestige_bonus_##NUM); \
    \
    void HandleApply(AuraEffect const* /*aurEff*/, AuraEffectHandleModes /*mode*/) \
    { \
        Unit* target = GetTarget(); \
        if (!target) return; \
        \
        uint32 bonusPercent = sConfigMgr->GetOption<uint32>("Prestige.StatBonusPercent", 1); \
        float bonus = static_cast<float>(NUM * bonusPercent); \
        \
        target->HandleStatModifier(UNIT_MOD_STAT_STRENGTH, TOTAL_PCT, bonus, true); \
        target->HandleStatModifier(UNIT_MOD_STAT_AGILITY, TOTAL_PCT, bonus, true); \
        target->HandleStatModifier(UNIT_MOD_STAT_STAMINA, TOTAL_PCT, bonus, true); \
        target->HandleStatModifier(UNIT_MOD_STAT_INTELLECT, TOTAL_PCT, bonus, true); \
        target->HandleStatModifier(UNIT_MOD_STAT_SPIRIT, TOTAL_PCT, bonus, true); \
    } \
    \
    void HandleRemove(AuraEffect const* /*aurEff*/, AuraEffectHandleModes /*mode*/) \
    { \
        Unit* target = GetTarget(); \
        if (!target) return; \
        \
        uint32 bonusPercent = sConfigMgr->GetOption<uint32>("Prestige.StatBonusPercent", 1); \
        float bonus = static_cast<float>(NUM * bonusPercent); \
        \
        target->HandleStatModifier(UNIT_MOD_STAT_STRENGTH, TOTAL_PCT, bonus, false); \
        target->HandleStatModifier(UNIT_MOD_STAT_AGILITY, TOTAL_PCT, bonus, false); \
        target->HandleStatModifier(UNIT_MOD_STAT_STAMINA, TOTAL_PCT, bonus, false); \
        target->HandleStatModifier(UNIT_MOD_STAT_INTELLECT, TOTAL_PCT, bonus, false); \
        target->HandleStatModifier(UNIT_MOD_STAT_SPIRIT, TOTAL_PCT, bonus, false); \
    } \
    \
    void Register() override \
    { \
        OnEffectApply += AuraEffectApplyFn(spell_prestige_bonus_##NUM::HandleApply, EFFECT_0, SPELL_AURA_DUMMY, AURA_EFFECT_HANDLE_REAL); \
        OnEffectRemove += AuraEffectRemoveFn(spell_prestige_bonus_##NUM::HandleRemove, EFFECT_0, SPELL_AURA_DUMMY, AURA_EFFECT_HANDLE_REAL); \
    } \
};

// Define spells for prestige levels 2-10
DEFINE_PRESTIGE_SPELL(2)
DEFINE_PRESTIGE_SPELL(3)
DEFINE_PRESTIGE_SPELL(4)
DEFINE_PRESTIGE_SPELL(5)
DEFINE_PRESTIGE_SPELL(6)
DEFINE_PRESTIGE_SPELL(7)
DEFINE_PRESTIGE_SPELL(8)
DEFINE_PRESTIGE_SPELL(9)
DEFINE_PRESTIGE_SPELL(10)

// SpellScriptLoader wrappers so the scripts can be referenced from the DB by name
class spell_prestige_bonus_1_SpellScriptLoader : public SpellScriptLoader
{
public:
    spell_prestige_bonus_1_SpellScriptLoader() : SpellScriptLoader("spell_prestige_bonus_1") {}
    AuraScript* GetAuraScript() const override { return new spell_prestige_bonus_1(); }
};

class spell_prestige_bonus_2_SpellScriptLoader : public SpellScriptLoader
{
public:
    spell_prestige_bonus_2_SpellScriptLoader() : SpellScriptLoader("spell_prestige_bonus_2") {}
    AuraScript* GetAuraScript() const override { return new spell_prestige_bonus_2(); }
};

class spell_prestige_bonus_3_SpellScriptLoader : public SpellScriptLoader
{
public:
    spell_prestige_bonus_3_SpellScriptLoader() : SpellScriptLoader("spell_prestige_bonus_3") {}
    AuraScript* GetAuraScript() const override { return new spell_prestige_bonus_3(); }
};

class spell_prestige_bonus_4_SpellScriptLoader : public SpellScriptLoader
{
public:
    spell_prestige_bonus_4_SpellScriptLoader() : SpellScriptLoader("spell_prestige_bonus_4") {}
    AuraScript* GetAuraScript() const override { return new spell_prestige_bonus_4(); }
};

class spell_prestige_bonus_5_SpellScriptLoader : public SpellScriptLoader
{
public:
    spell_prestige_bonus_5_SpellScriptLoader() : SpellScriptLoader("spell_prestige_bonus_5") {}
    AuraScript* GetAuraScript() const override { return new spell_prestige_bonus_5(); }
};

class spell_prestige_bonus_6_SpellScriptLoader : public SpellScriptLoader
{
public:
    spell_prestige_bonus_6_SpellScriptLoader() : SpellScriptLoader("spell_prestige_bonus_6") {}
    AuraScript* GetAuraScript() const override { return new spell_prestige_bonus_6(); }
};

class spell_prestige_bonus_7_SpellScriptLoader : public SpellScriptLoader
{
public:
    spell_prestige_bonus_7_SpellScriptLoader() : SpellScriptLoader("spell_prestige_bonus_7") {}
    AuraScript* GetAuraScript() const override { return new spell_prestige_bonus_7(); }
};

class spell_prestige_bonus_8_SpellScriptLoader : public SpellScriptLoader
{
public:
    spell_prestige_bonus_8_SpellScriptLoader() : SpellScriptLoader("spell_prestige_bonus_8") {}
    AuraScript* GetAuraScript() const override { return new spell_prestige_bonus_8(); }
};

class spell_prestige_bonus_9_SpellScriptLoader : public SpellScriptLoader
{
public:
    spell_prestige_bonus_9_SpellScriptLoader() : SpellScriptLoader("spell_prestige_bonus_9") {}
    AuraScript* GetAuraScript() const override { return new spell_prestige_bonus_9(); }
};

class spell_prestige_bonus_10_SpellScriptLoader : public SpellScriptLoader
{
public:
    spell_prestige_bonus_10_SpellScriptLoader() : SpellScriptLoader("spell_prestige_bonus_10") {}
    AuraScript* GetAuraScript() const override { return new spell_prestige_bonus_10(); }
};

// Register all prestige spell scripts (as SpellScriptLoader instances so DB names match)
void AddSC_dc_prestige_spells()
{
    new spell_prestige_bonus_1_SpellScriptLoader();
    new spell_prestige_bonus_2_SpellScriptLoader();
    new spell_prestige_bonus_3_SpellScriptLoader();
    new spell_prestige_bonus_4_SpellScriptLoader();
    new spell_prestige_bonus_5_SpellScriptLoader();
    new spell_prestige_bonus_6_SpellScriptLoader();
    new spell_prestige_bonus_7_SpellScriptLoader();
    new spell_prestige_bonus_8_SpellScriptLoader();
    new spell_prestige_bonus_9_SpellScriptLoader();
    new spell_prestige_bonus_10_SpellScriptLoader();
}
