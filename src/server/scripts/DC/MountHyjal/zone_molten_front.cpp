// PORTED from Project-Neltharion zone_molten_front.cpp (4.3.4 / TrinityCore lineage) to AzerothCore 3.3.5a.
// MECHANICAL first pass kept the dc entry offset (+3600000 on NPC_/GO_ enums) and CATA spell ids.
// This pass resolves the deeper 4.3.4 -> AC 3.3.5 API deltas so the unit COMPILES against this server:
//   * ObjectGuid replaces uint64 GUIDs; ObjectAccessor::Get{Player,Creature,GameObject}.
//   * EventMap::ScheduleEvent now takes Milliseconds -> every numeric delay is wrapped Milliseconds(...).
//   * CreatureAI::Talk(id, WorldObject const* whisper, Milliseconds delay) replaces Talk(id, guid) and the
//     non-existent TalkWithDelay(delay, id, guid).
//   * GetThreatMgr()/GetSortedThreatList() replace getThreatManager()/getThreatList().
//   * IsAlive()/GetVictim()/IsInCombat()/setActive style getters.
//   * npc_escortAI::Start(bool, ObjectGuid) (2-arg) replaces 4.3.4 Start(bool,bool,guid); SetRun() no longer
//     exists on the escort base -> local no-op shim.
//   * MotionMaster::MoveSplinePath(PointsArray*) replaces MoveSmoothPath(Vector3[], size) via DoMoveSmoothPath().
//   * MoveJump replaces the removed ForceMoveJump; MoveAroundPoint has no 3.3.5 equivalent (stubbed).
//   * Unit::Kill is now static -> Unit::Kill(killer, victim).
//   * CastWithDelay() does not exist on this fork -> immediate CastSpell(..., true) (cosmetic delay dropped).
// Spell IDs remain CATA; absent ids no-op until authored. ScriptNames wired by SQL (registration is a
// separate loader edit). See the structured report for the full delta + stub list.

#include "AchievementMgr.h"
#include "ScriptMgr.h"
#include "ScriptedCreature.h"
#include "ScriptedGossip.h"
#include "ScriptedEscortAI.h"
#include "ScriptedFollowerAI.h"
#include "ObjectAccessor.h"
#include "Player.h"
#include "Vehicle.h"
#include "GameObject.h"
#include "CreatureAI.h"
#include "CombatAI.h"            // VehicleAI
#include "MotionMaster.h"
#include "MoveSplineInitArgs.h"  // Movement::PointsArray
#include "GridNotifiers.h"       // AC: player-in-range searcher (GetPlayersInRange shim)
#include "CellImpl.h"
#include "SpellScript.h"
#include "SpellAuraEffects.h"
#include "SmartAI.h"
#include "SmartScript.h"
#include "Group.h"

// ---------------------------------------------------------------------------
// Local helpers bridging removed 4.3.4 conveniences to AC 3.3.5 primitives.
// ---------------------------------------------------------------------------

// 4.3.4 WorldObject::GetPlayersInRange(range, alive) is gone; reproduce it with the
// AC grid searcher (same shim the sibling zone_mount_hyjal.cpp uses).
static std::list<Player*> GetPlayersInRange(WorldObject* who, float range, bool alive)
{
    std::list<Player*> players;
    if (!who)
        return players;

    Acore::AnyPlayerInObjectRangeCheck checker(who, range, alive);
    Acore::PlayerListSearcher<Acore::AnyPlayerInObjectRangeCheck> searcher(who, players, checker);
    Cell::VisitObjects(who, searcher, range);
    return players;
}

// MoveSmoothPath(Vector3[], size) is gone; build a PointsArray and feed MoveSplinePath.
static void DoMoveSmoothPath(Unit* who, G3D::Vector3 const* path, uint32 size)
{
    if (!who || !path || !size)
        return;

    Movement::PointsArray points;
    points.reserve(size);
    for (uint32 i = 0; i < size; ++i)
        points.push_back(path[i]);

    who->GetMotionMaster()->MoveSplinePath(&points);
}

enum MoltenFrontDefaultSpells
{
    SPELL_DISMOUNT_AND_CANCEL_ALL_SHAPESHIFTS = 151235,
    SPELL_RIDE_VEHICLE = 46598,
    SPELL_RIDE_VEHICLE_SEAT_02 = 63313,
    SPELL_EJECT_ALL_PASSENGERS = 50630,
    SPELL_EJECT_PASSENGER_2 = 64630,
    SPELL_DUMMY_PING = 98914,
    SPELL_DUMMY_PING_2 = 98915,
    SPELL_DUMMY_PING_3 = 98916,
    SPELL_DUMMY_PING_4 = 98917,
    SPELL_DUMMY_PING_5 = 98918,
    SPELL_SANCTUARY_NO_COMBAT = 88467,
    SPELL_ROOT = 42716,
    SPELL_DUMMY_SPELLCLICK = 56685,
    SPELL_FLIGHT_SPEED_300 = 54422,
    SPELL_FLIGHT_SPEED_280 = 52211,
    SPELL_FLIGHT_SPEED_200 = 55034,
    SPELL_FLIGHT_SPEED_180 = 48602,
    SPELL_FLIGHT_SPEED_100 = 54421,
    SPELL_PLAYER_UPDATE_AREA = 93425,
};

enum MoltenFrontEvents
{
    EVENT_HYJAL_WISP_AWAY_1 = 1,
    EVENT_HYJAL_WISP_AWAY_2,
    EVENT_HYJAL_WISP_AWAY_3,
    EVENT_THE_FORLORN_SPIRE_1,
    EVENT_THE_FORLORN_SPIRE_ESCORT_1,
    EVENT_FORLORN_CAMERA_1,
    EVENT_FORLORN_CAMERA_2,
    EVENT_FLAME_PROTECTION_RUNE,
    EVENT_INTO_THE_FIRE_ESCORT_1,
    EVENT_INTO_THE_FIRE_END_GRIP_1,
    EVENT_WINDCALLER_ATTACK_EVENT_1,
    EVENT_TRAINED_HAWK_1,
    EVENT_ANREN_ESCORT_1,
    EVENT_ANREN_ESCORT_2,
    EVENT_ANREN_ESCORT_3,
    EVENT_ANREN_ESCORT_4,
    EVENT_ANREN_ESCORT_5,
    EVENT_ANREN_ESCORT_6,
    EVENT_ANREN_ESCORT_7,
    EVENT_ANREN_ESCORT_8,
    EVENT_ANREN_ESCORT_9,
    EVENT_ANREN_ESCORT_10,
    EVENT_ANREN_ESCORT_11,
    EVENT_ANREN_ESCORT_12,
    EVENT_ANREN_ESCORT_13,
    EVENT_ANREN_ESCORT_14,
    EVENT_ANREN_ESCORT_15,
    EVENT_FLAMEWALKER_SHAMAN_FLAME_SHOCK,
    EVENT_FLAMEWALKER_SHAMAN_FLAMEWAVE,
    EVENT_MOLTEN_BEHEMOTH_FIERY_BOULDER,
    EVENT_MOLTEN_BEHEMOTH_MOLTEN_STOMP,

    ACTION_FORLORN_RESET_CONTROLLER,
    ACTION_INTO_THE_FIRE_RESET_CONTROLLER,
    ACTION_INTO_THE_FIRE_END_GRIP,
    ACTION_MOLTEN_BEHEMOTH_ACHIEVEMENT_NOT_DESERVE,
};

// ############## Scripts ##############

enum QuestWispAway
{
    QUEST_WISP_AWAY = 29143,

    NPC_FIREKIN = 3653092,
    NPC_FIRE_ATTACKER_PORTAL = 3652531,

    SPELL_SUMMON_FIREKIN_AURA = 98184,
    SPELL_SUMMON_FIREKIN = 98183,

    SPELL_PORTAL_TO_WISP_RESPONSE = 98162,
    SPELL_WISP_SHIELD = 101529,
    SPELL_SUMMON_WISP = 98151,
    SPELL_PORTAL_WISP_GUARDIAN_AURA = 98193,
    SPELL_SMALL_THREAT_TOWARDS_HYJAL_WISP = 98187,
    SPELL_PORTAL_CLOSED_CREDIT = 98186,
    SPELL_DUMMY_AURA_CHECK = 151100,
    SPELL_EXPLODE_CAMERA_SHAKE = 69081,
};

class npc_hyjal_wisp_away : public CreatureScript
{
public:
    npc_hyjal_wisp_away() : CreatureScript("npc_hyjal_wisp_away") { }

    struct npc_hyjal_wisp_awayAI : public ScriptedAI
    {
        npc_hyjal_wisp_awayAI(Creature* creature) : ScriptedAI(creature), _summons(me) {}

        void IsSummonedBy(WorldObject* summoner) override
        {
            me->setActive(true);
            me->SetReactState(REACT_PASSIVE);

            if (Player* player = summoner ? summoner->ToPlayer() : nullptr)
                _playerGUID = player->GetGUID();
        }

        void JustDied(Unit* /*killer*/) override
        {
            if (Player* player = ObjectAccessor::GetPlayer(*me, _playerGUID))
                player->RemoveAura(SPELL_PORTAL_WISP_GUARDIAN_AURA);
        }

        void SpellHit(Unit* who, SpellInfo const* spellInfo) override
        {
            if (spellInfo->Id == SPELL_PORTAL_TO_WISP_RESPONSE)
            {
                if (Creature* portal = who->ToCreature())
                {
                    if (portal->GetEntry() == NPC_FIRE_ATTACKER_PORTAL)
                    {
                        portal->CastSpell(portal, SPELL_DUMMY_AURA_CHECK, true);
                        _inAction = true;
                        _portalGUID = portal->GetGUID();
                        _summons.Summon(portal);
                        // 4.3.4 ForceMoveJump -> AC MoveJump (arc jump to the portal).
                        me->GetMotionMaster()->MoveJump(portal->GetPositionX(), portal->GetPositionY(), portal->GetPositionZ(), 20.f, 5.f);
                        _events.ScheduleEvent(EVENT_HYJAL_WISP_AWAY_1, Milliseconds(3000));
                    }
                }
            }
        }

        void JustSummoned(Creature* summoned) override
        {
            if (summoned->GetEntry() == NPC_FIREKIN)
            {
                _summons.Summon(summoned);
            }
        }

        void SummonedCreatureDies(Creature* summon, Unit* /*killer*/) override
        {
            _summons.RemoveNotExisting();

            if (summon->GetEntry() == NPC_FIREKIN)
            {
                if (_firekinKillCount <= 8)
                    _firekinKillCount++;

                if (_firekinKillCount >= 8)
                {
                    if (Creature* portal = ObjectAccessor::GetCreature(*me, _portalGUID))
                    {
                        if (Player* player = ObjectAccessor::GetPlayer(*me, _playerGUID))
                        {
                            _inAction = false;
                            portal->CastSpell(portal, SPELL_EXPLODE_CAMERA_SHAKE, true);
                            me->GetMotionMaster()->Clear();
                            me->RemoveAura(SPELL_SUMMON_FIREKIN_AURA);

                            player->KilledMonsterCredit(NPC_FIRE_ATTACKER_PORTAL);

                            _events.ScheduleEvent(EVENT_HYJAL_WISP_AWAY_3, Milliseconds(2000));
                        }
                    }
                }
            }
        }

        void UpdateAI(uint32 diff) override
        {
            DoMeleeAttackIfReady();

            if (_checkTimer <= diff)
            {
                _checkTimer = 1000;

                if (Player* player = ObjectAccessor::GetPlayer(*me, _playerGUID))
                {
                    if (!player->IsAlive())
                    {
                        _summons.DespawnAll();
                        me->DespawnOrUnsummon();
                        player->RemoveAura(SPELL_PORTAL_WISP_GUARDIAN_AURA);

                        if (Creature* portal = ObjectAccessor::GetCreature(*me, _portalGUID))
                            portal->DespawnOrUnsummon();
                    }

                    if (player->GetQuestStatus(QUEST_WISP_AWAY) == QUEST_STATUS_NONE ||
                        player->GetQuestStatus(QUEST_WISP_AWAY) == QUEST_STATUS_REWARDED)
                    {
                        _summons.DespawnAll();
                        me->DespawnOrUnsummon();
                        player->RemoveAura(SPELL_PORTAL_WISP_GUARDIAN_AURA);

                        if (Creature* portal = ObjectAccessor::GetCreature(*me, _portalGUID))
                            portal->DespawnOrUnsummon();
                    }

                    if (me->GetDistance(player) > 80.f)
                    {
                        _summons.DespawnAll();
                        player->RemoveAura(SPELL_PORTAL_WISP_GUARDIAN_AURA);
                        me->DespawnOrUnsummon();

                        if (Creature* portal = ObjectAccessor::GetCreature(*me, _portalGUID))
                            portal->DespawnOrUnsummon();
                    }

                    if (me->GetMotionMaster()->GetCurrentMovementGeneratorType() != FOLLOW_MOTION_TYPE && !_inAction)
                    {
                        me->SetReactState(REACT_PASSIVE);
                        me->CastSpell(me, SPELL_SANCTUARY_NO_COMBAT, true);
                        me->GetMotionMaster()->MoveFollow(player, 1.0f, 0.5f * M_PI);
                    }
                }
            }
            else _checkTimer -= diff;

            _events.Update(diff);

            while (uint32 eventId = _events.ExecuteEvent())
            {
                switch (eventId)
                {
                case EVENT_HYJAL_WISP_AWAY_1:
                    if (Creature* portal = ObjectAccessor::GetCreature(*me, _portalGUID))
                    {
                        if (Player* player = ObjectAccessor::GetPlayer(*me, _playerGUID))
                            me->AI()->Talk(0, player);
                        me->CastSpell(me, SPELL_WISP_SHIELD, true);

                        _portalCenter = portal->GetPosition();
                        // 4.3.4 MoveAroundPoint has no 3.3.5 equivalent -- approximate with a MovePoint to
                        // the portal centre so the spline still runs and the event chain proceeds.
                        me->GetMotionMaster()->MovePoint(0, _portalCenter);
                        _events.ScheduleEvent(EVENT_HYJAL_WISP_AWAY_2, Milliseconds(1000));
                    }
                    break;
                case EVENT_HYJAL_WISP_AWAY_2:
                    me->CastSpell(me, SPELL_SUMMON_FIREKIN_AURA, true);
                    break;
                case EVENT_HYJAL_WISP_AWAY_3:
                    _summons.DespawnAll();
                    me->DespawnOrUnsummon();
                    break;
                default:
                    break;
                }
            }
        }
    private:
        bool _inAction = false;
        ObjectGuid _playerGUID;
        ObjectGuid _portalGUID;
        uint16 _checkTimer = 1000, _firekinCounter = 0, _firekinKillCount = 0;
        EventMap _events;
        Position _portalCenter;
        SummonList _summons;
    };

    CreatureAI* GetAI(Creature* creature) const override
    {
        return new npc_hyjal_wisp_awayAI(creature);
    }
};

enum QuestForlorn
{
    QUEST_THE_FORLORN_SPIRE = 29205,

    NPC_FORLORN_CONTROLLER = 3675186,
    NPC_FORLORN_CAMERA = 3653017,
    NPC_TURAK_RUNETOTEM = 3652964,
    NPC_KEEPER_TALDROS = 3652965,
    NPC_DELDREN_RAVENELM = 3652953,
    NPC_SAYNNA = 3652854,

    NPC_SHALIS_DARKHUNTER = 3652954,
    NPC_SIRA_MOONWARDEN = 3652955,

    NPC_IGNITER = 3652999,
    NPC_SENTINEL = 3652663,
    NPC_PYRELORD = 3652998,

    SPELL_NATURE_CHANNELING = 73093,
    SPELL_SUMMON_FORLORN_CAMERA = 151267,
    SPELL_FADE_TO_BLACK = 89147,
};

const Position SummonQuestNpcsPos1[] =
{
    { 1145.8f, 282.832f, 16.761f, 3.35f }, // druid pos
    { 1145.38f, 279.98f, 16.76f, 2.78f }, // shadow warden companion pos
    { 1214.10f, 218.86f, 54.78f, 2.78f }, // igniter pos1
    { 1205.22f, 207.40f, 54.41f, 2.78f }, // igniter pos2
    { 1186.37f, 204.34f, 54.89f, 2.78f }, // igniter pos3
    { 1213.320f, 168.012f,  60.00f, 0.85f }, // sentinel pos1
    { 1221.332f, 161.444f,  59.17f, 1.22f }, // sentinel1 pos2
    { 1184.571f, 141.567f, 63.555f, 0.829f }, // pyrelord pos
};

const Position cameraPos = { 1225.35f, 144.66f, 80.98f, 3.462f };

class npc_the_forlorn_spire_controller : public CreatureScript
{
public:
    npc_the_forlorn_spire_controller() : CreatureScript("npc_the_forlorn_spire_controller") { }

    struct npc_the_forlorn_spire_controllerAI : public ScriptedAI
    {
        npc_the_forlorn_spire_controllerAI(Creature* creature) : ScriptedAI(creature) {}

        void Reset() override
        {
            me->setActive(true);
        }

        void MoveInLineOfSight(Unit* who) override
        {
            if (me->IsWithinDistInMap(who, 30.0f))
                if (Player* player = who->ToPlayer())
                    if (!_isEventStarted)
                    {
                        if (player->GetQuestStatus(QUEST_THE_FORLORN_SPIRE) == QUEST_STATUS_REWARDED)
                            return;

                        if (player->GetQuestStatus(QUEST_THE_FORLORN_SPIRE) == QUEST_STATUS_INCOMPLETE)
                        {
                            _isEventStarted = true;

                            if (Creature* captain = me->FindNearestCreature(NPC_SAYNNA, 30.f))
                            {
                                captain->AI()->Talk(0, player);
                            }

                            uint8 randomId = urand(0, 2);

                            switch (randomId)
                            {
                            case 0:
                                if (Creature* anydruid = player->SummonCreature(NPC_TURAK_RUNETOTEM, SummonQuestNpcsPos1[0], TEMPSUMMON_MANUAL_DESPAWN))
                                {
                                    anydruid->SetPhaseMask(64, true);
                                    anydruid->setActive(true);
                                }
                                break;
                            case 1:
                                if (Creature* anydruid = player->SummonCreature(NPC_KEEPER_TALDROS, SummonQuestNpcsPos1[0], TEMPSUMMON_MANUAL_DESPAWN))
                                {
                                    anydruid->SetPhaseMask(64, true);
                                    anydruid->setActive(true);
                                }
                                break;
                            case 2:
                                if (Creature* anydruid = player->SummonCreature(NPC_DELDREN_RAVENELM, SummonQuestNpcsPos1[0], TEMPSUMMON_MANUAL_DESPAWN))
                                {
                                    anydruid->SetPhaseMask(64, true);
                                    anydruid->setActive(true);
                                }
                                break;
                            default:
                                break;
                            }
                        }
                    }
        }

        void DoAction(int32 actionId) override
        {
            if (actionId == ACTION_FORLORN_RESET_CONTROLLER)
            {
                _isEventStarted = false;
            }
        }

    private:
        bool _isEventStarted = false;
    };

    CreatureAI* GetAI(Creature* creature) const override
    {
        return new npc_the_forlorn_spire_controllerAI(creature);
    }
};

// quest=29205/the-forlorn-spire
class npc_the_forlorn_spire_anydruid : public CreatureScript
{
public:
    npc_the_forlorn_spire_anydruid() : CreatureScript("npc_the_forlorn_spire_anydruid") { }

    struct npc_the_forlorn_spire_anydruidAI : public npc_escortAI
    {
        npc_the_forlorn_spire_anydruidAI(Creature* creature) : npc_escortAI(creature), _summons(me) { }

        void IsSummonedBy(WorldObject* summoner) override
        {
            if (Creature* controller = me->FindNearestCreature(NPC_FORLORN_CONTROLLER, 30.f))
            {
                _controllerGUID = controller->GetGUID();
            }

            if (Player* player = summoner ? summoner->ToPlayer() : nullptr)
            {
                _playerGUID = player->GetGUID();

                uint8 randomId = urand(0, 1);

                switch (randomId)
                {
                case 0:
                    if (Creature* warden = me->SummonCreature(NPC_SHALIS_DARKHUNTER, SummonQuestNpcsPos1[1], TEMPSUMMON_MANUAL_DESPAWN))
                    {
                        _summons.Summon(warden);
                        warden->SetPhaseMask(64, true);
                        warden->setActive(true);
                    }
                    break;
                case 1:
                    if (Creature* warden = me->SummonCreature(NPC_SIRA_MOONWARDEN, SummonQuestNpcsPos1[1], TEMPSUMMON_MANUAL_DESPAWN))
                    {
                        _summons.Summon(warden);
                        warden->SetPhaseMask(64, true);
                        warden->setActive(true);
                    }
                    break;
                default:
                    break;
                }
            }
        }

        void JustDied(Unit* /* killer */) override
        {
            _summons.DespawnAll();

            if (Creature* controller = ObjectAccessor::GetCreature(*me, _controllerGUID))
                controller->AI()->DoAction(ACTION_FORLORN_RESET_CONTROLLER);
        }

        // 4.3.4 escort hook; harmless extra method on the AC base (not an override).
        void EscortAbandonTooFarDespawn()
        {
            _summons.DespawnAll();

            if (Creature* controller = ObjectAccessor::GetCreature(*me, _controllerGUID))
                controller->AI()->DoAction(ACTION_FORLORN_RESET_CONTROLLER);
        }

        void WaypointReached(uint32 waypointId) override
        {
            switch (waypointId)
            {
            case 1:
            {
                if (Player* player = ObjectAccessor::GetPlayer(*me, _playerGUID))
                    me->AI()->Talk(0, player, Milliseconds(500));
                _running = true; // SetRun() removed from escort base; tracked locally (no-op behaviourally).
            }
            break;
            case 13:
            {
                SetEscortPaused(true);

                if (Creature* igniter1 = me->SummonCreature(NPC_IGNITER, SummonQuestNpcsPos1[2], TEMPSUMMON_MANUAL_DESPAWN))
                    if (Creature* igniter2 = me->SummonCreature(NPC_IGNITER, SummonQuestNpcsPos1[3], TEMPSUMMON_MANUAL_DESPAWN))
                        if (Creature* igniter3 = me->SummonCreature(NPC_IGNITER, SummonQuestNpcsPos1[4], TEMPSUMMON_MANUAL_DESPAWN))
                        {
                            _summons.Summon(igniter1);
                            igniter1->setActive(true);
                            igniter1->AI()->AttackStart(me);

                            _summons.Summon(igniter2);
                            igniter2->setActive(true);
                            igniter2->AI()->AttackStart(me);

                            _summons.Summon(igniter3);
                            igniter3->setActive(true);
                            igniter3->AI()->AttackStart(me);
                        }
            }
            break;
            case 20:
                me->AI()->Talk(2);
                break;
            case 22:
                me->AI()->Talk(3);
                me->CastSpell(me, SPELL_NATURE_CHANNELING, true);

                _events.ScheduleEvent(EVENT_THE_FORLORN_SPIRE_ESCORT_1, Milliseconds(5000));
                break;
            default:
                break;
            }
        }

        void JustSummoned(Creature* summoned) override
        {
            if (summoned->GetEntry() == NPC_IGNITER)
            {
                _summons.Summon(summoned);
            }
        }

        void SummonedCreatureDies(Creature* /*summon*/, Unit* /*killer*/) override
        {
            _killCount++;
        }

        void UpdateAI(uint32 uiDiff) override
        {
            npc_escortAI::UpdateAI(uiDiff);

            _events.Update(uiDiff);

            if (_timer <= uiDiff)
            {
                _timer = 5000;

                if (!me->IsInCombat())
                    if (!_started)
                    {
                        Start(true, _playerGUID);
                        me->SetReactState(REACT_AGGRESSIVE);
                        SetDespawnAtEnd(false);
                        SetDespawnAtFar(true);
                        _started = true;
                    }

                if (!me->IsInCombat() && _killCount == 3 && _waveCount == 0)
                {
                    SetEscortPaused(false);
                    me->AI()->Talk(1);
                    _waveCount++;

                    if (Creature* sentinel1 = me->SummonCreature(NPC_SENTINEL, SummonQuestNpcsPos1[5], TEMPSUMMON_MANUAL_DESPAWN))
                        if (Creature* sentinel2 = me->SummonCreature(NPC_SENTINEL, SummonQuestNpcsPos1[6], TEMPSUMMON_MANUAL_DESPAWN))
                        {
                            _summons.Summon(sentinel1);
                            _summons.Summon(sentinel2);
                            sentinel1->setActive(true);
                            sentinel2->setActive(true);
                        }
                }

                if (!me->IsInCombat() && _killCount == 5 && _waveCount == 1)
                {
                    SetEscortPaused(false);
                    _waveCount++;

                    if (Creature* pyrelord = me->SummonCreature(NPC_PYRELORD, SummonQuestNpcsPos1[7], TEMPSUMMON_MANUAL_DESPAWN))
                    {
                        _summons.Summon(pyrelord);
                        pyrelord->setActive(true);
                    }
                }

                if (!me->IsInCombat() && _killCount == 6 && _waveCount == 2)
                {
                    _waveCount++;
                }
            }
            else _timer -= uiDiff;

            while (uint32 eventId = _events.ExecuteEvent())
            {
                switch (eventId)
                {
                case EVENT_THE_FORLORN_SPIRE_ESCORT_1:
                {
                    if (Creature* controller = ObjectAccessor::GetCreature(*me, _controllerGUID))
                        controller->AI()->DoAction(ACTION_FORLORN_RESET_CONTROLLER);

                    for (Player* it : GetPlayersInRange(me, 55.0f, true))
                    {
                        if (it->GetQuestStatus(QUEST_THE_FORLORN_SPIRE) == QUEST_STATUS_INCOMPLETE)
                        {
                            it->CastSpell(it, SPELL_DISMOUNT_AND_CANCEL_ALL_SHAPESHIFTS, true);
                            it->CastSpell(it, SPELL_FADE_TO_BLACK, true);
                            it->CastSpell(it, SPELL_SUMMON_FORLORN_CAMERA, true);
                        }
                    }

                    _summons.DespawnAll();
                    me->DespawnOrUnsummon(Milliseconds(1000));
                    break;
                }
                default:
                    break;
                }
            }
        }
    private:
        bool _started = false;
        bool _running = false;
        uint8 _waveCount = 0, _killCount = 0;
        EventMap _events;
        ObjectGuid _playerGUID, _controllerGUID;
        uint32 _timer = 4000;
        SummonList _summons;
    };

    CreatureAI* GetAI(Creature* creature) const override
    {
        return new npc_the_forlorn_spire_anydruidAI(creature);
    }
};

// guardian
class npc_the_forlorn_spire_warden : public CreatureScript
{
public:
    npc_the_forlorn_spire_warden() : CreatureScript("npc_the_forlorn_spire_warden") { }

    struct npc_the_forlorn_spire_wardenAI : public ScriptedAI
    {
        npc_the_forlorn_spire_wardenAI(Creature* creature) : ScriptedAI(creature) {}

        void IsSummonedBy(WorldObject* summoner) override
        {
            if (summoner)
                me->SetOwnerGUID(summoner->GetGUID());
        }

        void JustDied(Unit* /*killer*/) override
        {
        }

        void UpdateAI(uint32 diff) override
        {
            DoMeleeAttackIfReady();

            if (_checkTimer <= diff)
            {
                _checkTimer = 1000;

                if (Unit* owner = me->GetOwner())
                {
                    if (!owner->IsAlive())
                    {
                        me->DespawnOrUnsummon();
                    }

                    if (!me->GetVictim() && owner->IsInCombat())
                    {
                        if (me->GetReactState() != REACT_AGGRESSIVE)
                            me->SetReactState(REACT_AGGRESSIVE);

                        if (owner->GetVictim())
                            me->AI()->AttackStart(owner->GetVictim());
                    }

                    if (me->GetReactState() != REACT_PASSIVE && !owner->IsInCombat())
                    {
                        me->SetReactState(REACT_PASSIVE);
                        me->CastSpell(me, SPELL_SANCTUARY_NO_COMBAT, true);
                        me->GetMotionMaster()->MoveFollow(owner, 0.7f, 0.4f * M_PI);
                    }
                }
            }
            else _checkTimer -= diff;
        }
    private:
        ObjectGuid _playerGUID;
        uint16 _checkTimer = 1000;
    };

    CreatureAI* GetAI(Creature* creature) const override
    {
        return new npc_the_forlorn_spire_wardenAI(creature);
    }
};

enum TheForlornCamera
{
    NPC_FORLORN_CREDIT = 3653012,
    NPC_CHANNEL_TARGET = 3644403,
    SPELL_CAMERA_CHANNEL = 82557,
    SPELL_TELEPORT_END = 98053,
};

uint32 const ForlornCameraPathSize = 3;
const G3D::Vector3 ForlornCameraPath[ForlornCameraPathSize] =
{
    { 1217.737f, 158.068f, 90.1f },  // 0
    { 1203.962f, 176.085f, 90.1f },  // 1
    { 1187.602f, 182.640f, 90.1f },  // 2
};

class npc_the_forlorn_spire_camera : public CreatureScript
{
public:
    npc_the_forlorn_spire_camera() : CreatureScript("npc_the_forlorn_spire_camera") { }

    struct npc_the_forlorn_spire_cameraAI : public VehicleAI
    {
        npc_the_forlorn_spire_cameraAI(Creature* creature) : VehicleAI(creature) {}

        void IsSummonedBy(WorldObject* summoner) override
        {
            if (Player* player = summoner ? summoner->ToPlayer() : nullptr)
            {
                _playerGUID = player->GetGUID();
                // 4.3.4 CastWithDelay(500,...) -> immediate cast (no delayed-cast helper on this fork).
                player->CastSpell(me, SPELL_RIDE_VEHICLE, true);
            }
        }

        void PassengerBoarded(Unit* passenger, int8 /* seatId*/, bool apply) override
        {
            if (apply && passenger->IsPlayer())
            {
                // NearTeleportTo takes a non-const Position& on this fork; cameraPos is const.
                me->NearTeleportTo(cameraPos.GetPositionX(), cameraPos.GetPositionY(), cameraPos.GetPositionZ(), cameraPos.GetOrientation());
                _events.ScheduleEvent(EVENT_FORLORN_CAMERA_1, Milliseconds(1000));

                if (Creature* target = me->FindNearestCreature(NPC_CHANNEL_TARGET, 80.f))
                {
                    _targetBunnyGUID = target->GetGUID();
                    me->CastSpell(target, SPELL_CAMERA_CHANNEL, true);
                }
            }

            if (!apply && passenger->IsPlayer())
            {
                if (Creature* bunny = ObjectAccessor::GetCreature(*me, _targetBunnyGUID))
                {
                    passenger->ExitVehicle();
                    bunny->CastSpell(passenger, SPELL_TELEPORT_END, true);
                }
            }
        }

        void MovementInform(uint32 type, uint32 point) override
        {
            // AC 3.3.5: SPLINE_MOTION_TYPE does not exist; MoveSplinePath (DoMoveSmoothPath)
            // reports completion as ESCORT_MOTION_TYPE.
            if (type != ESCORT_MOTION_TYPE)
                return;

            switch (point)
            {
            case 2:
                me->CastSpell(me, SPELL_EJECT_ALL_PASSENGERS, true);

                if (Player* player = ObjectAccessor::GetPlayer(*me, _playerGUID))
                    player->CastSpell(player, SPELL_FADE_TO_BLACK, true);
                break;
            default:
                break;
            }
        }

        void UpdateAI(uint32 diff) override
        {
            _events.Update(diff);

            while (uint32 eventId = _events.ExecuteEvent())
            {
                switch (eventId)
                {
                case EVENT_FORLORN_CAMERA_1:
                    _events.ScheduleEvent(EVENT_FORLORN_CAMERA_2, Milliseconds(1000));
                    break;
                case EVENT_FORLORN_CAMERA_2:
                    if (Player* player = ObjectAccessor::GetPlayer(*me, _playerGUID))
                        player->KilledMonsterCredit(NPC_FORLORN_CREDIT);

                    DoMoveSmoothPath(me, ForlornCameraPath, ForlornCameraPathSize);
                    break;
                default:
                    break;
                }
            }
        }

    private:
        EventMap _events;
        ObjectGuid _playerGUID;
        ObjectGuid _targetBunnyGUID;
    };
    CreatureAI* GetAI(Creature* creature) const override
    {
        return new npc_the_forlorn_spire_cameraAI(creature);
    }
};

enum QuestEnduringTheHeat
{
    QUEST_ENDURING_THE_HEAT = 29210,

    SPELL_SEE_QUEST_INVIS_1 = 97741,
    SPELL_SEE_QUEST_INVIS_2 = 97742,
    SPELL_SEE_QUEST_INVIS_3 = 97743,
    SPELL_SEE_QUEST_INVIS_4 = 97744,
    SPELL_SEE_QUEST_INVIS_5 = 97745,
    SPELL_SEE_QUEST_INVIS_6 = 97746,
    SPELL_SEE_QUEST_INVIS_7 = 97747,
    SPELL_SEE_QUEST_INVIS_8 = 97748,
    SPELL_ENDURING_KILLCREDIT = 97773,
    SPELL_MOLTEN_SPLASH = 97775,
};

class npc_flame_protection_rune : public CreatureScript
{
public:
    npc_flame_protection_rune() : CreatureScript("npc_flame_protection_rune") { }

    struct npc_flame_protection_runeAI : public ScriptedAI
    {
        npc_flame_protection_runeAI(Creature* creature) : ScriptedAI(creature) {}

        void OnSpellClick(Unit* clicker, bool& /*result*/) override
        {
            if (Player* player = clicker->ToPlayer())
            {
                if (!player->HasAura(SPELL_SEE_QUEST_INVIS_1)
                    && !player->HasAura(SPELL_SEE_QUEST_INVIS_2)
                    && !player->HasAura(SPELL_SEE_QUEST_INVIS_3)
                    && !player->HasAura(SPELL_SEE_QUEST_INVIS_4)
                    && !player->HasAura(SPELL_SEE_QUEST_INVIS_5)
                    && !player->HasAura(SPELL_SEE_QUEST_INVIS_6)
                    && !player->HasAura(SPELL_SEE_QUEST_INVIS_7)
                    && !player->HasAura(SPELL_SEE_QUEST_INVIS_8))
                {
                    player->CastSpell(player, SPELL_ENDURING_KILLCREDIT, true);
                }
            }
        }
    };

    CreatureAI* GetAI(Creature* creature) const override
    {
        return new npc_flame_protection_runeAI(creature);
    }
};

class npc_molten_splash_origin_bunny : public CreatureScript
{
public:
    npc_molten_splash_origin_bunny() : CreatureScript("npc_molten_splash_origin_bunny") { }

    struct npc_molten_splash_origin_bunnyAI : public ScriptedAI
    {
        npc_molten_splash_origin_bunnyAI(Creature* creature) : ScriptedAI(creature) {}

        uint32 checkTimer = 1000;

        void UpdateAI(uint32 diff) override
        {
            if (checkTimer <= diff)
            {
                checkTimer = urand(5000, 20000);

                if (Player* player = me->SelectNearestPlayer(40.f))
                {
                    if (player->GetQuestStatus(QUEST_ENDURING_THE_HEAT) == QUEST_STATUS_INCOMPLETE
                        || player->GetQuestStatus(QUEST_ENDURING_THE_HEAT) == QUEST_STATUS_COMPLETE)
                    {
                        me->CastSpell(player, SPELL_MOLTEN_SPLASH, true);
                        checkTimer = urand(30000, 80000);
                    }
                }
            }
            else checkTimer -= diff;
        }
    };

    CreatureAI* GetAI(Creature* creature) const override
    {
        return new npc_molten_splash_origin_bunnyAI(creature);
    }
};

enum QuestIntoTheFire
{
    QUEST_INTO_THE_FIRE = 29206,

    NPC_INTO_THE_FIRE_CONTROLLER = 3675181,
    NPC_INTO_THE_FIRE_GRIP_CONTROLLER = 3675182,

    NPC_WINDCALLER_NORDRALA = 3653355,
    NPC_WINDCALLER_VORAMUS = 3653217,
    NPC_FLAMEWAKER_ASSASSIN = 3653328,
    NPC_DRUID_OF_THE_TALON = 3653329,
    NPC_INTO_THE_FIRE_CREDIT = 3653218,

    NPC_PYRELORD_2 = 3652683,
    SPELL_ENVELOPING_WINDS = 98566,
    SPELL_WRATH = 96427,
};

const Position SummonQuestNpcsPos2[] =
{
    { 1066.35f, 420.52f, 41.32f, 0.7812f }, // windcaller pos
    { 1089.066f, 465.866f, 47.105f, 0.54f }, // assassin pos1
    { 1117.616f, 490.279f, 59.148f, 5.95f }, // assassin pos2
    { 1167.24f, 531.87f, 56.23f, 4.191f }, // pyrelord2 pos
    { 1147.96f, 535.84f, 55.28f, 5.95f }, // talon pos1
    { 1154.60f, 547.28f, 54.61f, 5.42f }, // talon pos2
    { 1171.59f, 552.21f, 54.41f, 5.51f }, // talon pos3
    { 1185.61f, 517.70f, 56.90f, 2.37f }, // talon pos4
    { 1154.52f, 516.78f, 55.56f, 0.92f }, // talon pos5
    { 1173.67f, 481.56f, 59.24f, 2.6f }, // assassin pos3
};

const Position cameraPos2 = { 1225.35f, 144.66f, 80.98f, 3.462f };

class npc_into_the_fire_controller : public CreatureScript
{
public:
    npc_into_the_fire_controller() : CreatureScript("npc_into_the_fire_controller") { }

    struct npc_into_the_fire_controllerAI : public ScriptedAI
    {
        npc_into_the_fire_controllerAI(Creature* creature) : ScriptedAI(creature) {}

        void Reset() override
        {
            me->setActive(true);
        }

        void MoveInLineOfSight(Unit* who) override
        {
            if (me->IsWithinDistInMap(who, 10.0f))
                if (Player* player = who->ToPlayer())
                    if (!_isEventStarted)
                    {
                        if (player->GetQuestStatus(QUEST_INTO_THE_FIRE) == QUEST_STATUS_REWARDED)
                            return;

                        if (player->GetQuestStatus(QUEST_INTO_THE_FIRE) == QUEST_STATUS_INCOMPLETE)
                        {
                            _isEventStarted = true;

                            uint8 randomId = urand(0, 1);

                            switch (randomId)
                            {
                            case 0:
                                if (Creature* windcaller1 = player->SummonCreature(NPC_WINDCALLER_NORDRALA, SummonQuestNpcsPos2[0], TEMPSUMMON_MANUAL_DESPAWN))
                                {
                                    windcaller1->SetPhaseMask(4, true);
                                    windcaller1->setActive(true);
                                }
                                break;
                            case 1:
                                if (Creature* windcaller2 = player->SummonCreature(NPC_WINDCALLER_VORAMUS, SummonQuestNpcsPos2[0], TEMPSUMMON_MANUAL_DESPAWN))
                                {
                                    windcaller2->SetPhaseMask(4, true);
                                    windcaller2->setActive(true);
                                }
                                break;
                            default:
                                break;
                            }
                        }
                    }
        }

        void DoAction(int32 actionId) override
        {
            if (actionId == ACTION_INTO_THE_FIRE_RESET_CONTROLLER)
            {
                _isEventStarted = false;
            }
        }

    private:
        bool _isEventStarted = false;
    };

    CreatureAI* GetAI(Creature* creature) const override
    {
        return new npc_into_the_fire_controllerAI(creature);
    }
};

// quest=29205/the-forlorn-spire
class npc_into_the_fire_windcaller_nordrala : public CreatureScript
{
public:
    npc_into_the_fire_windcaller_nordrala() : CreatureScript("npc_into_the_fire_windcaller_nordrala") { }

    struct npc_into_the_fire_windcaller_nordralaAI : public npc_escortAI
    {
        npc_into_the_fire_windcaller_nordralaAI(Creature* creature) : npc_escortAI(creature), _summons(me) { }

        void IsSummonedBy(WorldObject* summoner) override
        {
            me->SetReactState(REACT_PASSIVE);

            if (Player* player = summoner ? summoner->ToPlayer() : nullptr)
            {
                _playerGUID = player->GetGUID();
                me->SetRegeneratingHealth(false);

                if (Creature* controller = me->FindNearestCreature(NPC_INTO_THE_FIRE_CONTROLLER, 30.f))
                    _controllerGUID = controller->GetGUID();

                me->AI()->Talk(0, player, Milliseconds(2000));

                _events.ScheduleEvent(EVENT_INTO_THE_FIRE_ESCORT_1, Milliseconds(10000));
            }
        }

        void JustDied(Unit* /* killer */) override
        {
            _summons.DespawnAll();

            if (Creature* controller = ObjectAccessor::GetCreature(*me, _controllerGUID))
                controller->AI()->DoAction(ACTION_INTO_THE_FIRE_RESET_CONTROLLER);
        }

        // 4.3.4 escort hook; harmless extra method on the AC base (not an override).
        void EscortAbandonTooFarDespawn()
        {
            _summons.DespawnAll();

            if (Creature* controller = ObjectAccessor::GetCreature(*me, _controllerGUID))
                controller->AI()->DoAction(ACTION_INTO_THE_FIRE_RESET_CONTROLLER);
        }

        void WaypointReached(uint32 waypointId) override
        {
            switch (waypointId)
            {
            case 3:
                if (Creature* assassin1 = me->SummonCreature(NPC_FLAMEWAKER_ASSASSIN, SummonQuestNpcsPos2[1], TEMPSUMMON_MANUAL_DESPAWN))
                {
                    _summons.Summon(assassin1);
                    assassin1->setActive(true);
                    assassin1->AI()->AttackStart(me);
                }
                break;
            case 7:
                if (Creature* assassin2 = me->SummonCreature(NPC_FLAMEWAKER_ASSASSIN, SummonQuestNpcsPos2[2], TEMPSUMMON_MANUAL_DESPAWN))
                {
                    _summons.Summon(assassin2);
                    assassin2->setActive(true);
                    assassin2->AI()->AttackStart(me);
                }
                break;
            case 8:
                if (Player* player = ObjectAccessor::GetPlayer(*me, _playerGUID))
                    me->AI()->Talk(2, player);
                break;
            case 10:
                if (Creature* assassin3 = me->SummonCreature(NPC_FLAMEWAKER_ASSASSIN, SummonQuestNpcsPos2[9], TEMPSUMMON_MANUAL_DESPAWN))
                {
                    _summons.Summon(assassin3);
                    assassin3->setActive(true);
                    assassin3->AI()->AttackStart(me);
                }
                break;
            case 11:
                if (Creature* pyrelord = me->SummonCreature(NPC_PYRELORD_2, SummonQuestNpcsPos2[3], TEMPSUMMON_MANUAL_DESPAWN))
                {
                    _summons.Summon(pyrelord);
                    pyrelord->setActive(true);
                    pyrelord->SetControlled(true, UNIT_STATE_ROOT);
                    me->SetFlag(UNIT_FIELD_FLAGS, UNIT_FLAG_IMMUNE_TO_PC | UNIT_FLAG_IMMUNE_TO_NPC);
                }
                break;
            case 14:
                if (Player* player = ObjectAccessor::GetPlayer(*me, _playerGUID))
                    me->AI()->Talk(3, player);
                me->RemoveFlag(UNIT_FIELD_FLAGS, UNIT_FLAG_IMMUNE_TO_PC | UNIT_FLAG_IMMUNE_TO_NPC);
                me->SetControlled(true, UNIT_STATE_ROOT);
                me->SetReactState(REACT_AGGRESSIVE);
                _started = false;
                me->RemoveAura(SPELL_ENVELOPING_WINDS);
                SetDespawnAtFar(false);

                if (Creature* talon1 = me->SummonCreature(NPC_DRUID_OF_THE_TALON, SummonQuestNpcsPos2[4], TEMPSUMMON_MANUAL_DESPAWN))
                    if (Creature* talon2 = me->SummonCreature(NPC_DRUID_OF_THE_TALON, SummonQuestNpcsPos2[5], TEMPSUMMON_MANUAL_DESPAWN))
                        if (Creature* talon3 = me->SummonCreature(NPC_DRUID_OF_THE_TALON, SummonQuestNpcsPos2[6], TEMPSUMMON_MANUAL_DESPAWN))
                            if (Creature* talon4 = me->SummonCreature(NPC_DRUID_OF_THE_TALON, SummonQuestNpcsPos2[7], TEMPSUMMON_MANUAL_DESPAWN))
                                if (Creature* talon5 = me->SummonCreature(NPC_DRUID_OF_THE_TALON, SummonQuestNpcsPos2[8], TEMPSUMMON_MANUAL_DESPAWN))
                                {
                                    _summons.Summon(talon1);
                                    _summons.Summon(talon2);
                                    _summons.Summon(talon3);
                                    _summons.Summon(talon4);
                                    _summons.Summon(talon5);
                                    talon1->setActive(true);
                                    talon2->setActive(true);
                                    talon3->setActive(true);
                                    talon4->setActive(true);
                                    talon5->setActive(true);

                                    if (Creature* pyre = me->FindNearestCreature(NPC_PYRELORD_2, 50.f))
                                    {
                                        talon1->AI()->AttackStart(pyre);
                                        talon2->AI()->AttackStart(pyre);
                                        talon3->AI()->AttackStart(pyre);
                                        talon4->AI()->AttackStart(pyre);
                                        talon5->AI()->AttackStart(pyre);
                                    }
                                }

                break;
            default:
                break;
            }
        }

        void JustSummoned(Creature* summoned) override
        {
            if (summoned->GetEntry() == NPC_FLAMEWAKER_ASSASSIN)
            {
                _summons.Summon(summoned);
                SetEscortPaused(true);
            }
        }

        void SummonedCreatureDies(Creature* summon, Unit* /*killer*/) override
        {
            if (summon->GetEntry() == NPC_FLAMEWAKER_ASSASSIN)
                SetEscortPaused(false);

            if (summon->GetEntry() == NPC_PYRELORD_2)
            {
                if (Creature* gripcontroller = me->FindNearestCreature(NPC_INTO_THE_FIRE_GRIP_CONTROLLER, 50.f))
                {
                    gripcontroller->AI()->DoAction(ACTION_INTO_THE_FIRE_END_GRIP);
                }

                _summons.DespawnAll();
                me->DespawnOrUnsummon();

                if (Creature* controller = ObjectAccessor::GetCreature(*me, _controllerGUID))
                    controller->AI()->DoAction(ACTION_INTO_THE_FIRE_RESET_CONTROLLER);
            }
        }

        void JustEngagedWith(Unit* who) override
        {
            if (who->GetEntry() == NPC_PYRELORD_2)
            {
                _events.ScheduleEvent(EVENT_WINDCALLER_ATTACK_EVENT_1, Milliseconds(urand(2000, 4000)));
            }
        }

        void UpdateAI(uint32 uiDiff) override
        {
            npc_escortAI::UpdateAI(uiDiff);

            _events.Update(uiDiff);

            if (_started)
            {
                if (!me->HasAura(SPELL_ENVELOPING_WINDS))
                    me->CastSpell(me, SPELL_ENVELOPING_WINDS, true);
            }

            if (_checkPlayerTimer <= uiDiff)
            {
                _checkPlayerTimer = 1000;

                if (Player* player = ObjectAccessor::GetPlayer(*me, _playerGUID))
                {
                    if (!player->IsAlive())
                    {
                        _summons.DespawnAll();
                        me->DespawnOrUnsummon();

                        if (Creature* controller = ObjectAccessor::GetCreature(*me, _controllerGUID))
                            controller->AI()->DoAction(ACTION_INTO_THE_FIRE_RESET_CONTROLLER);
                    }
                }
            }
            else _checkPlayerTimer -= uiDiff;

            while (uint32 eventId = _events.ExecuteEvent())
            {
                switch (eventId)
                {
                case EVENT_INTO_THE_FIRE_ESCORT_1:
                    me->CastSpell(me, SPELL_ENVELOPING_WINDS, true);
                    SetDespawnAtEnd(false);
                    SetDespawnAtFar(true);
                    if (Player* player = ObjectAccessor::GetPlayer(*me, _playerGUID))
                        me->AI()->Talk(1, player);
                    Start(false, _playerGUID);
                    _started = true;
                    break;
                case EVENT_WINDCALLER_ATTACK_EVENT_1:
                    if (Unit* victim = me->GetVictim())
                        me->CastSpell(victim, SPELL_WRATH, false);
                    _events.ScheduleEvent(EVENT_WINDCALLER_ATTACK_EVENT_1, Milliseconds(urand(3000, 5000)));
                    break;
                default:
                    break;
                }
            }
        }
    private:
        bool _started = false;
        EventMap _events;
        ObjectGuid _playerGUID, _controllerGUID;
        uint32 _checkPlayerTimer = 2000;
        SummonList _summons;
    };

    CreatureAI* GetAI(Creature* creature) const override
    {
        return new npc_into_the_fire_windcaller_nordralaAI(creature);
    }
};

enum IntoTheFireGrip
{
    SPELL_FURNACE_ASSAULT_CREDIT = 98826, // Trigger spell (98825) Furnace Phase Update
    SPELL_BACKDRAFT = 98839,

    GAMEOBJECT_FURNACE_DOOR = 3808427,
};

class npc_into_the_fire_end_controller : public CreatureScript
{
public:
    npc_into_the_fire_end_controller() : CreatureScript("npc_into_the_fire_end_controller") { }

    struct npc_into_the_fire_end_controllerAI : public ScriptedAI
    {
        npc_into_the_fire_end_controllerAI(Creature* creature) : ScriptedAI(creature) {}

        void Reset() override
        {
            me->setActive(true);
        }

        void DoAction(int32 actionId) override
        {
            if (actionId == ACTION_INTO_THE_FIRE_END_GRIP)
            {
                me->setActive(true);
                me->CastSpell(me, SPELL_FURNACE_ASSAULT_CREDIT, true);
                me->CastSpell(me, SPELL_BACKDRAFT, true);

                if (GameObject* door = me->FindNearestGameObject(GAMEOBJECT_FURNACE_DOOR, 50.f))
                {
                    _furnaceDoor = door->GetGUID();
                    door->SetGoState(GO_STATE_ACTIVE);
                    _events.ScheduleEvent(EVENT_INTO_THE_FIRE_END_GRIP_1, Milliseconds(8000));
                }

                for (Player* it : GetPlayersInRange(me, 45.0f, true))
                {
                    if (it->GetQuestStatus(QUEST_INTO_THE_FIRE) == QUEST_STATUS_INCOMPLETE)
                    {
                        it->CastSpell(it, SPELL_DISMOUNT_AND_CANCEL_ALL_SHAPESHIFTS, true);
                        it->KilledMonsterCredit(NPC_INTO_THE_FIRE_CREDIT);
                    }
                }
            }
        }

        void UpdateAI(uint32 uiDiff) override
        {
            _events.Update(uiDiff);

            while (uint32 eventId = _events.ExecuteEvent())
            {
                switch (eventId)
                {
                case EVENT_INTO_THE_FIRE_END_GRIP_1:
                    if (GameObject* door = ObjectAccessor::GetGameObject(*me, _furnaceDoor))
                        door->SetGoState(GO_STATE_READY);
                    break;
                default:
                    break;
                }
            }
        }

    private:
        ObjectGuid _furnaceDoor;
        EventMap _events;
    };

    CreatureAI* GetAI(Creature* creature) const override
    {
        return new npc_into_the_fire_end_controllerAI(creature);
    }
};

uint32 const TrainedHawkPathSize = 15;
const G3D::Vector3 TrainedHawkPath[TrainedHawkPathSize] =
{
    {   1248.446f, 522.867f, 65.089f    },
    {   1250.579f, 504.477f, 66.593f    },
    {   1250.250f, 461.130f, 61.452f    },
    {   1232.033f, 406.345f, 49.869f    },
    {   1206.339f, 361.024f, 45.769f    },
    {   1164.444f, 300.744f, 43.623f    },
    {   1122.587f, 238.390f, 40.289f    },
    {   1105.621f, 203.892f, 51.646f    },
    {   1077.144f, 148.343f, 72.680f    },
    {   1046.636f, 108.187f, 106.35f    },
    {   1004.504f, 51.6596f, 150.74f    },
    {   966.9389f, -4.2819f, 207.15f    },
    {   916.6203f, -78.6849f, 235.9f    },
    {   872.6154f, -133.192f, 255.5f    },
    {   858.1133f, -151.568f, 255.6f    }, // 14
};

uint32 const TrainedHawkPathSize2 = 42;
const G3D::Vector3 TrainedHawkPath2[TrainedHawkPathSize2] =
{
    {  844.109f, -166.707f, 255.3f },
    {  816.877f, -189.626f, 236.3f },
    {  786.758f, -222.995f, 218.6f },
    {  776.618f, -280.726f, 204.9f },
    {  776.263f, -319.889f, 200.7f },
    {  736.528f, -345.211f, 185.4f },
    {  697.105f, -369.096f, 186.5f },
    {  669.632f, -406.170f, 190.0f },
    {  677.329f, -467.187f, 186.3f },
    {  702.156f, -497.036f, 191.5f },
    {  756.542f, -494.568f, 190.9f },
    {  845.058f, -479.855f, 198.4f },
    {  896.818f, -454.574f, 215.5f },
    {  919.771f, -424.573f, 223.4f },
    {  883.541f, -394.661f, 215.4f },
    {  844.924f, -375.641f, 220.2f },
    {  829.995f, -350.349f, 217.9f },
    {  831.337f, -309.010f, 223.3f },
    {  831.758f, -269.802f, 232.5f },
    {  833.744f, -227.838f, 237.8f },
    {  845.964f, -194.040f, 249.5f },
    {  858.115f, -178.416f, 265.0f },
    {  883.853f, -152.397f, 269.7f },
    {  897.454f, -163.003f, 276.3f },
    {  901.916f, -178.793f, 256.6f },
    {  911.227f, -205.922f, 227.8f },
    {  918.446f, -234.283f, 210.1f },
    {  934.080f, -273.582f, 209.4f },
    {  953.958f, -328.430f, 209.1f },
    {  969.226f, -391.778f, 220.0f },
    {  966.167f, -436.776f, 221.6f },
    {  926.768f, -459.144f, 213.3f },
    {  893.154f, -438.587f, 227.8f },
    {  882.005f, -394.145f, 214.2f },
    {  885.911f, -361.837f, 210.7f },
    {  908.622f, -326.749f, 212.3f },
    {  944.397f, -270.168f, 210.1f },
    {  959.698f, -212.903f, 214.4f },
    {  953.526f, -159.839f, 246.8f },
    {  947.920f, -112.502f, 253.9f },
    {  905.848f, -100.801f, 267.4f },
    {  869.619f, -137.630f, 269.7f }, // 41
};

uint32 const TrainedHawkPathSize3 = 12;
const G3D::Vector3 TrainedHawkPath3[TrainedHawkPathSize3] =
{
    { 788.477f, -339.4f, 322.78f },
    { 808.072f, -372.7f, 322.78f },
    { 850.454f, -341.0f, 329.27f },
    { 907.997f, -286.1f, 310.46f },
    { 991.707f, -186.6f, 268.99f },
    { 1065.05f, -63.58f, 187.69f },
    { 1097.28f,  85.74f, 143.38f },
    { 1124.98f,  155.8f, 127.76f },
    { 1166.46f,  225.3f, 117.21f },
    { 1207.95f,  312.8f, 102.59f },
    { 1242.30f,  424.3f, 83.624f },
    { 1245.31f,  513.2f, 62.085f }, // 11
};

enum FireInTheSkies
{
    QUEST_FIRE_IN_THE_SKIES = 29290,
    SPELL_RETURN_TO_THE_FURNACE = 99674,

    NPC_RAGEPYRE = 3654252,
    NPC_FLASHFIRE = 3654254,
    NPC_HEATFLAYER = 3654256,
    NPC_BLAZEFURY = 3654253,
    NPC_HATESPARK = 3654255,
    NPC_SINGESLAYER = 3654257,

    SPELL_RAGEPYRE_CREDIT = 101098,
    SPELL_FLASHFIRE_CREDIT = 101099,
    SPELL_HEATFLAYER_CREDIT = 101101,
    SPELL_BLAZEFURY_CREDIT = 101097,
    SPELL_HATESPARK_CREDIT = 101100,
    SPELL_SINGESLAYER_CREDIT = 101103,
};

class npc_trained_fire_hawk_vehicle : public CreatureScript
{
public:
    npc_trained_fire_hawk_vehicle() : CreatureScript("npc_trained_fire_hawk_vehicle") { }

    struct npc_trained_fire_hawk_vehicleAI : public VehicleAI
    {
        npc_trained_fire_hawk_vehicleAI(Creature* creature) : VehicleAI(creature) {}

        void IsSummonedBy(WorldObject* summoner) override
        {
            me->SetReactState(REACT_PASSIVE);

            if (Player* player = summoner ? summoner->ToPlayer() : nullptr)
            {
                _playerGUID = player->GetGUID();
                player->CastSpell(player, SPELL_SANCTUARY_NO_COMBAT, true);
                player->CastSpell(player, SPELL_DISMOUNT_AND_CANCEL_ALL_SHAPESHIFTS, true);
            }
        }

        void KilledUnit(Unit* victim) override
        {
            switch (victim->GetEntry())
            {
            case NPC_RAGEPYRE:
                me->CastSpell(me, SPELL_RAGEPYRE_CREDIT, true);
                break;
            case NPC_FLASHFIRE:
                me->CastSpell(me, SPELL_FLASHFIRE_CREDIT, true);
                break;
            case NPC_HEATFLAYER:
                me->CastSpell(me, SPELL_HEATFLAYER_CREDIT, true);
                break;
            case NPC_BLAZEFURY:
                me->CastSpell(me, SPELL_BLAZEFURY_CREDIT, true);
                break;
            case NPC_HATESPARK:
                me->CastSpell(me, SPELL_HATESPARK_CREDIT, true);
                break;
            case NPC_SINGESLAYER:
                me->CastSpell(me, SPELL_SINGESLAYER_CREDIT, true);
                break;
            default:
                break;
            }
        }

        void PassengerBoarded(Unit* passenger, int8 /* seatId */, bool apply) override
        {
            if (apply && passenger->IsPlayer())
            {
                _events.ScheduleEvent(EVENT_TRAINED_HAWK_1, Milliseconds(500));
            }

            if (!apply && passenger->IsPlayer())
            {
                me->RemoveNpcFlag(UNIT_NPC_FLAG_SPELLCLICK);
                me->DespawnOrUnsummon();
            }
        }

        void SpellHit(Unit* /*who*/, SpellInfo const* spellInfo) override
        {
            if (spellInfo->Id == SPELL_RETURN_TO_THE_FURNACE && !_activated)
            {
                _activated = true;
                me->GetMotionMaster()->Clear();
                me->SetSpeed(MOVE_RUN, 4.5f);
                me->SetSpeed(MOVE_FLIGHT, 4.5f);
                DoMoveSmoothPath(me, TrainedHawkPath3, TrainedHawkPathSize3);
                _phase = 2;
            }
        }

        void MovementInform(uint32 type, uint32 point) override
        {
            // AC 3.3.5: SPLINE_MOTION_TYPE does not exist; MoveSplinePath (DoMoveSmoothPath)
            // reports completion as ESCORT_MOTION_TYPE.
            if (type != ESCORT_MOTION_TYPE)
                return;

            if (point == 14 && _phase == 0)
            {
                me->SetSpeed(MOVE_RUN, 1.4f);
                me->SetSpeed(MOVE_FLIGHT, 1.4f);
                DoMoveSmoothPath(me, TrainedHawkPath2, TrainedHawkPathSize2);
                _phase = 1;
            }

            if (_phase == 1 && point == 41)
            {
                _events.Reset();
                me->GetMotionMaster()->Clear();
                DoMoveSmoothPath(me, TrainedHawkPath2, TrainedHawkPathSize2);
            }

            if (_phase == 2 && point == 11)
            {
                if (Player* player = ObjectAccessor::GetPlayer(*me, _playerGUID))
                {
                    _events.Reset();
                    me->GetMotionMaster()->Clear();
                    player->ExitVehicle();
                    me->DespawnOrUnsummon();
                }
            }
        }

        void UpdateAI(uint32 diff) override
        {
            if (_checkTimer <= diff)
            {
                _checkTimer = 1000;

                if (!_complete)
                {
                    if (Player* player = ObjectAccessor::GetPlayer(*me, _playerGUID))
                    {
                        if (player->GetQuestStatus(QUEST_FIRE_IN_THE_SKIES) == QUEST_STATUS_COMPLETE)
                        {
                            _activated = true;
                            _complete = true;
                            me->GetMotionMaster()->Clear();
                            me->SetSpeed(MOVE_RUN, 4.5f);
                            me->SetSpeed(MOVE_FLIGHT, 4.5f);
                            DoMoveSmoothPath(me, TrainedHawkPath3, TrainedHawkPathSize3);
                            _events.Reset();
                            _phase = 2;
                        }
                    }
                }
            }
            else _checkTimer -= diff;

            _events.Update(diff);

            while (uint32 eventId = _events.ExecuteEvent())
            {
                switch (eventId)
                {
                case EVENT_TRAINED_HAWK_1:
                    me->SetSpeed(MOVE_RUN, 3.5f);
                    me->SetSpeed(MOVE_FLIGHT, 3.5f);
                    DoMoveSmoothPath(me, TrainedHawkPath, TrainedHawkPathSize);
                    break;
                default:
                    break;
                }
            }
        }
    private:
        bool _activated = false;
        bool _complete = false;
        uint8 _phase = 0;
        uint32 _checkTimer = 1000;
        ObjectGuid _playerGUID;
        EventMap _events;
    };
    CreatureAI* GetAI(Creature* creature) const override
    {
        return new npc_trained_fire_hawk_vehicleAI(creature);
    }
};
// quest=29272/need-water-badly#
enum QuestNeedWaterBadly
{
    QUEST_GET_ME_OUT_OF_HERE = 29272,

};

const Position AnrenJumpPos[] =
{
    { 1449.68f, 318.50f, -93.51f }, // starting jumps
    { 1442.51f, 324.99f, -93.54f }, // starting jumps
    { 1436.13f, 320.76f, -93.54f }, // starting jumps
    { 1431.36f, 324.21f, -93.54f }, // starting jumps
    { 1426.41f, 325.58f, -93.54f }, // starting jumps
    { 1420.95f, 326.76f, -91.67f }, // starting jumps
    { 1333.82f, 381.99f, -60.903f},
    { 1328.24f, 347.38f, -52.52f },
    { 1297.04f, 347.87f, -61.38f },
    { 1268.53f, 354.55f, -54.50f },
    { 1262.59f, 359.97f, -46.27f },
    { 1260.89f, 373.37f, -40.62f },
    { 1234.87f, 378.72f, -51.75f },
};

class npc_anren_shadowseeker_escort : public CreatureScript
{
public:
    npc_anren_shadowseeker_escort() : CreatureScript("npc_anren_shadowseeker_escort") { }

    struct npc_anren_shadowseeker_escortAI : public npc_escortAI
    {
        npc_anren_shadowseeker_escortAI(Creature* creature) : npc_escortAI(creature) { }

        void IsSummonedBy(WorldObject* summoner) override
        {
            if (Player* player = summoner ? summoner->ToPlayer() : nullptr)
            {
                _playerGUID = player->GetGUID();
                me->RemoveByteFlag(UNIT_FIELD_BYTES_1, 0, 7);
                me->SetHealth(15475);
                me->AI()->Talk(0, player, Milliseconds(1500));
                _events.ScheduleEvent(EVENT_ANREN_ESCORT_1, Milliseconds(5500));
            }
        }

        void JustDied(Unit* /* killer */) override
        {
            if (Player* player = ObjectAccessor::GetPlayer(*me, _playerGUID))
                me->AI()->Talk(9, player);
        }

        // 4.3.4 escort hook; harmless extra method on the AC base (not an override).
        void EscortAbandonTooFarDespawn()
        {
            if (Player* player = ObjectAccessor::GetPlayer(*me, _playerGUID))
                me->AI()->Talk(10, player);
        }

        void WaypointReached(uint32 waypointId) override
        {
            Player* player = ObjectAccessor::GetPlayer(*me, _playerGUID);
            switch (waypointId)
            {
            case 15:
                _running = false; // SetRun(false) -> local flag (escort base has no SetRun on this fork).
                if (player)
                    me->AI()->Talk(3, player, Milliseconds(1000));
                _events.ScheduleEvent(EVENT_ANREN_ESCORT_8, Milliseconds(4000));
                break;
            case 16:
                if (player)
                    me->AI()->Talk(4, player);
                _events.ScheduleEvent(EVENT_ANREN_ESCORT_9, Milliseconds(1000));
                break;
            case 17:
                if (player)
                    me->AI()->Talk(5, player, Milliseconds(100));
                _events.ScheduleEvent(EVENT_ANREN_ESCORT_10, Milliseconds(0));
                break;
            case 18:
                _events.ScheduleEvent(EVENT_ANREN_ESCORT_11, Milliseconds(500));
                break;
            case 20:
                _events.ScheduleEvent(EVENT_ANREN_ESCORT_14, Milliseconds(500));
                break;
            case 24: // credit
                SetDespawnAtEnd(true);
                SetDespawnAtFar(false);
                if (player)
                {
                    me->AI()->Talk(7, player, Milliseconds(500));
                    me->AI()->Talk(8, player, Milliseconds(7500));
                    player->KilledMonsterCredit(me->GetEntry());
                }
                break;
            default:
                break;
            }
        }

        void UpdateAI(uint32 uiDiff) override
        {
            npc_escortAI::UpdateAI(uiDiff);

            _events.Update(uiDiff);

            if (_checkPlayerTimer <= uiDiff)
            {
                _checkPlayerTimer = 1000;

                if (Player* player = ObjectAccessor::GetPlayer(*me, _playerGUID))
                {
                    if (!player->IsAlive())
                        me->DespawnOrUnsummon();

                    if (_isPlayerAround)
                    {
                        if (player->IsInCombat() || me->IsInCombat())
                            SetEscortPaused(true);
                        else
                            SetEscortPaused(false);
                    }
                    else
                    {
                        if (!player->IsInCombat())
                        {
                            if (player->GetDistance(me) < 10.f)
                            {
                                SetEscortPaused(false);
                                _isPlayerAround = true;
                            }
                            else
                                SetEscortPaused(true);
                        }
                    }
                }
            }
            else _checkPlayerTimer -= uiDiff;

            while (uint32 eventId = _events.ExecuteEvent())
            {
                switch (eventId)
                {
                case EVENT_ANREN_ESCORT_1:
                    me->GetMotionMaster()->MoveJump(AnrenJumpPos[0], 8.f, 10.f);
                    _events.ScheduleEvent(EVENT_ANREN_ESCORT_2, Milliseconds(2000));
                    break;
                case EVENT_ANREN_ESCORT_2:
                    me->GetMotionMaster()->MoveJump(AnrenJumpPos[1], 10.f, 15.f);
                    if (Player* player = ObjectAccessor::GetPlayer(*me, _playerGUID))
                        me->AI()->Talk(1, player, Milliseconds(1000));
                    _events.ScheduleEvent(EVENT_ANREN_ESCORT_3, Milliseconds(3500));
                    break;
                case EVENT_ANREN_ESCORT_3:
                    me->GetMotionMaster()->MoveJump(AnrenJumpPos[2], 8.f, 11.f);
                    _events.ScheduleEvent(EVENT_ANREN_ESCORT_4, Milliseconds(1500));
                    break;
                case EVENT_ANREN_ESCORT_4:
                    me->GetMotionMaster()->MoveJump(AnrenJumpPos[3], 9.f, 11.f);
                    _events.ScheduleEvent(EVENT_ANREN_ESCORT_5, Milliseconds(2000));
                    break;
                case EVENT_ANREN_ESCORT_5:
                    me->GetMotionMaster()->MoveJump(AnrenJumpPos[4], 9.f, 11.f);
                    _events.ScheduleEvent(EVENT_ANREN_ESCORT_6, Milliseconds(2000));
                    break;
                case EVENT_ANREN_ESCORT_6:
                    if (Player* player = ObjectAccessor::GetPlayer(*me, _playerGUID))
                        me->AI()->Talk(2, player, Milliseconds(1000));
                    me->GetMotionMaster()->MoveJump(AnrenJumpPos[5], 12.f, 11.f);
                    _events.ScheduleEvent(EVENT_ANREN_ESCORT_7, Milliseconds(5000));
                    break;
                case EVENT_ANREN_ESCORT_7:
                    SetDespawnAtEnd(false);
                    SetDespawnAtFar(true);
                    Start(true, _playerGUID);
                    break;
                case EVENT_ANREN_ESCORT_8:
                    me->GetMotionMaster()->MoveJump(AnrenJumpPos[6], 10.f, 20.f);
                    _isPlayerAround = false;
                    break;
                case EVENT_ANREN_ESCORT_9:
                    me->GetMotionMaster()->MoveJump(AnrenJumpPos[7], 12.f, 22.f);
                    _isPlayerAround = false;
                    break;
                case EVENT_ANREN_ESCORT_10:
                    me->GetMotionMaster()->MoveJump(AnrenJumpPos[8], 15.f, 20.f);
                    _isPlayerAround = false;
                    break;
                case EVENT_ANREN_ESCORT_11:
                    me->GetMotionMaster()->MoveJump(AnrenJumpPos[9], 15.f, 20.f);
                    _events.ScheduleEvent(EVENT_ANREN_ESCORT_12, Milliseconds(3000));
                    break;
                case EVENT_ANREN_ESCORT_12:
                    me->GetMotionMaster()->MoveJump(AnrenJumpPos[10], 15.f, 20.f);
                    if (Player* player = ObjectAccessor::GetPlayer(*me, _playerGUID))
                        me->AI()->Talk(6, player, Milliseconds(100));
                    _events.ScheduleEvent(EVENT_ANREN_ESCORT_13, Milliseconds(2000));
                    break;
                case EVENT_ANREN_ESCORT_13:
                    _isPlayerAround = false;
                    me->GetMotionMaster()->MoveJump(AnrenJumpPos[11], 15.f, 20.f);
                    break;
                case EVENT_ANREN_ESCORT_14:
                    _running = true; // SetRun(true) -> local flag (no SetRun on this fork's escort base).
                    me->GetMotionMaster()->MoveJump(AnrenJumpPos[12], 15.f, 15.f);
                    break;
                default:
                    break;
                }
            }
        }
    private:
        bool _isPlayerAround = true;
        bool _running = false;
        EventMap _events;
        ObjectGuid _playerGUID;
        uint32 _checkPlayerTimer = 2000;
    };

    CreatureAI* GetAI(Creature* creature) const override
    {
        return new npc_anren_shadowseeker_escortAI(creature);
    }
};

enum MoltenBehemoth
{
    SPELL_FIERY_BOULDER = 97247, // triggers ID - 97246 Fiery Boulder
    SPELL_MOLTEN_STOMP = 97243,
    SPELL_GRANT_FLAWLESS_VICTORY = 101167,

    ACHIEVEMENT_FLAWLESS_VICTORY = 5867,
};

class npc_molten_front_behemoth : public CreatureScript
{
public:
    npc_molten_front_behemoth() : CreatureScript("npc_molten_front_behemoth") { }

    struct npc_molten_front_behemothAI : public ScriptedAI
    {
        npc_molten_front_behemothAI(Creature* creature) : ScriptedAI(creature) {}

        void Reset() override
        {
            _events.Reset();
            _deservesAchiv = true;
            _unableToKill = false;
            _solo = false;
        }

        void DamageTaken(Unit* attacker, uint32& damage, DamageEffectType /*damagetype*/, SpellSchoolMask /*damageSchoolMask*/) override
        {
            if (Player* player = attacker ? attacker->ToPlayer() : nullptr)
            {
                if (damage >= me->GetHealth())
                    damage = me->GetHealth() - 1;

                if ((me->GetHealthPct() < 1))
                {
                    if (!_unableToKill)
                    {
                        _unableToKill = true;
                        _events.Reset();
                        if (me->HasUnitState(UNIT_STATE_CASTING))
                            me->CastStop();

                        // 4.3.4 getThreatManager().getThreatList() -> AC GetThreatMgr() + sorted list.
                        if (me->GetThreatMgr().GetThreatListSize() == 1)
                        {
                            for (ThreatReference const* ref : me->GetThreatMgr().GetSortedThreatList())
                            {
                                if (Unit* unit = ref->GetVictim())
                                    if (Player* plr = unit->ToPlayer())
                                        if (plr->GetGUID() == _playerGUID)
                                            _solo = true;
                            }
                        }
                    }

                    Unit::Kill(player, me);
                }
            }
        }

        void DoAction(int32 actionid) override
        {
            if (_deservesAchiv)
                if (actionid == ACTION_MOLTEN_BEHEMOTH_ACHIEVEMENT_NOT_DESERVE)
                    _deservesAchiv = false;
        }

        void JustDied(Unit* killer) override
        {
            if (_deservesAchiv && _solo)
            {
                if (Player* playerkilled = killer ? killer->ToPlayer() : nullptr)
                    playerkilled->CastSpell(playerkilled, SPELL_GRANT_FLAWLESS_VICTORY, true);
            }
        }

        void JustEngagedWith(Unit* who) override
        {
            if (Player* player = who ? who->ToPlayer() : nullptr)
                _playerGUID = player->GetGUID();

            _events.ScheduleEvent(EVENT_MOLTEN_BEHEMOTH_FIERY_BOULDER, Milliseconds(urand(2000, 8000)));
            _events.ScheduleEvent(EVENT_MOLTEN_BEHEMOTH_MOLTEN_STOMP, Milliseconds(urand(8000, 13000)));
        }

        void UpdateAI(uint32 diff) override
        {
            DoMeleeAttackIfReady();

            if (!UpdateVictim())
                return;

            if (me->HasUnitState(UNIT_STATE_CASTING))
                return;

            _events.Update(diff);

            while (uint32 eventId = _events.ExecuteEvent())
            {
                switch (eventId)
                {
                case EVENT_MOLTEN_BEHEMOTH_FIERY_BOULDER:
                    if (Unit* victim = me->GetVictim())
                        me->CastSpell(victim, SPELL_FIERY_BOULDER, false);

                    _events.ScheduleEvent(EVENT_MOLTEN_BEHEMOTH_FIERY_BOULDER, Milliseconds(urand(10000, 18000)));
                    break;
                case EVENT_MOLTEN_BEHEMOTH_MOLTEN_STOMP:
                    me->CastSpell(me, SPELL_MOLTEN_STOMP, false);
                    _events.ScheduleEvent(EVENT_MOLTEN_BEHEMOTH_MOLTEN_STOMP, Milliseconds(urand(12000, 25000)));
                    break;
                default:
                    break;
                }
            }
        }

    private:
        bool _unableToKill = false;
        bool _solo = false;
        bool _deservesAchiv = true;
        EventMap _events;
        ObjectGuid _playerGUID;
        uint16 _checkTimer = 1000;
    };

    CreatureAI* GetAI(Creature* creature) const override
    {
        return new npc_molten_front_behemothAI(creature);
    }
};

class spell_molten_behemoth_stomp : public SpellScriptLoader
{
public:
    spell_molten_behemoth_stomp() : SpellScriptLoader("spell_molten_behemoth_stomp") { }

    class spell_molten_behemoth_stomp_SpellScript : public SpellScript
    {
        PrepareSpellScript(spell_molten_behemoth_stomp_SpellScript);

        bool Validate(SpellInfo const* /*spellEntry*/) override
        {
            return true;
        }

        void HandleHit(SpellEffIndex /*effIndex*/)
        {
            Unit* caster = GetCaster();

            if (Unit* unit = GetHitUnit())
                if (unit->ToPlayer())
                    if (Creature* casteriscreature = caster ? caster->ToCreature() : nullptr)
                        if (CreatureAI* ai = casteriscreature->AI())
                            ai->DoAction(ACTION_MOLTEN_BEHEMOTH_ACHIEVEMENT_NOT_DESERVE);
        }

        void Register() override
        {
            OnEffectHitTarget += SpellEffectFn(spell_molten_behemoth_stomp_SpellScript::HandleHit, EFFECT_0, SPELL_EFFECT_SCHOOL_DAMAGE);
        }
    };

    SpellScript* GetSpellScript() const override
    {
        return new spell_molten_behemoth_stomp_SpellScript();
    }
};

class spell_molten_behemoth_fiery_boulder : public SpellScriptLoader
{
public:
    spell_molten_behemoth_fiery_boulder() : SpellScriptLoader("spell_molten_behemoth_fiery_boulder") { }

    class spell_molten_behemoth_fiery_boulder_SpellScript : public SpellScript
    {
        PrepareSpellScript(spell_molten_behemoth_fiery_boulder_SpellScript);

        bool Validate(SpellInfo const* /*spellEntry*/) override
        {
            return true;
        }

        void HandleHit(SpellEffIndex /*effIndex*/)
        {
            Unit* caster = GetCaster();

            if (Unit* unit = GetHitUnit())
                if (unit->ToPlayer())
                    if (Creature* casteriscreature = caster ? caster->ToCreature() : nullptr)
                        if (CreatureAI* ai = casteriscreature->AI())
                            ai->DoAction(ACTION_MOLTEN_BEHEMOTH_ACHIEVEMENT_NOT_DESERVE);
        }

        void Register() override
        {
            OnEffectHitTarget += SpellEffectFn(spell_molten_behemoth_fiery_boulder_SpellScript::HandleHit, EFFECT_1, SPELL_EFFECT_SCHOOL_DAMAGE);
        }
    };

    SpellScript* GetSpellScript() const override
    {
        return new spell_molten_behemoth_fiery_boulder_SpellScript();
    }
};

void AddSC_dc_molten_front()
{
    new npc_hyjal_wisp_away();
    new npc_the_forlorn_spire_controller();
    new npc_the_forlorn_spire_anydruid();
    new npc_the_forlorn_spire_warden();
    new npc_the_forlorn_spire_camera();
    new npc_flame_protection_rune();
    new npc_molten_splash_origin_bunny();
    new npc_into_the_fire_controller();
    new npc_into_the_fire_windcaller_nordrala();
    new npc_into_the_fire_end_controller();
    new npc_trained_fire_hawk_vehicle();
    new npc_anren_shadowseeker_escort();
    new npc_molten_front_behemoth();
    new spell_molten_behemoth_stomp();
    new spell_molten_behemoth_fiery_boulder();
}