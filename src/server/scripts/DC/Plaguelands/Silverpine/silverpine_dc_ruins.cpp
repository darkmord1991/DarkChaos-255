/*
 * This file is part of the AzerothCore Project. See AUTHORS file for Copyright information
 *
 * This program is free software; you can redistribute it and/or modify it
 * under the terms of the GNU Affero General Public License as published by the
 * Free Software Foundation; either version 3 of the License, or (at your
 * option) any later version.
 *
 * This program is distributed in the hope that it will be useful, but WITHOUT
 * ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
 * FITNESS FOR A PARTICULAR PURPOSE. See the GNU Affero General Public License for
 * more details.
 *
 * You should have received a copy of the GNU Affero General Public License along
 * with this program. If not, see <http://www.gnu.org/licenses/>.
 */

// Silverpine Forest on map 751, slice "ruins": the Ruins of Gilneas guardians, the guardian
// summon PlayerScript, Arthura's escape flight, the "Rise, Godfrey" cutscene and Archmage
// Ataeric's "Transdimensional Warfare: Chapter III" event.
//
// Ported from Project Neltharion 4.3.4 zone_silverpine_forest.cpp, lines 2655-3571. The
// matching data (templates, texts, quest relations, SummonProperties 3045) is the pending
// world SQL that ships with this file; read its header for what exists and what does not.
//
// Deliberate deviations from the source, each because the source cannot work here or is
// visibly broken:
//  - Map 751 bakes ONE area id per zone into the terrain (area == zone), so the source's
//    sub-area checks (5387/5456/204/5480) are position boxes taken from cata_world's own
//    spawn extents of those areas. Zone 4706 (Ruins of Gilneas) is 4939 here, 130 is 4935.
//  - Spells 85073 (summon Arthura's vehicle) and 85150 (summon the Rise Godfrey scene) are in
//    no client and no overlay; they were cast by SmartAI of NPCs not in this slice. The
//    PlayerScript summons both NPCs on quest accept instead, and summons the ruins guardians
//    on accepting 27406/27423 the way 45312's SmartAI did (the player is already inside
//    zone 4939 at the Forward Command, so no zone change would ever fire).
//  - Neltharion-custom 151235 (dismount) has no handler here: done with RemoveAurasByType.
//  - 85198/85200/85201 transform into creatures 44370/45673/45674, which do not exist here,
//    and an unresolved transform turns the target into a pig. The risen lords take their
//    Forsaken displays (34611/34610/34612, the ones the Shadowfang Keep copy uses) directly.
//    The source also swapped Walden's and Ashbury's transforms (wrong enum names); fixed.
//  - Guardian summon auras outlive their guardian (death, logout). A stale aura (aura up,
//    no live guardian of that entry) is removed before the source's "no aura" check, and
//    each missing guardian is summoned on its own.
//  - Ataeric: kills are counted from SummonedCreatureDies, not from the fiends' SmartAI ping
//    (98914), which targets entry 2120 and would never find the 751 Ataeric. The source's
//    "no player within 50 yd -> reset" sat behind an `else if (_phase = 5)` and could never
//    run; it is a plain check now. Kill thresholds use >= so a burst of kills between two
//    7 s checks cannot strand the event. Portals are despawned when he dies.

#include "CellImpl.h"
#include "CombatAI.h"
#include "CreatureScript.h"
#include "DBCStores.h"
#include "GridNotifiers.h"
#include "MotionMaster.h"
#include "ObjectAccessor.h"
#include "ObjectMgr.h"
#include "Player.h"
#include "PlayerScript.h"
#include "QuestDef.h"
#include "ScriptedCreature.h"
#include "SpellAuraDefines.h"
#include "TemporarySummon.h"
#include "Vehicle.h"
#include "silverpine_dc.h"
#include <array>
#include <initializer_list>
#include <list>

using namespace SilverpineDC;

namespace SilverpineRuins
{
    // Ruins of Gilneas on 751 (the 751 copy of Cata zone 4706).
    constexpr uint32 ZONE_RUINS_OF_GILNEAS_751 = 4939;

    enum RuinsSpells : uint32
    {
        // file-wide (source lines 42-58)
        SPELL_SANCTUARY_NO_COMBAT        = 88467,

        // AgathaDatas, shared with Arthura (source lines 1131-1133)
        SPELL_DOOMHOWL                   = 84012,
        SPELL_UNHOLY_SMITE               = 84014,
        SPELL_UNHOLY_DARKNESS            = 84013,

        // ArthuraDatas / BelmontDatas
        SPELL_SUMMON_ARTHURA1_AURA       = 84941,
        SPELL_SUMMON_BELMONT_AURA        = 84944,
        SPELL_FANOFKNIFES                = 79584,
        SPELL_SHADOWSTEP                 = 78638,
        SPELL_BACKSTAB                   = 76520,

        // BattlefrontSummons
        SPELL_BATTLEFRONT_SUMMON_GODFREY = 85517,
        SPELL_BATTLEFRONT_SUMMON_WALDEN  = 85518,
        SPELL_BATTLEFRONT_SUMMON_ASHBURY = 85519,

        // ArthuraFlight2Datas
        SPELL_FREEZE_ANIM                = 93199,

        // RiseGodfrey
        SPELL_RISE_FORSAKEN_3            = 85197,
        SPELL_FORSAKEN_EXPLODE           = 81876,
        SPELL_PERMANENT_FEIGN_DEATH      = 29266,

        // Transdimentional3
        SPELL_SUMMON_ARCANE_FIEND        = 87253,
        SPELL_ARCANE_SHIELD              = 87251,
        SPELL_SUICIDE                    = 87255,
        SPELL_ZERO_POWER                 = 87239,
        SPELL_DIMENSIONAL_BEAM           = 85373,
        SPELL_DIMENSIONAL_COLLAPSE       = 85400,
        SPELL_SELF_STUN                  = 85379,
    };

    enum RuinsQuests : uint32
    {
        QUEST_A_MAN_NAMED_GODFREY        = 27406,
        QUEST_RESISTANCE_IS_FUTILE       = 27423,
        QUEST_GREAT_ESCAPE               = 27438,
        QUEST_RISE_GODFREY               = 27472,
        QUEST_TRANSDIMENSIONAL_3         = 27518,
        QUEST_TAKING_BATTLEFRONT         = 27542,
        QUEST_ON_HER_MAJESTY             = 27594,
    };

    // Every creature below is summoned (by spell or by this file), so it lives at its PLAIN
    // Cata entry, the id the summon spell names (see silverpine_dc.h). Ataeric is the only
    // spawned one and sits in the +4,100,000 band.
    enum RuinsCreatures : uint32
    {
        // spell-summoned guardians (84941 / 84944)
        NPC_ARTHURA_GUARDIAN             = 45473,
        NPC_BELMONT_GUARDIAN             = 45474,

        // spell-summoned battlefront guardians (85517-85519); their AIs live in the
        // battlefront slice, this file only summons them and checks they are alive
        NPC_BATTLEFRONT_GODFREY          = 45878,
        NPC_BATTLEFRONT_WALDEN           = 45879,
        NPC_BATTLEFRONT_ASHBURY          = 45880,

        // ArthuraFlight2Datas
        NPC_ARTHURA_VEHICLE              = 45555,
        NPC_GODFREY_1                    = 45556,
        NPC_BELMONT_2                    = 45557,

        // RiseGodfrey. The source's names for 45606-45610 were shuffled (its NPC_GODFREY_3 is
        // 45608, which is Lord Walden in every DB). The ids are kept; the names here are the
        // creatures' real names.
        NPC_HIGH_WARLORD_CROMUSH_3       = 45612,
        NPC_LADY_SYLVANAS_3              = 45605,
        NPC_GODFREY_3                    = 45606,    // source: NPC_ASHBURY_3
        NPC_ASHBURY_3                    = 45607,    // source: NPC_WALDEN_3
        NPC_WALDEN_3                     = 45608,    // source: NPC_GODFREY_3
        NPC_VALKYR_AGATHA_3              = 45609,    // source: NPC_VALKYR_DASCHLA_3
        NPC_VALKYR_DASCHLA_3             = 45610,    // source: NPC_VALKYR_AGATHA_3
        NPC_VALKYR_ARTHURA_3             = 45611,
        NPC_CREDIT_RISE_GODFREY          = 45617,

        // Transdimentional3
        NPC_CREDIT_TRANSDIMENTIONAL_3    = 45769,
        NPC_TRANSDIMENTIONAL_PORTAL      = 45764,
        NPC_ARCANE_FIENDS                = 45766,
    };

    // Displays the risen lords take instead of the missing transform creatures.
    enum RuinsDisplays : uint32
    {
        DISPLAY_GODFREY_FORSAKEN         = 34611,
        DISPLAY_ASHBURY_FORSAKEN         = 34610,
        DISPLAY_WALDEN_FORSAKEN          = 34612,
    };

    // Source enum SilverpineEvents (lines 60-174): ids kept identical.
    enum RuinsEvents : uint32
    {
        EVENT_DOOMHOWL                   = 11,
        EVENT_UNHOLY_SMITE               = 12,
        EVENT_FANOFKNIFES                = 37,
        EVENT_SHADOWSTEP                 = 38,
        EVENT_ARTHURA_FLIGHT_1           = 39,
        EVENT_RISE_GODFREY_1             = 40,
        EVENT_RISE_GODFREY_2             = 41,
        EVENT_RISE_GODFREY_3             = 42,
        EVENT_RISE_GODFREY_4             = 43,
        EVENT_RISE_GODFREY_5             = 44,
        EVENT_ATAERIC_1                  = 45,
        EVENT_ATAERIC_2                  = 46,
        EVENT_ATAERIC_3                  = 47,
        EVENT_ATAERIC_4                  = 48,
        EVENT_ATAERIC_5                  = 49,
        EVENT_ATAERIC_6                  = 50,
    };

    enum RuinsMisc : uint32
    {
        POINT_SYLVANAS_END               = 1,
        DATA_RISEN_WALK_AWAY             = 1,    // SetData(1, 1) on the risen lords (their SmartAI)
        SEAT_ARTHURA_PLAYER              = 0,
        SEAT_ARTHURA_GODFREY             = 1,
    };

    constexpr uint32 SCENE_DESPAWN_MS = 300000;  // TEMPSUMMON_TIMED_DESPAWN of every scene actor (source value)

    // Arthura's escape flight (source lines 2993-3025).
    uint32 const Arthura2PathSize = 2;
    G3D::Vector3 const Arthura2Path[Arthura2PathSize] =
    {
        { -2117.14111f, 934.15802f, 34.3799f },
        { -2112.79248f, 935.61163f, 82.1235f },
    };

    uint32 const Arthura2PathSize2 = 22;
    G3D::Vector3 const Arthura2Path2[Arthura2PathSize2] =
    {
        { -2047.9951f, 937.7509f, 96.253f },
        { -1927.1787f, 931.2210f, 94.633f },
        { -1819.4152f, 975.2877f, 95.355f },
        { -1803.6243f, 1100.201f, 68.498f },
        { -1584.2254f, 1154.681f, 70.298f },
        { -1473.6402f, 1156.272f, 67.251f },
        { -1368.7523f, 1217.753f, 62.740f },
        { -1333.5772f, 1407.356f, 69.552f },
        { -1309.2415f, 1610.949f, 74.944f },
        { -1245.4510f, 1698.926f, 71.858f },
        { -1193.0434f, 1697.864f, 65.810f },
        { -1108.6926f, 1638.513f, 71.605f },
        { -993.50024f, 1576.868f, 65.549f },
        { -904.35955f, 1559.486f, 77.697f },
        { -825.77f, 1533.27f, 108.76f },
        { -745.71f, 1521.80f, 121.70f },
        { -651.12152f, 1494.841f, 93.887f },
        { -504.50476f, 1409.479f, 92.689f },
        { -410.55331f, 1316.347f, 85.182f },
        { -301.21499f, 1236.661f, 75.684f },
        { -254.06637f, 1246.742f, 79.608f },
        { -193.93673f, 1274.894f, 44.025f },
    };

    uint32 const ARTHURA_INTRO_LAST_POINT = Arthura2PathSize - 1;     // source: point == 1
    uint32 const ARTHURA_FLIGHT_LAST_POINT = Arthura2PathSize2 - 1;   // source: point == 21

    Position const GodfreyEscapePos  = { -2121.17f, 931.86f, 1.727f, 5.72f };
    Position const BelmontEscapePos  = { -2122.47f, 930.82f, 1.76f, 0.62f };

    // Where 85150 put the scene: the spot of the quest giver 45525 (nelt_world guid 221459).
    Position const RiseGodfreyScenePos = { -182.658f, 1275.42f, 46.5371f, 3.12414f };

    Position const CromushScenePos   = { -180.199f, 1280.599f, 45.91f, 3.1241f };
    Position const DaschlaScenePos   = { -193.287f, 1282.369f, 47.624f, 3.83f };    // 45610
    Position const AgathaScenePos    = { -194.350f, 1269.229f, 49.918f, 2.19f };    // 45609
    Position const ArthuraScenePos   = { -203.306f, 1275.540f, 45.580f, 6.19f };    // 45611
    Position const GodfreyScenePos   = { -197.397f, 1279.18f, 39.64f, 5.2f };       // 45606
    Position const WaldenScenePos    = { -198.326f, 1271.95f, 40.90f, 0.8f };       // 45608
    Position const AshburyScenePos   = { -198.587f, 1275.18f, 40.07f, 0.0f };       // 45607
    Position const SylvanasEndPos    = { -153.32f, 1270.27f, 51.54f, 3.07f };

    Position const AtaericPortal1Pos = { -135.48f, 1078.66f, 71.92f, 0.0f };
    Position const AtaericPortal2Pos = { -124.840f, 1077.902f, 76.219f, 0.0f };
    Position const AtaericPortal3Pos = { -145.70f, 1079.026f, 76.218f, 0.0f };
    Position const AtaericPortal4Pos = { -154.29f, 1078.265f, 82.811f, 0.0f };
    Position const AtaericPortal5Pos = { -119.86f, 1073.604f, 82.842f, 0.0f };
    Position const AtaericPortal6Pos = { -154.700f, 1077.630f, 68.606f, 0.0f };
    Position const AtaericPortal7Pos = { -115.630f, 1078.355f, 68.604f, 0.0f };

    // Source zone 130 areas 5387 (The Forsaken Front), 5456 (The Battlefront), 204 (Pyrewood
    // Village) and 5480 (Gilneas Liberation Front Base Camp). 751 reports area == zone, so
    // these are boxes: cata_world map-0 spawn extents of those areas plus 25 yd. 204 and 5480
    // lie entirely inside the Battlefront box.
    struct AreaBox
    {
        float MinX;
        float MaxX;
        float MinY;
        float MaxY;
    };

    AreaBox const BattlefrontAreas[] =
    {
        { -323.0f, 16.0f, 1158.0f, 1400.0f },       // 5387 The Forsaken Front
        { -1299.0f, -319.0f, 1135.0f, 1842.0f },    // 5456 The Battlefront (+ 204, 5480)
    };

    static bool IsInBattlefrontArea(WorldObject const* who)
    {
        float const x = who->GetPositionX();
        float const y = who->GetPositionY();
        for (AreaBox const& box : BattlefrontAreas)
            if (x >= box.MinX && x <= box.MaxX && y >= box.MinY && y <= box.MaxY)
                return true;

        return false;
    }

    // 4.3.4 WorldObject::GetPlayersInRange(range, alive) is gone; same shim as
    // DC/MountHyjal/zone_molten_front.cpp.
    static std::list<Player*> GetPlayersInRange(WorldObject* who, float range)
    {
        std::list<Player*> players;
        Acore::AnyPlayerInObjectRangeCheck checker(who, range, true);
        Acore::PlayerListSearcher<Acore::AnyPlayerInObjectRangeCheck> searcher(who, players, checker);
        Cell::VisitObjects(who, searcher, range);
        return players;
    }

    // Quest objectives for 27472 / 27518 cannot be read: neither quest is in acore_world yet.
    // The source credits the plain id; a later import may remap it to the 751 band like many
    // other objectives were, so both are credited. Crediting an entry no active objective names
    // changes nothing.
    static void CreditPlainAnd751(Player* player, uint32 cataEntry)
    {
        player->KilledMonsterCredit(cataEntry);
        player->KilledMonsterCredit(Creature751(cataEntry));
    }

    static void DespawnCreaturesInRange(Creature* me, uint32 entry, float range)
    {
        std::list<Creature*> creatures;
        me->GetCreatureListWithEntryInGrid(creatures, entry, range);
        for (Creature* creature : creatures)
            creature->DespawnOrUnsummon();
    }

    static bool HasLiveGuardian(Player* player, uint32 entry)
    {
        for (Unit* controlled : player->m_Controlled)
            if (controlled->GetEntry() == entry && controlled->IsAlive())
                return true;

        return false;
    }
}

using namespace SilverpineRuins;

// ######################### RUINS OF GILNEAS GUARDIANS #########################

// Shared body of npc_arthura_ruins and npc_belmont_guardian: the source duplicates it with
// only the follow angle, the summon aura and the ability set differing.
struct npc_silverpine_ruins_guardianAI : public ScriptedAI
{
    npc_silverpine_ruins_guardianAI(Creature* creature, uint32 summonAura, float followAngle)
        : ScriptedAI(creature), _summonAura(summonAura), _followAngle(followAngle) { }

    void IsSummonedBy(WorldObject* summoner) override
    {
        me->SetReactState(REACT_PASSIVE);

        if (Player* player = summoner->ToPlayer())
            _playerGUID = player->GetGUID();
    }

    void DamageTaken(Unit* attacker, uint32& /*damage*/, DamageEffectType /*damagetype*/,
        SpellSchoolMask /*damageSchoolMask*/) override
    {
        Unit* owner = me->GetOwner();
        if (attacker && owner && !owner->GetVictim())
            AttackStart(attacker);
    }

    void JustEngagedWith(Unit* /*who*/) override
    {
        if (me->GetReactState() == REACT_AGGRESSIVE && me->IsInCombat())
            ScheduleAbilities();
        else
            _events.Reset();
    }

    void UpdateAI(uint32 diff) override
    {
        scheduler.Update(diff);

        if (_checkTimer <= diff)
        {
            _checkTimer = 500;
            CheckOwner();
        }
        else
            _checkTimer -= diff;

        if (!UpdateVictim())
            return;

        OnCombatUpdate();

        _events.Update(diff);

        if (me->HasUnitState(UNIT_STATE_CASTING))
            return;

        while (uint32 eventId = _events.ExecuteEvent())
            ExecuteAbility(eventId);

        DoMeleeAttackIfReady();
    }

protected:
    virtual void ScheduleAbilities() = 0;
    virtual void ExecuteAbility(uint32 eventId) = 0;
    virtual void OnCombatUpdate() { }

    Player* GetSummoner() const { return ObjectAccessor::GetPlayer(*me, _playerGUID); }

    EventMap _events;

private:
    void DespawnAndDropAura(Player* player)
    {
        player->RemoveAurasDueToSpell(_summonAura);
        me->DespawnOrUnsummon();
    }

    void CheckOwner()
    {
        Player* player = GetSummoner();
        if (!player)
            return;

        Unit* owner = me->GetOwner();
        if (!owner || !owner->IsAlive())
        {
            DespawnAndDropAura(player);
            return;
        }

        QuestStatus const godfrey = player->GetQuestStatus(QUEST_A_MAN_NAMED_GODFREY);
        QuestStatus const futile = player->GetQuestStatus(QUEST_RESISTANCE_IS_FUTILE);
        if ((godfrey == QUEST_STATUS_NONE && futile == QUEST_STATUS_NONE) ||
            (godfrey == QUEST_STATUS_REWARDED && futile == QUEST_STATUS_REWARDED))
        {
            DespawnAndDropAura(player);
            return;
        }

        Unit* playerVictim = player->GetVictim();
        if (!me->GetVictim() && me->GetReactState() != REACT_AGGRESSIVE && playerVictim && player->IsInCombat())
        {
            me->SetReactState(REACT_AGGRESSIVE);
            AttackStart(playerVictim);
        }

        if (me->GetReactState() != REACT_PASSIVE && !playerVictim && !player->IsInCombat())
        {
            me->SetReactState(REACT_PASSIVE);
            DoCastSelf(SPELL_SANCTUARY_NO_COMBAT, true);
            me->RemoveUnitFlag(UNIT_FLAG_PET_IN_COMBAT);
            me->GetMotionMaster()->MoveFollow(player, 1.0f, _followAngle);
        }

        if (!_isFollowing)
        {
            me->GetMotionMaster()->MoveFollow(player, 1.0f, _followAngle);
            _isFollowing = true;
        }
    }

    uint32 const _summonAura;
    float const _followAngle;
    ObjectGuid _playerGUID;
    uint32 _checkTimer = 500;
    bool _isFollowing = false;
};

// 45473 Arthura, summoned by 84941 for 27406 / 27423 (source lines 2663-2797)
struct npc_arthura_ruins : public npc_silverpine_ruins_guardianAI
{
    npc_arthura_ruins(Creature* creature)
        : npc_silverpine_ruins_guardianAI(creature, SPELL_SUMMON_ARTHURA1_AURA, 1.3f * float(M_PI)) { }

protected:
    void ScheduleAbilities() override
    {
        _events.ScheduleEvent(EVENT_DOOMHOWL, 4s, 8s);
        _events.ScheduleEvent(EVENT_UNHOLY_SMITE, 1s, 4s);
    }

    void OnCombatUpdate() override
    {
        Player* player = GetSummoner();
        if (!player)
            return;

        if (player->GetHealthPct() <= 35.0f && !_lowHP)
        {
            // The source reset the rotation here and never restarted it; restart it after the heal.
            _events.Reset();
            DoCast(player, SPELL_UNHOLY_DARKNESS);
            ScheduleAbilities();
            _lowHP = true;
        }

        if (player->GetHealthPct() >= 36.0f && _lowHP)
            _lowHP = false;
    }

    void ExecuteAbility(uint32 eventId) override
    {
        switch (eventId)
        {
            case EVENT_DOOMHOWL:
                if (Unit* victim = me->GetVictim())
                    DoCast(victim, SPELL_DOOMHOWL);
                _events.ScheduleEvent(EVENT_DOOMHOWL, 12s, 25s);
                break;
            case EVENT_UNHOLY_SMITE:
                if (Unit* victim = me->GetVictim())
                    DoCast(victim, SPELL_UNHOLY_SMITE);
                _events.ScheduleEvent(EVENT_UNHOLY_SMITE, 3s, 7s);
                break;
            default:
                break;
        }
    }

private:
    bool _lowHP = false;
};

// 45474 Deathstalker Commander Belmont, summoned by 84944 (source lines 2807-2934). Also the
// quest ender of 27406 / 27423 and starter of 27438 (npcflag 2, relations in the SQL).
// The source cast 93425 "Update Zone Auras" on the player while 27406 was complete and 49416
// was missing, to refresh Cata's phase auras. 93425 has no effect here and 751 has no phases,
// so that call is left out.
struct npc_belmont_guardian : public npc_silverpine_ruins_guardianAI
{
    npc_belmont_guardian(Creature* creature)
        : npc_silverpine_ruins_guardianAI(creature, SPELL_SUMMON_BELMONT_AURA, 0.7f * float(M_PI)) { }

protected:
    void ScheduleAbilities() override
    {
        _events.ScheduleEvent(EVENT_FANOFKNIFES, 4s, 8s);
        _events.ScheduleEvent(EVENT_SHADOWSTEP, 1s, 4s);
    }

    void ExecuteAbility(uint32 eventId) override
    {
        switch (eventId)
        {
            case EVENT_FANOFKNIFES:
                DoCastSelf(SPELL_FANOFKNIFES);
                _events.ScheduleEvent(EVENT_FANOFKNIFES, 6s, 11s);
                break;
            case EVENT_SHADOWSTEP:
                if (Unit* victim = me->GetVictim())
                {
                    DoCast(victim, SPELL_SHADOWSTEP);

                    // source: CastWithDelay(1000, victim, SPELL_BACKSTAB)
                    ObjectGuid const victimGuid = victim->GetGUID();
                    scheduler.Schedule(1s, [this, victimGuid](TaskContext /*context*/)
                    {
                        if (Unit* target = ObjectAccessor::GetUnit(*me, victimGuid))
                            if (target->IsAlive())
                                DoCast(target, SPELL_BACKSTAB);
                    });
                }
                _events.ScheduleEvent(EVENT_SHADOWSTEP, 4s, 12s);
                break;
            default:
                break;
        }
    }
};

// ######################### GUARDIAN SUMMONS #########################

// Source lines 2945-2982. Hooks: OnUpdateZone -> OnPlayerUpdateZone, plus OnPlayerUpdateArea
// (the source read area ids from the zone hook) and OnPlayerQuestAccept, which replaces the
// quest-accept SmartAI casts (45312 / 45525) whose spells do not exist here.
class playerscript_silverpine_quest_guardian_summons : public PlayerScript
{
public:
    playerscript_silverpine_quest_guardian_summons() : PlayerScript("playerscript_silverpine_quest_guardian_summons",
        { PLAYERHOOK_ON_UPDATE_ZONE, PLAYERHOOK_ON_UPDATE_AREA, PLAYERHOOK_ON_PLAYER_QUEST_ACCEPT }) { }

    void OnPlayerUpdateZone(Player* player, uint32 newZone, uint32 /*newArea*/) override
    {
        HandleGuardians(player, newZone);
    }

    void OnPlayerUpdateArea(Player* player, uint32 /*oldArea*/, uint32 /*newArea*/) override
    {
        HandleGuardians(player, player->GetZoneId());
    }

    void OnPlayerQuestAccept(Player* player, Quest const* quest) override
    {
        if (player->GetMapId() != MAP_LORDAERON_751)
            return;

        switch (quest->GetQuestId())
        {
            case QUEST_A_MAN_NAMED_GODFREY:
            case QUEST_RESISTANCE_IS_FUTILE:
                HandleGuardians(player, player->GetZoneId());
                break;
            case QUEST_GREAT_ESCAPE:
                SummonEscapeFlight(player);
                break;
            case QUEST_RISE_GODFREY:
                player->SummonCreature(NPC_LADY_SYLVANAS_3, RiseGodfreyScenePos, TEMPSUMMON_TIMED_DESPAWN,
                    SCENE_DESPAWN_MS);
                break;
            default:
                break;
        }
    }

private:
    struct GuardianSummon
    {
        uint32 Spell;
        uint32 Entry;
    };

    // Summon every guardian of the set whose aura is missing. An aura whose guardian is gone
    // (died, owner relogged) is stale and is dropped first so the guardian comes back.
    static void SummonMissing(Player* player, std::initializer_list<GuardianSummon> guardians)
    {
        for (GuardianSummon const& guardian : guardians)
            if (player->HasAura(guardian.Spell) && !HasLiveGuardian(player, guardian.Entry))
                player->RemoveAurasDueToSpell(guardian.Spell);

        for (GuardianSummon const& guardian : guardians)
            if (!player->HasAura(guardian.Spell))
                player->CastSpell(player, guardian.Spell, true);
    }

    static void HandleGuardians(Player* player, uint32 zoneId)
    {
        if (player->GetMapId() != MAP_LORDAERON_751 || !player->IsInWorld() || !player->IsAlive())
            return;

        if (zoneId == ZONE_RUINS_OF_GILNEAS_751)
        {
            QuestStatus const godfrey = player->GetQuestStatus(QUEST_A_MAN_NAMED_GODFREY);
            QuestStatus const futile = player->GetQuestStatus(QUEST_RESISTANCE_IS_FUTILE);
            if (godfrey == QUEST_STATUS_INCOMPLETE || godfrey == QUEST_STATUS_COMPLETE ||
                futile == QUEST_STATUS_COMPLETE || futile == QUEST_STATUS_INCOMPLETE)
            {
                SummonMissing(player, {
                    { SPELL_SUMMON_BELMONT_AURA, NPC_BELMONT_GUARDIAN },
                    { SPELL_SUMMON_ARTHURA1_AURA, NPC_ARTHURA_GUARDIAN } });
            }
        }
        else if (zoneId == ZONE_SILVERPINE_751 && IsInBattlefrontArea(player))
        {
            if (player->GetQuestStatus(QUEST_ON_HER_MAJESTY) == QUEST_STATUS_REWARDED)
                return;

            if (player->GetQuestStatus(QUEST_TAKING_BATTLEFRONT) == QUEST_STATUS_REWARDED)
            {
                SummonMissing(player, {
                    { SPELL_BATTLEFRONT_SUMMON_GODFREY, NPC_BATTLEFRONT_GODFREY },
                    { SPELL_BATTLEFRONT_SUMMON_WALDEN, NPC_BATTLEFRONT_WALDEN },
                    { SPELL_BATTLEFRONT_SUMMON_ASHBURY, NPC_BATTLEFRONT_ASHBURY } });
            }
        }
    }

    // Stands in for 85073. The flight needs Vehicle 1119 (seats 8562/8563) in BOTH the server
    // and the client Vehicle/VehicleSeat.dbc; an unknown vehicle hangs the client. Until the
    // template carries a VehicleId the server resolves, nothing is summoned.
    static void SummonEscapeFlight(Player* player)
    {
        CreatureTemplate const* vehicleTemplate = sObjectMgr->GetCreatureTemplate(NPC_ARTHURA_VEHICLE);
        if (!vehicleTemplate || !vehicleTemplate->VehicleId || !sVehicleStore.LookupEntry(vehicleTemplate->VehicleId))
            return;

        player->SummonCreature(NPC_ARTHURA_VEHICLE, *player, TEMPSUMMON_MANUAL_DESPAWN);
    }
};

// ######################### THE GREAT ESCAPE #########################

// 45555 Arthura, quest 27438 (source lines 3027-3161)
struct npc_arthura_flight_escape : public VehicleAI
{
    npc_arthura_flight_escape(Creature* creature) : VehicleAI(creature), _summons(me) { }

    void IsSummonedBy(WorldObject* summoner) override
    {
        Player* player = summoner->ToPlayer();
        if (player)
        {
            _playerGUID = player->GetGUID();

            // source: SPELL_DISMOUNT_AND_CANCEL_ALL_SHAPESHIFTS (151235, no handler here)
            player->RemoveAurasByType(SPELL_AURA_MOUNTED);
            player->RemoveAurasByType(SPELL_AURA_MOD_SHAPESHIFT);

            me->SetControlled(true, UNIT_STATE_ROOT);
            player->AreaExploredOrEventHappens(QUEST_GREAT_ESCAPE);

            Creature* godfrey = me->SummonCreature(NPC_GODFREY_1, GodfreyEscapePos, TEMPSUMMON_TIMED_DESPAWN,
                SCENE_DESPAWN_MS);
            if (godfrey)
            {
                Creature* belmont = me->SummonCreature(NPC_BELMONT_2, BelmontEscapePos, TEMPSUMMON_TIMED_DESPAWN,
                    SCENE_DESPAWN_MS);
                if (belmont)
                {
                    _summons.Summon(godfrey);
                    _summons.Summon(belmont);
                    _belmontGUID = belmont->GetGUID();
                    godfrey->EnterVehicle(me, SEAT_ARTHURA_GODFREY);
                }
                else
                    godfrey->DespawnOrUnsummon();
            }
        }

        me->SetDisableGravity(true);
        me->SetCanFly(true);

        if (!player)
            return;

        // The summon spell (85073) seated its caster; here the player is boarded explicitly, as
        // a triggered ride so it is not blocked, and is frozen afterwards like the source did.
        player->CastCustomSpell(VEHICLE_SPELL_RIDE_HARDCODED, SPELLVALUE_BASE_POINT0, SEAT_ARTHURA_PLAYER + 1, me,
            true);
        DoCast(player, SPELL_FREEZE_ANIM, true);

        if (player->GetVehicleBase() != me)
            EjectAndDespawn();
    }

    void PassengerBoarded(Unit* passenger, int8 /*seatId*/, bool apply) override
    {
        if (_ending)
            return;

        if (apply && passenger->IsPlayer())
        {
            if (Creature* belmont = ObjectAccessor::GetCreature(*me, _belmontGUID))
            {
                Talk(0, 1s);
                belmont->SetStandState(UNIT_STAND_STATE_STAND);
                if (belmont->IsAIEnabled)
                {
                    belmont->AI()->Talk(0, 5s);
                    belmont->AI()->Talk(1, 11s);
                    belmont->AI()->Talk(2, 16s);
                }
                belmont->DespawnOrUnsummon(26s);
                _events.ScheduleEvent(EVENT_ARTHURA_FLIGHT_1, 20s);
            }
        }

        if (!apply)
            EjectAndDespawn();
    }

    void MovementInform(uint32 type, uint32 point) override
    {
        // SPLINE_MOTION_TYPE in the source; MoveSplinePath reports ESCORT_MOTION_TYPE with the
        // source's 0-based node index (see SilverpineDC::DoMoveSmoothPath). Both follow-ups run
        // on the next update instead of inside the spline callback.
        if (type != ESCORT_MOTION_TYPE)
            return;

        if (point == ARTHURA_INTRO_LAST_POINT && _introFlight)
        {
            _introFlight = false;
            scheduler.Schedule(0ms, [this](TaskContext /*context*/)
            {
                DoMoveSmoothPath(me, Arthura2Path2, Arthura2PathSize2);
            });
        }
        else if (point == ARTHURA_FLIGHT_LAST_POINT && !_introFlight)
            scheduler.Schedule(0ms, [this](TaskContext /*context*/) { EjectAndDespawn(); });
    }

    void UpdateAI(uint32 diff) override
    {
        scheduler.Update(diff);

        if (_checkTimer <= diff)
        {
            _checkTimer = 1000;

            // The source read me->GetOwner(), which a plain summon does not have; the summoner
            // is the player. A summoner who left the map ends the flight too.
            Player* player = ObjectAccessor::GetPlayer(*me, _playerGUID);
            if (!player || !player->IsAlive() || player->GetQuestStatus(QUEST_GREAT_ESCAPE) == QUEST_STATUS_NONE)
            {
                EjectAndDespawn();
                return;
            }
        }
        else
            _checkTimer -= diff;

        _events.Update(diff);

        while (uint32 eventId = _events.ExecuteEvent())
        {
            switch (eventId)
            {
                case EVENT_ARTHURA_FLIGHT_1:
                    me->SetControlled(false, UNIT_STATE_ROOT);
                    Talk(1);
                    DoMoveSmoothPath(me, Arthura2Path, Arthura2PathSize);
                    break;
                default:
                    break;
            }
        }
    }

private:
    // source: SPELL_EJECT_ALL_PASSENGERS + _summons.DespawnAll() with itself in the list
    void EjectAndDespawn()
    {
        if (_ending)
            return;

        _ending = true;

        if (Player* player = ObjectAccessor::GetPlayer(*me, _playerGUID))
            player->RemoveAurasDueToSpell(SPELL_FREEZE_ANIM);

        if (Vehicle* kit = me->GetVehicleKit())
            kit->RemoveAllPassengers();

        _summons.DespawnAll();
        me->DespawnOrUnsummon();
    }

    EventMap _events;
    SummonList _summons;
    ObjectGuid _playerGUID;
    ObjectGuid _belmontGUID;
    uint32 _checkTimer = 1000;
    bool _introFlight = true;
    bool _ending = false;
};

// ######################### RISE, GODFREY #########################

// 45605 Lady Sylvanas Windrunner, cutscene for quest 27472 (source lines 3183-3328)
struct npc_sylvanas_rise_godfrey_scene : public ScriptedAI
{
    npc_sylvanas_rise_godfrey_scene(Creature* creature) : ScriptedAI(creature), _sceneSummons(me) { }

    void IsSummonedBy(WorldObject* summoner) override
    {
        if (Player* player = summoner->ToPlayer())
            _playerGUID = player->GetGUID();

        Talk(0, 2s);
        _events.ScheduleEvent(EVENT_RISE_GODFREY_1, 8s);

        auto summonActor = [this](uint32 entry, Position const& pos)
        {
            return me->SummonCreature(entry, pos, TEMPSUMMON_TIMED_DESPAWN, SCENE_DESPAWN_MS);
        };

        Creature* cromush = summonActor(NPC_HIGH_WARLORD_CROMUSH_3, CromushScenePos);
        Creature* daschla = summonActor(NPC_VALKYR_DASCHLA_3, DaschlaScenePos);
        Creature* agatha = summonActor(NPC_VALKYR_AGATHA_3, AgathaScenePos);
        Creature* arthura = summonActor(NPC_VALKYR_ARTHURA_3, ArthuraScenePos);
        Creature* godfrey = summonActor(NPC_GODFREY_3, GodfreyScenePos);
        Creature* walden = summonActor(NPC_WALDEN_3, WaldenScenePos);
        Creature* ashbury = summonActor(NPC_ASHBURY_3, AshburyScenePos);

        // GUIDs instead of the source's FindNearestCreature: two players running the scene at
        // the same spot would otherwise drive each other's actors.
        for (Creature* summon : { cromush, daschla, agatha, arthura, godfrey, walden, ashbury })
            if (summon)
                _sceneSummons.Summon(summon);

        _cromushGUID = cromush ? cromush->GetGUID() : ObjectGuid::Empty;
        _valkyrGUIDs = { agatha ? agatha->GetGUID() : ObjectGuid::Empty,
                         daschla ? daschla->GetGUID() : ObjectGuid::Empty,
                         arthura ? arthura->GetGUID() : ObjectGuid::Empty };
        _godfreyGUID = godfrey ? godfrey->GetGUID() : ObjectGuid::Empty;
        _ashburyGUID = ashbury ? ashbury->GetGUID() : ObjectGuid::Empty;
        _waldenGUID = walden ? walden->GetGUID() : ObjectGuid::Empty;
    }

    void MovementInform(uint32 type, uint32 point) override
    {
        if (type != POINT_MOTION_TYPE || point != POINT_SYLVANAS_END)
            return;

        me->SetFacingTo(SylvanasEndPos.GetOrientation());
        _events.ScheduleEvent(EVENT_RISE_GODFREY_5, 2s);
    }

    void UpdateAI(uint32 diff) override
    {
        _events.Update(diff);

        while (uint32 eventId = _events.ExecuteEvent())
        {
            switch (eventId)
            {
                case EVENT_RISE_GODFREY_1:
                    for (ObjectGuid const& guid : _valkyrGUIDs)
                        if (Creature* valkyr = ObjectAccessor::GetCreature(*me, guid))
                            valkyr->CastSpell(valkyr, SPELL_RISE_FORSAKEN_3, true);
                    _events.ScheduleEvent(EVENT_RISE_GODFREY_2, 8s);
                    break;
                case EVENT_RISE_GODFREY_2:
                {
                    Creature* godfrey = ObjectAccessor::GetCreature(*me, _godfreyGUID);
                    Creature* ashbury = ObjectAccessor::GetCreature(*me, _ashburyGUID);
                    Creature* walden = ObjectAccessor::GetCreature(*me, _waldenGUID);
                    Creature* cromush = ObjectAccessor::GetCreature(*me, _cromushGUID);
                    if (godfrey && ashbury && walden && cromush)
                    {
                        RaiseLord(godfrey, DISPLAY_GODFREY_FORSAKEN);
                        RaiseLord(ashbury, DISPLAY_ASHBURY_FORSAKEN);
                        RaiseLord(walden, DISPLAY_WALDEN_FORSAKEN);

                        godfrey->AI()->Talk(0, 1s);
                        Talk(1, 5s);
                        cromush->AI()->Talk(0, 11s);
                        Talk(2, 15s);
                        godfrey->AI()->Talk(1, 18s);
                        godfrey->AI()->Talk(2, 24s);
                        godfrey->AI()->Talk(3, 29s);
                        Talk(3, 32s);
                        Talk(4, 40s);
                        godfrey->AI()->Talk(4, 45s);
                    }
                    _events.ScheduleEvent(EVENT_RISE_GODFREY_3, 49s);
                    break;
                }
                case EVENT_RISE_GODFREY_3:
                    if (Player* player = ObjectAccessor::GetPlayer(*me, _playerGUID))
                    {
                        // The lords' SmartAI listens for data 1 = 1 (walk off); kept for it.
                        for (ObjectGuid const& guid : { _godfreyGUID, _ashburyGUID, _waldenGUID })
                            if (Creature* lord = ObjectAccessor::GetCreature(*me, guid))
                                if (lord->IsAIEnabled)
                                    lord->AI()->SetData(DATA_RISEN_WALK_AWAY, 1);

                        me->SetFacingToObject(player);
                        Talk(5, player, 1s);
                    }
                    _events.ScheduleEvent(EVENT_RISE_GODFREY_4, 6s);
                    break;
                case EVENT_RISE_GODFREY_4:
                    me->SetWalk(true);
                    me->GetMotionMaster()->MovePoint(POINT_SYLVANAS_END, SylvanasEndPos.GetPositionX(),
                        SylvanasEndPos.GetPositionY(), SylvanasEndPos.GetPositionZ());
                    break;
                case EVENT_RISE_GODFREY_5:
                    for (Player* player : GetPlayersInRange(me, 100.0f))
                        if (player->GetQuestStatus(QUEST_RISE_GODFREY) == QUEST_STATUS_INCOMPLETE)
                            CreditPlainAnd751(player, NPC_CREDIT_RISE_GODFREY);

                    _sceneSummons.DespawnAll();
                    me->DespawnOrUnsummon();
                    break;
                default:
                    break;
            }
        }
    }

private:
    void RaiseLord(Creature* lord, uint32 risenDisplay)
    {
        lord->RemoveAurasDueToSpell(SPELL_PERMANENT_FEIGN_DEATH);
        lord->SetStandState(UNIT_STAND_STATE_STAND);
        lord->SetDisplayId(risenDisplay);
        lord->CastSpell(lord, SPELL_FORSAKEN_EXPLODE, true);
    }

    EventMap _events;
    SummonList _sceneSummons;
    ObjectGuid _playerGUID;
    ObjectGuid _cromushGUID;
    ObjectGuid _godfreyGUID;
    ObjectGuid _ashburyGUID;
    ObjectGuid _waldenGUID;
    std::array<ObjectGuid, 3> _valkyrGUIDs;
};

// ######################### TRANSDIMENSIONAL WARFARE: CHAPTER III #########################

// 4102120 Archmage Ataeric (Cata 2120 on 751), quest 27518 (source lines 3346-3571)
struct npc_archmage_ataeric_transdimentional_3 : public ScriptedAI
{
    npc_archmage_ataeric_transdimentional_3(Creature* creature) : ScriptedAI(creature), _summons(me) { }

    void InitializeAI() override
    {
        ResetEvent();
    }

    void JustRespawned() override
    {
        ResetEvent();
    }

    // Called by EnterEvadeMode. Evading strips the idle auras, so they are put back here (the
    // source only applied them on respawn and left Ataeric unshielded after an evade).
    void Reset() override
    {
        ResetEvent();
    }

    void JustDied(Unit* /*killer*/) override
    {
        DespawnCreaturesInRange(me, NPC_ARCANE_FIENDS, 60.0f);
        _summons.DespawnAll();
    }

    void JustSummoned(Creature* summon) override
    {
        _summons.Summon(summon);

        // The fiends' own SmartAI (attack the closest player within 30 yd, despawn after 40 s)
        // is not imported; Ataeric does it for them.
        if (summon->GetEntry() == NPC_ARCANE_FIENDS)
        {
            if (Player* player = summon->SelectNearestPlayer(30.0f))
                summon->AI()->AttackStart(player);

            summon->DespawnOrUnsummon(40s);
        }
    }

    void SummonedCreatureDies(Creature* summon, Unit* /*killer*/) override
    {
        if (_eventStarted && summon->GetEntry() == NPC_ARCANE_FIENDS)
            ++_killCount;
    }

    void JustEngagedWith(Unit* /*who*/) override
    {
        if (!_eventStarted)
        {
            _eventStarted = true;
            _phase = 1;
            _events.ScheduleEvent(EVENT_ATAERIC_1, 1s);
        }
    }

    void UpdateAI(uint32 diff) override
    {
        scheduler.Update(diff);
        _events.Update(diff);

        if (_eventStarted)
        {
            if (_checkTimer <= diff)
            {
                _checkTimer = 7000;

                if (!me->SelectNearestPlayer(50.0f))
                {
                    me->CombatStop(true);
                    ResetEvent();
                    return;
                }

                DoCastSelf(SPELL_SUMMON_ARCANE_FIEND, true);
                AdvancePhase();
            }
            else
                _checkTimer -= diff;
        }

        while (uint32 eventId = _events.ExecuteEvent())
        {
            switch (eventId)
            {
                case EVENT_ATAERIC_1:
                    Talk(0);
                    Talk(1, 3s);
                    break;
                case EVENT_ATAERIC_2:
                    me->SummonCreature(NPC_TRANSDIMENTIONAL_PORTAL, AtaericPortal1Pos, TEMPSUMMON_MANUAL_DESPAWN);
                    RecastBeam();
                    Talk(2);
                    break;
                case EVENT_ATAERIC_3:
                    me->SummonCreature(NPC_TRANSDIMENTIONAL_PORTAL, AtaericPortal2Pos, TEMPSUMMON_MANUAL_DESPAWN);
                    RecastBeam();
                    Talk(3);
                    break;
                case EVENT_ATAERIC_4:
                    me->SummonCreature(NPC_TRANSDIMENTIONAL_PORTAL, AtaericPortal3Pos, TEMPSUMMON_MANUAL_DESPAWN);
                    RecastBeam();
                    Talk(4);
                    break;
                case EVENT_ATAERIC_5:
                    for (Position const* pos : { &AtaericPortal4Pos, &AtaericPortal5Pos, &AtaericPortal6Pos,
                        &AtaericPortal7Pos })
                        me->SummonCreature(NPC_TRANSDIMENTIONAL_PORTAL, *pos, TEMPSUMMON_MANUAL_DESPAWN);
                    RecastBeam();
                    Talk(5);
                    break;
                case EVENT_ATAERIC_6:
                    for (Player* player : GetPlayersInRange(me, 100.0f))
                    {
                        if (player->GetQuestStatus(QUEST_TRANSDIMENSIONAL_3) == QUEST_STATUS_INCOMPLETE)
                        {
                            CreditPlainAnd751(player, NPC_CREDIT_TRANSDIMENTIONAL_3);
                            player->CastSpell(player, SPELL_SANCTUARY_NO_COMBAT, true);
                        }
                    }
                    me->RemoveAurasDueToSpell(SPELL_DIMENSIONAL_BEAM);
                    Talk(7);
                    DoCastSelf(SPELL_DIMENSIONAL_COLLAPSE, true);
                    DoCastSelf(SPELL_SUICIDE, true);
                    break;
                default:
                    break;
            }
        }
    }

private:
    void ResetEvent()
    {
        me->setActive(true);
        me->SetControlled(true, UNIT_STATE_ROOT);
        _checkTimer = 3000;
        _eventStarted = false;
        _phase = 0;
        _killCount = 0;
        _events.Reset();
        scheduler.CancelAll();

        _summons.DespawnAll();
        DespawnCreaturesInRange(me, NPC_ARCANE_FIENDS, 60.0f);

        DoCastSelf(SPELL_SANCTUARY_NO_COMBAT, true);
        DoCastSelf(SPELL_ZERO_POWER, true);
        DoCastSelf(SPELL_SELF_STUN, true);
        DoCastSelf(SPELL_ARCANE_SHIELD, true);
        RecastBeam(200ms);
    }

    // source: RemoveAura(SPELL_DIMENSIONAL_BEAM) + CastWithDelay(500, me, SPELL_DIMENSIONAL_BEAM)
    void RecastBeam(Milliseconds delay = 500ms)
    {
        me->RemoveAurasDueToSpell(SPELL_DIMENSIONAL_BEAM);
        scheduler.Schedule(delay, [this](TaskContext /*context*/)
        {
            DoCastSelf(SPELL_DIMENSIONAL_BEAM, true);
        });
    }

    void AdvancePhase()
    {
        switch (_phase)
        {
            case 1:
            case 2:
            case 3:
            case 4:
                if (_killCount >= 3)
                {
                    _killCount = 0;
                    _events.ScheduleEvent(EVENT_ATAERIC_2 + (_phase - 1), 0ms);
                    ++_phase;
                }
                break;
            case 5:
                if (_killCount >= 4)
                {
                    _killCount = 0;
                    _phase = 0;
                    Talk(6);
                    _events.ScheduleEvent(EVENT_ATAERIC_6, 7s);
                    DespawnCreaturesInRange(me, NPC_ARCANE_FIENDS, 50.0f);
                }
                break;
            default:
                break;
        }
    }

    EventMap _events;
    SummonList _summons;
    uint32 _checkTimer = 3000;
    uint8 _phase = 0;
    uint8 _killCount = 0;
    bool _eventStarted = false;
};

void AddSC_dc_silverpine_ruins()
{
    RegisterCreatureAI(npc_arthura_ruins);
    RegisterCreatureAI(npc_belmont_guardian);
    new playerscript_silverpine_quest_guardian_summons();
    RegisterCreatureAI(npc_arthura_flight_escape);
    RegisterCreatureAI(npc_sylvanas_rise_godfrey_scene);
    RegisterCreatureAI(npc_archmage_ataeric_transdimentional_3);
}
