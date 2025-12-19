/*
 * Copyright (C) 2016+ AzerothCore <www.azerothcore.org>
 * Released under GNU AGPL v3 License
 *
 * DarkChaos-255 Challenge Mode Aura Scripts
 * 
 * Spell IDs: 800020-800029 (Challenge Mode Markers)
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

// Spell 800020: Hardcore Mode
class spell_challenge_hardcore_800020 : public AuraScript
{
    PrepareAuraScript(spell_challenge_hardcore_800020);

    void OnApply(AuraEffect const* /*aurEff*/, AuraEffectHandleModes /*mode*/)
    {
        Player* player = GetTarget()->ToPlayer();
        if (!player)
            return;

        LOG_DEBUG("scripts.challengemode", "Challenge Mode aura applied: Hardcore Mode (One Death and You Die) - Player: {}", 
            player->GetName());
    }

    void OnRemove(AuraEffect const* /*aurEff*/, AuraEffectHandleModes /*mode*/)
    {
        Player* player = GetTarget()->ToPlayer();
        if (!player)
            return;

        LOG_DEBUG("scripts.challengemode", "Challenge Mode aura removed: Hardcore Mode (One Death and You Die) - Player: {}", 
            player->GetName());
    }

    void Register() override
    {
        OnEffectApply += AuraEffectApplyFn(spell_challenge_hardcore_800020::OnApply, 0, SPELL_AURA_DUMMY, AURA_EFFECT_HANDLE_REAL);
        OnEffectRemove += AuraEffectRemoveFn(spell_challenge_hardcore_800020::OnRemove, 0, SPELL_AURA_DUMMY, AURA_EFFECT_HANDLE_REAL);
    }
};

// Spell 800021: Semi-Hardcore Mode
class spell_challenge_semi_hardcore_800021 : public AuraScript
{
    PrepareAuraScript(spell_challenge_semi_hardcore_800021);

    void OnApply(AuraEffect const* /*aurEff*/, AuraEffectHandleModes /*mode*/)
    {
        Player* player = GetTarget()->ToPlayer();
        if (!player)
            return;

        LOG_DEBUG("scripts.challengemode", "Challenge Mode aura applied: Semi-Hardcore Mode (Multiple Lives Allowed) - Player: {}", 
            player->GetName());
    }

    void OnRemove(AuraEffect const* /*aurEff*/, AuraEffectHandleModes /*mode*/)
    {
        Player* player = GetTarget()->ToPlayer();
        if (!player)
            return;

        LOG_DEBUG("scripts.challengemode", "Challenge Mode aura removed: Semi-Hardcore Mode (Multiple Lives Allowed) - Player: {}", 
            player->GetName());
    }

    void Register() override
    {
        OnEffectApply += AuraEffectApplyFn(spell_challenge_semi_hardcore_800021::OnApply, 0, SPELL_AURA_DUMMY, AURA_EFFECT_HANDLE_REAL);
        OnEffectRemove += AuraEffectRemoveFn(spell_challenge_semi_hardcore_800021::OnRemove, 0, SPELL_AURA_DUMMY, AURA_EFFECT_HANDLE_REAL);
    }
};

// Spell 800022: Self-Crafted Only
class spell_challenge_self_crafted_800022 : public AuraScript
{
    PrepareAuraScript(spell_challenge_self_crafted_800022);

    void OnApply(AuraEffect const* /*aurEff*/, AuraEffectHandleModes /*mode*/)
    {
        Player* player = GetTarget()->ToPlayer();
        if (!player)
            return;

        LOG_DEBUG("scripts.challengemode", "Challenge Mode aura applied: Self-Crafted Mode (You Must Craft Your Own Gear) - Player: {}", 
            player->GetName());
    }

    void OnRemove(AuraEffect const* /*aurEff*/, AuraEffectHandleModes /*mode*/)
    {
        Player* player = GetTarget()->ToPlayer();
        if (!player)
            return;

        LOG_DEBUG("scripts.challengemode", "Challenge Mode aura removed: Self-Crafted Mode (You Must Craft Your Own Gear) - Player: {}", 
            player->GetName());
    }

    void Register() override
    {
        OnEffectApply += AuraEffectApplyFn(spell_challenge_self_crafted_800022::OnApply, 0, SPELL_AURA_DUMMY, AURA_EFFECT_HANDLE_REAL);
        OnEffectRemove += AuraEffectRemoveFn(spell_challenge_self_crafted_800022::OnRemove, 0, SPELL_AURA_DUMMY, AURA_EFFECT_HANDLE_REAL);
    }
};

// Spell 800023: Item Quality Level Restriction
class spell_challenge_item_quality_800023 : public AuraScript
{
    PrepareAuraScript(spell_challenge_item_quality_800023);

    void OnApply(AuraEffect const* /*aurEff*/, AuraEffectHandleModes /*mode*/)
    {
        Player* player = GetTarget()->ToPlayer();
        if (!player)
            return;

        LOG_DEBUG("scripts.challengemode", "Challenge Mode aura applied: Item Quality Restriction (Limited to Green or Better) - Player: {}", 
            player->GetName());
    }

    void OnRemove(AuraEffect const* /*aurEff*/, AuraEffectHandleModes /*mode*/)
    {
        Player* player = GetTarget()->ToPlayer();
        if (!player)
            return;

        LOG_DEBUG("scripts.challengemode", "Challenge Mode aura removed: Item Quality Restriction (Limited to Green or Better) - Player: {}", 
            player->GetName());
    }

    void Register() override
    {
        OnEffectApply += AuraEffectApplyFn(spell_challenge_item_quality_800023::OnApply, 0, SPELL_AURA_DUMMY, AURA_EFFECT_HANDLE_REAL);
        OnEffectRemove += AuraEffectRemoveFn(spell_challenge_item_quality_800023::OnRemove, 0, SPELL_AURA_DUMMY, AURA_EFFECT_HANDLE_REAL);
    }
};

// Spell 800024: Slow XP Gain
class spell_challenge_slow_xp_800024 : public AuraScript
{
    PrepareAuraScript(spell_challenge_slow_xp_800024);

    void OnApply(AuraEffect const* /*aurEff*/, AuraEffectHandleModes /*mode*/)
    {
        Player* player = GetTarget()->ToPlayer();
        if (!player)
            return;

        LOG_DEBUG("scripts.challengemode", "Challenge Mode aura applied: Slow XP Mode (Reduced Experience Gain) - Player: {}", 
            player->GetName());
    }

    void OnRemove(AuraEffect const* /*aurEff*/, AuraEffectHandleModes /*mode*/)
    {
        Player* player = GetTarget()->ToPlayer();
        if (!player)
            return;

        LOG_DEBUG("scripts.challengemode", "Challenge Mode aura removed: Slow XP Mode (Reduced Experience Gain) - Player: {}", 
            player->GetName());
    }

    void Register() override
    {
        OnEffectApply += AuraEffectApplyFn(spell_challenge_slow_xp_800024::OnApply, 0, SPELL_AURA_DUMMY, AURA_EFFECT_HANDLE_REAL);
        OnEffectRemove += AuraEffectRemoveFn(spell_challenge_slow_xp_800024::OnRemove, 0, SPELL_AURA_DUMMY, AURA_EFFECT_HANDLE_REAL);
    }
};

// Spell 800025: Very Slow XP Gain
class spell_challenge_very_slow_xp_800025 : public AuraScript
{
    PrepareAuraScript(spell_challenge_very_slow_xp_800025);

    void OnApply(AuraEffect const* /*aurEff*/, AuraEffectHandleModes /*mode*/)
    {
        Player* player = GetTarget()->ToPlayer();
        if (!player)
            return;

        LOG_DEBUG("scripts.challengemode", "Challenge Mode aura applied: Very Slow XP Mode (Minimal Experience Gain) - Player: {}", 
            player->GetName());
    }

    void OnRemove(AuraEffect const* /*aurEff*/, AuraEffectHandleModes /*mode*/)
    {
        Player* player = GetTarget()->ToPlayer();
        if (!player)
            return;

        LOG_DEBUG("scripts.challengemode", "Challenge Mode aura removed: Very Slow XP Mode (Minimal Experience Gain) - Player: {}", 
            player->GetName());
    }

    void Register() override
    {
        OnEffectApply += AuraEffectApplyFn(spell_challenge_very_slow_xp_800025::OnApply, 0, SPELL_AURA_DUMMY, AURA_EFFECT_HANDLE_REAL);
        OnEffectRemove += AuraEffectRemoveFn(spell_challenge_very_slow_xp_800025::OnRemove, 0, SPELL_AURA_DUMMY, AURA_EFFECT_HANDLE_REAL);
    }
};

// Spell 800026: Quest XP Only
class spell_challenge_quest_xp_only_800026 : public AuraScript
{
    PrepareAuraScript(spell_challenge_quest_xp_only_800026);

    void OnApply(AuraEffect const* /*aurEff*/, AuraEffectHandleModes /*mode*/)
    {
        Player* player = GetTarget()->ToPlayer();
        if (!player)
            return;

        LOG_DEBUG("scripts.challengemode", "Challenge Mode aura applied: Quest XP Only Mode (No Mob Experience) - Player: {}", 
            player->GetName());
    }

    void OnRemove(AuraEffect const* /*aurEff*/, AuraEffectHandleModes /*mode*/)
    {
        Player* player = GetTarget()->ToPlayer();
        if (!player)
            return;

        LOG_DEBUG("scripts.challengemode", "Challenge Mode aura removed: Quest XP Only Mode (No Mob Experience) - Player: {}", 
            player->GetName());
    }

    void Register() override
    {
        OnEffectApply += AuraEffectApplyFn(spell_challenge_quest_xp_only_800026::OnApply, 0, SPELL_AURA_DUMMY, AURA_EFFECT_HANDLE_REAL);
        OnEffectRemove += AuraEffectRemoveFn(spell_challenge_quest_xp_only_800026::OnRemove, 0, SPELL_AURA_DUMMY, AURA_EFFECT_HANDLE_REAL);
    }
};

// Spell 800027: Iron Man Mode
class spell_challenge_iron_man_800027 : public AuraScript
{
    PrepareAuraScript(spell_challenge_iron_man_800027);

    void OnApply(AuraEffect const* /*aurEff*/, AuraEffectHandleModes /*mode*/)
    {
        Player* player = GetTarget()->ToPlayer();
        if (!player)
            return;

        LOG_DEBUG("scripts.challengemode", "Challenge Mode aura applied: Iron Man Mode (Hardcore + Self-Crafted + Item Restrictions) - Player: {}", 
            player->GetName());
    }

    void OnRemove(AuraEffect const* /*aurEff*/, AuraEffectHandleModes /*mode*/)
    {
        Player* player = GetTarget()->ToPlayer();
        if (!player)
            return;

        LOG_DEBUG("scripts.challengemode", "Challenge Mode aura removed: Iron Man Mode (Hardcore + Self-Crafted + Item Restrictions) - Player: {}", 
            player->GetName());
    }

    void Register() override
    {
        OnEffectApply += AuraEffectApplyFn(spell_challenge_iron_man_800027::OnApply, 0, SPELL_AURA_DUMMY, AURA_EFFECT_HANDLE_REAL);
        OnEffectRemove += AuraEffectRemoveFn(spell_challenge_iron_man_800027::OnRemove, 0, SPELL_AURA_DUMMY, AURA_EFFECT_HANDLE_REAL);
    }
};

// Spell 800029: Iron Man+ Mode
class spell_challenge_iron_man_plus_800029 : public AuraScript
{
    PrepareAuraScript(spell_challenge_iron_man_plus_800029);

    void OnApply(AuraEffect const* /*aurEff*/, AuraEffectHandleModes /*mode*/)
    {
        Player* player = GetTarget()->ToPlayer();
        if (!player)
            return;

        LOG_DEBUG("scripts.challengemode", "Challenge Mode aura applied: Iron Man+ Mode (No talents/glyphs/groups/dungeons/professions) - Player: {}",
            player->GetName());
    }

    void OnRemove(AuraEffect const* /*aurEff*/, AuraEffectHandleModes /*mode*/)
    {
        Player* player = GetTarget()->ToPlayer();
        if (!player)
            return;

        LOG_DEBUG("scripts.challengemode", "Challenge Mode aura removed: Iron Man+ Mode (No talents/glyphs/groups/dungeons/professions) - Player: {}",
            player->GetName());
    }

    void Register() override
    {
        OnEffectApply += AuraEffectApplyFn(spell_challenge_iron_man_plus_800029::OnApply, 0, SPELL_AURA_DUMMY, AURA_EFFECT_HANDLE_REAL);
        OnEffectRemove += AuraEffectRemoveFn(spell_challenge_iron_man_plus_800029::OnRemove, 0, SPELL_AURA_DUMMY, AURA_EFFECT_HANDLE_REAL);
    }
};

// Spell 800028: Multiple Challenges Combination
class spell_challenge_combination_800028 : public AuraScript
{
    PrepareAuraScript(spell_challenge_combination_800028);

    void OnApply(AuraEffect const* /*aurEff*/, AuraEffectHandleModes /*mode*/)
    {
        Player* player = GetTarget()->ToPlayer();
        if (!player)
            return;

        LOG_DEBUG("scripts.challengemode", "Challenge Mode aura applied: Multiple Challenge Modes Active - Player: {}", 
            player->GetName());
    }

    void OnRemove(AuraEffect const* /*aurEff*/, AuraEffectHandleModes /*mode*/)
    {
        Player* player = GetTarget()->ToPlayer();
        if (!player)
            return;

        LOG_DEBUG("scripts.challengemode", "Challenge Mode aura removed: Multiple Challenge Modes Active - Player: {}", 
            player->GetName());
    }

    void Register() override
    {
        OnEffectApply += AuraEffectApplyFn(spell_challenge_combination_800028::OnApply, 0, SPELL_AURA_DUMMY, AURA_EFFECT_HANDLE_REAL);
        OnEffectRemove += AuraEffectRemoveFn(spell_challenge_combination_800028::OnRemove, 0, SPELL_AURA_DUMMY, AURA_EFFECT_HANDLE_REAL);
    }
};

// Register all challenge mode aura scripts
void AddSC_spell_challenge_mode_auras()
{
    RegisterSpellScript(spell_challenge_hardcore_800020);
    RegisterSpellScript(spell_challenge_semi_hardcore_800021);
    RegisterSpellScript(spell_challenge_self_crafted_800022);
    RegisterSpellScript(spell_challenge_item_quality_800023);
    RegisterSpellScript(spell_challenge_slow_xp_800024);
    RegisterSpellScript(spell_challenge_very_slow_xp_800025);
    RegisterSpellScript(spell_challenge_quest_xp_only_800026);
    RegisterSpellScript(spell_challenge_iron_man_800027);
    RegisterSpellScript(spell_challenge_combination_800028);
    RegisterSpellScript(spell_challenge_iron_man_plus_800029);
}
