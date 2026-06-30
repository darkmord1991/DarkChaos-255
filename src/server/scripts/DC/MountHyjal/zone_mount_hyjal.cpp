// PORTED from Project-Neltharion zone_mount_hyjal.cpp by port_neltharion_cpp.py (first pass).
// MECHANICAL: applied API-delta subs + dc entry offset (+3600000 on NPC_/GO_ enums). NEEDS a compile
// pass on the AC build for the deeper 4.3.4->3.3.5 deltas (vehicle/escort signatures, helper
// renames). Spell IDs are CATA — see the spell-downport list. ScriptNames wired by SQL.

/* ScriptData
SDName: Mount Hyjal
SD%Complete: 100 (with SQL)
SDComment: Wondi Scripts!
SDCategory: Mount Hyjal
EndScriptData */

#include "UnorderedMap.h"
#include "AchievementMgr.h"
#include "ScriptMgr.h"
#include "ScriptedCreature.h"
#include "ScriptedGossip.h"
#include "ScriptedEscortAI.h"
#include "ScriptedFollowerAI.h"
#include "Player.h"
#include "Vehicle.h"
#include "GameObject.h"
#include "CreatureAI.h"
#include "CreatureTextMgr.h"
#include "SpellScript.h"
#include "SpellAuraEffects.h"
#include "SmartAI.h"
#include "SmartScript.h"

enum MountHyjalDefaultSpells
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

enum MountHyjalEvents
{
    EVENT_TIMER_0 = 1,
    EVENT_TIMER_1,
    EVENT_TIMER_2,
    EVENT_TIMER_3,
    EVENT_TIMER_4,
    EVENT_TIMER_FADE,
    EVENT_PROVEDITOR_1,
    EVENT_FLAMEWARD_1,
    EVENT_FLAMEWARD_2,
    EVENT_AESSINA_VEH_1,
    EVENT_AESSINA_VEH_2,
    EVENT_AESSINA_VEH_3,
    EVENT_AESSINA_VEH_4,
    EVENT_AESSINA_VEH_5,
    EVENT_CHILD_OF_TORTOLLA_1,
    EVENT_AGILITY_TRAINER_1,
    EVENT_AGILITY_TRAINER_2,
    EVENT_EMERALD_DRAKE_1,
    EVENT_EMERALD_DRAKE_2,
    EVENT_GRADUATION_1,
    EVENT_GRADUATION_2,
    EVENT_WINGS_OF_AVIANA_1,
    EVENT_LOGOSH_1,
    EVENT_LOGOSH_2,
    EVENT_LOGOSH_3,

    ACTION_GRADUATION_1,
    ACTION_GRADUATION_2,
    ACTION_GRADUATION_3,
    ACTION_GRADUATION_4,
};

enum AronusFlightData
{
    NPC_DEATHWING = 3639867,
    NPC_RAGNAROS = 3638806,

    SPELL_FLAME_BREATH = 95692,
    SPELL_EJECT_PASSENGER = 50630,
    SPELL_FADE_TO_BLACK = 97710,
};

uint32 const AronusVehiclePathSize1 = 3;
const G3D::Vector3 AronusVehiclePath1[AronusVehiclePathSize1] =
{
    { 4739.02f, -3237.51f, 1086.64f }, // 0
    { 4623.37f, -3210.95f, 1073.93f }, // 1
    { 4603.22f, -3288.47f, 1075.54f }, // 2
};

uint32 const AronusVehiclePathSize2 = 7;
const G3D::Vector3 AronusVehiclePath2[AronusVehiclePathSize2] =
{
    { 4702.86f, -3255.87f, 1091.969f},   // 0
    { 4673.62f, -3189.59f, 1105.02f },   // 1
    { 4415.34f, -3115.84f, 1099.76f },  // 2
    { 4333.77f, -3161.17f, 1082.10f },  // 3
    { 4170.11f, -3094.82f, 1062.42f },  // 4
    { 4120.65f, -3020.22f, 1019.12f },  // 5
    { 4062.83f, -3043.11f,  990.52f },  // 6
};

uint32 const AronusVehiclePathSize3 = 8;
const G3D::Vector3 AronusVehiclePath3[AronusVehiclePathSize3] =
{
   { 4181.818f, -3308.750f, 1114.41f },  // 0
   { 4331.326f, -2988.072f, 1188.50f },  // 1
   { 4653.400f, -3068.358f, 1323.18f },  // 2
   { 4885.663f, -3513.686f, 1659.74f },  // 3
   { 5178.740f, -3491.761f, 1762.36f },  // 4
   { 5357.850f, -3756.948f, 1735.16f },  // 5
   { 5566.035f, -3767.635f, 1654.33f },  // 6
   { 5533.055f, -3623.681f, 1570.04f },  // 7
};

static Position PlayerJumpPos = { 5531.485f, -3620.92f, 1567.53f };

class npc_aronus_vehicle : public CreatureScript
{
public:
    npc_aronus_vehicle() : CreatureScript("npc_aronus_vehicle") { }

    struct npc_aronus_vehicleAI : public npc_escortAI
    {
        npc_aronus_vehicleAI(Creature* creature) : npc_escortAI(creature) { }

        uint8 flyphase = 0;

        void IsSummonedBy(Unit* summoner)
        {
            if (auto player = summoner->ToPlayer())
                playerGUID = player->GetGUID();
        }

        void PassengerBoarded(Unit* passenger, int8 seatId, bool apply)
        {
            flyphase = 1;
            if (apply && passenger->GetTypeId() == TYPEID_PLAYER)
                events.ScheduleEvent(EVENT_TIMER_0, 1000);
        }

        void MovementInform(uint32 type, uint32 point) override
        {
            if (type != ESCORT_MOTION_TYPE)
                return;

            if (auto passenger = me->GetVehicleKit()->GetPassenger(0)) {
                switch (point)
                {
                case 2:
                    if (flyphase == 1)
                        events.ScheduleEvent(EVENT_TIMER_1, 1000);
                    break;
                case 3:
                    if (flyphase == 2)
                        AiTalk(me->AI(), 1, playerGUID);
                    break;
                case 6:
                    if (flyphase == 2)
                        events.ScheduleEvent(EVENT_TIMER_2, 1000);
                    break;
                case 7:
                    if (flyphase == 3)
                        events.ScheduleEvent(EVENT_TIMER_4, 3000);
                    break;
                default:
                    break;
                }
            }
        }
        void WaypointReached(uint32 waypointId) {}

        void UpdateAI(uint32 const diff)
        {
            events.Update(diff);

            while (uint32 eventId = events.ExecuteEvent())
            {
                switch (eventId)
                {
                case EVENT_TIMER_0:
                    me->SetCanFly(true);
                    me->SetDisableGravity(true);
                    me->SetSpeed(MOVE_FLIGHT, 1.2f);
                    me->AI()->DoCast(SPELL_FLIGHT_SPEED_180);
                    MoveSmoothPath(me->GetMotionMaster(), AronusVehiclePath1, AronusVehiclePathSize1);
                    events.ScheduleEvent(EVENT_TIMER_FADE, 2000);
                    break;
                case EVENT_TIMER_1:
                    AiTalk(me->AI(), 0, playerGUID);
                    MoveSmoothPath(me->GetMotionMaster(), AronusVehiclePath2, AronusVehiclePathSize2);
                    me->RemoveAura(SPELL_FLIGHT_SPEED_180);
                    me->AI()->DoCast(SPELL_FLIGHT_SPEED_280);
                    flyphase = 2;
                    break;
                case EVENT_TIMER_2:
                    flyphase = 3;
                    me->SetOrientation(4.116f);
                    me->SummonCreature(NPC_RAGNAROS, 4024.39f, -3100.2f, 972.58f, 0.969f, TEMPSUMMON_TIMED_DESPAWN, 8000); //  SAI ragna
                    events.ScheduleEvent(EVENT_TIMER_3, 5000);

                    if (auto deathwing = me->FindNearestCreature(NPC_DEATHWING, 300.0f))
                        deathwing->AI()->DoCast(SPELL_FLAME_BREATH);
                    break;
                case EVENT_TIMER_3:
                    AiTalk(me->AI(), 2, playerGUID);
                    MoveSmoothPath(me->GetMotionMaster(), AronusVehiclePath3, AronusVehiclePathSize3);
                    me->RemoveAura(SPELL_FLIGHT_SPEED_280);
                    me->AI()->DoCast(SPELL_FLIGHT_SPEED_300);
                    me->SetSpeed(MOVE_FLIGHT, 2.5f);
                    break;
                case EVENT_TIMER_4:
                    me->AI()->DoCast(SPELL_EJECT_PASSENGER);
                    if (auto player = ObjectAccessor::GetPlayer(*me, playerGUID))
                        player->GetMotionMaster()->MoveJump(PlayerJumpPos, 12.0f, 14.0f);
                    me->DespawnOrUnsummon(1000);
                    break;

                case EVENT_TIMER_FADE:
                    if (auto player = ObjectAccessor::GetPlayer(*me, playerGUID))
                    {
                        player->RemoveAura(SPELL_FADE_TO_BLACK);
                    }
                    break;
                default:
                    break;
                }
            }
        }
    private:
        EventMap events;
        ObjectGuid playerGUID;
    };
    CreatureAI* GetAI(Creature* creature) const
    {
        return new npc_aronus_vehicleAI(creature);
    }
};

enum EnterMountHyjalZone
{
    MOUNT_HYJAL_ZONEID = 616,
    SCORCHED_PLAIN_AREAID = 5017,
    AS_HYJAL_BURNS_QUESTID = 25316,
    SPELL_SUMMON_ARONUS = 151010,
};

static Position FirstQuestTeleport = { 4761.667f, -3234.507f, 1093.803f, 2.9624f };

class first_quest_mount_hyjal_playerscript : public PlayerScript
{
public:
    first_quest_mount_hyjal_playerscript() : PlayerScript("first_quest_mount_hyjal_playerscript") { }

    void OnPlayerUpdateZone(Player* player, uint32 newZone, uint32 newArea)
    {
        if (newZone == MOUNT_HYJAL_ZONEID && newArea == SCORCHED_PLAIN_AREAID && player->GetQuestStatus(AS_HYJAL_BURNS_QUESTID) == QUEST_STATUS_INCOMPLETE)
        {
            player->AreaExploredOrEventHappens(AS_HYJAL_BURNS_QUESTID);
            player->NearTeleportTo(FirstQuestTeleport);
            CastWithDelay(player, 2000, player, SPELL_SUMMON_ARONUS);
        }
        else
            return;
    }
};

enum EmeraldFlame
{
    QUEST_FLAMES_FROM_ABOVE = 25574,
    SPELL_TWILIGHT_BREATH = 78954,
    OBJECT_FLAMES_1 = 203065,
};

uint32 const EmeraldFlamePathSize = 10;
const G3D::Vector3 EmeraldFlamePath[EmeraldFlamePathSize] =
{
    { 5734.722f, -3301.180f, 1622.117f },
    { 5743.885f, -3294.595f, 1621.790f },
    { 5752.720f, -3289.144f, 1621.752f },
    { 5763.919f, -3283.627f, 1621.882f },
    { 5772.471f, -3285.888f, 1622.047f },
    { 5777.381f, -3290.716f, 1623.207f },
    { 5782.762f, -3302.702f, 1624.523f },
    { 5779.277f, -3314.132f, 1631.050f },
    { 5760.595f, -3333.994f, 1644.458f },
    { 5722.669f, -3357.374f, 1642.473f }, // 9 
};

class npc_emerald_flameweaver_infiltrators : public CreatureScript
{
public:
    npc_emerald_flameweaver_infiltrators() : CreatureScript("npc_emerald_flameweaver_infiltrators") { }

    struct npc_emerald_flameweaver_infiltratorsAI : public ScriptedAI
    {
        npc_emerald_flameweaver_infiltratorsAI(Creature* creature) : ScriptedAI(creature) {}

        void IsSummonedBy(Unit* summoner)
        {
            MoveSmoothPath(me->GetMotionMaster(), EmeraldFlamePath, EmeraldFlamePathSize);
        }

        void MovementInform(uint32 type, uint32 point)
        {
            if (type != ESCORT_MOTION_TYPE)
                return;

            switch (point)
            {
            case 1:
                me->CastSpell(me, SPELL_TWILIGHT_BREATH);
                break;
            case 2:
                me->SummonGameObject(OBJECT_FLAMES_1, me->GetPositionX(), me->GetPositionY(), 1606.59f, me->GetOrientation(), 0, 0, 0, 0, 10);
                break;
            case 3:
                me->CastSpell(me, SPELL_TWILIGHT_BREATH);
                me->SummonGameObject(OBJECT_FLAMES_1, me->GetPositionX(), me->GetPositionY(), 1606.59f, me->GetOrientation(), 0, 0, 0, 0, 10);
                break;
            case 4:
                me->SummonGameObject(OBJECT_FLAMES_1, me->GetPositionX(), me->GetPositionY(), 1606.59f, me->GetOrientation(), 0, 0, 0, 0, 10);
                break;
            case 5:
                me->CastSpell(me, SPELL_TWILIGHT_BREATH);
                me->SummonGameObject(OBJECT_FLAMES_1, me->GetPositionX(), me->GetPositionY(), 1606.59f, me->GetOrientation(), 0, 0, 0, 0, 10);
                break;
            case 6:
            {
                me->SummonGameObject(OBJECT_FLAMES_1, me->GetPositionX(), me->GetPositionY(), 1606.59f, me->GetOrientation(), 0, 0, 0, 0, 10);

                auto character = GetPlayersInRange(me, 70, true);
                for (auto it = character.begin(); it != character.end(); it++)
                    if ((*it)->GetQuestStatus(QUEST_FLAMES_FROM_ABOVE) == QUEST_STATUS_INCOMPLETE)
                        (*it)->KilledMonsterCredit(me->GetEntry());
                break;
            }
            case 9:
                me->DespawnOrUnsummon();
                break;
            default:
                break;
            }
        }
    };
    CreatureAI* GetAI(Creature* creature) const
    {
        return new npc_emerald_flameweaver_infiltratorsAI(creature);
    }
};

// enum Inferno
// {
//     SPELL_INFERNO_TICK_AURA   = 74813,
//     SPELL_INFERNO_AOE         = 74817,
// };
// 
// class spell_inferno_tick : public SpellScriptLoader
// {
// public:
//     spell_inferno_tick() : SpellScriptLoader("spell_inferno_tick") { }
// 
//     class spell_inferno_tick_AuraScript : public AuraScript
//     {
//         PrepareAuraScript(spell_inferno_tick_AuraScript);
// 
//         bool Validate(SpellInfo const* /*spellInfo*/)
//         {
//             if (!sSpellMgr->GetSpellInfo(SPELL_INFERNO_TICK_AURA))
//                 return false;
// 
//             return true;
//             TC_LOG_ERROR("sql.sql", "SPELL_INFERNO_TICK_AURA returned true");
//         }
// 
//         void HandleProc(AuraEffect const* aurEff, ProcEventInfo& /*eventInfo*/)
//         {
//             int32 damageForTick[8] = { 1500, 1500, 2000, 2000, 3000, 3000, 5000, 5000 };
// 
//             GetCaster()->CastCustomSpell(GetCaster(), SPELL_INFERNO_AOE, &damageForTick[aurEff->GetTotalTicks() - 1], NULL, NULL, true);
//             TC_LOG_ERROR("sql.sql", "Inferno hits!");
//         }
// 
//         void Register()
//         {
//             OnEffectPeriodic += AuraEffectPeriodicFn(spell_inferno_tick_AuraScript::HandleProc, EFFECT_0, SPELL_AURA_PERIODIC_TRIGGER_SPELL);
//         }
//     };
// 
//     AuraScript* GetAuraScript() const
//     {
//         return new spell_inferno_tick_AuraScript();
//     }
// };

enum QuestThroughtheDream
{
    QUEST_THROUGH_THE_DREAM = 25325,

    SPELL_FANDRALS_CHAINS = 76236,
    SPELL_FANDRAL_CREATOR_AURA = 76237,
    SPELL_AURA_PHASE_2048 = 68480,
    SPELL_FANDRAL_PING = 77828,
};

class npc_archdruid_fandral_staghelm_dream : public CreatureScript
{
public:
    npc_archdruid_fandral_staghelm_dream() : CreatureScript("npc_archdruid_fandral_staghelm_dream") { }

    struct npc_archdruid_fandral_staghelm_dreamAI : public ScriptedAI
    {
        npc_archdruid_fandral_staghelm_dreamAI(Creature* creature) : ScriptedAI(creature) {}

        void IsSummonedBy(Unit* summoner)
        {
            if (auto player = summoner->ToPlayer())
            {
                _playerGUID = player->GetGUID();
                me->GetMotionMaster()->MoveFollow(player, 1.f, 1.f * M_PI);
                CastWithDelay(me, 500, me, SPELL_FANDRALS_CHAINS);
            }
            else
                me->DespawnOrUnsummon();
        }

        void SpellHit(Unit* who, SpellInfo const* spellInfo)
        {
            if (spellInfo->Id == SPELL_FANDRAL_PING)
            {
                if (auto playerx = who->ToPlayer())
                    if (playerx->GetGUID() == _playerGUID)
                    {
                        playerx->AreaExploredOrEventHappens(QUEST_THROUGH_THE_DREAM);
                        me->CastSpell(me, SPELL_ROOT);
                        me->DespawnOrUnsummon(5000);
                    }
            }
        }

        void UpdateAI(uint32 const diff)
        {
            DoMeleeAttackIfReady();

            if (_checkTimer <= diff)
            {
                _checkTimer = 2000;

                if (auto player = ObjectAccessor::GetPlayer(*me, _playerGUID))
                {
                    if (!player->IsAlive())
                        me->DespawnOrUnsummon();

                    if (player->HasAura(SPELL_AURA_PHASE_2048))
                        player->RemoveAura(SPELL_AURA_PHASE_2048);

                    if (player->GetQuestStatus(QUEST_THROUGH_THE_DREAM) == QUEST_STATUS_NONE)
                        me->DespawnOrUnsummon();

                    if (me->GetDistance(player) > 80.f)
                        me->DespawnOrUnsummon();
                }
            }
            else _checkTimer -= diff;

        }
    private:
        ObjectGuid _playerGUID;
        uint16 _checkTimer = 1000;
    };

    CreatureAI* GetAI(Creature* creature) const
    {
        return new npc_archdruid_fandral_staghelm_dreamAI(creature);
    }
};

enum QuestEndSupply
{
    NPC_PROVEDITOR = 3639436,
    NPC_SLAVE_DRIVER = 3639438,
    NPC_TWILIGHT_SLAVE = 3639431,

    SPELL_UPPERCUT = 80182,
    SPELL_HOLD_BURDEN = 73918,
    SPELL_SUMMON_SUPPLIES = 73959,
    SPELL_FEAR_VISUAL = 151111,

    WAYPOINT_PATH = 39436,
};

class npc_spawn_ogres_and_slaves_controller : public CreatureScript
{
public:
    npc_spawn_ogres_and_slaves_controller() : CreatureScript("npc_spawn_ogres_and_slaves_controller") { }

    struct npc_spawn_ogres_and_slaves_controllerAI : public ScriptedAI
    {
        npc_spawn_ogres_and_slaves_controllerAI(Creature* creature) : ScriptedAI(creature) {}

        void Reset()
        {
            me->setActive(true);
        }

        void UpdateAI(uint32 const diff)
        {
            if (_checkTimer <= diff)
            {
                _checkTimer = 60000;

                if (auto ogr = me->SummonCreature(NPC_PROVEDITOR, me->GetPositionX(), me->GetPositionY(), me->GetPositionZ() + 0.5f, me->GetOrientation(), TEMPSUMMON_TIMED_DESPAWN, 900000))
                    ogr->setActive(true);
            }
            else _checkTimer -= diff;
        }
    private:
        uint16 _checkTimer = 5000;
    };

    CreatureAI* GetAI(Creature* creature) const
    {
        return new npc_spawn_ogres_and_slaves_controllerAI(creature);
    }
};

class npc_twilight_proveditor : public CreatureScript
{
public:
    npc_twilight_proveditor() : CreatureScript("npc_twilight_proveditor") { }

    struct npc_twilight_proveditorAI : public ScriptedAI
    {
        npc_twilight_proveditorAI(Creature* creature) : ScriptedAI(creature), _summons(me) {}

        void IsSummonedBy(Unit* summoner)
        {
            if (auto slavedriver = me->SummonCreature(NPC_SLAVE_DRIVER, 5127.52f, -2356.76f, 1414.76f, 5.387f, TEMPSUMMON_TIMED_DESPAWN, 900000))
            {
                slavedriver->setActive(true);

                if (auto slave1 = me->SummonCreature(NPC_TWILIGHT_SLAVE, 5129.259f, -2351.40f, 1414.31f, 4.85f, TEMPSUMMON_TIMED_DESPAWN, 900000))
                    if (auto slave2 = me->SummonCreature(NPC_TWILIGHT_SLAVE, 5126.129f, -2349.87f, 1413.75f, 5.20f, TEMPSUMMON_TIMED_DESPAWN, 900000))
                        if (auto slave3 = me->SummonCreature(NPC_TWILIGHT_SLAVE, 5125.000f, -2352.95f, 1414.10f, 5.97f, TEMPSUMMON_TIMED_DESPAWN, 900000))
                        {
                            slave1->setActive(true);
                            slave1->AI()->SetData(1, 1);
                            slave2->setActive(true);
                            slave2->AI()->SetData(2, 1);
                            slave3->setActive(true);
                            slave3->AI()->SetData(3, 1);

                            me->GetMotionMaster()->MovePath(WAYPOINT_PATH, false);
                        }
            }
        }

        void JustSummoned(Creature* summoned)
        {
            _summons.Summon(summoned);
        }

        void EnterEvadeMode()
        {
        }

        void MovementInform(uint32 type, uint32 point)
        {
            if (type != WAYPOINT_MOTION_TYPE)
                return;

            me->SetHomePosition(me->GetPositionX(), me->GetPositionY(), me->GetPositionZ(), me->GetOrientation());

            if (point == 48)
            {
                _summons.DespawnAll();
                me->DespawnOrUnsummon();
            }
        }

        void JustEngagedWith(Unit* /*who*/)
        {
            _events.ScheduleEvent(EVENT_PROVEDITOR_1, urand(4000, 12000));
        }

        void UpdateAI(uint32 const diff) override
        {
            DoMeleeAttackIfReady();

            if (me->HasUnitState(UNIT_STATE_CASTING))
                return;

            _events.Update(diff);

            while (uint32 eventId = _events.ExecuteEvent())
            {
                switch (eventId)
                {
                case EVENT_PROVEDITOR_1:
                    if (auto victim = me->GetVictim())
                        me->CastSpell(victim, SPELL_UPPERCUT);

                    _events.ScheduleEvent(EVENT_PROVEDITOR_1, urand(11000, 16000));
                    break;
                default:
                    break;
                }
            }
        }

    private:
        bool _pathStarted = false;
        EventMap _events;
        SummonList _summons;
        ObjectGuid _slavedriverGUID;
        uint16 _checkTimer = 2000;
    };

    CreatureAI* GetAI(Creature* creature) const
    {
        return new npc_twilight_proveditorAI(creature);
    }
};

class npc_twilight_slavedriver : public CreatureScript
{
public:
    npc_twilight_slavedriver() : CreatureScript("npc_twilight_slavedriver") { }

    struct npc_twilight_slavedriverAI : public ScriptedAI
    {
        npc_twilight_slavedriverAI(Creature* creature) : ScriptedAI(creature) {}

        void IsSummonedBy(Unit* summoner)
        {
            if (auto owner = summoner->ToCreature())
                _proveditorGUID = owner->GetGUID();
        }

        void JustEngagedWith(Unit* /*who*/)
        {
        }

        void UpdateAI(uint32 const diff)
        {
            DoMeleeAttackIfReady();

            if (me->HasUnitState(UNIT_STATE_CASTING))
                return;

            if (_checkTimer <= diff)
            {
                _checkTimer = 1000;

                if (auto prove = ObjectAccessor::GetCreature(*me, _proveditorGUID))
                {
                    if (!prove->IsInCombat())
                    {
                        me->GetMotionMaster()->MoveFollow(prove, 0.6f, 1.5f * M_PI, MOTION_SLOT_ACTIVE);
                        me->GetThreatMgr().ClearAllThreat();

                        if (me->IsInCombat())
                            if (auto victim = me->GetVictim())
                                prove->AI()->AttackStart(victim);
                    }
                    else
                    {
                        me->GetMotionMaster()->Clear();

                        if (!me->IsInCombat())
                            if (auto victim = prove->GetVictim())
                                me->AI()->AttackStart(victim);
                    }
                }
            }
            else _checkTimer -= diff;
        }

    private:
        ObjectGuid _proveditorGUID;
        uint16 _checkTimer = 1000;
    };

    CreatureAI* GetAI(Creature* creature) const
    {
        return new npc_twilight_slavedriverAI(creature);
    }
};

class npc_twilight_slave : public CreatureScript
{
public:
    npc_twilight_slave() : CreatureScript("npc_twilight_slave") { }

    struct npc_twilight_slaveAI : public ScriptedAI
    {
        npc_twilight_slaveAI(Creature* creature) : ScriptedAI(creature) {}

        void IsSummonedBy(Unit* summoner)
        {
            if (auto owner = summoner->ToCreature())
                _proveditorGUID = owner->GetGUID();

            if (auto drive = me->FindNearestCreature(NPC_SLAVE_DRIVER, 10.f))
                _slavedriverGUID = drive->GetGUID();

            me->SetReactState(REACT_PASSIVE);
            CastWithDelay(me, 200, me, SPELL_HOLD_BURDEN);
            _opponentsDead = false;
        }

        void SetData(uint32 data, uint32 state)
        {
            switch (data)
            {
            case 1:
                _whichSlave = 1;
                break;
            case 2:
                _whichSlave = 2;
                break;
            case 3:
                _whichSlave = 3;
                break;
            default:
                break;
            }
        }

        void UpdateAI(uint32 const diff)
        {
            DoMeleeAttackIfReady();

            if (_checkTimer <= diff)
            {
                _checkTimer = 800;

                if (auto prove = ObjectAccessor::GetCreature(*me, _proveditorGUID))
                {
                    if (!prove->IsInCombat())
                    {
                        switch (_whichSlave)
                        {
                        case 1:
                            me->SetRooted(false);
                            me->GetMotionMaster()->MoveFollow(prove, 2.0f, 0.7f * M_PI);
                            break;
                        case 2:
                            me->SetRooted(false);
                            me->GetMotionMaster()->MoveFollow(prove, 2.0f, 1.0f * M_PI);
                            break;
                        case 3:
                            me->SetRooted(false);
                            me->GetMotionMaster()->MoveFollow(prove, 2.0f, 1.3f * M_PI);
                            break;
                        default:
                            break;
                        }
                    }
                    else
                    {
                        me->GetMotionMaster()->Clear();
                        me->SetRooted(true);
                    }

                    if (!_opponentsDead)
                    {
                        if (auto driver = ObjectAccessor::GetCreature(*me, _slavedriverGUID))
                        {
                            if (!driver->IsAlive())
                                if (!prove->IsAlive())
                                {
                                    _opponentsDead = true;
                                    me->GetMotionMaster()->Clear();
                                    me->RemoveAura(SPELL_HOLD_BURDEN);
                                    me->CastSpell(me, SPELL_SUMMON_SUPPLIES);
                                    CastWithDelay(me, 2500, me, SPELL_FEAR_VISUAL);
                                    me->DespawnOrUnsummon(6000);
                                }
                        }
                    }
                }
            }
            else _checkTimer -= diff;
        }

    private:
        bool _opponentsDead = false;
        uint8 _whichSlave = 0;
        ObjectGuid _proveditorGUID;
        ObjectGuid _slavedriverGUID;
        uint16 _checkTimer = 1000;
    };

    CreatureAI* GetAI(Creature* creature) const
    {
        return new npc_twilight_slaveAI(creature);
    }
};
//

enum PreppingSoil
{
    NPC_FLAMEWARD = 3640460,
};

class go_flameward_inferno : public GameObjectScript
{
public:
    go_flameward_inferno() : GameObjectScript("go_flameward_inferno") { }

    bool OnGossipHello(Player* player, GameObject* go) override
    {
        if (!player->FindNearestCreature(NPC_FLAMEWARD, 20.f))
        {
            go->SetLootState(GO_READY);
            go->UseDoorOrButton(0, false, player);

            if (auto flameward = player->SummonCreature(NPC_FLAMEWARD, go->GetPositionX(), go->GetPositionY() + 0.1f, go->GetPositionZ() + 1.8f, go->GetOrientation(), TEMPSUMMON_MANUAL_DESPAWN))
                flameward->setActive(true);
        }

        return true;
    }
};

enum QuestPrepping
{
    QUEST_PREPPING_THE_SOIL = 25502,

    NPC_ASHBEARER = 3646925,
    NPC_KILL_CREDIT_OBJ_1 = 3640461,
    NPC_KILL_CREDIT_OBJ_2 = 3640462,

    NPC_FLAMEWARD_HELPER = 3675029,
    NPC_FLAMEWARD_HELPER_GUID_1 = 3858933,
    NPC_FLAMEWARD_HELPER_GUID_2 = 3858937,
    NPC_FLAMEWARD_HELPER_GUID_3 = 3858936,
    NPC_FLAMEWARD_HELPER_GUID_4 = 3858935,
    NPC_FLAMEWARD_HELPER_GUID_5 = 3858934,

    SPELL_COSMETIC_SHIELD = 75454,
};

const Position AshSpawnPosition1[] =
{
    { 4376.3364f, -2340.976f, 1151.636f },
    { 4357.4663f, -2347.303f, 1151.865f },
    { 4345.1542f, -2327.608f, 1154.054f },
    { 4362.5048f, -2306.074f, 1159.168f }
};

const Position AshSpawnPosition2[] =
{
    { 4718.090f, -2422.2038f, 1167.046f },
    { 4705.526f, -2381.7275f, 1169.674f },
    { 4683.125f, -2393.2082f, 1162.697f },
    { 4695.034f, -2429.7006f, 1159.009f }
};

const Position AshSpawnPosition3[] =
{
    { 4696.59082f, -2618.6320f, 1150.6185f },
    { 4669.40722f, -2626.2204f, 1149.2640f },
    { 4659.32617f, -2647.6511f, 1148.9287f },
    { 4680.89892f, -2681.4392f, 1156.8551f }
};

const Position AshSpawnPosition4[] =
{
    { 4591.5971f, -2697.4013f, 1140.8170f },
    { 4613.8149f, -2686.0078f, 1140.3431f },
    { 4626.1435f, -2709.4343f, 1146.9135f },
    { 4601.7211f, -2730.8833f, 1148.4626f }
};

const Position AshSpawnPosition5[] =
{
    { 4366.799f, -2547.478f, 1120.437f },
    { 4399.268f, -2534.519f, 1116.601f },
    { 4415.128f, -2559.662f, 1119.860f },
    { 4388.924f, -2581.268f, 1121.252f }
};

class npc_activated_flameward : public CreatureScript
{
public:
    npc_activated_flameward() : CreatureScript("npc_activated_flameward") { }

    struct npc_activated_flamewardAI : public ScriptedAI
    {
        npc_activated_flamewardAI(Creature* creature) : ScriptedAI(creature), _summons(me) {}

        void IsSummonedBy(Unit* summoner)
        {
            me->SetReactState(REACT_PASSIVE);
            CastWithDelay(me, 100, me, SPELL_COSMETIC_SHIELD);

            if (auto player = summoner->ToPlayer())
            {
                _playerGUID = player->GetGUID();
                player->KilledMonsterCredit(NPC_KILL_CREDIT_OBJ_1);
            }

            if (auto locationhelper = me->FindNearestCreature(NPC_FLAMEWARD_HELPER, 10.f))
            {
                _flamewardHelperGUID = locationhelper->GetGUID().GetCounter();

                _started = true;
                TalkWithDelay(me->AI(), 1000, 0, _playerGUID);
                _events.ScheduleEvent(EVENT_FLAMEWARD_1, 3000);
            }
        }

        void JustDied(Unit* /* killer */)
        {
            AiTalk(me->AI(), 2, _playerGUID);
            _summons.DespawnAll();
        }

        void SpellHit(Unit* who, SpellInfo const* spellInfo)
        {
            if (spellInfo->Id == SPELL_DUMMY_PING_2)
            {
                _summons.RemoveNotExisting();

                if (_counter < 4)
                {
                    _counter++;
                    _events.ScheduleEvent(EVENT_FLAMEWARD_2, 6500);
                }
                else
                {
                    AiTalk(me->AI(), 1, _playerGUID);
                    me->DespawnOrUnsummon();
                    if (auto player = ObjectAccessor::GetPlayer(*me, _playerGUID))
                        player->KilledMonsterCredit(NPC_KILL_CREDIT_OBJ_2);
                }
            }
        }

        void UpdateAI(uint32 const diff) override
        {
            _events.Update(diff);

            if (_checkTimer <= diff)
            {
                _checkTimer = 1000;

                if (_started)
                {
                    if (auto player = ObjectAccessor::GetPlayer(*me, _playerGUID))
                    {
                        if (!player->IsAlive())
                        {
                            _started = false;
                            _summons.DespawnAll();
                            me->DespawnOrUnsummon();
                            AiTalk(me->AI(), 2, _playerGUID);
                        }

                        if (me->GetDistance(player) >= 60.f)
                        {
                            _started = false;
                            _summons.DespawnAll();
                            me->DespawnOrUnsummon();
                        }

                        if (player->GetQuestStatus(QUEST_PREPPING_THE_SOIL) == QUEST_STATUS_NONE)
                        {
                            _started = false;
                            _summons.DespawnAll();
                            me->DespawnOrUnsummon();
                        }
                    }
                }
            }
            else _checkTimer -= diff;

            if (_despawnTimer <= diff)
            {
                _despawnTimer = 100000;

                _started = false;
                _summons.DespawnAll();
                me->DespawnOrUnsummon();
            }
            else _despawnTimer -= diff;

            while (uint32 eventId = _events.ExecuteEvent())
            {
                switch (eventId)
                {
                case EVENT_FLAMEWARD_1:
                    _counter = 1;

                    switch (_flamewardHelperGUID)
                    {
                    case NPC_FLAMEWARD_HELPER_GUID_1:
                        if (auto ash = me->SummonCreature(NPC_ASHBEARER, AshSpawnPosition1[urand(0, 3)], TEMPSUMMON_CORPSE_TIMED_DESPAWN, 10000))
                        {
                            _summons.Summon(ash);
                            ash->SetHomePosition(me->GetPositionX(), me->GetPositionY() + 2, me->GetPositionZ() + 0.5f, me->GetOrientation());
                        }
                        break;
                    case NPC_FLAMEWARD_HELPER_GUID_2:
                        if (auto ash = me->SummonCreature(NPC_ASHBEARER, AshSpawnPosition2[urand(0, 3)], TEMPSUMMON_CORPSE_TIMED_DESPAWN, 10000))
                        {
                            _summons.Summon(ash);
                            ash->SetHomePosition(me->GetPositionX(), me->GetPositionY() + 2, me->GetPositionZ() + 0.5f, me->GetOrientation());
                        }
                        break;
                    case NPC_FLAMEWARD_HELPER_GUID_3:
                        if (auto ash = me->SummonCreature(NPC_ASHBEARER, AshSpawnPosition3[urand(0, 3)], TEMPSUMMON_CORPSE_TIMED_DESPAWN, 10000))
                        {
                            _summons.Summon(ash);
                            ash->SetHomePosition(me->GetPositionX(), me->GetPositionY() + 2, me->GetPositionZ() + 0.5f, me->GetOrientation());
                        }
                        break;
                    case NPC_FLAMEWARD_HELPER_GUID_4:
                        if (auto ash = me->SummonCreature(NPC_ASHBEARER, AshSpawnPosition4[urand(0, 3)], TEMPSUMMON_CORPSE_TIMED_DESPAWN, 10000))
                        {
                            _summons.Summon(ash);
                            ash->SetHomePosition(me->GetPositionX(), me->GetPositionY() + 2, me->GetPositionZ() + 0.5f, me->GetOrientation());
                        }
                        break;
                    case NPC_FLAMEWARD_HELPER_GUID_5:
                        if (auto ash = me->SummonCreature(NPC_ASHBEARER, AshSpawnPosition5[urand(0, 3)], TEMPSUMMON_CORPSE_TIMED_DESPAWN, 10000))
                        {
                            _summons.Summon(ash);
                            ash->SetHomePosition(me->GetPositionX(), me->GetPositionY() + 2, me->GetPositionZ() + 0.5f, me->GetOrientation());
                        }
                        break;
                    default:
                        break;
                    }
                    break;
                case EVENT_FLAMEWARD_2:
                    switch (_flamewardHelperGUID)
                    {
                    case NPC_FLAMEWARD_HELPER_GUID_1:
                        if (auto ash = me->SummonCreature(NPC_ASHBEARER, AshSpawnPosition1[urand(0, 3)], TEMPSUMMON_CORPSE_TIMED_DESPAWN, 10000))
                        {
                            _summons.Summon(ash);
                            ash->SetHomePosition(me->GetPositionX(), me->GetPositionY() + 2, me->GetPositionZ() + 0.5f, me->GetOrientation());
                        }
                        break;
                    case NPC_FLAMEWARD_HELPER_GUID_2:
                        if (auto ash = me->SummonCreature(NPC_ASHBEARER, AshSpawnPosition2[urand(0, 3)], TEMPSUMMON_CORPSE_TIMED_DESPAWN, 10000))
                        {
                            _summons.Summon(ash);
                            ash->SetHomePosition(me->GetPositionX(), me->GetPositionY() + 2, me->GetPositionZ() + 0.5f, me->GetOrientation());
                        }
                        break;
                    case NPC_FLAMEWARD_HELPER_GUID_3:
                        if (auto ash = me->SummonCreature(NPC_ASHBEARER, AshSpawnPosition3[urand(0, 3)], TEMPSUMMON_CORPSE_TIMED_DESPAWN, 10000))
                        {
                            _summons.Summon(ash);
                            ash->SetHomePosition(me->GetPositionX(), me->GetPositionY() + 2, me->GetPositionZ() + 0.5f, me->GetOrientation());
                        }
                        break;
                    case NPC_FLAMEWARD_HELPER_GUID_4:
                        if (auto ash = me->SummonCreature(NPC_ASHBEARER, AshSpawnPosition4[urand(0, 3)], TEMPSUMMON_CORPSE_TIMED_DESPAWN, 10000))
                        {
                            _summons.Summon(ash);
                            ash->SetHomePosition(me->GetPositionX(), me->GetPositionY() + 2, me->GetPositionZ() + 0.5f, me->GetOrientation());
                        }
                        break;
                    case NPC_FLAMEWARD_HELPER_GUID_5:
                        if (auto ash = me->SummonCreature(NPC_ASHBEARER, AshSpawnPosition5[urand(0, 3)], TEMPSUMMON_CORPSE_TIMED_DESPAWN, 10000))
                        {
                            _summons.Summon(ash);
                            ash->SetHomePosition(me->GetPositionX(), me->GetPositionY() + 2, me->GetPositionZ() + 0.5f, me->GetOrientation());
                        }
                        break;
                    default:
                        break;
                    }
                default:
                    break;
                }
            }
        }
    private:
        bool _started = false;
        EventMap _events;
        SummonList _summons;
        uint16 _counter = 0;
        uint32 _flamewardHelperGUID = 0;  // low GUID counter (compared against spawn-GUID constants)
        ObjectGuid _playerGUID;
        uint16 _checkTimer = 1000;
        uint64 _despawnTimer = 299900;
    };

    CreatureAI* GetAI(Creature* creature) const
    {
        return new npc_activated_flamewardAI(creature);
    }
};

enum AessinasMiracle
{
    NPC_HAMUUL_GROOVE = 3639858,
    NPC_SUMMONED_AESSINA = 3641406,

    SPELL_SWITCH_SEAT_01 = 84926,
    SPELL_CHANNEL_BEAM_1 = 76883,
    SPELL_SPOTLIGHT_1 = 77589,
    SPELL_SPEED_MINUS_90 = 47373,
};

class npc_aessina_miracle_vehicle : public CreatureScript
{
public:
    npc_aessina_miracle_vehicle() : CreatureScript("npc_aessina_miracle_vehicle") { }

    struct npc_aessina_miracle_vehicleAI : public VehicleAI
    {
        npc_aessina_miracle_vehicleAI(Creature* creature) : VehicleAI(creature), _summons(me) {}

        void IsSummonedBy(Unit* summoner)
        {
            me->SetReactState(REACT_PASSIVE);
            me->SetPhaseMask(32, false);
            me->setActive(true);
            me->SetRooted(true);
            CastWithDelay(me, 100, me, SPELL_SPEED_MINUS_90);
            CastWithDelay(me, 100, me, SPELL_SPOTLIGHT_1);

            if (auto player = summoner->ToPlayer())
            {
                _playerGUID = player->GetGUID();
                CastWithDelay(player, 100, me, SPELL_RIDE_VEHICLE);
            }
        }

        void PassengerBoarded(Unit* passenger, int8 seatId, bool apply)
        {
            if (apply && passenger->GetTypeId() == TYPEID_PLAYER)
            {
                if (seatId == 0)
                {
                    if (auto aessina = me->SummonCreature(NPC_SUMMONED_AESSINA, me->GetPositionX(), me->GetPositionY(), me->GetPositionZ(), me->GetOrientation(), TEMPSUMMON_MANUAL_DESPAWN))
                    {
                        me->setActive(aessina);
                        _aessinaGUID = aessina->GetGUID();
                        _summons.Summon(aessina);
                        CastWithDelay(aessina, 300, me, SPELL_RIDE_VEHICLE_SEAT_02);
                    }

                    _events.ScheduleEvent(EVENT_AESSINA_VEH_1, 2000);
                }
                else
                    passenger->CastSpell(passenger, SPELL_SWITCH_SEAT_01);
            }

            if (!apply && passenger->GetTypeId() == TYPEID_PLAYER)
            {
                if (seatId == 0)
                {
                    _summons.DespawnAll();
                    me->DespawnOrUnsummon();
                }
            }
        }

        void UpdateAI(uint32 const diff)
        {
            _events.Update(diff);

            if (_checkTimer <= diff)
            {
                _checkTimer = 1000;

                if (auto player = ObjectAccessor::GetPlayer(*me, _playerGUID))
                {
                    if (!player->IsAlive())
                    {
                        _summons.DespawnAll();
                        me->DespawnOrUnsummon();
                    }

                    if (me->GetDistance(player) >= 50.f)
                    {
                        _summons.DespawnAll();
                        me->DespawnOrUnsummon();
                    }
                }
            }
            else _checkTimer -= diff;

            _events.Update(diff);

            while (uint32 eventId = _events.ExecuteEvent())
            {
                switch (eventId)
                {
                case EVENT_AESSINA_VEH_1:
                    me->SetRooted(false);
                    me->GetMotionMaster()->MovePoint(1, 5135.51f, -1756.11f, 1349.144f, false);

                    if (auto aessina1 = ObjectAccessor::GetCreature(*me, _aessinaGUID))
                        if (auto aessina = aessina1->AI())
                        {
                            TalkWithDelay(aessina, 1000, 0, _playerGUID);
                            TalkWithDelay(aessina, 8000, 1, _playerGUID);
                            _events.ScheduleEvent(EVENT_AESSINA_VEH_2, 15000);
                        }
                    break;
                case EVENT_AESSINA_VEH_2:
                    if (auto aessina1 = ObjectAccessor::GetCreature(*me, _aessinaGUID))
                        if (auto aessina = aessina1->AI())
                        {
                            TalkWithDelay(aessina, 1000, 2, _playerGUID);
                            TalkWithDelay(aessina, 9000, 3, _playerGUID);
                            _events.ScheduleEvent(EVENT_AESSINA_VEH_3, 17000);
                        }
                    break;
                case EVENT_AESSINA_VEH_3:
                    if (auto aessina1 = ObjectAccessor::GetCreature(*me, _aessinaGUID))
                        if (auto aessina = aessina1->AI())
                        {
                            TalkWithDelay(aessina, 1000, 4, _playerGUID);
                            TalkWithDelay(aessina, 9500, 5, _playerGUID);
                            _events.ScheduleEvent(EVENT_AESSINA_VEH_4, 16500);
                        }
                    break;
                case EVENT_AESSINA_VEH_4:
                    if (auto aessina1 = ObjectAccessor::GetCreature(*me, _aessinaGUID))
                        if (auto aessina = aessina1->AI())
                        {
                            TalkWithDelay(aessina, 1000, 6, _playerGUID);
                            _events.ScheduleEvent(EVENT_AESSINA_VEH_5, 2500);
                        }
                    break;
                case EVENT_AESSINA_VEH_5:
                    if (auto player = ObjectAccessor::GetPlayer(*me, _playerGUID))
                    {
                        if (auto hamuul = me->FindNearestCreature(NPC_HAMUUL_GROOVE, 40.f))
                        {
                            _summons.DespawnAll();
                            me->DespawnOrUnsummon();
                            player->ExitVehicle();
                            TalkWithDelay(hamuul->AI(), 2000, 0, _playerGUID);
                        }
                    }
                    break;
                default:
                    break;
                }
            }
        }
    private:
        uint16 _checkTimer = 1000;
        ObjectGuid _playerGUID;
        ObjectGuid _aessinaGUID;
        EventMap _events;
        SummonList _summons;
    };
    CreatureAI* GetAI(Creature* creature) const
    {
        return new npc_aessina_miracle_vehicleAI(creature);
    }
};

enum QuestStrenghtofTortolla
{
    QUEST_THE_STRENGTH_OF_TORTOLLA = 25915,
    QUEST_FINISH_NEMESIS = 25923,

    NPC_QUEST_EVENT_TRIGGER = 3675014,

    SPELL_NEMESIS_CRYSTAL_EXAMINATION = 77753,
    SPELL_CHILD_OF_TORTOLLA_AURA = 77736,
    SPELL_PING_CHILD = 77770,
    SPELL_CHILD_SHELL = 77775,
};

class npc_strength_of_tortolla : public CreatureScript
{
public:
    npc_strength_of_tortolla() : CreatureScript("npc_strength_of_tortolla") { }

    struct npc_strength_of_tortollaAI : public ScriptedAI
    {
        npc_strength_of_tortollaAI(Creature* creature) : ScriptedAI(creature) {}

        void IsSummonedBy(Unit* summoner)
        {
            me->SetReactState(REACT_PASSIVE);
            me->setActive(true);

            if (auto player = summoner->ToPlayer())
            {
                CastWithDelay(me, 100, player, SPELL_CHILD_OF_TORTOLLA_AURA);
                _playerGUID = player->GetGUID();
                me->GetMotionMaster()->MoveFollow(player, 0.7f, 0.3f * M_PI);
            }
        }
        void SpellHit(Unit* who, SpellInfo const* spellInfo)
        {
            if (spellInfo->Id == SPELL_PING_CHILD)
            {
                me->CastSpell(me, SPELL_CHILD_SHELL);
            }
        }

        void JustDied(Unit* killer)
        {
            if (auto player = ObjectAccessor::GetPlayer(*me, _playerGUID))
                player->RemoveAura(SPELL_CHILD_OF_TORTOLLA_AURA);
        }

        void UpdateAI(uint32 const diff)
        {
            DoMeleeAttackIfReady();

            if (_checkTimer <= diff)
            {
                _checkTimer = 1000;

                if (auto player = ObjectAccessor::GetPlayer(*me, _playerGUID))
                {
                    if (player->GetQuestStatus(QUEST_THE_STRENGTH_OF_TORTOLLA) == QUEST_STATUS_INCOMPLETE)
                    {
                        if (!_inProgress)
                        {
                            if (auto trigger = me->FindNearestCreature(NPC_QUEST_EVENT_TRIGGER, 10.f))
                            {
                                _inProgress = true;
                                me->CastSpell(me, SPELL_ROOT);
                                me->SetFacingToObject(trigger);
                                me->CastSpell(trigger, SPELL_NEMESIS_CRYSTAL_EXAMINATION);
                                trigger->CastSpell(player, SPELL_NEMESIS_CRYSTAL_EXAMINATION);
                                AiTalk(me->AI(), 0, _playerGUID);
                                _events.ScheduleEvent(EVENT_CHILD_OF_TORTOLLA_1, 6000);
                            }
                        }
                    }

                    if (!player->IsAlive())
                    {
                        me->DespawnOrUnsummon();
                        player->RemoveAura(SPELL_CHILD_OF_TORTOLLA_AURA);
                    }

                    if (player->GetQuestStatus(QUEST_THE_STRENGTH_OF_TORTOLLA) == QUEST_STATUS_NONE ||
                        player->GetQuestStatus(QUEST_FINISH_NEMESIS) == QUEST_STATUS_REWARDED)
                    {
                        me->DespawnOrUnsummon();
                        player->RemoveAura(SPELL_CHILD_OF_TORTOLLA_AURA);
                    }

                    if (me->GetReactState() != REACT_PASSIVE)
                    {
                        me->SetReactState(REACT_PASSIVE);
                        me->GetMotionMaster()->MoveFollow(player, 0.7f, 0.3f * M_PI);
                    }

                    if (me->GetDistance(player) > 80.f)
                    {
                        me->DespawnOrUnsummon();
                        player->RemoveAura(SPELL_CHILD_OF_TORTOLLA_AURA);
                    }
                }
            }
            else _checkTimer -= diff;

            _events.Update(diff);

            if (me->HasUnitState(UNIT_STATE_CASTING))
                return;

            while (uint32 eventId = _events.ExecuteEvent())
            {
                switch (eventId)
                {
                case EVENT_CHILD_OF_TORTOLLA_1:
                    me->RemoveAura(SPELL_ROOT);
                    break;
                default:
                    break;
                }
            }
        }
    private:
        bool _inProgress = false;
        ObjectGuid _playerGUID;
        uint16 _checkTimer = 1000;
        EventMap _events;
    };

    CreatureAI* GetAI(Creature* creature) const
    {
        return new npc_strength_of_tortollaAI(creature);
    }
};

enum QuestAgilityTraining
{
    QUEST_AGILITY_TRAINING = 25499,

    SPELL_AGILITY_TRAINING_AURA = 75397,
    SPELL_IMMUNITY_ALL = 4309,
};

class npc_blazing_trainer_agility_training : public CreatureScript
{
public:
    npc_blazing_trainer_agility_training() : CreatureScript("npc_blazing_trainer_agility_training") { }

    struct npc_blazing_trainer_agility_trainingAI : public ScriptedAI
    {
        npc_blazing_trainer_agility_trainingAI(Creature* creature) : ScriptedAI(creature) {}

        void IsSummonedBy(Unit* summoner)
        {
            //me->SetReactState(REACT_PASSIVE);
            me->setActive(true);
            me->SetRooted(true);

            if (auto player = summoner->ToPlayer())
            {
                _playerGUID = player->GetGUID();
                player->CastSpell(player, SPELL_DISMOUNT_AND_CANCEL_ALL_SHAPESHIFTS);
                TalkWithDelay(me->AI(), 100, 0, _playerGUID);
                CastWithDelay(me, 100, me, SPELL_IMMUNITY_ALL);
                _events.ScheduleEvent(EVENT_AGILITY_TRAINER_1, 500);
            }
        }

        void UpdateAI(uint32 const diff)
        {
            if (auto player = ObjectAccessor::GetPlayer(*me, _playerGUID))
            {
                if (!player->IsAlive())
                {
                    me->DespawnOrUnsummon();
                    player->RemoveAura(SPELL_AGILITY_TRAINING_AURA);
                }

                if (player->GetQuestStatus(QUEST_AGILITY_TRAINING) == QUEST_STATUS_NONE ||
                    player->GetQuestStatus(QUEST_AGILITY_TRAINING) == QUEST_STATUS_COMPLETE)
                {
                    player->CombatStop();
                    me->DespawnOrUnsummon();
                }

                if (me->GetDistance(player) > 80.f)
                {
                    player->CombatStop();
                    me->DespawnOrUnsummon();
                    player->RemoveAura(SPELL_AGILITY_TRAINING_AURA);
                }
                else if (me->GetDistance(player) < 1.f)
                {
                    me->SetRooted(true);
                    AiTalk(me->AI(), 1, _playerGUID);
                    player->FailQuest(QUEST_AGILITY_TRAINING);
                    player->CombatStop();
                    player->RemoveAura(SPELL_AGILITY_TRAINING_AURA);
                    me->DespawnOrUnsummon();
                }

                if (player->GetAreaId() != 4994)
                {
                    me->SetRooted(true);
                    AiTalk(me->AI(), 2, _playerGUID);
                    player->FailQuest(QUEST_AGILITY_TRAINING);
                    player->CombatStop();
                    player->RemoveAura(SPELL_AGILITY_TRAINING_AURA);
                    me->DespawnOrUnsummon();
                }
            }

            if (_checkTimer <= diff)
            {
                _checkTimer = 1000;
                me->SetHomePosition(me->GetPositionX(), me->GetPositionY(), me->GetPositionZ(), me->GetOrientation());\


            }
            else _checkTimer -= diff;

            _events.Update(diff);

            while (uint32 eventId = _events.ExecuteEvent())
            {
                switch (eventId)
                {
                case EVENT_AGILITY_TRAINER_1:
                    me->SetRooted(false);

                    if (auto player = ObjectAccessor::GetPlayer(*me, _playerGUID))
                        me->AI()->AttackStart(player);
                    break;
                default:
                    break;
                }
            }
        }
    private:
        bool _inProgress = false;
        ObjectGuid _playerGUID;
        uint16 _checkTimer = 1000;
        EventMap _events;
    };

    CreatureAI* GetAI(Creature* creature) const
    {
        return new npc_blazing_trainer_agility_trainingAI(creature);
    }
};

enum MentalTrainingSpeaking
{
    EVENT_QUESTION_1 = 1,      // 'Do Dogs bark?'             	   -- Yes
    EVENT_QUESTION_2 = 2,      // 'Are Oceans filled with water?'  -- Yes
    EVENT_QUESTION_3 = 3,      // 'Is Fire hot?'                   -- Yes
    EVENT_QUESTION_4 = 4,      // 'Is Vinegar sour?'               -- Yes
    EVENT_QUESTION_5 = 5,      // 'Is Blood red?'                  -- Yes
    EVENT_QUESTION_6 = 6,      // 'Do Maggots feast on corpses?'   -- Yes
    EVENT_QUESTION_7 = 7,      // 'Do Wolves Howl?'                -- Yes
    EVENT_QUESTION_8 = 8,      // 'Do Murderers kill?'             -- Yes
    EVENT_QUESTION_9 = 9,      // 'Do Rivers flow upstream?'       -- No
    EVENT_QUESTION_10 = 10,    // 'Are Deserts lush?'              -- No
    EVENT_QUESTION_11 = 11,    // 'Are Slaves free?'               -- No
    EVENT_QUESTION_12 = 12,    // 'Do Liars speak the truth?'      -- No
    EVENT_QUESTION_13 = 13,    // 'Is Ice hot?'                    -- No
    EVENT_QUESTION_14 = 14,    // 'Do Giants tread lightly?'       -- No
    EVENT_QUESTION_15 = 15,    // 'Does Fire consume stone?'       -- No
    EVENT_QUESTION_16 = 16,    // 'Do Rocks float on water? '      -- No 

    EVENT_START = 17,
    EVENT_ASK_QUESTION = 18,

    QUEST_MENTAL_TRAINING_SPEAKING_THE_TRUTH_TO_POWER = 25299,

    SPELL_YES = 73982,
    // Trigger spell(74010) Answer Yes Correct.  // Caster Aura Spell (74008) Answer the Question! 
    // Trigger spell(74011) Answer Yes Incorrect // Caster Aura Spell (74009) Answer the Question!

    SPELL_NO = 73983,
    // Trigger spell(74012) Answer No Correct   // Caster Aura Spell (74009) Answer the Question!
    // Trigger spell(74013) Answer No Incorrect // Caster Aura Spell (74008) Answer the Question!

    SPELL_ANSWER_THE_QUESTION_YES_CONTROLLER = 74008,
    SPELL_ANSWER_THE_QUESTION_NO_CONTROLLER = 74009,

    SPELL_ANSWER_YES_CORRECT = 74010,
    SPELL_ANSWER_YES_INCORRECT = 74011,
    SPELL_ANSWER_NO_CORRECT = 74012,
    SPELL_ANSWER_NO_INCORRECT = 74013,

    SPELL_ANSWER_THE_QUESTION_YES_CORRECT_NO_INCORRECT = 74008,
    SPELL_ANSWER_THE_QUESTION_NO_CORRECT_YES_INCORRECT = 74009,

    SPELL_DISMISS_ORB_OF_ASCENSION = 76643,
    SPELL_MENTAL_TRAINING = 73984,

    SPELL_PING_ORB = 150000,
    // 9 secs idle check aura after 8 seconds send ping to orb
    SPELL_IDLE_CHECK_AURA = 150001,

    NPC_ORB_OF_ASCENSION = 3639601,
};

class npc_orb_of_ascension : public CreatureScript
{
public:
    npc_orb_of_ascension() : CreatureScript("npc_orb_of_ascension") { }

    struct npc_orb_of_ascensionAI : public ScriptedAI
    {
        npc_orb_of_ascensionAI(Creature* creature) : ScriptedAI(creature) {}

        bool EventStarted = false;
        bool WaitingForAnswer = false;
        uint32 WaitingForAnswerTimer = 8000;

        void IsSummonedBy(Unit* summoner)
        {
            if (auto player = summoner->ToPlayer())
            {
                playerGUID = player->GetGUID();
                events.ScheduleEvent(EVENT_ASK_QUESTION, 3000);
                player->SetRooted(true);
            }
        }
        void SpellHit(Unit* who, SpellInfo const* spellInfo)
        {

            if (spellInfo->Id == SPELL_PING_ORB)
                if (auto player = ObjectAccessor::GetPlayer(*me, playerGUID))
                    if (who->GetGUID() == playerGUID)
                    {
                        player->RemoveAura(SPELL_IDLE_CHECK_AURA);
                        WaitingForAnswer = false;
                        events.ScheduleEvent(EVENT_ASK_QUESTION, 3500);
                    }

            if (spellInfo->Id == SPELL_DISMISS_ORB_OF_ASCENSION)
                if (auto player = ObjectAccessor::GetPlayer(*me, playerGUID))
                    if (who->GetGUID() == playerGUID)
                    {
                        player->SetRooted(false);
                        player->RemoveAura(SPELL_IDLE_CHECK_AURA);
                        player->RemoveAura(SPELL_MENTAL_TRAINING);
                        me->DespawnOrUnsummon();
                    }
        }
        void JustDied(Unit* /*killer*/)
        {
            if (auto player = ObjectAccessor::GetPlayer(*me, playerGUID))
            {
                player->SetRooted(false);
                player->RemoveAura(SPELL_IDLE_CHECK_AURA);
                player->RemoveAura(SPELL_MENTAL_TRAINING);
                me->DespawnOrUnsummon();

            }
        }
        void RandomEvent()
        {
            if (auto player = ObjectAccessor::GetPlayer(*me, playerGUID))
                if (player->GetQuestStatus(QUEST_MENTAL_TRAINING_SPEAKING_THE_TRUTH_TO_POWER) == QUEST_STATUS_INCOMPLETE)
                {
                    uint8 InitEvents[16] = { EVENT_QUESTION_1, EVENT_QUESTION_2, EVENT_QUESTION_3, EVENT_QUESTION_4, EVENT_QUESTION_5, EVENT_QUESTION_6, EVENT_QUESTION_7,
                EVENT_QUESTION_8, EVENT_QUESTION_9, EVENT_QUESTION_10, EVENT_QUESTION_11, EVENT_QUESTION_12, EVENT_QUESTION_13, EVENT_QUESTION_14, EVENT_QUESTION_15, EVENT_QUESTION_16 };

                    // i think to do (should be NOT repeatable, now the events can be draw many times
                    uint8 number = urand(1, 16);
                    events.ScheduleEvent(InitEvents[number], 0);
                }
                else
                {
                    player->SetRooted(false);
                    player->RemoveAura(SPELL_IDLE_CHECK_AURA);
                    player->RemoveAura(SPELL_MENTAL_TRAINING);
                    me->DespawnOrUnsummon();
                }
        }
        void UpdateAI(uint32 const diff)
        {
            events.Update(diff);

            while (uint32 eventId = events.ExecuteEvent())
            {
                switch (eventId)
                {
                case EVENT_ASK_QUESTION:
                    if (auto player = ObjectAccessor::GetPlayer(*me, playerGUID))
                        if (!player->isDead())
                            RandomEvent();
                        else
                        {
                            player->RemoveAura(SPELL_MENTAL_TRAINING);
                            me->DespawnOrUnsummon();
                        }
                    break;
                    // for answer "yes"
                case EVENT_QUESTION_1:
                    me->AI()->Talk(0);
                    if (auto player = ObjectAccessor::GetPlayer(*me, playerGUID))
                    {
                        me->CastSpell(player, SPELL_ANSWER_THE_QUESTION_YES_CORRECT_NO_INCORRECT);
                        player->CastSpell(player, SPELL_IDLE_CHECK_AURA);
                        WaitingForAnswer = true;
                    }
                    break;
                case EVENT_QUESTION_2:
                    me->AI()->Talk(1);
                    if (auto player = ObjectAccessor::GetPlayer(*me, playerGUID))
                    {
                        me->CastSpell(player, SPELL_ANSWER_THE_QUESTION_YES_CORRECT_NO_INCORRECT);
                        player->CastSpell(player, SPELL_IDLE_CHECK_AURA);
                        WaitingForAnswer = true;
                    }
                    break;
                case EVENT_QUESTION_3:
                    me->AI()->Talk(2);
                    if (auto player = ObjectAccessor::GetPlayer(*me, playerGUID))
                    {
                        me->CastSpell(player, SPELL_ANSWER_THE_QUESTION_YES_CORRECT_NO_INCORRECT);
                        player->CastSpell(player, SPELL_IDLE_CHECK_AURA);
                        WaitingForAnswer = true;
                    }
                    break;
                case EVENT_QUESTION_4:
                    me->AI()->Talk(3);
                    if (auto player = ObjectAccessor::GetPlayer(*me, playerGUID))
                    {
                        me->CastSpell(player, SPELL_ANSWER_THE_QUESTION_YES_CORRECT_NO_INCORRECT);
                        player->CastSpell(player, SPELL_IDLE_CHECK_AURA);
                        WaitingForAnswer = true;
                    }
                    break;
                case EVENT_QUESTION_5:
                    me->AI()->Talk(4);
                    if (auto player = ObjectAccessor::GetPlayer(*me, playerGUID))
                    {
                        me->CastSpell(player, SPELL_ANSWER_THE_QUESTION_YES_CORRECT_NO_INCORRECT);
                        player->CastSpell(player, SPELL_IDLE_CHECK_AURA);
                        WaitingForAnswer = true;
                    }
                    break;
                case EVENT_QUESTION_6:
                    me->AI()->Talk(5);
                    if (auto player = ObjectAccessor::GetPlayer(*me, playerGUID))
                    {
                        me->CastSpell(player, SPELL_ANSWER_THE_QUESTION_YES_CORRECT_NO_INCORRECT);
                        player->CastSpell(player, SPELL_IDLE_CHECK_AURA);
                        WaitingForAnswer = true;
                    }
                    break;
                case EVENT_QUESTION_7:
                    me->AI()->Talk(6);
                    if (auto player = ObjectAccessor::GetPlayer(*me, playerGUID))
                    {
                        me->CastSpell(player, SPELL_ANSWER_THE_QUESTION_YES_CORRECT_NO_INCORRECT);
                        player->CastSpell(player, SPELL_IDLE_CHECK_AURA);
                        WaitingForAnswer = true;
                    }
                    break;
                case EVENT_QUESTION_8:
                    me->AI()->Talk(7);
                    if (auto player = ObjectAccessor::GetPlayer(*me, playerGUID))
                    {
                        me->CastSpell(player, SPELL_ANSWER_THE_QUESTION_YES_CORRECT_NO_INCORRECT);
                        player->CastSpell(player, SPELL_IDLE_CHECK_AURA);
                        WaitingForAnswer = true;
                    }
                    break;
                    // for answer "no"
                case EVENT_QUESTION_9:
                    me->AI()->Talk(8);
                    if (auto player = ObjectAccessor::GetPlayer(*me, playerGUID))
                    {
                        me->CastSpell(player, SPELL_ANSWER_THE_QUESTION_NO_CORRECT_YES_INCORRECT);
                        player->CastSpell(player, SPELL_IDLE_CHECK_AURA);
                        WaitingForAnswer = true;
                    }
                    break;
                case EVENT_QUESTION_10:
                    me->AI()->Talk(9);
                    if (auto player = ObjectAccessor::GetPlayer(*me, playerGUID))
                    {
                        me->CastSpell(player, SPELL_ANSWER_THE_QUESTION_NO_CORRECT_YES_INCORRECT);
                        player->CastSpell(player, SPELL_IDLE_CHECK_AURA);
                        WaitingForAnswer = true;
                    }
                    break;
                case EVENT_QUESTION_11:
                    me->AI()->Talk(10);
                    if (auto player = ObjectAccessor::GetPlayer(*me, playerGUID))
                    {
                        me->CastSpell(player, SPELL_ANSWER_THE_QUESTION_NO_CORRECT_YES_INCORRECT);
                        player->CastSpell(player, SPELL_IDLE_CHECK_AURA);
                        WaitingForAnswer = true;
                    }
                    break;
                case EVENT_QUESTION_12:
                    me->AI()->Talk(11);
                    if (auto player = ObjectAccessor::GetPlayer(*me, playerGUID))
                    {
                        me->CastSpell(player, SPELL_ANSWER_THE_QUESTION_NO_CORRECT_YES_INCORRECT);
                        player->CastSpell(player, SPELL_IDLE_CHECK_AURA);
                        WaitingForAnswer = true;
                    }
                    break;
                case EVENT_QUESTION_13:
                    me->AI()->Talk(12);
                    if (auto player = ObjectAccessor::GetPlayer(*me, playerGUID))
                    {
                        me->CastSpell(player, SPELL_ANSWER_THE_QUESTION_NO_CORRECT_YES_INCORRECT);
                        player->CastSpell(player, SPELL_IDLE_CHECK_AURA);
                        WaitingForAnswer = true;
                    }
                    break;
                case EVENT_QUESTION_14:
                    me->AI()->Talk(13);
                    if (auto player = ObjectAccessor::GetPlayer(*me, playerGUID))
                    {
                        me->CastSpell(player, SPELL_ANSWER_THE_QUESTION_NO_CORRECT_YES_INCORRECT);
                        player->CastSpell(player, SPELL_IDLE_CHECK_AURA);
                        WaitingForAnswer = true;
                    }
                    break;
                case EVENT_QUESTION_15:
                    me->AI()->Talk(14);
                    if (auto player = ObjectAccessor::GetPlayer(*me, playerGUID))
                    {
                        me->CastSpell(player, SPELL_ANSWER_THE_QUESTION_NO_CORRECT_YES_INCORRECT);
                        player->CastSpell(player, SPELL_IDLE_CHECK_AURA);
                        WaitingForAnswer = true;
                    }
                    break;
                case EVENT_QUESTION_16:
                    me->AI()->Talk(15);
                    if (auto player = ObjectAccessor::GetPlayer(*me, playerGUID))
                    {
                        me->CastSpell(player, SPELL_ANSWER_THE_QUESTION_NO_CORRECT_YES_INCORRECT);
                        player->CastSpell(player, SPELL_IDLE_CHECK_AURA);
                        WaitingForAnswer = true;
                    }
                    break;
                default:
                    break;
                }
            }
        }
    private:
        EventMap events;
        ObjectGuid playerGUID;
    };

    CreatureAI* GetAI(Creature* creature) const
    {
        return new npc_orb_of_ascensionAI(creature);
    }
};

// main YES spells
class spell_answer_yes_master : public SpellScriptLoader
{
public:
    spell_answer_yes_master() : SpellScriptLoader("spell_answer_yes_master") { }

    class spell_answer_yes_master_SpellScript : public SpellScript
    {
        PrepareSpellScript(spell_answer_yes_master_SpellScript);

        bool Validate(SpellInfo const* /*spellEntry*/)
        {
            return true;
        }
        void HandleScriptEffect(SpellEffIndex effIndex)
        {
            if (Unit* caster = GetCaster())
            {
                if (caster->HasAura(SPELL_ANSWER_THE_QUESTION_YES_CORRECT_NO_INCORRECT))
                    caster->CastSpell(caster, SPELL_ANSWER_YES_CORRECT);
                else if (caster->HasAura(SPELL_ANSWER_THE_QUESTION_NO_CORRECT_YES_INCORRECT))
                    caster->CastSpell(caster, SPELL_ANSWER_YES_INCORRECT);
            }
        }
        void Register()
        {
            OnEffectHitTarget += SpellEffectFn(spell_answer_yes_master_SpellScript::HandleScriptEffect, EFFECT_0, SPELL_EFFECT_SCRIPT_EFFECT);
        }

    };
    SpellScript* GetSpellScript() const
    {
        return new spell_answer_yes_master_SpellScript();
    }
};

enum AnswerYesCorrect
{
    SPELL_ANSWER_THE_QUESTION_YES_CORRECT_NO_INCORRECT_AURA = 74008,
    SPELL_ANSWER_THE_QUESTION_NO_CORRECT_YES_INCORRECT_AURA = 74009,
};

class spell_answer_yes_correct : public SpellScriptLoader
{
public:
    spell_answer_yes_correct() : SpellScriptLoader("spell_answer_yes_correct") { }

    class spell_answer_yes_correct_SpellScript : public SpellScript
    {
        PrepareSpellScript(spell_answer_yes_correct_SpellScript);

        bool Validate(SpellInfo const* /*spellEntry*/)
        {
            if (!sSpellMgr->GetSpellInfo(SPELL_ANSWER_THE_QUESTION_YES_CORRECT_NO_INCORRECT_AURA))
                return false;
            return true;
        }
        void HandleScriptEffect(SpellEffIndex effIndex)
        {
            if (Unit* caster = GetCaster())
            {
                caster->RemoveAura(SPELL_ANSWER_THE_QUESTION_YES_CORRECT_NO_INCORRECT_AURA);
                caster->CastSpell(caster, SPELL_PING_ORB);
            }
        }
        void Register()
        {
            OnEffectHitTarget += SpellEffectFn(spell_answer_yes_correct_SpellScript::HandleScriptEffect, EFFECT_0, SPELL_EFFECT_SCRIPT_EFFECT);
        }
    };
    SpellScript* GetSpellScript() const
    {
        return new spell_answer_yes_correct_SpellScript();
    }
};

class spell_answer_yes_incorrect : public SpellScriptLoader
{
public:
    spell_answer_yes_incorrect() : SpellScriptLoader("spell_answer_yes_incorrect") { }

    class spell_answer_yes_incorrect_SpellScript : public SpellScript
    {
        PrepareSpellScript(spell_answer_yes_incorrect_SpellScript);

        bool Validate(SpellInfo const* /*spellEntry*/)
        {
            if (!sSpellMgr->GetSpellInfo(SPELL_ANSWER_THE_QUESTION_NO_CORRECT_YES_INCORRECT_AURA))
                return false;
            return true;
        }
        void HandleScriptEffect(SpellEffIndex effIndex)
        {
            if (Unit* caster = GetCaster())
            {
                caster->RemoveAura(SPELL_ANSWER_THE_QUESTION_NO_CORRECT_YES_INCORRECT_AURA);
                caster->CastSpell(caster, SPELL_PING_ORB);
            }
        }
        void HandleOnHit(SpellEffIndex effIndex)
        {
            Unit* caster = GetCaster();
            if (!caster)
                return;

            uint32 amount = CalculatePct(caster->GetCreateHealth(), GetSpellInfo()->GetEffect(effIndex).BasePoints);

            SetHitDamage(amount);
        }
        void Register()
        {
            OnEffectLaunchTarget += SpellEffectFn(spell_answer_yes_incorrect_SpellScript::HandleOnHit, EFFECT_0, SPELL_EFFECT_SCHOOL_DAMAGE);
            OnEffectHitTarget += SpellEffectFn(spell_answer_yes_incorrect_SpellScript::HandleScriptEffect, EFFECT_1, SPELL_EFFECT_SCRIPT_EFFECT);
        }
    };

    SpellScript* GetSpellScript() const
    {
        return new spell_answer_yes_incorrect_SpellScript();
    }
};

// main no spells
class spell_answer_no_master : public SpellScriptLoader
{
public:
    spell_answer_no_master() : SpellScriptLoader("spell_answer_no_master") { }

    class spell_answer_no_master_SpellScript : public SpellScript
    {
        PrepareSpellScript(spell_answer_no_master_SpellScript);

        bool Validate(SpellInfo const* /*spellEntry*/)
        {
            return true;
        }
        void HandleScriptEffect(SpellEffIndex effIndex)
        {
            if (Unit* caster = GetCaster())
            {
                if (caster->HasAura(SPELL_ANSWER_THE_QUESTION_NO_CORRECT_YES_INCORRECT))
                    caster->CastSpell(caster, SPELL_ANSWER_NO_CORRECT);
                else if (caster->HasAura(SPELL_ANSWER_THE_QUESTION_YES_CORRECT_NO_INCORRECT))
                    caster->CastSpell(caster, SPELL_ANSWER_NO_INCORRECT);
            }
        }
        void Register()
        {
            OnEffectHitTarget += SpellEffectFn(spell_answer_no_master_SpellScript::HandleScriptEffect, EFFECT_0, SPELL_EFFECT_SCRIPT_EFFECT);
        }

    };
    SpellScript* GetSpellScript() const
    {
        return new spell_answer_no_master_SpellScript();
    }
};

class spell_answer_no_correct : public SpellScriptLoader
{
public:
    spell_answer_no_correct() : SpellScriptLoader("spell_answer_no_correct") { }

    class spell_answer_no_correct_SpellScript : public SpellScript
    {
        PrepareSpellScript(spell_answer_no_correct_SpellScript);

        bool Validate(SpellInfo const* /*spellEntry*/)
        {
            if (!sSpellMgr->GetSpellInfo(SPELL_ANSWER_THE_QUESTION_NO_CORRECT_YES_INCORRECT_AURA))
                return false;
            return true;
        }

        void HandleScriptEffect(SpellEffIndex effIndex)
        {
            if (Unit* caster = GetCaster())
            {
                caster->RemoveAura(SPELL_ANSWER_THE_QUESTION_NO_CORRECT_YES_INCORRECT_AURA);
                caster->CastSpell(caster, SPELL_PING_ORB);
            }
        }

        void Register()
        {
            OnEffectHitTarget += SpellEffectFn(spell_answer_no_correct_SpellScript::HandleScriptEffect, EFFECT_0, SPELL_EFFECT_SCRIPT_EFFECT);
        }

    };
    SpellScript* GetSpellScript() const
    {
        return new spell_answer_no_correct_SpellScript();
    }
};

class spell_answer_no_incorrect : public SpellScriptLoader
{
public:
    spell_answer_no_incorrect() : SpellScriptLoader("spell_answer_no_incorrect") { }

    class spell_answer_no_incorrect_SpellScript : public SpellScript
    {
        PrepareSpellScript(spell_answer_no_incorrect_SpellScript);

        bool Validate(SpellInfo const* /*spellEntry*/)
        {
            if (!sSpellMgr->GetSpellInfo(SPELL_ANSWER_THE_QUESTION_YES_CORRECT_NO_INCORRECT_AURA))
                return false;
            return true;
        }

        void HandleOnHit(SpellEffIndex effIndex)
        {
            Unit* caster = GetCaster();
            if (!caster)
                return;

            uint32 amount = CalculatePct(caster->GetCreateHealth(), GetSpellInfo()->GetEffect(effIndex).BasePoints);

            SetHitDamage(amount);
        }

        void HandleScriptEffect(SpellEffIndex effIndex)
        {
            if (Unit* caster = GetCaster())
            {
                caster->RemoveAura(SPELL_ANSWER_THE_QUESTION_YES_CORRECT_NO_INCORRECT_AURA);
                caster->CastSpell(caster, SPELL_PING_ORB);
            }
        }
        void Register()
        {
            OnEffectLaunchTarget += SpellEffectFn(spell_answer_no_incorrect_SpellScript::HandleOnHit, EFFECT_0, SPELL_EFFECT_SCHOOL_DAMAGE);
            OnEffectHitTarget += SpellEffectFn(spell_answer_no_incorrect_SpellScript::HandleScriptEffect, EFFECT_1, SPELL_EFFECT_SCRIPT_EFFECT);
        }

    };
    SpellScript* GetSpellScript() const
    {
        return new spell_answer_no_incorrect_SpellScript();
    }
};

enum QuestWalkingTheDog
{
    QUEST_WALKING_THE_DOG = 25294,
    NPC_WALKING_THE_DOG_CREDIT = 3639673,
    SPELL_FEED_SPAWN_OF_SMOLDEROS = 74142,
};

class npc_spawn_of_smolderos_dog : public CreatureScript
{
public:
    npc_spawn_of_smolderos_dog() : CreatureScript("npc_spawn_of_smolderos_dog") { }

    struct npc_spawn_of_smolderos_dogAI : public ScriptedAI
    {
        npc_spawn_of_smolderos_dogAI(Creature* creature) : ScriptedAI(creature) {}

        void IsSummonedBy(Unit* summoner)
        {
            me->SetReactState(REACT_PASSIVE);
            me->setActive(true);

            if (auto player = summoner->ToPlayer())
                _playerGUID = player->GetGUID();
        }

        void SpellHit(Unit* who, SpellInfo const* spellInfo)
        {
            if (spellInfo->Id == SPELL_FEED_SPAWN_OF_SMOLDEROS)
            {
                if (auto player = ObjectAccessor::GetPlayer(*me, _playerGUID))
                    player->KilledMonsterCredit(NPC_WALKING_THE_DOG_CREDIT);
            }
        }

        void UpdateAI(uint32 const diff)
        {
            DoMeleeAttackIfReady();

            if (_checkTimer <= diff)
            {
                _checkTimer = 1000;

                if (auto player = ObjectAccessor::GetPlayer(*me, _playerGUID))
                {
                    if (!player->IsAlive())
                        me->DespawnOrUnsummon();

                    if (player->GetQuestStatus(QUEST_WALKING_THE_DOG) == QUEST_STATUS_NONE
                        || player->GetQuestStatus(QUEST_WALKING_THE_DOG) == QUEST_STATUS_COMPLETE
                        || player->GetQuestStatus(QUEST_WALKING_THE_DOG) == QUEST_STATUS_REWARDED)
                    {
                        me->SetRooted(true);
                        me->DespawnOrUnsummon(6000);
                    }

                    if (me->GetReactState() != REACT_PASSIVE)
                    {
                        me->SetReactState(REACT_PASSIVE);
                        me->GetMotionMaster()->MoveFollow(player, 0.7f, 0.3f * M_PI);
                    }

                    if (me->GetDistance(player) > 100.f)
                        me->DespawnOrUnsummon();
                }
            }
            else _checkTimer -= diff;
        }
    private:
        ObjectGuid _playerGUID;
        uint16 _checkTimer = 1000;
    };

    CreatureAI* GetAI(Creature* creature) const
    {
        return new npc_spawn_of_smolderos_dogAI(creature);
    }
};

enum QuestGrudgeMatch
{
    QUEST_GRUDGE_MATCH = 25496,
    SPELL_LITTLE_BIG_FLAME_BREATH = 74143,
    SPELL_ATTACK_COSMETIC = 42880,

    NPC_BUTCHER = 3640412,
    NPC_GROMMKO = 3640409,
};

class npc_spawn_of_smolderos_grudge_match : public CreatureScript
{
public:
    npc_spawn_of_smolderos_grudge_match() : CreatureScript("npc_spawn_of_smolderos_grudge_match") { }

    struct npc_spawn_of_smolderos_grudge_matchAI : public ScriptedAI
    {
        npc_spawn_of_smolderos_grudge_matchAI(Creature* creature) : ScriptedAI(creature) {}

        void IsSummonedBy(Unit* summoner)
        {
            if (auto butcher = me->FindNearestCreature(NPC_BUTCHER, 30.f))
            {
                _butcherGUID = butcher->GetGUID();
                butcher->SetRegeneratingHealth(false);
            }

            if (auto grommko = me->FindNearestCreature(NPC_GROMMKO, 30.f))
            {
                _grommkoGUID = grommko->GetGUID();
                grommko->RemoveFlag(UNIT_NPC_FLAGS, UNIT_NPC_FLAG_GOSSIP | UNIT_NPC_FLAG_QUESTGIVER);
            }

            me->GetMotionMaster()->MovePoint(1, 4745.7036f, -4231.2216f, 894.522f);
            me->SetReactState(REACT_PASSIVE);
        }

        void MovementInform(uint32 type, uint32 point)
        {
            if (type != POINT_MOTION_TYPE)
                return;

            if (!_butcherKilled)
            {
                if (point == 1)
                    _fight = true;
            }
            else
            {
                if (point == 2)
                {
                    if (auto grommko = ObjectAccessor::GetCreature(*me, _grommkoGUID))
                    {
                        me->SetFacingToObject(grommko);
                        me->DespawnOrUnsummon(3000);
                    }
                }
            }
        }

        void UpdateAI(uint32 const diff)
        {
            DoMeleeAttackIfReady();

            if (_fight)
            {
                if (auto butcher = me->FindNearestCreature(NPC_BUTCHER, 30.f))
                {
                    if (_checkTimer <= diff)
                    {
                        _checkTimer = 6500;
                        me->CastSpell(butcher, SPELL_LITTLE_BIG_FLAME_BREATH);
                    }
                    else _checkTimer -= diff;

                    if (_checkTimer2 <= diff)
                    {
                        _checkTimer2 = 2000;
                        butcher->CastSpell(me, SPELL_ATTACK_COSMETIC);
                    }
                    else _checkTimer2 -= diff;
                }
                else
                {
                    _butcherKilled = true;
                    _fight = false;
                    me->GetMotionMaster()->MovePoint(2, 4753.262f, -4237.679f, 894.65f);

                    if (auto grommko = ObjectAccessor::GetCreature(*me, _grommkoGUID))
                    {
                        grommko->AI()->Talk(0);
                        grommko->SetFaction(14);

                        if (auto player = grommko->FindNearestPlayer(40.f))
                            grommko->AI()->AttackStart(player);
                    }
                }
            }

            if (me->HasUnitState(UNIT_STATE_CASTING))
                return;
        }
    private:
        bool _fight = false;
        bool _butcherKilled = false;
        ObjectGuid _butcherGUID;
        ObjectGuid _grommkoGUID;
        uint16 _checkTimer = 1000;
        uint16 _checkTimer2 = 1000;
    };

    CreatureAI* GetAI(Creature* creature) const
    {
        return new npc_spawn_of_smolderos_grudge_matchAI(creature);
    }
};

enum QuestSlashAndBurn
{
    QUEST_SLASH_AND_BURN = 25608,
    SPELL_PARACHUTE = 44795,
};

class npc_emerald_drake_slash_burn : public CreatureScript
{
public:
    npc_emerald_drake_slash_burn() : CreatureScript("npc_emerald_drake_slash_burn") { }

    struct npc_emerald_drake_slash_burnAI : public VehicleAI
    {
        npc_emerald_drake_slash_burnAI(Creature* creature) : VehicleAI(creature) {}

        void IsSummonedBy(Unit* summoner)
        {
            me->SetReactState(REACT_PASSIVE);
            me->SetPhaseMask(32768, true);

            if (auto player = summoner->ToPlayer())
                _playerGUID = player->GetGUID();
        }

        void SpellHit(Unit* who, SpellInfo const* spellInfo)
        {
            if (spellInfo->Id == SPELL_DUMMY_PING)
            {
                if (auto player = ObjectAccessor::GetPlayer(*me, _playerGUID))
                    player->KilledMonsterCredit(40573);
            }
        }

        void UpdateAI(uint32 const diff) override
        {
            if (_checkTimer <= diff)
            {
                _checkTimer = 1000;

                if (_isInCorrectArea)
                {
                    if (me->GetAreaId() != 4998
                        && me->GetAreaId() != 4991
                        && me->GetAreaId() != 4995
                        && me->GetAreaId() != 4984
                        && me->GetAreaId() != 4994)
                    {
                        _isInCorrectArea = false;
                        AiTalk(me->AI(), 0, _playerGUID);
                        _events.ScheduleEvent(EVENT_EMERALD_DRAKE_1, 10000);
                    }
                }
                else
                {
                    if (me->GetAreaId() == 4998
                        || me->GetAreaId() == 4984
                        || me->GetAreaId() == 4991
                        || me->GetAreaId() == 4995
                        || me->GetAreaId() == 4994)
                    {
                        _events.CancelEvent(EVENT_EMERALD_DRAKE_1);
                        _isInCorrectArea = true;
                    }
                }

                if (auto player = ObjectAccessor::GetPlayer(*me, _playerGUID))
                {
                    if (player->GetQuestStatus(QUEST_SLASH_AND_BURN) == QUEST_STATUS_NONE ||
                        player->GetQuestStatus(QUEST_SLASH_AND_BURN) == QUEST_STATUS_REWARDED)
                    {
                        me->DespawnOrUnsummon();
                        me->CastSpell(me, SPELL_EJECT_ALL_PASSENGERS);
                    }
                }
            }
            else _checkTimer -= diff;

            _events.Update(diff);

            while (uint32 eventId = _events.ExecuteEvent())
            {
                switch (eventId)
                {
                case EVENT_EMERALD_DRAKE_1:
                    me->CastSpell(me, SPELL_EJECT_ALL_PASSENGERS);
                    me->DespawnOrUnsummon(100);
                    break;
                default:
                    break;
                }
            }
        }
    private:
        bool _isInCorrectArea = false;
        uint32 _checkTimer = 1000;
        ObjectGuid _playerGUID;

        EventMap _events;
    };
    CreatureAI* GetAI(Creature* creature) const
    {
        return new npc_emerald_drake_slash_burnAI(creature);
    }
};

enum GraduationSpeech
{
    QUEST_GRADUATION_SPEECH = 25315,

    NPC_GRADUATION_CREDIT = 3640618,
    NPC_TWILIGHT_INITIATE = 3640185,
    NPC_GRADUATION_CONTROLLER = 3675196,

    GO_PODIUM = 3802996,

    SPELL_TWILIGHT_SPEECH = 74948,
    SPELL_TWILIGHT_SPEECH_AURA = 94441,
};

class npc_graduation_speech_controller : public CreatureScript
{
public:
    npc_graduation_speech_controller() : CreatureScript("npc_graduation_speech_controller") { }

    struct npc_graduation_speech_controllerAI : public ScriptedAI
    {
        npc_graduation_speech_controllerAI(Creature* creature) : ScriptedAI(creature) {}

        void Reset()
        {
            me->setActive(true);
            _eventStarted = false;
            _waitinForAnswer = false;
            _playerGUID = 0;
            _satisfyAnswer = 0;

            if (auto podium = me->FindNearestGameObject(GO_PODIUM, 5.f))
                podium->ResetDoorOrButton();
        }

        void DrawNpcAndTalk()
        {
            // 1 - inspire / 2 - incite / 3 - pander
            _satisfyAnswer = urand(1, 3);
            _waitinForAnswer = true;
            auto initiates = SelectNearbyUnits(me, NPC_TWILIGHT_INITIATE, 25.f);

            if (!initiates.empty())
            {
                auto initiate = initiates.begin();
                advance(initiate, urand(0, initiates.size() - 1));
                auto result = *initiate;

                if (auto target = result->ToCreature())
                {
                    switch (_satisfyAnswer)
                    {
                    case 1: // inspire
                        AiTalk(target->AI(), 3, _playerGUID);
                        break;
                    case 2: // incite
                        AiTalk(target->AI(), 4, _playerGUID);
                        break;
                    case 3: // pander
                        AiTalk(target->AI(), 5, _playerGUID);
                        break;
                    default:
                        break;
                    }
                }
            }
            else
            {
                Reset();

                if (auto player = ObjectAccessor::GetPlayer(*me, _playerGUID))
                {
                    player->RemoveAura(SPELL_TWILIGHT_SPEECH_AURA);
                    player->RemoveAura(SPELL_TWILIGHT_SPEECH);
                }
            }
        }

        void DoAction(int32 const actionId)
        {
            if (actionId == ACTION_GRADUATION_1)  // inspiration
            {
                _events.CancelEvent(EVENT_GRADUATION_1);
                _waitinForAnswer = false;

                if (_satisfyAnswer != 1)
                {
                    auto initiates = SelectNearbyUnits(me, NPC_TWILIGHT_INITIATE, 25.f);

                    if (!initiates.empty())
                    {
                        auto initiate = initiates.begin();
                        advance(initiate, urand(0, initiates.size() - 1));
                        auto result = *initiate;

                        if (auto target = result->ToCreature())
                        {
                            TalkWithDelay(target->AI(), 1500, 7, _playerGUID);
                            _events.ScheduleEvent(EVENT_GRADUATION_2, 5000);
                        }
                    }
                }
                else
                {
                    auto initiates = SelectNearbyUnits(me, NPC_TWILIGHT_INITIATE, 25.f);

                    if (!initiates.empty())
                    {
                        auto initiate = initiates.begin();
                        advance(initiate, urand(0, initiates.size() - 1));
                        auto result = *initiate;

                        if (auto target = result->ToCreature())
                        {
                            if (auto player = ObjectAccessor::GetPlayer(*me, _playerGUID))
                                player->KilledMonsterCredit(NPC_GRADUATION_CREDIT);

                            TalkWithDelay(target->AI(), 1500, 6, _playerGUID);
                            _events.ScheduleEvent(EVENT_GRADUATION_2, 5000);
                        }
                    }
                }
            }

            if (actionId == ACTION_GRADUATION_2)  // incite
            {
                _events.CancelEvent(EVENT_GRADUATION_1);
                _waitinForAnswer = false;

                if (_satisfyAnswer != 2)
                {
                    auto initiates = SelectNearbyUnits(me, NPC_TWILIGHT_INITIATE, 25.f);

                    if (!initiates.empty())
                    {
                        auto initiate = initiates.begin();
                        advance(initiate, urand(0, initiates.size() - 1));
                        auto result = *initiate;

                        if (auto target = result->ToCreature())
                        {
                            TalkWithDelay(target->AI(), 1500, 7, _playerGUID);
                            _events.ScheduleEvent(EVENT_GRADUATION_2, 5000);
                        }
                    }
                }
                else
                {
                    auto initiates = SelectNearbyUnits(me, NPC_TWILIGHT_INITIATE, 25.f);

                    if (!initiates.empty())
                    {
                        auto initiate = initiates.begin();
                        advance(initiate, urand(0, initiates.size() - 1));
                        auto result = *initiate;

                        if (auto target = result->ToCreature())
                        {
                            if (auto player = ObjectAccessor::GetPlayer(*me, _playerGUID))
                                player->KilledMonsterCredit(NPC_GRADUATION_CREDIT);

                            TalkWithDelay(target->AI(), 1500, 6, _playerGUID);
                            _events.ScheduleEvent(EVENT_GRADUATION_2, 5000);
                        }
                    }
                }
            }

            if (actionId == ACTION_GRADUATION_3)  // pander
            {
                _events.CancelEvent(EVENT_GRADUATION_1);
                _waitinForAnswer = false;

                if (_satisfyAnswer != 3)
                {
                    auto initiates = SelectNearbyUnits(me, NPC_TWILIGHT_INITIATE, 25.f);

                    if (!initiates.empty())
                    {
                        auto initiate = initiates.begin();
                        advance(initiate, urand(0, initiates.size() - 1));
                        auto result = *initiate;

                        if (auto target = result->ToCreature())
                        {
                            TalkWithDelay(target->AI(), 1500, 7, _playerGUID);
                            _events.ScheduleEvent(EVENT_GRADUATION_2, 5000);
                        }
                    }
                }
                else
                {
                    auto initiates = SelectNearbyUnits(me, NPC_TWILIGHT_INITIATE, 25.f);

                    if (!initiates.empty())
                    {
                        auto initiate = initiates.begin();
                        advance(initiate, urand(0, initiates.size() - 1));
                        auto result = *initiate;

                        if (auto target = result->ToCreature())
                        {
                            if (auto player = ObjectAccessor::GetPlayer(*me, _playerGUID))
                                player->KilledMonsterCredit(NPC_GRADUATION_CREDIT);

                            TalkWithDelay(target->AI(), 1500, 6, _playerGUID);
                            _events.ScheduleEvent(EVENT_GRADUATION_2, 5000);
                        }
                    }
                }
            }

            if (actionId == ACTION_GRADUATION_4)  // step down
            {
                _events.CancelEvent(EVENT_GRADUATION_1);
                _events.CancelEvent(EVENT_GRADUATION_2);
                Reset();
            }
        }

        void SpellHit(Unit* who, SpellInfo const* spellInfo)
        {
            if (!_eventStarted)
            {
                if (spellInfo->Id == SPELL_DUMMY_PING)
                {
                    if (auto player = who->ToPlayer())
                    {
                        _eventStarted = true;
                        _playerGUID = player->GetGUID();
                        _events.ScheduleEvent(EVENT_GRADUATION_2, 2500, 1);
                    }
                }
            }
        }

        void UpdateAI(uint32 const diff)
        {
            if (_eventStarted)
            {
                if (_waitinForAnswer)
                {
                    if (_checkTimer <= diff)
                    {
                        _checkTimer = 17000;
                        _events.ScheduleEvent(EVENT_GRADUATION_1, 15000);
                    }
                    else _checkTimer -= diff;
                }
            }

            _events.Update(diff);

            while (uint32 eventId = _events.ExecuteEvent())
            {
                switch (eventId)
                {
                case EVENT_GRADUATION_1:
                    if (auto player = ObjectAccessor::GetPlayer(*me, _playerGUID))
                    {
                        player->RemoveAura(SPELL_TWILIGHT_SPEECH_AURA);
                        player->RemoveAura(SPELL_TWILIGHT_SPEECH);
                        AiTalk(me->AI(), 0, _playerGUID);
                        Reset();
                    }
                    break;
                case EVENT_GRADUATION_2:
                    if (auto player = ObjectAccessor::GetPlayer(*me, _playerGUID))
                    {
                        if (player->GetQuestStatus(QUEST_GRADUATION_SPEECH) == QUEST_STATUS_COMPLETE)
                        {
                            player->RemoveAura(SPELL_TWILIGHT_SPEECH_AURA);
                            player->RemoveAura(SPELL_TWILIGHT_SPEECH);
                            Reset();
                        }
                        else
                            DrawNpcAndTalk();
                    }
                    break;
                default:
                    break;
                }
            }
        }
    private:
        bool _eventStarted = false;
        bool _waitinForAnswer = false;
        uint8 _satisfyAnswer = 0; // 1 - inspire / 2 - incite / 3 - pander
        ObjectGuid _playerGUID;
        uint16 _checkTimer = 1000;
        uint16 _noPlayerTimer = 1000;
        EventMap _events;
    };

    CreatureAI* GetAI(Creature* creature) const
    {
        return new npc_graduation_speech_controllerAI(creature);
    }
};

class spell_inspiration_graduation : public SpellScriptLoader
{
public:
    spell_inspiration_graduation() : SpellScriptLoader("spell_inspiration_graduation") { }

    class spell_inspiration_graduation_SpellScript : public SpellScript
    {
        PrepareSpellScript(spell_inspiration_graduation_SpellScript);

        bool Validate(SpellInfo const* /*spellEntry*/)
        {
            return true;
        }
        void HandleScriptEffect(SpellEffIndex effIndex)
        {
            if (auto caster = GetCaster())
                if (auto player = caster->ToPlayer())
                {
                    if (auto initiate = caster->FindNearestCreature(NPC_TWILIGHT_INITIATE, 6.f))
                        if (auto controller = caster->FindNearestCreature(NPC_GRADUATION_CONTROLLER, 6.f))
                        {
                            sCreatureTextMgr->SendChat(initiate, 0, 0, CHAT_MSG_ADDON, LANG_ADDON, TEXT_RANGE_NORMAL, 0, TEAM_NEUTRAL, false, player);
                            controller->AI()->DoAction(ACTION_GRADUATION_1);
                        }
                }
        }
        void Register()
        {
            OnEffectHitTarget += SpellEffectFn(spell_inspiration_graduation_SpellScript::HandleScriptEffect, EFFECT_0, SPELL_EFFECT_SCRIPT_EFFECT);
        }
    };
    SpellScript* GetSpellScript() const
    {
        return new spell_inspiration_graduation_SpellScript();
    }
};

class spell_divisiveness_graduation : public SpellScriptLoader
{
public:
    spell_divisiveness_graduation() : SpellScriptLoader("spell_divisiveness_graduation") { }

    class spell_divisiveness_graduation_SpellScript : public SpellScript
    {
        PrepareSpellScript(spell_divisiveness_graduation_SpellScript);

        bool Validate(SpellInfo const* /*spellEntry*/)
        {
            return true;
        }
        void HandleScriptEffect(SpellEffIndex effIndex)
        {
            if (auto caster = GetCaster())
                if (auto player = caster->ToPlayer())
                {
                    if (auto initiate = caster->FindNearestCreature(NPC_TWILIGHT_INITIATE, 6.f))
                        if (auto controller = caster->FindNearestCreature(NPC_GRADUATION_CONTROLLER, 6.f))
                        {
                            sCreatureTextMgr->SendChat(initiate, 1, 0, CHAT_MSG_ADDON, LANG_ADDON, TEXT_RANGE_NORMAL, 0, TEAM_NEUTRAL, false, player);
                            controller->AI()->DoAction(ACTION_GRADUATION_2);
                        }
                }
        }
        void Register()
        {
            OnEffectHitTarget += SpellEffectFn(spell_divisiveness_graduation_SpellScript::HandleScriptEffect, EFFECT_0, SPELL_EFFECT_SCRIPT_EFFECT);
        }
    };
    SpellScript* GetSpellScript() const
    {
        return new spell_divisiveness_graduation_SpellScript();
    }
};

class spell_crazy_graduation : public SpellScriptLoader
{
public:
    spell_crazy_graduation() : SpellScriptLoader("spell_crazy_graduation") { }

    class spell_crazy_graduation_SpellScript : public SpellScript
    {
        PrepareSpellScript(spell_crazy_graduation_SpellScript);

        bool Validate(SpellInfo const* /*spellEntry*/)
        {
            return true;
        }
        void HandleScriptEffect(SpellEffIndex effIndex)
        {
            if (auto caster = GetCaster())
                if (auto player = caster->ToPlayer())
                {
                    if (auto initiate = caster->FindNearestCreature(NPC_TWILIGHT_INITIATE, 6.f))
                        if (auto controller = caster->FindNearestCreature(NPC_GRADUATION_CONTROLLER, 6.f))
                        {
                            sCreatureTextMgr->SendChat(initiate, 2, 0, CHAT_MSG_ADDON, LANG_ADDON, TEXT_RANGE_NORMAL, 0, TEAM_NEUTRAL, false, player);
                            controller->AI()->DoAction(ACTION_GRADUATION_3);
                        }
                }
        }
        void Register()
        {
            OnEffectHitTarget += SpellEffectFn(spell_crazy_graduation_SpellScript::HandleScriptEffect, EFFECT_0, SPELL_EFFECT_SCRIPT_EFFECT);
        }
    };
    SpellScript* GetSpellScript() const
    {
        return new spell_crazy_graduation_SpellScript();
    }
};

class spell_step_down_graduation : public SpellScriptLoader
{
public:
    spell_step_down_graduation() : SpellScriptLoader("spell_step_down_graduation") { }

    class spell_step_down_graduation_SpellScript : public SpellScript
    {
        PrepareSpellScript(spell_step_down_graduation_SpellScript);

        void RemoveAura()
        {
            if (auto caster = GetCaster())
                if (auto player = caster->ToPlayer())
                {
                    if (auto controller = caster->FindNearestCreature(NPC_GRADUATION_CONTROLLER, 6.f))
                    {
                        controller->AI()->DoAction(ACTION_GRADUATION_4);
                    }
                }
        }

        void Register()
        {
            AfterHit += SpellHitFn(spell_step_down_graduation_SpellScript::RemoveAura);
        }
    };
    SpellScript* GetSpellScript() const
    {
        return new spell_step_down_graduation_SpellScript();
    }
};

enum QuestCalltheFlock
{
    QUEST_CALL_THE_FLOCK = 29147,

    SPELL_SOAR = 98027,
    SPELL_LUDICROUS_SPEED_ACHIEVEMENT = 115006,
};

class npc_wings_of_aviana_daily : public CreatureScript
{
public:
    npc_wings_of_aviana_daily() : CreatureScript("npc_wings_of_aviana_daily") { }

    struct npc_wings_of_aviana_dailyAI : public VehicleAI
    {
        npc_wings_of_aviana_dailyAI(Creature* creature) : VehicleAI(creature) {}

        void IsSummonedBy(Unit* summoner)
        {
            me->SetReactState(REACT_PASSIVE);
            me->SetPhaseMask(32, true);

            if (auto player = summoner->ToPlayer())
                _playerGUID = player->GetGUID();
        }

        void SpellHit(Unit* who, SpellInfo const* spellInfo)
        {
            if (spellInfo->Id == SPELL_SOAR)
            {
                if (!_gotAchievement)
                {
                    if (me->GetAuraCount(SPELL_SOAR) >= 65)
                    {
                        if (auto player = ObjectAccessor::GetPlayer(*me, _playerGUID))
                        {
                            player->CastSpell(player, SPELL_LUDICROUS_SPEED_ACHIEVEMENT);
                            _gotAchievement = true;
                        }
                    }
                }
            }
        }

        void UpdateAI(uint32 const diff) override
        {
            if (_checkTimer <= diff)
            {
                _checkTimer = 1000;

                if (_isInCorrectArea)
                {
                    if (me->GetAreaId() != 5018
                        && me->GetAreaId() != 5013
                        && me->GetAreaId() != 4989
                        && me->GetAreaId() != 5015
                        && me->GetAreaId() != 5781
                        && me->GetAreaId() != 5022
                        && me->GetAreaId() != 5019
                        && me->GetAreaId() != 5087
                        && me->GetAreaId() != 4861
                        && me->GetAreaId() != 5016)
                    {
                        _isInCorrectArea = false;
                        AiTalk(me->AI(), 0, _playerGUID);
                        _events.ScheduleEvent(EVENT_WINGS_OF_AVIANA_1, 10000);
                    }
                }
                else
                {
                    if (me->GetAreaId() == 5018
                        || me->GetAreaId() == 5013
                        || me->GetAreaId() == 4989
                        || me->GetAreaId() == 5015
                        || me->GetAreaId() == 5781
                        || me->GetAreaId() == 5022
                        || me->GetAreaId() == 5019
                        || me->GetAreaId() == 5087
                        || me->GetAreaId() == 4861
                        || me->GetAreaId() == 5016)
                    {
                        _events.CancelEvent(EVENT_WINGS_OF_AVIANA_1);
                        _isInCorrectArea = true;
                    }
                }

                if (auto player = ObjectAccessor::GetPlayer(*me, _playerGUID))
                {
                    if (player->GetQuestStatus(QUEST_CALL_THE_FLOCK) == QUEST_STATUS_NONE ||
                        player->GetQuestStatus(QUEST_CALL_THE_FLOCK) == QUEST_STATUS_REWARDED)
                    {
                        me->DespawnOrUnsummon();
                        me->CastSpell(me, SPELL_EJECT_ALL_PASSENGERS);
                    }
                }
            }
            else _checkTimer -= diff;

            _events.Update(diff);

            while (uint32 eventId = _events.ExecuteEvent())
            {
                switch (eventId)
                {
                case EVENT_WINGS_OF_AVIANA_1:
                    me->CastSpell(me, SPELL_EJECT_ALL_PASSENGERS);
                    me->DespawnOrUnsummon(100);
                    break;
                default:
                    break;
                }
            }
        }
    private:
        bool _gotAchievement = false;
        bool _isInCorrectArea = false;
        uint32 _checkTimer = 1000;
        ObjectGuid _playerGUID;

        EventMap _events;
    };
    CreatureAI* GetAI(Creature* creature) const
    {
        return new npc_wings_of_aviana_dailyAI(creature);
    }
};

enum QuestPuntingSeason
{
    QUEST_PUNTING_SEASON = 29101,
    NPC_PUTING_SEASON_CREDIT = 3652177,
    NPC_FLAME_ELEMENTAL = 3652219,
    SPELL_KNOCKBACK_ELEMENTAL = 74902,
    SPELL_VISUAL_HOLD_CHILD = 96303,
    SPELL_AND_THE_MEEK_SHALL_INHERIT_KALIMDOR_CHILD_UPDATE = 98102,
};

class npc_turtle_punter : public CreatureScript
{
public:
    npc_turtle_punter() : CreatureScript("npc_turtle_punter") { }

    struct npc_turtle_punterAI : public VehicleAI
    {
        npc_turtle_punterAI(Creature* creature) : VehicleAI(creature) {}

        void IsSummonedBy(Unit* summoner)
        {
            me->setActive(true);
            me->SetReactState(REACT_PASSIVE);

            if (Player* player = summoner->ToPlayer())
                _playerGUID = player->GetGUID();
        }

        void PassengerBoarded(Unit* passenger, int8 /* seatId */, bool apply)
        {
            if (apply && passenger->GetTypeId() == TYPEID_PLAYER)
            {
            }

            if (!apply && passenger->GetTypeId() == TYPEID_PLAYER)
            {
                passenger->RemoveAura(SPELL_VISUAL_HOLD_CHILD);
                me->RemoveFlag(UNIT_NPC_FLAGS, UNIT_NPC_FLAG_SPELLCLICK);
                me->DespawnOrUnsummon(8000);
            }
        }

        void UpdateAI(uint32 const diff)
        {
            if (auto player = ObjectAccessor::GetPlayer(*me, _playerGUID))
            {
                if (player->GetQuestStatus(QUEST_PUNTING_SEASON) == QUEST_STATUS_NONE ||
                    player->GetQuestStatus(QUEST_PUNTING_SEASON) == QUEST_STATUS_REWARDED)
                {
                    player->ExitVehicle();
                    me->RemoveFlag(UNIT_NPC_FLAGS, UNIT_NPC_FLAG_SPELLCLICK);
                    me->DespawnOrUnsummon(100);
                }

                if (me->GetDistance(player) >= 10.f)
                {
                    me->RemoveFlag(UNIT_NPC_FLAGS, UNIT_NPC_FLAG_SPELLCLICK);
                    me->DespawnOrUnsummon(100);
                }
            }

            //_events.Update(diff);
            //
            //while (uint32 eventId = _events.ExecuteEvent())
            //{
            //    switch (eventId)
            //    {
            //    case EVENT_STUNT_HORSE_1:
            //        me->SetRooted(false);
            //        MoveSmoothPath(me->GetMotionMaster(), StoutHorsePath, StoutHorsePathSize);
            //        break;
            //    default:
            //        break;
            //    }
            //}
        }
    private:
        ObjectGuid _playerGUID;
        EventMap _events;
    };
    CreatureAI* GetAI(Creature* creature) const
    {
        return new npc_turtle_punterAI(creature);
    }
};

class npc_punt_child_of_tortolla : public CreatureScript
{
public:
    npc_punt_child_of_tortolla() : CreatureScript("npc_punt_child_of_tortolla") { }

    struct npc_punt_child_of_tortollaAI : public ScriptedAI
    {
        npc_punt_child_of_tortollaAI(Creature* creature) : ScriptedAI(creature) {}

        void IsSummonedBy(Unit* summoner)
        {
            if (me->GetOwnerGUID() != summoner->GetOwnerGUID())
            {
                if (auto myowner = summoner->GetOwner())
                    if (auto newowner = myowner->ToPlayer())
                    {
                        me->SetOwnerGUID(newowner->GetGUID());
                        _playerGUID = me->GetOwnerGUID();
                    }
            }

            me->setActive(true);
            me->SetReactState(REACT_PASSIVE);
            me->SetPhaseMask(32, true);
        }

        void UpdateAI(uint32 const diff)
        {
            if (_checkTimer <= diff)
            {
                _checkTimer = 20000;

                if (me->IsInWater())
                {
                    if (auto player = ObjectAccessor::GetPlayer(*me, _playerGUID))
                    {
                        player->KilledMonsterCredit(NPC_PUTING_SEASON_CREDIT);
                        me->DespawnOrUnsummon(6000);
                    }
                }
                else
                {
                    me->DespawnOrUnsummon(6000);

                    if (me->FindNearestCreature(NPC_FLAME_ELEMENTAL, 3.f))
                    {
                        me->CastSpell(me, SPELL_KNOCKBACK_ELEMENTAL);

                        if (auto player = ObjectAccessor::GetPlayer(*me, _playerGUID))
                            player->CastSpell(player, SPELL_AND_THE_MEEK_SHALL_INHERIT_KALIMDOR_CHILD_UPDATE);
                    }
                }
            }
            else _checkTimer -= diff;
        }
    private:
        ObjectGuid _playerGUID;
        uint32 _checkTimer = 100;
    };

    CreatureAI* GetAI(Creature* creature) const
    {
        return new npc_punt_child_of_tortollaAI(creature);
    }
};

class spell_tortolla_save_turtle : public SpellScriptLoader
{
public:
    spell_tortolla_save_turtle() : SpellScriptLoader("spell_tortolla_save_turtle") { }

    class spell_tortolla_save_turtle_SpellScript : public SpellScript
    {
        PrepareSpellScript(spell_tortolla_save_turtle_SpellScript);

        void HandleOnCast()
        {
            if (auto caster = GetCaster())
                if (auto owner = caster->GetOwner())
                    if (auto player = owner->ToPlayer())
                        if (caster->IsVehicle())
                            player->ExitVehicle();
        }

        void Register()
        {
            OnCast += SpellCastFn(spell_tortolla_save_turtle_SpellScript::HandleOnCast);
        }
    };
    SpellScript* GetSpellScript() const
    {
        return new spell_tortolla_save_turtle_SpellScript();
    }
};

class spell_drop_turtle : public SpellScriptLoader
{
public:
    spell_drop_turtle() : SpellScriptLoader("spell_drop_turtle") { }

    class spell_drop_turtle_SpellScript : public SpellScript
    {
        PrepareSpellScript(spell_drop_turtle_SpellScript);

        bool Validate(SpellInfo const* /*spellEntry*/)
        {
            return true;
        }
        void HandleScriptEffect(SpellEffIndex effIndex)
        {
            if (auto caster = GetCaster())
                if (auto owner = caster->GetOwner())
                    if (auto player = owner->ToPlayer())
                        if (caster->IsVehicle())
                        {
                            player->ExitVehicle();

                            if (auto veh = caster->ToCreature())
                                veh->SummonCreature(NPC_PUTING_SEASON_CREDIT, veh->GetPositionX(), veh->GetPositionY(), veh->GetPositionZ(), veh->GetOrientation(), TEMPSUMMON_TIMED_DESPAWN, 600000);
                        }

        }
        void Register()
        {
            OnEffectHitTarget += SpellEffectFn(spell_drop_turtle_SpellScript::HandleScriptEffect, EFFECT_1, SPELL_EFFECT_SCRIPT_EFFECT);
        }
    };
    SpellScript* GetSpellScript() const
    {
        return new spell_drop_turtle_SpellScript();
    }
};

enum QuestLycanthoth
{
    QUEST_LYCANTHOTH_H = 25272,
    QUEST_LYCANTHOTH_A = 25273,
    SPELL_SUMMON_SPIRIT_OF_GOLDRINN = 74078, // 39627
    SPELL_SUMMON_SPIRIT_OF_LOGOSH = 74077, // 39622
    SPELL_TELEPORT_1 = 151415,

    NPC_BUNNY_TRIGGER = 3675197,
};

uint32 const LogoshPathSize = 5;
const G3D::Vector3 LogoshPath[LogoshPathSize] =
{
    {  5149.99f, -2297.27f, 1278.9f },
    {  5157.30f, -2289.78f, 1279.9f },
    {  5166.50f, -2282.31f, 1279.9f },
    {  5176.72f, -2274.10f, 1276.9f },
    {  5187.57f, -2265.60f, 1273.67f}, // 4
};

uint32 const LogoshPathSize2 = 6;
const G3D::Vector3 LogoshPath2[LogoshPathSize2] =
{
    {  5187.57f, -2265.60f, 1273.67f },
    {  5196.64f, -2259.28f, 1271.77f },
    {  5210.09f, -2252.79f, 1269.05f },
    {  5223.82f, -2241.72f, 1266.35f },
    {  5234.68f, -2227.53f, 1264.19f },
    {  5246.96f, -2222.75f, 1263.87f }, // 5
};

class npc_spirit_of_logosh_goldrinn_vehicle : public CreatureScript
{
public:
    npc_spirit_of_logosh_goldrinn_vehicle() : CreatureScript("npc_spirit_of_logosh_goldrinn_vehicle") { }

    struct npc_spirit_of_logosh_goldrinn_vehicleAI : public VehicleAI
    {
        npc_spirit_of_logosh_goldrinn_vehicleAI(Creature* creature) : VehicleAI(creature) {}

        void IsSummonedBy(Unit* summoner)
        {
            me->SetReactState(REACT_PASSIVE);
            me->SetRooted(true);
            me->RemoveFlag(UNIT_NPC_FLAGS, UNIT_NPC_FLAG_GOSSIP | UNIT_NPC_FLAG_QUESTGIVER);

            if (auto player = summoner->ToPlayer())
            {
                _playerGUID = player->GetGUID();
                player->CastSpell(me, SPELL_RIDE_VEHICLE);
            }
        }

        void PassengerBoarded(Unit* passenger, int8 /* seatId */, bool apply)
        {
            if (apply && passenger->GetTypeId() == TYPEID_PLAYER)
            {
                _events.ScheduleEvent(EVENT_LOGOSH_1, 2000);
            }

            if (!apply && passenger->GetTypeId() == TYPEID_PLAYER)
            {
                me->DespawnOrUnsummon(2500);
            }
        }

        void MovementInform(uint32 type, uint32 point)
        {
            if (type != ESCORT_MOTION_TYPE)
                return;

            if (_pathmode == 1)
            {
                if (point == 2)
                {
                    if (auto player = ObjectAccessor::GetPlayer(*me, _playerGUID))
                        player->CastSpell(player, SPELL_FADE_TO_BLACK);
                }

                if (point == 4)
                {
                    if (auto player = ObjectAccessor::GetPlayer(*me, _playerGUID))
                    {
                        player->ExitVehicle();
                        player->GetMotionMaster()->MoveJump(5178.640f, -2269.761f, 1275.2f, 30.f, 30.f);
                    }

                    _events.ScheduleEvent(EVENT_LOGOSH_3, 1000);
                }
            }
            // cant script cuz because camera view is falling while using changeseat
            //if (_pathmode == 2)
            //{
            //    if (point == 5)
            //    {
            //        if (auto player = ObjectAccessor::GetPlayer(*me, _playerGUID))
            //        {
            //            player->ExitVehicle();
            //            me->RemoveFlag(UNIT_NPC_FLAGS, UNIT_NPC_FLAG_SPELLCLICK);
            //            me->DespawnOrUnsummon(1000);
            //        }
            //    }
            //}
        }

        void UpdateAI(uint32 const diff)
        {
            _events.Update(diff);

            while (uint32 eventId = _events.ExecuteEvent())
            {
                switch (eventId)
                {
                case EVENT_LOGOSH_1:
                    _pathmode = 1;
                    me->SetRooted(false);
                    MoveSmoothPath(me->GetMotionMaster(), LogoshPath, LogoshPathSize);
                    break;
                case EVENT_LOGOSH_2:
                    _pathmode++;
                    MoveSmoothPath(me->GetMotionMaster(), LogoshPath2, LogoshPathSize2);
                    break;
                case EVENT_LOGOSH_3:
                    if (auto player = ObjectAccessor::GetPlayer(*me, _playerGUID))
                    {
                        player->RemoveAura(SPELL_FADE_TO_BLACK);
                        player->TeleportTo(1, 5360.246f, -2184.654f, 1287.916f, 5.919f);
                    }
                    break;
                default:
                    break;
                }
            }
        }
    private:
        bool _timeToTP = false;
        uint8 _pathmode = 0;
        ObjectGuid _playerGUID;
        EventMap _events;
    };
    CreatureAI* GetAI(Creature* creature) const
    {
        return new npc_spirit_of_logosh_goldrinn_vehicleAI(creature);
    }
};

void AddSC_dc_mount_hyjal_ported()
{
    new npc_aronus_vehicle();
    new first_quest_mount_hyjal_playerscript();
    new npc_emerald_flameweaver_infiltrators();
    //new spell_inferno_tick(); // TODO
    new npc_archdruid_fandral_staghelm_dream();
    new npc_spawn_ogres_and_slaves_controller();
    new npc_twilight_proveditor();
    new npc_twilight_slavedriver();
    new npc_twilight_slave();
    new go_flameward_inferno();
    new npc_activated_flameward();
    new npc_aessina_miracle_vehicle();
    new npc_strength_of_tortolla();
    new npc_blazing_trainer_agility_training();
    new npc_spawn_of_smolderos_dog();
    new npc_orb_of_ascension();
    new spell_answer_yes_master();
    new spell_answer_yes_correct();
    new spell_answer_yes_incorrect();
    new spell_answer_no_master();
    new spell_answer_no_correct();
    new spell_answer_no_incorrect();
    new npc_spawn_of_smolderos_grudge_match();
    new npc_emerald_drake_slash_burn();
    new npc_graduation_speech_controller();
    new spell_inspiration_graduation();
    new spell_divisiveness_graduation();
    new spell_crazy_graduation();
    new spell_step_down_graduation();
    new npc_wings_of_aviana_daily();
    new npc_turtle_punter();
    new npc_punt_child_of_tortolla();
    new spell_tortolla_save_turtle();
    new spell_drop_turtle();
    new npc_spirit_of_logosh_goldrinn_vehicle();
}