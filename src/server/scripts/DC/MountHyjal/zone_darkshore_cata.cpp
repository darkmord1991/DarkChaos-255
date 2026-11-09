/*
 * Copyright (C) 2016+ DarkChaos <www.azerothcore.org>, released under AGPL v3.
 *
 * Cataclysm-era Darkshore escorts on the downported continent (map 750).
 *
 * The zone's creatures and gameobjects came in with HyjalCata/184_, the quest
 * layer with 190_, and the creature_text + script_waypoint rows these two AIs
 * need with 191_. Ported from Project-Neltharion zone_darkshore.cpp.
 *
 * Two deliberate departures from the Neltharion originals:
 *
 *  1. They bootstrapped the escort by having OnQuestAccept cast a dummy "ping"
 *     spell at the NPC and starting the walk from SpellHit. Neither spell was
 *     downported, and the indirection buys nothing here -- OnQuestAccept
 *     already has both the player and the creature, so the escort is started
 *     directly. One less DBC dependency, same behaviour.
 *  2. Quest credit was granted by iterating every player within 50-80 yards.
 *     Escort credit belongs to the player who started it, so it is given via
 *     GetPlayerForEscort(). This also avoids handing credit to bystanders.
 *
 * Delayed lines use TaskScheduler because AzerothCore has no TalkWithDelay().
 *
 * Also here: the quest controllers and vehicles ported later (197_/198_), and
 * the Foolhardy Adventurer murloc decoy for 13560 (r49, from the BFA-HavenCore
 * comparison of 2026-11-09).
 */

#include "CreatureScript.h"
#include "ObjectAccessor.h"
#include "Player.h"
#include "ScriptedCreature.h"
#include "ScriptedEscortAI.h"
#include "ScriptMgr.h"
#include "SpellAuraEffects.h"
#include "SpellInfo.h"
#include "SpellScript.h"
#include "SpellScriptLoader.h"
#include "TaskScheduler.h"
#include "Vehicle.h"

enum DarkshoreShared
{
    // +3,700,000 Kalimdor-clone band
    NPC_ELISA_STEELHAND         = 3733231,
    NPC_ARCHAEOLOGIST_GROFF     = 3734340,

    QUEST_THE_LAST_REFUGEE      = 13605,
    QUEST_ABSENT_MINDED_PROSPECTOR = 13911,

    SEARCH_RADIUS               = 25
};

// ---------------------------------------------------------------------------
// Archaeologist Hollee -- quest 13605 "The Last Refugee"
// ---------------------------------------------------------------------------
struct npc_hollee_escort : public npc_escortAI
{
    npc_hollee_escort(Creature* creature) : npc_escortAI(creature) { }

    void Reset() override
    {
        if (!HasEscortState(STATE_ESCORT_ESCORTING))
        {
            _scheduler.CancelAll();
        }
    }

    void StartEscort(Player* player)
    {
        me->RemoveNpcFlag(NPCFlags(UNIT_NPC_FLAG_GOSSIP | UNIT_NPC_FLAG_QUESTGIVER));

        _scheduler.Schedule(2s, [this, guid = player->GetGUID()](TaskContext /*context*/)
        {
            Talk(0, ObjectAccessor::GetPlayer(*me, guid));
            _scheduler.Schedule(4500ms, [this, guid](TaskContext /*ctx*/)
            {
                Talk(1, ObjectAccessor::GetPlayer(*me, guid));
                Start(true, guid);
            });
        });
    }

    void WaypointReached(uint32 pointId) override
    {
        Player* player = GetPlayerForEscort();

        switch (pointId)
        {
            case 9:
                me->SetFacingTo(6.243f);
                Talk(2, player);
                me->SetWalk(false);
                break;
            case 11:
                // Hollee kneels to examine the ground, then stands back up.
                me->SetStandState(UNIT_STAND_STATE_KNEEL);
                _scheduler.Schedule(1500ms, [this](TaskContext /*ctx*/) { Talk(3, GetPlayerForEscort()); });
                _scheduler.Schedule(9s, [this](TaskContext /*ctx*/)
                {
                    me->SetStandState(UNIT_STAND_STATE_STAND);
                    Talk(4, GetPlayerForEscort());
                });
                break;
            case 33:
                _scheduler.Schedule(1s, [this](TaskContext /*ctx*/) { Talk(5, GetPlayerForEscort()); });
                _scheduler.Schedule(8s, [this](TaskContext /*ctx*/) { Talk(6, GetPlayerForEscort()); });
                break;
            case 58:
                me->SetFacingTo(3.99f);
                _scheduler.Schedule(1s, [this](TaskContext /*ctx*/)
                {
                    Talk(7, GetPlayerForEscort());
                    _scheduler.Schedule(3s, [this](TaskContext /*ctx*/) { CompleteEscort(); });
                });
                break;
            case 66:
                // Without Elisa there is nobody to hand the refugee over to.
                if (Creature* steelhand = me->FindNearestCreature(NPC_ELISA_STEELHAND, float(SEARCH_RADIUS)))
                {
                    steelhand->AI()->Talk(0);
                }
                else
                {
                    me->DespawnOrUnsummon();
                }
                break;
            case 68:
                PlayHandoverDialogue();
                break;
            default:
                break;
        }
    }

    void UpdateEscortAI(uint32 diff) override
    {
        _scheduler.Update(diff);
    }

private:
    // Credit goes to the escort's own player, not everyone standing nearby.
    void CompleteEscort()
    {
        me->SetReactState(REACT_PASSIVE);

        if (Player* player = GetPlayerForEscort())
        {
            me->SetFacingToObject(player);
            _scheduler.Schedule(1s, [this](TaskContext /*ctx*/) { Talk(8, GetPlayerForEscort()); });

            if (player->GetQuestStatus(QUEST_THE_LAST_REFUGEE) == QUEST_STATUS_INCOMPLETE)
            {
                player->AreaExploredOrEventHappens(QUEST_THE_LAST_REFUGEE);
            }
        }
        else
        {
            me->DespawnOrUnsummon();
        }
    }

    void PlayHandoverDialogue()
    {
        Creature* steelhand = me->FindNearestCreature(NPC_ELISA_STEELHAND, float(SEARCH_RADIUS));
        if (!steelhand)
        {
            return;
        }

        ObjectGuid const steelhandGUID = steelhand->GetGUID();

        Talk(9);
        _scheduler.Schedule(5500ms, [this, steelhandGUID](TaskContext /*ctx*/) { TalkFrom(steelhandGUID, 1); });
        _scheduler.Schedule(12500ms, [this](TaskContext /*ctx*/) { Talk(10); });
        _scheduler.Schedule(18500ms, [this, steelhandGUID](TaskContext /*ctx*/) { TalkFrom(steelhandGUID, 2); });
        _scheduler.Schedule(24500ms, [this](TaskContext /*ctx*/) { Talk(11); });
        _scheduler.Schedule(28500ms, [this, steelhandGUID](TaskContext /*ctx*/) { TalkFrom(steelhandGUID, 3); });
        me->DespawnOrUnsummon(35s);
    }

    // Resolve by GUID at fire time -- Elisa can die or despawn during the 28s
    // of dialogue, and a stored Creature* would dangle.
    void TalkFrom(ObjectGuid guid, uint8 group)
    {
        if (Creature* speaker = ObjectAccessor::GetCreature(*me, guid))
        {
            speaker->AI()->Talk(group);
        }
    }

    TaskScheduler _scheduler;
};

class npc_hollee_escort_questgiver : public CreatureScript
{
public:
    npc_hollee_escort_questgiver() : CreatureScript("npc_hollee_escort") { }

    bool OnQuestAccept(Player* player, Creature* creature, Quest const* quest) override
    {
        if (quest->GetQuestId() == QUEST_THE_LAST_REFUGEE)
        {
            if (npc_hollee_escort* ai = CAST_AI(npc_hollee_escort, creature->AI()))
            {
                ai->StartEscort(player);
            }
        }

        return true;
    }

    CreatureAI* GetAI(Creature* creature) const override
    {
        return new npc_hollee_escort(creature);
    }
};

// ---------------------------------------------------------------------------
// Prospector Remtravel -- quest 13911 "The Absent-Minded Prospector"
// ---------------------------------------------------------------------------
struct npc_prospector_remtravel_escort : public npc_escortAI
{
    npc_prospector_remtravel_escort(Creature* creature) : npc_escortAI(creature) { }

    void Reset() override
    {
        if (!HasEscortState(STATE_ESCORT_ESCORTING))
        {
            _scheduler.CancelAll();
        }
    }

    void StartEscort(Player* player)
    {
        me->RemoveNpcFlag(NPCFlags(UNIT_NPC_FLAG_GOSSIP | UNIT_NPC_FLAG_QUESTGIVER));

        _scheduler.Schedule(1s, [this, guid = player->GetGUID()](TaskContext /*context*/)
        {
            Talk(0, ObjectAccessor::GetPlayer(*me, guid));
            Talk(1, ObjectAccessor::GetPlayer(*me, guid));
            Start(true, guid);
        });
    }

    void WaypointReached(uint32 pointId) override
    {
        Player* player = GetPlayerForEscort();

        switch (pointId)
        {
            case 9:
                Talk(2, player);
                break;
            case 22:
                Talk(3, player);
                me->SetWalk(false);
                break;
            case 33:
                Talk(4, player);
                me->SetWalk(true);
                break;
            case 35:
                CompleteEscort();
                break;
            default:
                break;
        }
    }

    void UpdateEscortAI(uint32 diff) override
    {
        _scheduler.Update(diff);
    }

private:
    void CompleteEscort()
    {
        me->SetReactState(REACT_PASSIVE);
        me->SetUnitFlag(UnitFlags(UNIT_FLAG_IMMUNE_TO_PC | UNIT_FLAG_IMMUNE_TO_NPC));
        me->SetFacingTo(5.7f);
        Talk(5);

        if (Player* player = GetPlayerForEscort())
        {
            if (player->GetQuestStatus(QUEST_ABSENT_MINDED_PROSPECTOR) == QUEST_STATUS_INCOMPLETE)
            {
                player->AreaExploredOrEventHappens(QUEST_ABSENT_MINDED_PROSPECTOR);
            }
        }

        if (Creature* groff = me->FindNearestCreature(NPC_ARCHAEOLOGIST_GROFF, float(SEARCH_RADIUS)))
        {
            ObjectGuid const groffGUID = groff->GetGUID();
            _scheduler.Schedule(6s, [this, groffGUID](TaskContext /*ctx*/)
            {
                if (Creature* speaker = ObjectAccessor::GetCreature(*me, groffGUID))
                {
                    speaker->AI()->Talk(0);
                }
            });
        }
    }

    TaskScheduler _scheduler;
};

class npc_prospector_remtravel_escort_questgiver : public CreatureScript
{
public:
    npc_prospector_remtravel_escort_questgiver() : CreatureScript("npc_prospector_remtravel_escort") { }

    bool OnQuestAccept(Player* player, Creature* creature, Quest const* quest) override
    {
        if (quest->GetQuestId() == QUEST_ABSENT_MINDED_PROSPECTOR)
        {
            if (npc_prospector_remtravel_escort* ai = CAST_AI(npc_prospector_remtravel_escort, creature->AI()))
            {
                ai->StartEscort(player);
            }
        }

        return true;
    }

    CreatureAI* GetAI(Creature* creature) const override
    {
        return new npc_prospector_remtravel_escort(creature);
    }
};

// ---------------------------------------------------------------------------
// Coaxing the Spirits -- quest 13547, four summoned spirit companions
// ---------------------------------------------------------------------------
// The four spirits are identical apart from the angle they follow the player
// at, so the original's four copy-pasted branches collapse into this table.
//
// TWO FIXES vs the Neltharion original, both real defects rather than style:
//  * it called me->GetOwner()->isAlive() with no null check, in a branch that
//    runs every second -- a summon whose owner has logged out crashes the
//    worldserver. GetOwner() is null-guarded here.
//  * it despawned unless GetZoneId() == 148 (Darkshore on map 1). On map 750
//    the zone is this project's own AreaTable id, so every spirit would vanish
//    one second after being summoned. Both ids are accepted -- the same
//    belt-and-braces the Hyjal port already uses with DC_HYJAL_AREAID.
// ---------------------------------------------------------------------------
enum CoaxingTheSpirits
{
    QUEST_COAXING_THE_SPIRITS   = 13547,

    ZONE_DARKSHORE_RETAIL       = 148,   // Darkshore on continent 1
    ZONE_DARKSHORE_DC           = 4929,  // Darkshore as it exists on map 750

    NPC_SPIRIT_THUNDRIS         = 3733002,
    NPC_SPIRIT_ELISSA           = 3733034,
    NPC_SPIRIT_TALDAN           = 3733036,
    NPC_SPIRIT_CAYLAIS          = 3733038,

    FOLLOW_DISTANCE_TENTHS      = 9      // 0.9f, kept integral for the enum
};

struct npc_coaxing_the_spirits_companion : public ScriptedAI
{
    npc_coaxing_the_spirits_companion(Creature* creature) : ScriptedAI(creature) { }

    void IsSummonedBy(WorldObject* summoner) override
    {
        me->SetReactState(REACT_PASSIVE);

        if (Player* player = summoner->ToPlayer())
        {
            _playerGUID = player->GetGUID();
        }
    }

    void UpdateAI(uint32 diff) override
    {
        if (_checkTimer > diff)
        {
            _checkTimer -= diff;
            DoMeleeAttackIfReady();
            return;
        }

        _checkTimer = 1000;

        Player* player = ObjectAccessor::GetPlayer(*me, _playerGUID);
        if (!player)
        {
            me->DespawnOrUnsummon();
            return;
        }

        // Null-guarded: the original dereferenced GetOwner() blind.
        Unit* owner = me->GetOwner();
        if ((owner && !owner->IsAlive()) || !IsInDarkshore())
        {
            me->DespawnOrUnsummon();
            return;
        }

        QuestStatus const status = player->GetQuestStatus(QUEST_COAXING_THE_SPIRITS);
        if (status == QUEST_STATUS_REWARDED || status == QUEST_STATUS_NONE)
        {
            me->DespawnOrUnsummon();
            return;
        }

        if (!_isFollowing)
        {
            me->GetMotionMaster()->MoveFollow(player, float(FOLLOW_DISTANCE_TENTHS) / 10.0f, FollowAngle());
            _isFollowing = true;
        }

        DoMeleeAttackIfReady();
    }

private:
    bool IsInDarkshore() const
    {
        uint32 const zone = me->GetZoneId();
        return zone == ZONE_DARKSHORE_RETAIL || zone == ZONE_DARKSHORE_DC;
    }

    // Spread the four spirits around the player rather than stacking them.
    float FollowAngle() const
    {
        switch (me->GetEntry())
        {
            case NPC_SPIRIT_CAYLAIS:  return 0.5f * float(M_PI);
            case NPC_SPIRIT_TALDAN:   return 0.8f * float(M_PI);
            case NPC_SPIRIT_ELISSA:   return 1.1f * float(M_PI);
            case NPC_SPIRIT_THUNDRIS: return 1.4f * float(M_PI);
            default:                  return 0.0f;
        }
    }

    ObjectGuid _playerGUID;
    uint32 _checkTimer = 1000;
    bool _isFollowing = false;
};

// ---------------------------------------------------------------------------
// The Offering to Azshara -- quests 13900 / 13897
// ---------------------------------------------------------------------------
// A stationary trigger. When an eligible player comes within 50 yards it
// summons four Darkscale Priestesses; once they are all dead it summons Queen
// Azshara. Positions are Blizzard's, unchanged -- map 750 preserves Kalimdor
// coordinates, so only the creature entries need the +3,700,000 offset.
//
// Unlike the vehicle script this one has NO area/zone constant and casts no
// spells, so neither of the two map-750 porting hazards applies to it.
// ---------------------------------------------------------------------------
enum OfferingToAzshara
{
    QUEST_THE_OFFERING_TO_AZSHARA = 13900,
    QUEST_THE_BATTLE_OF_DARKSHORE = 13897,

    NPC_DARKSCALE_PRIESTESS       = 3734415,
    NPC_QUEEN_AZSHARA             = 3734416,
    NPC_MALFURION_STORMRAGE       = 3734422,

    AZSHARA_TRIGGER_RANGE         = 50,
    AZSHARA_SEARCH_RANGE          = 80,
    AZSHARA_CHECK_MS              = 3000
};

Position const kPriestessPos[4] =
{
    { 4587.04f, 890.86f, 41.40f, 6.27f },
    { 4595.28f, 901.76f, 41.69f, 4.87f },
    { 4609.01f, 890.59f, 38.44f, 3.13f },
    { 4600.50f, 879.76f, 38.06f, 1.77f }
};

Position const kQueenPos = { 4598.52f, 890.88f, 39.87f, 0.96f };

struct npc_offering_to_azshara_controller : public ScriptedAI
{
    npc_offering_to_azshara_controller(Creature* creature) : ScriptedAI(creature) { }

    void Reset() override
    {
        _priestessesUp = false;
        _checkTimer = AZSHARA_CHECK_MS;
    }

    void MoveInLineOfSight(Unit* who) override
    {
        if (_priestessesUp || !me->IsWithinDistInMap(who, float(AZSHARA_TRIGGER_RANGE)))
        {
            return;
        }

        Player* player = who->ToPlayer();
        if (!player || !IsEligible(player) || EventActorNearby())
        {
            return;
        }

        for (Position const& pos : kPriestessPos)
        {
            me->SummonCreature(NPC_DARKSCALE_PRIESTESS, pos, TEMPSUMMON_MANUAL_DESPAWN);
        }

        _priestessesUp = true;
    }

    void UpdateAI(uint32 diff) override
    {
        if (_checkTimer > diff)
        {
            _checkTimer -= diff;
            return;
        }

        _checkTimer = AZSHARA_CHECK_MS;

        // The last priestess dying is what calls Azshara up.
        if (_priestessesUp && !me->FindNearestCreature(NPC_DARKSCALE_PRIESTESS, float(AZSHARA_SEARCH_RANGE), true))
        {
            me->SummonCreature(NPC_QUEEN_AZSHARA, kQueenPos, TEMPSUMMON_MANUAL_DESPAWN);
            _priestessesUp = false;
        }
    }

private:
    // Finished the follow-up already? Then the scene is over for this player.
    bool IsEligible(Player* player) const
    {
        if (player->GetQuestStatus(QUEST_THE_BATTLE_OF_DARKSHORE) == QUEST_STATUS_REWARDED)
        {
            return false;
        }

        QuestStatus const status = player->GetQuestStatus(QUEST_THE_OFFERING_TO_AZSHARA);
        return status == QUEST_STATUS_INCOMPLETE || status == QUEST_STATUS_COMPLETE
            || status == QUEST_STATUS_REWARDED;
    }

    // Don't restack the scene while any of it is still standing.
    bool EventActorNearby() const
    {
        return me->FindNearestCreature(NPC_DARKSCALE_PRIESTESS, float(AZSHARA_SEARCH_RANGE), true)
            || me->FindNearestCreature(NPC_MALFURION_STORMRAGE, float(AZSHARA_SEARCH_RANGE), true)
            || me->FindNearestCreature(NPC_QUEEN_AZSHARA, float(AZSHARA_SEARCH_RANGE), true);
    }

    bool _priestessesUp = false;
    uint32 _checkTimer = AZSHARA_CHECK_MS;
};

// ---------------------------------------------------------------------------
// Possessed Vengeful Protector -- quest 13514 "The Ancients' Ire"
// ---------------------------------------------------------------------------
// The rideable ancient (entry 3732851, VehicleId 326). It is summoned by spell
// 64602 when the player clicks one of the two Vengeful Protectors standing in
// Shatterspear Vale -- see HyjalCata/198_ for that chain.
//
// THE MAP-750 FIX: the original despawned the vehicle 10 seconds after
// me->GetAreaId() stopped equalling AREA_SHATTERSPEAR_VALE (4664). On map 750
// that comparison can never succeed, because this project uses its own
// AreaTable ids -- so the vehicle would always have vanished. Both the retail
// area and our Darkshore id are accepted, matching how the existing Hyjal port
// handles DC_HYJAL_AREAID.
// ---------------------------------------------------------------------------
enum VengefulProtector
{
    QUEST_THE_ANCIENTS_IRE      = 13514,
    SPELL_EJECT_ALL_PASSENGERS  = 50630,
    NPC_BUILD_STRUCTURES_CREDIT = 3733913,

    AREA_SHATTERSPEAR_VALE      = 4664,  // retail Darkshore sub-area
    AREA_DARKSHORE_DC           = 4929,  // Darkshore as it exists on map 750

    VENGEFUL_CHECK_MS           = 1000,
    VENGEFUL_LEAVE_GRACE_MS     = 10000
};

struct npc_vengeful_protector_ancient_vehicle : public ScriptedAI
{
    npc_vengeful_protector_ancient_vehicle(Creature* creature) : ScriptedAI(creature) { }

    void IsSummonedBy(WorldObject* summoner) override
    {
        if (Player* player = summoner->ToPlayer())
        {
            _playerGUID = player->GetGUID();
        }

        _inCorrectArea = IsInEventArea();
    }

    void JustDied(Unit* /*killer*/) override
    {
        me->CastSpell(me, SPELL_EJECT_ALL_PASSENGERS, true);
    }

    void UpdateAI(uint32 diff) override
    {
        if (_checkTimer > diff)
        {
            _checkTimer -= diff;
            _events.Update(diff);
            DrainEvents();
            return;
        }

        _checkTimer = VENGEFUL_CHECK_MS;

        // Wandering out of the vale gives a grace period, not an instant boot.
        if (_inCorrectArea && !IsInEventArea())
        {
            _inCorrectArea = false;
            Talk(0, ObjectAccessor::GetPlayer(*me, _playerGUID));
            _events.ScheduleEvent(EVENT_VENGEFUL_DESPAWN, Milliseconds(VENGEFUL_LEAVE_GRACE_MS));
        }
        else if (!_inCorrectArea && IsInEventArea())
        {
            _events.CancelEvent(EVENT_VENGEFUL_DESPAWN);
            _inCorrectArea = true;
        }

        Player* player = ObjectAccessor::GetPlayer(*me, _playerGUID);
        if (!player)
        {
            Dismiss();
            return;
        }

        QuestStatus const status = player->GetQuestStatus(QUEST_THE_ANCIENTS_IRE);
        if (status == QUEST_STATUS_NONE || status == QUEST_STATUS_REWARDED)
        {
            Dismiss();
            return;
        }

        _events.Update(diff);
        DrainEvents();
    }

private:
    enum { EVENT_VENGEFUL_DESPAWN = 1 };

    bool IsInEventArea() const
    {
        uint32 const area = me->GetAreaId();
        return area == AREA_SHATTERSPEAR_VALE || area == AREA_DARKSHORE_DC
            || me->GetZoneId() == AREA_DARKSHORE_DC;
    }

    // Always eject before despawning -- otherwise the rider is left seated on
    // an object that no longer exists.
    void Dismiss()
    {
        me->CastSpell(me, SPELL_EJECT_ALL_PASSENGERS, true);
        me->DespawnOrUnsummon(100ms);
    }

    void DrainEvents()
    {
        while (uint32 eventId = _events.ExecuteEvent())
        {
            if (eventId == EVENT_VENGEFUL_DESPAWN)
            {
                Dismiss();
            }
        }
    }

    ObjectGuid _playerGUID;
    EventMap _events;
    uint32 _checkTimer = VENGEFUL_CHECK_MS;
    bool _inCorrectArea = true;
};

// ---------------------------------------------------------------------------
// Darkshore Wisp -- drifting motion at the Bashal'Aran ritual sites
// ---------------------------------------------------------------------------
// The Cata source has npc_darkshore_wisp_spellclick for this, but it is not
// portable as written: it picks a circle centre with a switch over the SOURCE
// server's spawn guids (168572-168581). Those guids mean nothing here, so a
// verbatim port would fall through every case and do nothing at all.
//
// It also calls MoveAroundPoint, which this core does not have -- there is no
// single-call circular path in MotionMaster. MoveRandom around the spawn point
// gives the same read at a glance (wisps drifting in place around the ritual
// site) without hardcoding anything, and it keeps working if the wisps are
// moved. The radius is varied per spawn so a cluster does not drift in lockstep.
//
// Purely cosmetic, and additive: the wisps' actual behaviour -- the sparkle
// visual -- is already driven by SmartAI (event 11 -> cast 'Darkshore Wisp
// Sparkle') and is left untouched.
// ---------------------------------------------------------------------------
struct npc_darkshore_wisp_circling : public ScriptedAI
{
    npc_darkshore_wisp_circling(Creature* creature) : ScriptedAI(creature) { }

    void InitializeAI() override
    {
        me->SetReactState(REACT_PASSIVE);
        StartDrifting();
    }

    void JustRespawned() override
    {
        StartDrifting();
    }

    void StartDrifting()
    {
        float const radius = 5.0f + float(me->GetSpawnId() % 7) * 0.5f;
        me->GetMotionMaster()->MoveRandom(radius);
    }

    void UpdateAI(uint32 /*diff*/) override { }
};

// ---------------------------------------------------------------------------
// Foolhardy Adventurer -- quest 13560 "An Ocean Not So Deep"
// ---------------------------------------------------------------------------
// A rideable murloc decoy (entry 3734207, VehicleId 400). The player clicks it
// (npc_spellclick 46598), steers it into the Greymist murlocs and presses its
// one action-bar spell, 62684 Depth Charge Countdown Pulse: an 8 s aura whose
// two 2 s periodic triggers are 35151 (the countdown tick) and 62689 (Murloc
// Aggro Pulse, which pulls every murloc within 40 yd onto the decoy). When the
// aura expires the decoy blows up with 62682.
//
// Built from Neltharion's npc_possessed_murloc_bomb + its aura script and
// HavenCore's vehicle_foolhardy_adventurer, with three changes for map 750:
//
//  1. Credit is given per murloc HIT by the blast, not per kill. 62682 deals
//     1540 Fire, tuned for level-12 murlocs; ours are in the 80-90 band and
//     would survive it, so a kill-based credit would never fire. Each Greymist
//     Tidehunter/Warrior caught in the blast credits the rider once and is
//     then killed by the script.
//  2. The rider is ejected BEFORE the blast. A seated rider controls the
//     decoy, so the kills would also reach them through KillCredit1 (set in
//     the r49 SQL) and count twice.
//  3. The rider is held as an ObjectGuid and resolved when used -- HavenCore's
//     lambdas captured raw Creature pointers -- and the shore teleport is a
//     NearTeleportTo on the current map. HavenCore sent the player to map 1,
//     which from map 750 is the wrong continent.
// ---------------------------------------------------------------------------
enum FoolhardyAdventurer
{
    QUEST_AN_OCEAN_NOT_SO_DEEP      = 13560,

    SPELL_DEPTH_CHARGE_PULSE        = 35151,
    SPELL_DEPTH_CHARGE_DETONATION   = 62682,

    NPC_GREYMIST_KILL_CREDIT        = 3732852,
    NPC_GREYMIST_TIDEHUNTER         = 3733262,
    NPC_GREYMIST_WARRIOR            = 3733277,

    SAY_FOOLHARDY_TAUNT             = 0,
    SAY_FOOLHARDY_IMMINENT          = 1,

    ACTION_FOOLHARDY_DETONATE       = 1
};

// Back on the beach, clear of the wreck (HavenCore's point; map 750 keeps the
// Kalimdor coordinates).
Position const FoolhardyShorePos = { 7746.35f, -405.84f, 1.5f, 6.088f };

struct npc_foolhardy_adventurer : public ScriptedAI
{
    npc_foolhardy_adventurer(Creature* creature) : ScriptedAI(creature) { }

    void Reset() override
    {
        me->SetReactState(REACT_PASSIVE);
    }

    // State is cleared on respawn only: Reset() can also run on evade, which
    // may happen between the eject and the blast and must not lose the rider.
    void JustRespawned() override
    {
        _scheduler.CancelAll();
        _riderGUID.Clear();
        _blastVictims.clear();
        _pulses = 0;
        _detonated = false;
        _dismissing = false;
    }

    void PassengerBoarded(Unit* passenger, int8 /*seatId*/, bool apply) override
    {
        if (!passenger || !passenger->IsPlayer())
            return;

        if (apply)
        {
            _riderGUID = passenger->GetGUID();
            me->SetWalk(false);

            // Only for players on the quest; anyone else, or a rider who has
            // left, gets the decoy taken away.
            _scheduler.Schedule(1s, [this](TaskContext context)
            {
                Player* rider = ObjectAccessor::GetPlayer(*me, _riderGUID);
                if (!rider || rider->GetVehicleBase() != me
                    || rider->GetQuestStatus(QUEST_AN_OCEAN_NOT_SO_DEEP) != QUEST_STATUS_INCOMPLETE)
                {
                    Dismiss();
                    return;
                }

                context.Repeat();
            });
            return;
        }

        // Off the decoy, by the blast or by choice: back onto the beach.
        passenger->m_Events.AddEventAtOffset([guid = passenger->GetGUID()]()
        {
            if (Player* player = ObjectAccessor::FindPlayer(guid))
                player->NearTeleportTo(FoolhardyShorePos.GetPositionX(), FoolhardyShorePos.GetPositionY(),
                    FoolhardyShorePos.GetPositionZ(), FoolhardyShorePos.GetOrientation());
        }, 500ms);

        if (!_detonated)
            Dismiss();
    }

    void SpellHit(Unit* /*caster*/, SpellInfo const* spellInfo) override
    {
        if (spellInfo->Id != SPELL_DEPTH_CHARGE_PULSE)
            return;

        // Four ticks over the 8 s countdown.
        ++_pulses;
        if (_pulses == 1)
            Talk(SAY_FOOLHARDY_TAUNT, ObjectAccessor::GetPlayer(*me, _riderGUID));
        else if (_pulses == 3)
            Talk(SAY_FOOLHARDY_IMMINENT, ObjectAccessor::GetPlayer(*me, _riderGUID));
    }

    void SpellHitTarget(Unit* target, SpellInfo const* spellInfo) override
    {
        if (spellInfo->Id != SPELL_DEPTH_CHARGE_DETONATION || !target->IsCreature())
            return;

        uint32 const entry = target->GetEntry();
        if (entry == NPC_GREYMIST_TIDEHUNTER || entry == NPC_GREYMIST_WARRIOR)
            _blastVictims.push_back(target->GetGUID());
    }

    void DoAction(int32 action) override
    {
        if (action != ACTION_FOOLHARDY_DETONATE || _detonated)
            return;

        _detonated = true;
        _scheduler.CancelAll();

        if (Vehicle* kit = me->GetVehicleKit())
            kit->RemoveAllPassengers();

        me->CastSpell(me, SPELL_DEPTH_CHARGE_DETONATION, true);

        // Settle the blast once the spell has finished hitting its targets.
        _scheduler.Schedule(100ms, [this](TaskContext /*context*/)
        {
            Player* rider = ObjectAccessor::GetPlayer(*me, _riderGUID);
            bool const onQuest = rider
                && rider->GetQuestStatus(QUEST_AN_OCEAN_NOT_SO_DEEP) == QUEST_STATUS_INCOMPLETE;

            for (ObjectGuid const& guid : _blastVictims)
            {
                if (onQuest)
                    rider->KilledMonsterCredit(NPC_GREYMIST_KILL_CREDIT);

                if (Creature* murloc = ObjectAccessor::GetCreature(*me, guid))
                    if (murloc->IsAlive())
                        Unit::Kill(me, murloc);
            }

            _blastVictims.clear();
        });

        me->DespawnOrUnsummon(1500ms);
    }

    void JustDied(Unit* /*killer*/) override
    {
        if (Vehicle* kit = me->GetVehicleKit())
            kit->RemoveAllPassengers();
    }

    void UpdateAI(uint32 diff) override
    {
        _scheduler.Update(diff);
    }

private:
    // Always eject before despawning, or the rider is left seated on an object
    // that no longer exists. Guarded because the eject re-enters
    // PassengerBoarded(apply = false), which calls back here.
    void Dismiss()
    {
        if (_dismissing)
            return;

        _dismissing = true;
        if (Vehicle* kit = me->GetVehicleKit())
            kit->RemoveAllPassengers();

        me->DespawnOrUnsummon(100ms);
    }

    TaskScheduler _scheduler;
    ObjectGuid _riderGUID;
    GuidVector _blastVictims;
    uint8 _pulses = 0;
    bool _detonated = false;
    bool _dismissing = false;
};

// 62684 Depth Charge Countdown Pulse -- when the countdown runs out, tell the
// decoy to blow. Only a natural expiry counts: a despawn or a death removes the
// aura too, and must not set off a blast.
class spell_darkshore_depth_charge_countdown : public AuraScript
{
    PrepareAuraScript(spell_darkshore_depth_charge_countdown);

    void HandleRemove(AuraEffect const* /*aurEff*/, AuraEffectHandleModes /*mode*/)
    {
        if (GetTargetApplication()->GetRemoveMode() != AURA_REMOVE_BY_EXPIRE)
            return;

        if (Creature* decoy = GetTarget()->ToCreature())
            if (decoy->IsAIEnabled)
                decoy->AI()->DoAction(ACTION_FOOLHARDY_DETONATE);
    }

    void Register() override
    {
        OnEffectRemove += AuraEffectRemoveFn(spell_darkshore_depth_charge_countdown::HandleRemove, EFFECT_0,
            SPELL_AURA_PERIODIC_TRIGGER_SPELL, AURA_EFFECT_HANDLE_REAL);
    }
};

void AddSC_dc_darkshore_cata()
{
    new npc_hollee_escort_questgiver();
    new npc_prospector_remtravel_escort_questgiver();
    RegisterCreatureAI(npc_coaxing_the_spirits_companion);
    RegisterCreatureAI(npc_offering_to_azshara_controller);
    RegisterCreatureAI(npc_vengeful_protector_ancient_vehicle);
    RegisterCreatureAI(npc_darkshore_wisp_circling);
    RegisterCreatureAI(npc_foolhardy_adventurer);
    RegisterSpellScript(spell_darkshore_depth_charge_countdown);
}
