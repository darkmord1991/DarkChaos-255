/*
 * Dark Chaos - Playable Worgen (12) & Goblin (9) support (Worgoblin port)
 * =======================================================================
 *
 * Server-side scripts for the two custom playable races, ported from
 * mod-worgoblin (https://github.com/evrydayjunglist/mod-worgoblin).
 *
 * Everything else about the races is data-driven (ChrRaces/CharBaseInfo/
 * CharSections/CharStartOutfit/SkillRaceClassInfo DBCs + playercreateinfo*
 * world tables, see Custom/Custom feature SQLs/worlddb/Worgoblin/):
 *  - RaceMgr picks the races up dynamically from ChrRaces.dbc.
 *  - DC-FirstStart heirlooms/start handling is class-keyed and works as-is.
 *
 * This file only covers the two racials that need code:
 *  - Best Deals Anywhere (69044): goblin vendor discount.
 *  - Rocket Barrage (69041): damage scaling (level + SP/AP coefficients).
 */

#include "Player.h"
#include "ScriptMgr.h"
#include "SpellScript.h"

enum WorgoblinSpells
{
    SPELL_BEST_DEALS_ANYWHERE = 69044
};

class dc_worgoblin_player : public PlayerScript
{
public:
    dc_worgoblin_player() : PlayerScript("dc_worgoblin_player") { }

    void OnPlayerGetReputationPriceDiscount(Player const* player, FactionTemplateEntry const* factionTemplate, float& discount) override
    {
        if (!factionTemplate || !factionTemplate->faction)
            return;

        // Goblin racial: Best Deals Anywhere - always the best vendor discount
        if (player->HasSpell(SPELL_BEST_DEALS_ANYWHERE))
            discount *= 0.8f;
    }
};

class spell_rocket_barrage : public SpellScript
{
    PrepareSpellScript(spell_rocket_barrage);

    void HandleDamage(SpellEffIndex /*effIndex*/)
    {
        Unit* caster = GetCaster();
        int32 basePoints = caster->GetLevel() * 2;
        basePoints += caster->SpellBaseDamageBonusDone(GetSpellInfo()->GetSchoolMask()) * 0.429f;
        basePoints += caster->GetTotalAttackPowerValue(caster->getClass() != CLASS_HUNTER ? BASE_ATTACK : RANGED_ATTACK) * 0.25f;
        SetEffectValue(basePoints);
    }

    void Register() override
    {
        OnEffectLaunchTarget += SpellEffectFn(spell_rocket_barrage::HandleDamage, EFFECT_0, SPELL_EFFECT_SCHOOL_DAMAGE);
    }
};

void AddSC_dc_worgoblin()
{
    new dc_worgoblin_player();
    RegisterSpellScript(spell_rocket_barrage);
}
