/*
 * Dark Chaos - racials of races 28-31 that need code
 * ==================================================
 *
 * Drakkari Troll (28), Void Elf (29), Lightforged Draenei (30) and Mag'har Orc (31). The spell rows,
 * the grants and every racial that is pure data live in
 * Custom/Custom feature SQLs/worlddb/Races28to31/ (00_RACIALS.md has the full design).
 *
 * This file covers what spell data cannot express on 3.3.5:
 *  - Spatial Rift (256948 + 257040): retail places the rift with an area trigger (effect 179) and
 *    swaps the action button (aura 332); neither exists here. The rift is a slotted object like
 *    Demonic Circle, and a second spell, usable while the first one's aura is up, steps through it.
 *  - Light's Judgment (255647 -> 256893): retail's fixed 3 second delay is a spell attribute this
 *    client does not have, so the strike is scheduled.
 *  - Light's Reckoning (255652 -> 256896): the eruption on death.
 *  - Demonbane (255653): retail's bonus experience aura (447) does not exist here.
 *  - Ancestral Call (274738): picks one of four blessings at random.
 *  - The damage and healing of 256893 and 256896, which retail takes from a tooltip formula.
 */

#include "GameObject.h"
#include "ObjectAccessor.h"
#include "Player.h"
#include "Random.h"
#include "ScriptMgr.h"
#include "SpellAuraEffects.h"
#include "SpellInfo.h"
#include "SpellScript.h"
#include "SpellScriptLoader.h"
#include "Util.h"
#include <algorithm>
#include <array>

enum Races2831Spells
{
    SPELL_SPATIAL_RIFT             = 256948,
    SPELL_LIGHTS_JUDGMENT_STRIKE   = 256893,
    SPELL_LIGHTS_RECKONING         = 255652,   // passive marker, granted with the other racials
    SPELL_LIGHTS_RECKONING_BURST   = 256896,
    SPELL_DEMONBANE                = 255653,   // passive marker, granted with the other racials
    SPELL_RICTUS_OF_LAUGHING_SKULL = 274739,   // critical strike
    SPELL_ZEAL_OF_BURNING_BLADE    = 274740,   // haste
    SPELL_FEROCITY_OF_FROSTWOLF    = 274741,   // damage done, standing in for mastery
    SPELL_MIGHT_OF_BLACKROCK       = 274742    // healing done and damage taken, standing in for versatility
};

namespace
{
    Milliseconds const LIGHTS_JUDGMENT_DELAY = Milliseconds(3000);
    float const LIGHTS_JUDGMENT_COEFFICIENT = 0.75f;
    float const LIGHTS_RECKONING_COEFFICIENT = 0.5f;
    uint32 const DEMONBANE_XP_PCT = 20;

    // Retail scales these with the better of attack and spell power, so they suit every class.
    int32 RacialPower(Unit* caster, float coefficient)
    {
        WeaponAttackType const attackType = caster->getClass() != CLASS_HUNTER ? BASE_ATTACK : RANGED_ATTACK;
        float const attackPower = caster->GetTotalAttackPowerValue(attackType);
        float const spellPower = float(caster->SpellBaseDamageBonusDone(SPELL_SCHOOL_MASK_HOLY));
        return int32(caster->GetLevel() * 2 + std::max(attackPower, spellPower) * coefficient);
    }
}

class dc_races_28_31_player : public PlayerScript
{
public:
    dc_races_28_31_player() : PlayerScript("dc_races_28_31_player",
        { PLAYERHOOK_ON_PLAYER_JUST_DIED, PLAYERHOOK_ON_GIVE_EXP }) { }

    // Runs from Player::KillPlayer, one update after the killing blow, while the body is still where it fell.
    void OnPlayerJustDied(Player* player) override
    {
        if (player->HasSpell(SPELL_LIGHTS_RECKONING))
            player->CastSpell(player, SPELL_LIGHTS_RECKONING_BURST, true);
    }

    void OnPlayerGiveXP(Player* player, uint32& amount, Unit* victim, uint8 /*xpSource*/) override
    {
        if (victim && victim->GetCreatureType() == CREATURE_TYPE_DEMON && player->HasSpell(SPELL_DEMONBANE))
            AddPct(amount, DEMONBANE_XP_PCT);
    }
};

// 256948 - Spatial Rift
class spell_dc_spatial_rift : public AuraScript
{
    PrepareAuraScript(spell_dc_spatial_rift);

    void HandleRemove(AuraEffect const* /*aurEff*/, AuraEffectHandleModes /*mode*/)
    {
        GetTarget()->RemoveGameObject(GetId(), true);
    }

    void Register() override
    {
        AfterEffectRemove += AuraEffectRemoveFn(spell_dc_spatial_rift::HandleRemove, EFFECT_0, SPELL_AURA_DUMMY,
            AURA_EFFECT_HANDLE_REAL);
    }
};

// 257040 - Spatial Rift: Teleport
class spell_dc_spatial_rift_teleport : public SpellScript
{
    PrepareSpellScript(spell_dc_spatial_rift_teleport);

    bool Validate(SpellInfo const* /*spellInfo*/) override
    {
        return ValidateSpellInfo({ SPELL_SPATIAL_RIFT });
    }

    SpellCastResult CheckRift()
    {
        return GetCaster()->GetGameObject(SPELL_SPATIAL_RIFT) ? SPELL_CAST_OK : SPELL_FAILED_NO_VALID_TARGETS;
    }

    void HandleDummy(SpellEffIndex /*effIndex*/)
    {
        Unit* caster = GetCaster();
        if (GameObject* rift = caster->GetGameObject(SPELL_SPATIAL_RIFT))
        {
            caster->NearTeleportTo(rift->GetPositionX(), rift->GetPositionY(), rift->GetPositionZ(),
                caster->GetOrientation(), false, false, false, true);
            caster->RemoveAurasDueToSpell(SPELL_SPATIAL_RIFT);
        }
    }

    void Register() override
    {
        OnCheckCast += SpellCheckCastFn(spell_dc_spatial_rift_teleport::CheckRift);
        OnEffectHitTarget += SpellEffectFn(spell_dc_spatial_rift_teleport::HandleDummy, EFFECT_0, SPELL_EFFECT_DUMMY);
    }
};

// 255647 - Light's Judgment
class spell_dc_lights_judgment : public SpellScript
{
    PrepareSpellScript(spell_dc_lights_judgment);

    bool Validate(SpellInfo const* /*spellInfo*/) override
    {
        return ValidateSpellInfo({ SPELL_LIGHTS_JUDGMENT_STRIKE });
    }

    void HandleAfterCast()
    {
        WorldLocation const* dest = GetExplTargetDest();
        Player* player = GetCaster()->ToPlayer();
        if (!dest || !player)
            return;

        float const x = dest->GetPositionX();
        float const y = dest->GetPositionY();
        float const z = dest->GetPositionZ();
        player->m_Events.AddEventAtOffset([guid = player->GetGUID(), mapId = player->GetMapId(), x, y, z]()
        {
            Player* caster = ObjectAccessor::FindPlayer(guid);
            if (caster && caster->IsInWorld() && caster->GetMapId() == mapId)
                caster->CastSpell(x, y, z, SPELL_LIGHTS_JUDGMENT_STRIKE, true);
        }, LIGHTS_JUDGMENT_DELAY);
    }

    void Register() override
    {
        AfterCast += SpellCastFn(spell_dc_lights_judgment::HandleAfterCast);
    }
};

// 256893 - Light's Judgment (the strike)
class spell_dc_lights_judgment_strike : public SpellScript
{
    PrepareSpellScript(spell_dc_lights_judgment_strike);

    void HandleDamage(SpellEffIndex /*effIndex*/)
    {
        SetEffectValue(RacialPower(GetCaster(), LIGHTS_JUDGMENT_COEFFICIENT));
    }

    void Register() override
    {
        OnEffectLaunchTarget += SpellEffectFn(spell_dc_lights_judgment_strike::HandleDamage, EFFECT_0,
            SPELL_EFFECT_SCHOOL_DAMAGE);
    }
};

// 256896 - Light's Reckoning (the eruption)
class spell_dc_lights_reckoning_burst : public SpellScript
{
    PrepareSpellScript(spell_dc_lights_reckoning_burst);

    void HandleDamage(SpellEffIndex /*effIndex*/)
    {
        SetEffectValue(RacialPower(GetCaster(), LIGHTS_RECKONING_COEFFICIENT));
    }

    void HandleHeal(SpellEffIndex /*effIndex*/)
    {
        SetEffectValue(RacialPower(GetCaster(), LIGHTS_RECKONING_COEFFICIENT));
    }

    void Register() override
    {
        OnEffectLaunchTarget += SpellEffectFn(spell_dc_lights_reckoning_burst::HandleDamage, EFFECT_0,
            SPELL_EFFECT_SCHOOL_DAMAGE);
        OnEffectHitTarget += SpellEffectFn(spell_dc_lights_reckoning_burst::HandleHeal, EFFECT_1, SPELL_EFFECT_HEAL);
    }
};

// 274738 - Ancestral Call
class spell_dc_ancestral_call : public SpellScript
{
    PrepareSpellScript(spell_dc_ancestral_call);

    bool Validate(SpellInfo const* /*spellInfo*/) override
    {
        return ValidateSpellInfo({ SPELL_RICTUS_OF_LAUGHING_SKULL, SPELL_ZEAL_OF_BURNING_BLADE,
            SPELL_FEROCITY_OF_FROSTWOLF, SPELL_MIGHT_OF_BLACKROCK });
    }

    void HandleDummy(SpellEffIndex /*effIndex*/)
    {
        static std::array<uint32, 4> const blessings =
        {
            SPELL_RICTUS_OF_LAUGHING_SKULL, SPELL_ZEAL_OF_BURNING_BLADE,
            SPELL_FEROCITY_OF_FROSTWOLF, SPELL_MIGHT_OF_BLACKROCK
        };

        Unit* caster = GetCaster();
        caster->CastSpell(caster, blessings[urand(0, blessings.size() - 1)], true);
    }

    void Register() override
    {
        OnEffectHitTarget += SpellEffectFn(spell_dc_ancestral_call::HandleDummy, EFFECT_0, SPELL_EFFECT_DUMMY);
    }
};

void AddSC_dc_races_28_31()
{
    new dc_races_28_31_player();
    RegisterSpellScript(spell_dc_spatial_rift);
    RegisterSpellScript(spell_dc_spatial_rift_teleport);
    RegisterSpellScript(spell_dc_lights_judgment);
    RegisterSpellScript(spell_dc_lights_judgment_strike);
    RegisterSpellScript(spell_dc_lights_reckoning_burst);
    RegisterSpellScript(spell_dc_ancestral_call);
}
