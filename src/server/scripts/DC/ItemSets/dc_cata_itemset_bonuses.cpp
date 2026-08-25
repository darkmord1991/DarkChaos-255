/*
 * Copyright (C) 2016+ AzerothCore <www.azerothcore.org>
 * Released under GNU AGPL v3 License
 *
 * DarkChaos-255 -- Cataclysm item set bonuses that cannot be expressed as data.
 *
 * Most downported Cata set bonuses are plain modifier or proc auras and are handled
 * entirely by `itemset_dbc` + `spell_dbc` (see
 * Custom/Custom feature SQLs/worlddb/ItemSets/). The ones here carry
 * SPELL_AURA_DUMMY, which is inert without a script.
 *
 * Two families are implemented:
 *
 *   1. "Your <ability> deals N% additional damage as Fire over 4 sec."
 *      Cataclysm never links the damage-over-time spell through EffectTriggerSpell
 *      -- the id lives only in the tooltip text -- so each script names its own.
 *      The percentage is read from the aura effect amount rather than hardcoded,
 *      so retuning is a spell_dbc edit and not a rebuild.
 *
 *   2. "When <buff> expires you gain X% parry for N sec."
 *      The trigger is the expiry of an unrelated stock aura, so the script attaches
 *      to that stock aura and is gated on the player actually having the set bonus.
 *      It is a no-op for everyone else.
 *
 * Percentages and durations are Blizzard's own values, read from the 4.3.4 client.
 * Each script is bound to its spell through `spell_script_names` -- see
 * 14_cata_itemset_script_bindings.sql.
 */

#include "ScriptMgr.h"
#include "SpellAuraEffects.h"
#include "SpellMgr.h"
#include "SpellScript.h"

namespace
{
    // ---- what the bonuses actually apply -------------------------------------
    constexpr uint32 SPELL_FIERY_CLAWS         = 99002;   // Druid   fire DoT, 2s tick
    constexpr uint32 SPELL_FLAMES_OF_FAITHFUL  = 99092;   // Paladin fire DoT, 2s tick
    constexpr uint32 SPELL_BURNING_WOUNDS      = 99173;   // Rogue   fire DoT, 2s tick
    constexpr uint32 SPELL_COMBUST             = 99240;   // Warrior fire DoT, 2s tick
    constexpr uint32 SPELL_FLAMING_RUNE_WEAPON = 101162;  // DK      +parry
    constexpr uint32 SPELL_FLAME_WALL          = 99243;   // Warrior +parry

    // ---- batch 2 -------------------------------------------------------------
    constexpr uint32 SPELL_TRICKS_OF_TIME       = 105864;  // Rogue  -20% energy cost
    constexpr uint32 SPELL_KISS_OF_DEATH        = 105582;  // DK     Blood Rune -> Death Rune

    // ---- the set bonus auras that gate the family-2 scripts ------------------
    constexpr uint32 SPELL_DK_T12_BLOOD_4P     = 98966;
    constexpr uint32 SPELL_WARRIOR_T12_PROT_4P = 99242;
    constexpr uint32 SPELL_PALADIN_T12_PROT_4P = 99091;
    constexpr uint32 SPELL_FLAMING_AEGIS       = 99090;   // Paladin +parry

    // 3.3.5 SpellFamilyFlags of the abilities each bonus keys off, taken from OUR
    // Spell.dbc. Cataclysm assigns these bits differently, so a Cata mask copied
    // across would match the wrong abilities entirely.
    //   Druid   Mangle (Bear) 0x40<<32 | Mangle (Cat) 0x400<<32 | Maul 0x800 | Shred 0x9000
    //   Paladin Crusader Strike 0x8000<<32
    //   Warrior Shield Slam 0x200<<32
    //   DK      Obliterate 0x20000<<32 | Scourge Strike 0x8000000<<32, 0x80<<64
    constexpr uint32 FAMILY_NONE = 0;

    // -------------------------------------------------------------------------
    // Family 1 -- a share of the ability's damage, re-applied as a fire DoT.
    // Family == FAMILY_NONE means "no ability filter": the proc flags alone decide,
    // which is what the Rogue set wants (any melee critical strike).
    // -------------------------------------------------------------------------
    template <uint32 DotSpell, uint32 Family, uint32 Flag0, uint32 Flag1, uint32 Flag2>
    class ItemSetFireDot : public AuraScript
    {
        PrepareAuraScript(ItemSetFireDot);

        bool Validate(SpellInfo const* /*spellInfo*/) override
        {
            return ValidateSpellInfo({ DotSpell });
        }

        bool CheckProc(ProcEventInfo& eventInfo)
        {
            DamageInfo* damageInfo = eventInfo.GetDamageInfo();
            if (!damageInfo || !damageInfo->GetDamage())
                return false;

            if (!eventInfo.GetActor() || !eventInfo.GetProcTarget())
                return false;

            if (Family == FAMILY_NONE)
                return true;

            SpellInfo const* spellInfo = eventInfo.GetSpellInfo();
            if (!spellInfo || spellInfo->SpellFamilyName != Family)
                return false;

            return spellInfo->SpellFamilyFlags.HasFlag(Flag0, Flag1, Flag2);
        }

        void HandleProc(AuraEffect const* aurEff, ProcEventInfo& eventInfo)
        {
            PreventDefaultAction();

            SpellInfo const* dot = sSpellMgr->GetSpellInfo(DotSpell);
            if (!dot)
                return;

            uint32 const ticks = dot->GetMaxTicks();
            if (!ticks)
                return;

            // aurEff->GetAmount() is the percentage straight out of the DBC, so the
            // tuning lives in spell_dbc and never needs a rebuild.
            int32 const amount = int32(CalculatePct(eventInfo.GetDamageInfo()->GetDamage(),
                aurEff->GetAmount()) / ticks);
            if (amount <= 0)
                return;

            eventInfo.GetProcTarget()->CastDelayedSpellWithPeriodicAmount(
                eventInfo.GetActor(), DotSpell, SPELL_AURA_PERIODIC_DAMAGE, amount);
        }

        void Register() override
        {
            DoCheckProc += AuraCheckProcFn(ItemSetFireDot::CheckProc);
            OnEffectProc += AuraEffectProcFn(ItemSetFireDot::HandleProc, EFFECT_0, SPELL_AURA_DUMMY);
        }
    };

    // -------------------------------------------------------------------------
    // Death Knight T12 DPS 4pc. Same idea, but Blizzard applies it as a single
    // instant hit ("instantly deal ... as Fire damage") and ships no spell for it,
    // so the damage is dealt directly instead of through a triggered cast.
    // -------------------------------------------------------------------------
    template <uint32 Family, uint32 Flag0, uint32 Flag1, uint32 Flag2>
    class ItemSetInstantFire : public AuraScript
    {
        PrepareAuraScript(ItemSetInstantFire);

        bool CheckProc(ProcEventInfo& eventInfo)
        {
            DamageInfo* damageInfo = eventInfo.GetDamageInfo();
            if (!damageInfo || !damageInfo->GetDamage())
                return false;

            if (!eventInfo.GetActor() || !eventInfo.GetProcTarget())
                return false;

            SpellInfo const* spellInfo = eventInfo.GetSpellInfo();
            if (!spellInfo || spellInfo->SpellFamilyName != Family)
                return false;

            return spellInfo->SpellFamilyFlags.HasFlag(Flag0, Flag1, Flag2);
        }

        void HandleProc(AuraEffect const* aurEff, ProcEventInfo& eventInfo)
        {
            PreventDefaultAction();

            int32 const amount = int32(CalculatePct(eventInfo.GetDamageInfo()->GetDamage(),
                aurEff->GetAmount()));
            if (amount <= 0)
                return;

            Unit* actor = eventInfo.GetActor();
            Unit* target = eventInfo.GetProcTarget();

            SpellNonMeleeDamage damageLog(actor, target, GetSpellInfo(), SPELL_SCHOOL_MASK_FIRE);
            damageLog.damage = uint32(amount);

            Unit::DealDamage(actor, target, uint32(amount), nullptr, SPELL_DIRECT_DAMAGE,
                SPELL_SCHOOL_MASK_FIRE, GetSpellInfo(), false);
            actor->SendSpellNonMeleeDamageLog(&damageLog);
        }

        void Register() override
        {
            DoCheckProc += AuraCheckProcFn(ItemSetInstantFire::CheckProc);
            OnEffectProc += AuraEffectProcFn(ItemSetInstantFire::HandleProc, EFFECT_0, SPELL_AURA_DUMMY);
        }
    };

    // -------------------------------------------------------------------------
    // Family 2 -- a stock buff running out grants a second buff, but only while
    // the player wears the set. Attached to the STOCK aura, because that is what
    // expires; gated so it costs nothing for anyone not wearing the set.
    // -------------------------------------------------------------------------
    template <uint32 SetBonus, uint32 Granted>
    class ItemSetOnExpire : public AuraScript
    {
        PrepareAuraScript(ItemSetOnExpire);

        bool Validate(SpellInfo const* /*spellInfo*/) override
        {
            return ValidateSpellInfo({ Granted });
        }

        void HandleRemove(AuraEffect const* /*aurEff*/, AuraEffectHandleModes /*mode*/)
        {
            AuraApplication const* app = GetTargetApplication();
            if (!app || app->GetRemoveMode() != AURA_REMOVE_BY_EXPIRE)
                return;

            Unit* target = GetTarget();
            if (!target || !target->HasAura(SetBonus))
                return;

            target->CastSpell(target, Granted, true);
        }

        void Register() override
        {
            // Bound to EFFECT_ALL / SPELL_AURA_ANY so a DBC layout difference in the
            // stock aura cannot silently stop the handler from running.
            OnEffectRemove += AuraEffectRemoveFn(ItemSetOnExpire::HandleRemove,
                EFFECT_ALL, SPELL_AURA_ANY, AURA_EFFECT_HANDLE_REAL);
        }
    };

    // -------------------------------------------------------------------------
    // Rogue T13 2pc -- "After triggering Tricks of the Trade, your abilities cost
    // 35% less energy." The reduction itself lives in Tricks of Time (105864,
    // MOD_POWER_COST_SCHOOL_PCT), so this only has to fire it on the right ability.
    // -------------------------------------------------------------------------
    class spell_dc_rogue_t13_2p : public AuraScript
    {
        PrepareAuraScript(spell_dc_rogue_t13_2p);

        bool Validate(SpellInfo const* /*spellInfo*/) override
        {
            return ValidateSpellInfo({ SPELL_TRICKS_OF_TIME });
        }

        bool CheckProc(ProcEventInfo& eventInfo)
        {
            SpellInfo const* spellInfo = eventInfo.GetSpellInfo();
            if (!spellInfo || spellInfo->SpellFamilyName != SPELLFAMILY_ROGUE)
                return false;

            // Tricks of the Trade
            return spellInfo->SpellFamilyFlags.HasFlag(0, 0x04000000, 0);
        }

        void HandleProc(AuraEffect const* aurEff, ProcEventInfo& /*eventInfo*/)
        {
            PreventDefaultAction();

            if (Unit* target = GetTarget())
                target->CastSpell(target, SPELL_TRICKS_OF_TIME, true, nullptr, aurEff);
        }

        void Register() override
        {
            DoCheckProc += AuraCheckProcFn(spell_dc_rogue_t13_2p::CheckProc);
            OnEffectProc += AuraEffectProcFn(spell_dc_rogue_t13_2p::HandleProc, EFFECT_0, SPELL_AURA_DUMMY);
        }
    };

    // -------------------------------------------------------------------------
    // Death Knight T13 Blood 2pc -- "When an attack drops your health below 35%,
    // one of your Blood Runes immediately activates as a Death Rune."
    // The threshold is the aura effect amount, so it is tunable from spell_dbc.
    // Guarded by a cooldown on the granted aura so a burst of hits cannot chain it.
    // -------------------------------------------------------------------------
    class spell_dc_dk_t13_blood_2p : public AuraScript
    {
        PrepareAuraScript(spell_dc_dk_t13_blood_2p);

        bool Validate(SpellInfo const* /*spellInfo*/) override
        {
            return ValidateSpellInfo({ SPELL_KISS_OF_DEATH });
        }

        bool CheckProc(ProcEventInfo& eventInfo)
        {
            DamageInfo* damageInfo = eventInfo.GetDamageInfo();
            if (!damageInfo || !damageInfo->GetDamage())
                return false;

            Unit* target = GetTarget();
            if (!target || !target->IsAlive())
                return false;

            AuraEffect const* aurEff = GetEffect(EFFECT_0);
            if (!aurEff)
                return false;

            // Only when this hit is what takes the player under the threshold, so a
            // player already below it does not re-trigger on every subsequent swing.
            uint32 const maxHealth = target->GetMaxHealth();
            if (!maxHealth)
                return false;

            uint32 const current = target->GetHealth();
            uint32 const before = current + damageInfo->GetDamage();
            int32 const pct = aurEff->GetAmount();

            bool const wasAbove = before * 100 >= maxHealth * uint32(pct);
            bool const nowBelow = current * 100 < maxHealth * uint32(pct);
            return wasAbove && nowBelow && !target->HasAura(SPELL_KISS_OF_DEATH);
        }

        void HandleProc(AuraEffect const* aurEff, ProcEventInfo& /*eventInfo*/)
        {
            PreventDefaultAction();

            if (Unit* target = GetTarget())
                target->CastSpell(target, SPELL_KISS_OF_DEATH, true, nullptr, aurEff);
        }

        void Register() override
        {
            DoCheckProc += AuraCheckProcFn(spell_dc_dk_t13_blood_2p::CheckProc);
            // 105552's EFFECT_0 is APPLY_AURA / PROC_TRIGGER_SPELL, not DUMMY -- Cata
            // SpellEffect.dbc idx0 = Effect 6, Aura 42, triggering 105582. Our spell_dbc
            // row copies that faithfully, so the DUMMY binding never resolved and the
            // Kiss of Death proc silently never fired.
            OnEffectProc += AuraEffectProcFn(spell_dc_dk_t13_blood_2p::HandleProc, EFFECT_0, SPELL_AURA_PROC_TRIGGER_SPELL);
        }
    };

    // -------------------------------------------------------------------------
    // Druid T12 Restoration 4pc -- "Your Swiftmend also heals an injured target
    // within 15 yards for the same amount." The second heal is dealt directly,
    // for exactly the amount the original landed for, because no spell ships for it.
    // -------------------------------------------------------------------------
    template <uint32 Family, uint32 Flag0, uint32 Flag1, uint32 Flag2>
    class ItemSetSecondHeal : public AuraScript
    {
        PrepareAuraScript(ItemSetSecondHeal);

        bool CheckProc(ProcEventInfo& eventInfo)
        {
            HealInfo* healInfo = eventInfo.GetHealInfo();
            if (!healInfo || !healInfo->GetHeal())
                return false;

            SpellInfo const* spellInfo = eventInfo.GetSpellInfo();
            if (!spellInfo || spellInfo->SpellFamilyName != Family)
                return false;

            return spellInfo->SpellFamilyFlags.HasFlag(Flag0, Flag1, Flag2);
        }

        void HandleProc(AuraEffect const* /*aurEff*/, ProcEventInfo& eventInfo)
        {
            PreventDefaultAction();

            Unit* healer = eventInfo.GetActor();
            if (!healer)
                return;

            Unit* second = healer->GetNextRandomRaidMemberOrPet(15.0f);
            if (!second || second == eventInfo.GetProcTarget() || !second->IsAlive())
                return;

            if (second->IsFullHealth())
                return;

            uint32 const amount = eventInfo.GetHealInfo()->GetHeal();
            HealInfo healInfo(healer, second, amount, GetSpellInfo(), GetSpellInfo()->GetSchoolMask());
            healer->HealBySpell(healInfo);
        }

        void Register() override
        {
            DoCheckProc += AuraCheckProcFn(ItemSetSecondHeal::CheckProc);
            OnEffectProc += AuraEffectProcFn(ItemSetSecondHeal::HandleProc, EFFECT_0, SPELL_AURA_DUMMY);
        }
    };

    // RegisterSpellScriptWithArgs is a macro, so a templated type written inline
    // would be split on its own commas. Alias each instantiation first.
    using DruidT12Feral2P  = ItemSetFireDot<SPELL_FIERY_CLAWS, SPELLFAMILY_DRUID, 0x0000A800, 0x00000440, 0>;
    using PaladinT12Ret2P  = ItemSetFireDot<SPELL_FLAMES_OF_FAITHFUL, SPELLFAMILY_PALADIN, 0, 0x00008000, 0>;
    using WarriorT12Prot2P = ItemSetFireDot<SPELL_COMBUST, SPELLFAMILY_WARRIOR, 0, 0x00000200, 0>;
    using RogueT12_2P      = ItemSetFireDot<SPELL_BURNING_WOUNDS, FAMILY_NONE, 0, 0, 0>;
    using DkT12Blood4P     = ItemSetOnExpire<SPELL_DK_T12_BLOOD_4P, SPELL_FLAMING_RUNE_WEAPON>;
    using WarriorT12Prot4P = ItemSetOnExpire<SPELL_WARRIOR_T12_PROT_4P, SPELL_FLAME_WALL>;
    using PaladinT12Prot4P = ItemSetOnExpire<SPELL_PALADIN_T12_PROT_4P, SPELL_FLAMING_AEGIS>;

    // Obliterate | Scourge Strike
    using DkT12Dps4P       = ItemSetInstantFire<SPELLFAMILY_DEATHKNIGHT, 0, 0x08020000, 0x00000080>;
    // Hammer of the Righteous -- stands in for Cataclysm's Shield of the Righteous
    using PaladinT12Prot2P = ItemSetInstantFire<SPELLFAMILY_PALADIN, 0, 0x00040000, 0>;
    // Swiftmend
    using DruidT12Resto4P  = ItemSetSecondHeal<SPELLFAMILY_DRUID, 0, 0x00000002, 0>;
    // Flash of Light | Holy Light  (Divine Light does not exist in 3.3.5)
    using PaladinT12Holy4P = ItemSetSecondHeal<SPELLFAMILY_PALADIN, 0xC0000000, 0, 0>;
}

void AddSC_dc_cata_itemset_bonuses()
{
    // Family 1 -- a share of the ability's damage, re-applied as fire over time
    RegisterSpellScriptWithArgs(DruidT12Feral2P, "spell_dc_druid_t12_feral_2p");
    RegisterSpellScriptWithArgs(PaladinT12Ret2P, "spell_dc_paladin_t12_ret_2p");
    RegisterSpellScriptWithArgs(WarriorT12Prot2P, "spell_dc_warrior_t12_prot_2p");
    RegisterSpellScriptWithArgs(RogueT12_2P, "spell_dc_rogue_t12_2p");

    // Family 1b -- instant fire damage
    RegisterSpellScriptWithArgs(DkT12Dps4P, "spell_dc_dk_t12_dps_4p");
    RegisterSpellScriptWithArgs(PaladinT12Prot2P, "spell_dc_paladin_t12_prot_2p");

    // Family 2 -- a stock buff expiring grants parry, while the set is worn
    RegisterSpellScriptWithArgs(DkT12Blood4P, "spell_dc_dk_t12_blood_4p");
    RegisterSpellScriptWithArgs(WarriorT12Prot4P, "spell_dc_warrior_t12_prot_4p");
    RegisterSpellScriptWithArgs(PaladinT12Prot4P, "spell_dc_paladin_t12_prot_4p");

    // Batch 2 -- one-offs that do not share a family with anything else
    RegisterSpellScript(spell_dc_rogue_t13_2p);
    RegisterSpellScript(spell_dc_dk_t13_blood_2p);
    RegisterSpellScriptWithArgs(DruidT12Resto4P, "spell_dc_druid_t12_resto_4p");
    RegisterSpellScriptWithArgs(PaladinT12Holy4P, "spell_dc_paladin_t12_holy_4p");
}
