/*
 * DarkChaos-255 Mount Speed: riding skill sets the speed, every bonus applies
 *
 * Stock 3.3.5 takes a mount's speed from the mount spell itself (60/100% ground, 150/280/310% flying). Here
 * it follows the character's Riding skill instead, the way later expansions do it:
 *
 *     Riding   Ground   Flying
 *       75       60%       -
 *      150      100%       -
 *      225      100%     150%
 *      300      100%     280%  (310% once the character knows a 310% flyer, the WotLK rule for scaling mounts)
 *
 * - Only mounts at a standard speed are re-rated: ground 1-100% (60, 100 and the 59/99 Cata trikes), flying
 *   150-310%. Mounts with a speed of their own (Borrowed Broom 170%, test mounts, 0% parade mounts) keep it.
 * - Below 75 riding (ground) or 225 riding (flying) there is no tier and the mount keeps its own speed. Who may
 *   fly at all is still decided elsewhere (mount spell area rules, Cold Weather Flying, the 750/751 licenses).
 * - DC.MountSpeed.RidingSkill: 0 = stock, 1 = raise only (a 60% mount runs 100% with Journeyman, a mount is
 *   never slowed), 2 = follow (also slows a mount the skill does not cover yet, e.g. an account-wide 310%
 *   flyer on a character with Expert Riding).
 *
 * Bonuses. The core combines max(best *_NOT_STACK bonus, product of *_ALWAYS bonuses) * (1 + mount speed), so
 * the Riding Crop, Crusader Aura, On a Pale Horse and Pathfinding (NOT_STACK) are lost as soon as the ALWAYS
 * product is larger: Collector's Speed (DC-Collection, 300510-300513), Scorched / Plague Weather Flying on maps
 * 750/751 (300610/300611, +50%), Mithril Spurs and the mount speed enchants. DC.MountSpeed.StackBonuses = 1
 * multiplies the two groups instead. Within the NOT_STACK group the best one still wins (crop vs Crusader Aura),
 * and the ALWAYS group already multiplied before. A new DC bonus therefore needs no code: give its spell a
 * SPELL_AURA_MOD_MOUNTED_SPEED_ALWAYS (130) / SPELL_AURA_MOD_MOUNTED_FLIGHT_SPEED_ALWAYS (209) effect.
 *
 * Druid flight forms are not mounts and are not touched (Swift Flight Form already needs 300 riding and turns
 * 310% with a 310% flyer in spell_dru_swift_flight_passive).
 *
 * Hook: PlayerScript::OnPlayerCalcMountedSpeed, called from Unit::UpdateSpeed for a mounted player's MOVE_RUN
 * and MOVE_FLIGHT. Applies to playerbots as well.
 */

#include "Config.h"
#include "Player.h"
#include "ScriptMgr.h"
#include "SharedDefines.h"

#include <algorithm>
#include <array>
#include <atomic>

namespace
{
    constexpr char const* CONFIG_RIDING_SKILL = "DC.MountSpeed.RidingSkill";
    constexpr char const* CONFIG_STACK_BONUSES = "DC.MountSpeed.StackBonuses";

    enum RidingSkillMode : uint8
    {
        RIDING_MODE_OFF    = 0,
        RIDING_MODE_RAISE  = 1,
        RIDING_MODE_FOLLOW = 2,
    };

    struct RidingTier
    {
        uint16 Skill;
        int32 Ground;
        int32 Flying;   // 0 = this tier does not fly
    };

    // Highest first: the first tier the skill reaches wins.
    constexpr std::array<RidingTier, 4> RIDING_TIERS =
    {{
        { 300, 100, 280 },  // Artisan Riding (34091)
        { 225, 100, 150 },  // Expert Riding (34090)
        { 150, 100, 0 },    // Journeyman Riding (33391)
        { 75,  60,  0 },    // Apprentice Riding (33388)
    }};

    constexpr int32 SPEED_FLYING_ARTISAN = 280;
    constexpr int32 SPEED_FLYING_310 = 310;

    // The speeds a mount spell carries when it is an ordinary mount of some riding tier.
    constexpr int32 STANDARD_GROUND_MIN = 1;
    constexpr int32 STANDARD_GROUND_MAX = 100;
    constexpr int32 STANDARD_FLYING_MIN = 150;
    constexpr int32 STANDARD_FLYING_MAX = 310;

    // Written on the world thread at config (re)load, read from map threads.
    std::atomic<uint8> sRidingMode{RIDING_MODE_FOLLOW};
    std::atomic<bool> sStackBonuses{true};

    RidingTier const* FindTier(uint16 skill)
    {
        for (RidingTier const& tier : RIDING_TIERS)
            if (skill >= tier.Skill)
                return &tier;

        return nullptr;
    }

    bool IsStandardMountSpeed(UnitMoveType moveType, int32 speed)
    {
        if (moveType == MOVE_FLIGHT)
            return speed >= STANDARD_FLYING_MIN && speed <= STANDARD_FLYING_MAX;

        return speed >= STANDARD_GROUND_MIN && speed <= STANDARD_GROUND_MAX;
    }

    // 0 when the character's riding skill gives no speed for this movement type.
    int32 GetRidingSpeed(Player* player, UnitMoveType moveType)
    {
        RidingTier const* tier = FindTier(player->GetBaseSkillValue(SKILL_RIDING));
        if (!tier)
            return 0;

        if (moveType != MOVE_FLIGHT)
            return tier->Ground;

        if (tier->Flying == SPEED_FLYING_ARTISAN && player->Has310Flyer(false))
            return SPEED_FLYING_310;

        return tier->Flying;
    }

    void RefreshMountedSpeed(Player* player)
    {
        if (!player->IsInWorld() || !player->IsMounted())
            return;

        player->UpdateSpeed(MOVE_RUN, true);
        player->UpdateSpeed(MOVE_FLIGHT, true);
    }

    class DCMountSpeedWorldScript : public WorldScript
    {
    public:
        DCMountSpeedWorldScript() : WorldScript("DCMountSpeedWorldScript", { WORLDHOOK_ON_AFTER_CONFIG_LOAD }) { }

        void OnAfterConfigLoad(bool /*reload*/) override
        {
            uint32 mode = sConfigMgr->GetOption<uint32>(CONFIG_RIDING_SKILL, RIDING_MODE_FOLLOW);
            if (mode > RIDING_MODE_FOLLOW)
                mode = RIDING_MODE_FOLLOW;

            sRidingMode = static_cast<uint8>(mode);
            sStackBonuses = sConfigMgr->GetOption<bool>(CONFIG_STACK_BONUSES, true);
        }
    };

    class DCMountSpeedPlayerScript : public PlayerScript
    {
    public:
        DCMountSpeedPlayerScript() : PlayerScript("DCMountSpeedPlayerScript",
        {
            PLAYERHOOK_ON_CALC_MOUNTED_SPEED, PLAYERHOOK_ON_SET_SKILL, PLAYERHOOK_ON_LEARN_SPELL
        }) { }

        void OnPlayerCalcMountedSpeed(Player* player, UnitMoveType moveType, int32& mountSpeedMod,
            float& stackBonus, float& nonStackBonus) override
        {
            uint8 const mode = sRidingMode;
            if (mode != RIDING_MODE_OFF && IsStandardMountSpeed(moveType, mountSpeedMod))
            {
                if (int32 const ridingSpeed = GetRidingSpeed(player, moveType))
                {
                    if (mode == RIDING_MODE_FOLLOW)
                        mountSpeedMod = ridingSpeed;
                    else
                        mountSpeedMod = std::max(mountSpeedMod, ridingSpeed);
                }
            }

            // The core takes the larger of the two; returning the product in both makes every bonus count.
            if (sStackBonuses)
            {
                float const combined = stackBonus * nonStackBonus;
                stackBonus = combined;
                nonStackBonus = combined;
            }
        }

        // A riding rank learned (or unlearned) while mounted takes effect at once instead of at the next mount.
        void OnPlayerSetSkill(Player* player, uint32 skillId, uint32 /*value*/, uint32 /*max*/, uint32 /*step*/,
            uint32 /*newValue*/) override
        {
            if (skillId == SKILL_RIDING && sRidingMode != RIDING_MODE_OFF)
                RefreshMountedSpeed(player);
        }

        // Learning the first 310% flyer while riding a 280% one.
        void OnPlayerLearnSpell(Player* player, uint32 /*spellId*/) override
        {
            if (sRidingMode != RIDING_MODE_OFF && player->Has310Flyer(false))
                RefreshMountedSpeed(player);
        }
    };
}

void AddSC_dc_mount_speed()
{
    new DCMountSpeedWorldScript();
    new DCMountSpeedPlayerScript();
}
