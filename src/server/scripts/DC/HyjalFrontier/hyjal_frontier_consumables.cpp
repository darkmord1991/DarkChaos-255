/*
 * DarkChaos -- Hyjal Frontier consumables
 *
 * Makes the branded drink line actually restore mana.
 *
 * THE PROBLEM
 * -----------
 * The four Frontier drinks are built exactly like Blizzard's own -- verified
 * against stock spell 43183 in the live server's Spell.dbc:
 *
 *     effect 0 : APPLY_AURA, SPELL_AURA_MOD_POWER_REGEN (85), BasePoints -1
 *     effect 1 : APPLY_AURA, SPELL_AURA_PERIODIC_DUMMY  (226), BasePoints = the
 *                real mana-per-5s value, period 2200 ms
 *
 * The DBC data is correct. What is missing is that the value only reaches the
 * MOD_POWER_REGEN effect through a HARDCODED SPELL-ID WHITELIST in the core --
 * AuraEffect::HandlePeriodicDummyAuraTick (SpellAuraEffects.cpp), which lists
 * 430, 431, 432, 1133, 1135, 1137, 10250, 22734, 27089, 34291, 43182, 43183,
 * 46755, 49472, 57073 and 61830 and nothing else.
 *
 * The DC ids are not in that list, so the dummy tick did nothing, effect 0 stayed
 * at (-1 + 1) = 0, and all four drinks restored ZERO mana while still playing the
 * drink animation.
 *
 * WHY A SCRIPT AND NOT A CORE EDIT
 * --------------------------------
 * Adding four ids to that switch would work, but it is an edit to
 * src/server/game/ that has to be re-applied on every upstream merge. This hook
 * runs FIRST in AuraEffect::PeriodicTick --
 *
 *     bool prevented = GetBase()->CallScriptEffectPeriodicHandlers(this, aurApp);
 *     if (prevented) return;
 *
 * -- so a script can own the behaviour entirely and the core stays untouched.
 *
 * The arena ramp below is not decoration: it mirrors the core's own handling so
 * these drinks behave identically to stock ones in arenas (the 6-second rule
 * means a fresh drink must not pay full value on its first ticks).
 */

#include "ScriptMgr.h"
#include "Player.h"
#include "SpellScript.h"
#include "SpellAuraEffects.h"

enum FrontierDrinkSpells
{
    SPELL_FOOTHILLS_DRINK   = 300551,
    SPELL_SCORCHED_DRINK    = 300556,
    SPELL_SUMMIT_DRINK      = 300561,
    SPELL_NORDRASSIL_DRINK  = 300566
};

// Frontier drinks: copy the periodic dummy's amount onto the MOD_POWER_REGEN
// effect, which is what the core does for the stock drink ids.
class spell_dc_frontier_drink : public AuraScript
{
    PrepareAuraScript(spell_dc_frontier_drink);

    void HandleDummyTick(AuraEffect const* aurEff)
    {
        // Always take over: if we let the core run its switch it would find no
        // matching id and silently do nothing, which is the bug.
        PreventDefaultAction();

        Unit* caster = GetCaster();
        if (!caster || !caster->IsPlayer())
            return;

        AuraEffect* regen = GetEffect(EFFECT_0);
        if (!regen)
            return;

        // Guard the structure rather than assume it. If someone re-authors the
        // spell and moves the regen off effect 0, writing to it would corrupt
        // whatever aura took its place -- the core makes the same check.
        if (regen->GetAuraType() != SPELL_AURA_MOD_POWER_REGEN)
        {
            LOG_ERROR("scripts.dc", "Frontier drink {}: effect 0 is aura {}, expected SPELL_AURA_MOD_POWER_REGEN ({}). Drink will not restore mana.",
                      GetId(), uint32(regen->GetAuraType()), uint32(SPELL_AURA_MOD_POWER_REGEN));
            return;
        }

        Player* player = caster->ToPlayer();

        if (!player->InArena())
        {
            regen->ChangeAmount(aurEff->GetAmount());
            return;
        }

        // Arena only -- the 6-second rule. Mirrors the core's stock behaviour:
        // tick 1 pays nothing, then 166% and 133% to catch up, then normal.
        switch (aurEff->GetTickNumber())
        {
            case 1:
                regen->ChangeAmount(0);
                break;
            case 2:
                regen->ChangeAmount(aurEff->GetAmount() * 5 / 3);
                break;
            case 3:
                regen->ChangeAmount(aurEff->GetAmount() * 4 / 3);
                break;
            default:
                regen->ChangeAmount(aurEff->GetAmount());
                break;
        }
    }

    void Register() override
    {
        OnEffectPeriodic += AuraEffectPeriodicFn(spell_dc_frontier_drink::HandleDummyTick,
                                                 EFFECT_1, SPELL_AURA_PERIODIC_DUMMY);
    }
};

void AddSC_hyjal_frontier_consumables()
{
    RegisterSpellScript(spell_dc_frontier_drink);
}
