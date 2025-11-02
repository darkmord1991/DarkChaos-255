/*
 * Copyright (C) 2016+ AzerothCore <www.azerothcore.org>
 * Released under GNU AGPL v3 License
 *
 * DarkChaos-255 Challenge Mode Aura Scripts
 * 
 * Spell IDs: 800020-800028 (Challenge Mode Markers)
 * 
 * These are DUMMY marker auras that display which challenge mode(s)
 * a player has active. They have no mechanical effect - the actual
 * challenge mode effects are handled in dc_challenge_modes.cpp
 * 
 * These auras are purely visual, shown in the buff bar to identify
 * which challenge mode(s) are active for the player.
 */

#include "ScriptMgr.h"
#include "Player.h"
#include "SpellScript.h"
#include "SpellAuraEffects.h"
#include "Config.h"

// Base class for all challenge mode auras
class ChallengeModeDummyAura : public AuraScript
{
    PrepareAuraScript(ChallengeModeDummyAura);

protected:
    virtual const char* GetModeName() const = 0;

    void OnApply(AuraEffect const* /*aurEff*/, AuraEffectHandleModes /*mode*/)
    {
        Player* player = GetTarget()->ToPlayer();
        if (!player)
            return;

        LOG_INFO("scripts.challengemode", "Challenge Mode aura applied: {} - Player: {}", 
            GetModeName(), player->GetName());
    }

    void OnRemove(AuraEffect const* /*aurEff*/, AuraEffectHandleModes /*mode*/)
    {
        Player* player = GetTarget()->ToPlayer();
        if (!player)
            return;

        LOG_INFO("scripts.challengemode", "Challenge Mode aura removed: {} - Player: {}", 
            GetModeName(), player->GetName());
    }

    void Register() override
    {
        OnEffectApply += AuraEffectApplyFn(ChallengeModeDummyAura::OnApply, 0, SPELL_AURA_DUMMY, AURA_EFFECT_HANDLE_REAL);
        OnEffectRemove += AuraEffectRemoveFn(ChallengeModeDummyAura::OnRemove, 0, SPELL_AURA_DUMMY, AURA_EFFECT_HANDLE_REAL);
    }
};

// Spell 800020: Hardcore Mode
class spell_challenge_hardcore_800020 : public ChallengeModeDummyAura
{
    PrepareAuraScript(spell_challenge_hardcore_800020);

protected:
    const char* GetModeName() const override { return "Hardcore Mode (One Death and You Die)"; }
};

// Spell 800021: Semi-Hardcore Mode
class spell_challenge_semi_hardcore_800021 : public ChallengeModeDummyAura
{
    PrepareAuraScript(spell_challenge_semi_hardcore_800021);

protected:
    const char* GetModeName() const override { return "Semi-Hardcore Mode (Multiple Lives Allowed)"; }
};

// Spell 800022: Self-Crafted Only
class spell_challenge_self_crafted_800022 : public ChallengeModeDummyAura
{
    PrepareAuraScript(spell_challenge_self_crafted_800022);

protected:
    const char* GetModeName() const override { return "Self-Crafted Mode (You Must Craft Your Own Gear)"; }
};

// Spell 800023: Item Quality Level Restriction
class spell_challenge_item_quality_800023 : public ChallengeModeDummyAura
{
    PrepareAuraScript(spell_challenge_item_quality_800023);

protected:
    const char* GetModeName() const override { return "Item Quality Restriction (Limited to Green or Better)"; }
};

// Spell 800024: Slow XP Gain
class spell_challenge_slow_xp_800024 : public ChallengeModeDummyAura
{
    PrepareAuraScript(spell_challenge_slow_xp_800024);

protected:
    const char* GetModeName() const override { return "Slow XP Mode (Reduced Experience Gain)"; }
};

// Spell 800025: Very Slow XP Gain
class spell_challenge_very_slow_xp_800025 : public ChallengeModeDummyAura
{
    PrepareAuraScript(spell_challenge_very_slow_xp_800025);

protected:
    const char* GetModeName() const override { return "Very Slow XP Mode (Minimal Experience Gain)"; }
};

// Spell 800026: Quest XP Only
class spell_challenge_quest_xp_only_800026 : public ChallengeModeDummyAura
{
    PrepareAuraScript(spell_challenge_quest_xp_only_800026);

protected:
    const char* GetModeName() const override { return "Quest XP Only Mode (No Mob Experience)"; }
};

// Spell 800027: Iron Man Mode
class spell_challenge_iron_man_800027 : public ChallengeModeDummyAura
{
    PrepareAuraScript(spell_challenge_iron_man_800027);

protected:
    const char* GetModeName() const override { return "Iron Man Mode (Hardcore + Self-Crafted + Item Restrictions)"; }
};

// Spell 800028: Multiple Challenges Combination
class spell_challenge_combination_800028 : public ChallengeModeDummyAura
{
    PrepareAuraScript(spell_challenge_combination_800028);

protected:
    const char* GetModeName() const override { return "Multiple Challenge Modes Active"; }
};

// Register all challenge mode aura scripts
void AddSC_spell_challenge_mode_auras()
{
    RegisterAuraScript(spell_challenge_hardcore_800020);
    RegisterAuraScript(spell_challenge_semi_hardcore_800021);
    RegisterAuraScript(spell_challenge_self_crafted_800022);
    RegisterAuraScript(spell_challenge_item_quality_800023);
    RegisterAuraScript(spell_challenge_slow_xp_800024);
    RegisterAuraScript(spell_challenge_very_slow_xp_800025);
    RegisterAuraScript(spell_challenge_quest_xp_only_800026);
    RegisterAuraScript(spell_challenge_iron_man_800027);
    RegisterAuraScript(spell_challenge_combination_800028);
}
