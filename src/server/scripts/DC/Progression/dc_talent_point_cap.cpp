/*
 * DarkChaos: optional ceiling on class talent points.
 *
 * The core hands out one talent point per level from 10 with no upper limit,
 * so a level-160 character has 151 points and a level-255 character 246 --
 * more than the three trees hold, although they were designed around the 71
 * points of a level-80 character. DC.Talents.MaxPoints stops the count at a
 * chosen number; 0 (the default) leaves the stock behaviour untouched.
 *
 * The ceiling applies to the total the core computed, bonus points from quest
 * rewards included. A character holding more spent points than the ceiling is
 * reset by the core the next time its talent points are recalculated (login,
 * level change), free of charge.
 *
 * DC.Talents.PetMaxPoints does the same for hunter pets. A pet gets one point
 * per 4 levels from 20 ((level - 16) / 4: 16 at 80, 36 at 160), plus 4 from
 * the owner's Beast Mastery. The cap applies to the level part only, so Beast
 * Mastery's 4 stay on top. Playerbot pet templates stop at 20 points; a cap of
 * 20 keeps every bot pet's spent points valid (16 would reset the pets of
 * hunters without Beast Mastery, which the templates filled to 20).
 */

#include "Config.h"
#include "Pet.h"
#include "Player.h"
#include "ScriptMgr.h"
#include "SpellAuraDefines.h"
#include <algorithm>
#include <atomic>

namespace
{
    // Written on the world thread at config (re)load, read on map threads.
    std::atomic<uint32> s_maxTalentPoints{0};
    std::atomic<uint32> s_maxPetTalentPoints{0};
}

class dc_talent_point_cap_world : public WorldScript
{
public:
    dc_talent_point_cap_world() : WorldScript("dc_talent_point_cap_world", { WORLDHOOK_ON_AFTER_CONFIG_LOAD }) { }

    void OnAfterConfigLoad(bool /*reload*/) override
    {
        s_maxTalentPoints = sConfigMgr->GetOption<uint32>("DC.Talents.MaxPoints", 0);
        s_maxPetTalentPoints = sConfigMgr->GetOption<uint32>("DC.Talents.PetMaxPoints", 0);
    }
};

class dc_talent_point_cap_player : public PlayerScript
{
public:
    dc_talent_point_cap_player() : PlayerScript("dc_talent_point_cap_player",
        { PLAYERHOOK_ON_CALCULATE_TALENTS_POINTS }) { }

    void OnPlayerCalculateTalentsPoints(Player const* /*player*/, uint32& talentPointsForLevel) override
    {
        uint32 maxPoints = s_maxTalentPoints;
        if (maxPoints && talentPointsForLevel > maxPoints)
            talentPointsForLevel = maxPoints;
    }
};

class dc_talent_point_cap_pet : public PetScript
{
public:
    dc_talent_point_cap_pet() : PetScript("dc_talent_point_cap_pet",
        { PETHOOK_ON_CALCULATE_MAX_TALENT_POINTS_FOR_LEVEL }) { }

    // `points` arrives as the level part plus the owner's SPELL_AURA_MOD_PET_TALENT_POINTS (Beast Mastery).
    void OnCalculateMaxTalentPointsForLevel(Pet* pet, uint8 /*level*/, uint8& points) override
    {
        uint32 maxPoints = s_maxPetTalentPoints;
        if (!maxPoints || !pet)
            return;

        int32 bonus = 0;
        if (Unit* owner = pet->GetOwner())
            bonus = owner->GetTotalAuraModifier(SPELL_AURA_MOD_PET_TALENT_POINTS);

        int32 levelPoints = int32(points) - bonus;
        if (levelPoints > int32(maxPoints))
            points = uint8(std::clamp<int32>(int32(maxPoints) + bonus, 0, 255));
    }
};

void AddSC_dc_talent_point_cap()
{
    new dc_talent_point_cap_world();
    new dc_talent_point_cap_player();
    new dc_talent_point_cap_pet();
}
