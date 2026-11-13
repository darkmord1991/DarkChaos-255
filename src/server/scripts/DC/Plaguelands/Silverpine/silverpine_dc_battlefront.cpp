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

// Silverpine Forest on map 751 -- the Battlefront slice of the Neltharion 4.3.4 port.
//
// Source: Project Neltharion zone_silverpine_forest.cpp, lines 3573-4420. The Horde Haulers that follow
// in the source are deliberately not ported (see silverpine_dc.h).
//
//   npc_godfrey_battlefront_guardian   the three Forsaken lords that follow the player through Silverpine
//   npc_walden_battlefront_guardian    after "Taking the Battlefront" (27542). Spells 85517-85519 summon
//   npc_ashbury_battlefront_guardian   them, so they live at their PLAIN Cata ids 45878-45880.
//   npc_cowering_trooper               "Of No Consequence" (27547), the spawned clone 4145910.
//   npc_lorna_majesty                  "On Her Majesty's Secret Service" (27594), the spawned clone 4145997.
//
// Neltharion-custom spells, which exist in no client, are replaced by direct AI calls:
//   151318 / 151319 "ping my summons" (player -> own guardians) -> SetGUID(playerGuid, 151318 / 151319)
//   98915 Godfrey -> Lorna (a real spell, kept as a SpellHit too)  -> SetGUID(godfreyGuid, 98915)
//   91166 "cower emote" aura (not on this server)                  -> EMOTE_STATE_COWER
// The SetGUID ids ARE the source's spell ids, so another slice can drive these AIs the same way.
// Event ids are the source's SilverpineEvents values; point id 1 is the source's.
//
// Behaviour fixes against the source, each marked "Source:" where it happens:
//   - GetOwner() was dereferenced unguarded; the owner is resolved from the stored player GUID instead.
//   - the periodic check never re-armed its timer, so it ran on every tick after the first.
//   - Lorna kept `_activated` through an evade, so the scene could never be started again.
//   - Walden's emergency heal cleared his combat rotation until the next pull.

#include "CellImpl.h"
#include "CreatureScript.h"
#include "GridNotifiers.h"
#include "GridNotifiersImpl.h"
#include "ObjectAccessor.h"
#include "ObjectMgr.h"
#include "Player.h"
#include "QuestDef.h"
#include "ScriptedCreature.h"
#include "SpellInfo.h"
#include "TaskScheduler.h"
#include "TemporarySummon.h"
#include "silverpine_dc.h"

namespace
{
    enum BattlefrontSpells : uint32
    {
        // file-wide (source lines 42-58)
        SPELL_DUMMY_PING                    = 98914,
        SPELL_DUMMY_PING_2                  = 98915,
        SPELL_SANCTUARY_NO_COMBAT           = 88467,
        SPELL_DUMMY_SPELLCLICK              = 56685,

        // BattlefrontSummons: the marker auras the summon spells leave on the player
        SPELL_BATTLEFRONT_SUMMON_GODFREY    = 85517,
        SPELL_BATTLEFRONT_SUMMON_WALDEN     = 85518,
        SPELL_BATTLEFRONT_SUMMON_ASHBURY    = 85519,

        // BattlefrontGuardianDatas
        SPELL_WALDEN_PENANCE                = 54518,
        SPELL_WALDEN_SHIELD                 = 11974,
        SPELL_WALDEN_INNER_FIRE             = 48168,
        SPELL_WALDEN_SMITE                  = 9734,
        SPELL_WALDEN_HOLYNOVA               = 85965,

        SPELL_GODFREY_FIREBALL              = 79854,
        SPELL_GODFREY_BLASTWAVE             = 79857,
        SPELL_GODFREY_FLAMESTRIKE           = 79856,
        SPELL_GODFREY_MOLTEN                = 79849,

        SPELL_ASHBURY_FORM                  = 16592,
        SPELL_ASHBURY_MINDBLAST             = 13860,
        SPELL_ASHBURY_PAIN                  = 589,
        SPELL_ASHBURY_PSYCHIC               = 22884,

        // CoweringTropper. 151111 is Neltharion's "Fear Visual": in our spell_dbc it is a self-cast
        // SPELL_AURA_MOD_FEAR, i.e. the trooper flees in random directions until it despawns.
        SPELL_RUN_RANDOMLY                  = 151111,
        SPELL_EXECUTION                     = 85584,

        // LornaMajesty
        SPELL_LORNA_CLEAVE                  = 85240,
        SPELL_LORNA_THUNDERCLAP             = 81140,
        SPELL_LORNA_CHARGE                  = 22120,
        SPELL_LORNA_COMMANDING_SHOUT        = 80983
    };

    // SetGUID ids: the source's spell ids, see the file header.
    enum BattlefrontActions : int32
    {
        ACTION_PING_MY_SUMMONS              = 151318,
        ACTION_PING_MY_SUMMONS_2            = 151319,
        ACTION_LORNA_RESET_PING             = 98914,    // SPELL_DUMMY_PING
        ACTION_LORNA_GODFREY_PING           = 98915     // SPELL_DUMMY_PING_2
    };

    // The source's SilverpineEvents values, kept numerically identical.
    enum BattlefrontEvents : uint32
    {
        EVENT_WALDEN_SMITE                  = 51,
        EVENT_WALDEN_HOLYNOVA               = 52,
        EVENT_GODFREY_FIREBALL              = 53,
        EVENT_GODFREY_BLASTWAVE             = 54,
        EVENT_GODFREY_FLAMESTRIKE           = 55,
        EVENT_ASHBURY_MINDBLAST             = 56,
        EVENT_ASHBURY_PAIN                  = 57,
        EVENT_ASHBURY_PSYCHIC               = 58,
        EVENT_COWERINGTROPPER_1             = 59,
        EVENT_COWERINGTROPPER_2             = 60,
        EVENT_COWERINGTROPPER_3             = 61,
        EVENT_MAJESTY_1                     = 62,
        EVENT_MAJESTY_2                     = 63,
        EVENT_LORNA_CLEAVE                  = 65,
        EVENT_LORNA_THUNDERCLAP             = 66,
        EVENT_LORNA_CHARGE                  = 67
    };

    enum BattlefrontCreatures : uint32
    {
        // Summoned by 85517-85519, which name the plain ids.
        NPC_GODFREY_GUARDIAN                = 45878,
        NPC_WALDEN_GUARDIAN                 = 45879,
        NPC_ASHBURY_GUARDIAN                = 45880,

        // Cata ids of the two spawned NPCs; on 751 they sit at + 4,100,000.
        NPC_COWERING_TROOPER_CATA           = 45910,
        NPC_LORNA_MAJESTY_CATA              = 45997,

        // Never spawned: the kill-credit marker quest 27594 names ("Commander Lorna Crowley captured").
        NPC_LORNA_CAPTURE_CREDIT            = 46002
    };

    constexpr uint32 NPC_COWERING_TROOPER_751 = SilverpineDC::Creature751(NPC_COWERING_TROOPER_CATA);
    constexpr uint32 NPC_LORNA_MAJESTY_751    = SilverpineDC::Creature751(NPC_LORNA_MAJESTY_CATA);

    enum BattlefrontQuests : uint32
    {
        QUEST_OF_NO_CONSEQUENCE             = 27547,
        QUEST_ON_HER_MAJESTY                = 27594
    };

    constexpr uint32 POINT_BATTLEFRONT_SCENE = 1;

    // On 751 the Silverpine / Ruins of Gilneas border runs past Lorna's camp at the Greymane Wall, a spot the
    // source still counted as Silverpine (zone 130). Within this radius of the scene, 4939 counts too.
    constexpr uint32 ZONE_RUINS_OF_GILNEAS_751  = 4939;
    constexpr float BATTLEFRONT_SCENE_X         = -802.0f;
    constexpr float BATTLEFRONT_SCENE_Y         = 1342.0f;
    constexpr float BATTLEFRONT_BORDER_RADIUS   = 100.0f;

    constexpr float GUARDIAN_FOLLOW_DIST        = 0.8f;
    constexpr float PING_RANGE                  = 100.0f;
    constexpr float LORNA_CREDIT_RANGE          = 80.0f;

    // Summoned for this player? A spell summon is a Guardian (owner set); a script summon only has a summoner.
    bool IsSummonedFor(Creature const* creature, ObjectGuid const& playerGuid)
    {
        if (!playerGuid)
            return false;

        if (creature->GetOwnerGUID() == playerGuid || creature->GetCreatorGUID() == playerGuid)
            return true;

        TempSummon const* summon = creature->ToTempSummon();
        return summon && summon->GetSummonerGUID() == playerGuid;
    }

    // The player's own guardian of `entry`, never another player's (the source used FindNearestCreature).
    Creature* FindGuardianOf(WorldObject const* searcher, ObjectGuid const& playerGuid, uint32 entry, float range)
    {
        std::list<Creature*> candidates;
        searcher->GetCreatureListWithEntryInGrid(candidates, entry, range);
        for (Creature* candidate : candidates)
            if (candidate->IsAlive() && IsSummonedFor(candidate, playerGuid))
                return candidate;

        return nullptr;
    }

    // Replaces player->CastSpell(player, 151318 / 151319).
    void PingGuardiansOf(Player* player, int32 action)
    {
        for (uint32 entry : { NPC_GODFREY_GUARDIAN, NPC_WALDEN_GUARDIAN, NPC_ASHBURY_GUARDIAN })
            if (Creature* guardian = FindGuardianOf(player, player->GetGUID(), entry, PING_RANGE))
                if (guardian->IsAIEnabled)
                    guardian->AI()->SetGUID(player->GetGUID(), action);
    }

    // Credit whatever creature the live quest's first objective names. The 751 import moved some objectives to
    // the + 4,100,000 clone and left others raw, so the id is read rather than assumed.
    uint32 QuestCreditEntry(uint32 questId, uint32 fallback)
    {
        if (Quest const* quest = sObjectMgr->GetQuestTemplate(questId))
            if (quest->RequiredNpcOrGo[0] > 0)
                return uint32(quest->RequiredNpcOrGo[0]);

        return fallback;
    }

    void TalkFrom(Creature* speaker, uint8 group, Milliseconds delay = 0ms)
    {
        if (speaker && speaker->IsAIEnabled)
            speaker->AI()->Talk(group, nullptr, delay);
    }

    // ------------------------------------------------------------------------------------------------------
    // The three battlefront guardians (source lines 3598-4128). The source had three copies of one AI that
    // differed only in these values plus the per-lord extras overridden below.
    // ------------------------------------------------------------------------------------------------------
    struct GuardianProfile
    {
        uint32 SummonMarkerSpell;   // removed from the player on despawn, so the summons can be cast again
        uint32 SelfBuffSpell;
        float FollowAnglePi;        // follow angle in multiples of pi
        float SceneX;
        float SceneY;
        float SceneZ;
        float SceneFacing;
        uint32 CheckIntervalMs;
        Milliseconds DespawnDelay;
    };

    GuardianProfile const GodfreyProfile =
    {
        SPELL_BATTLEFRONT_SUMMON_GODFREY, SPELL_GODFREY_MOLTEN, 0.7f,
        -801.97f, 1342.131f, 33.933037f, 4.09f, 500, 500ms
    };

    GuardianProfile const WaldenProfile =
    {
        SPELL_BATTLEFRONT_SUMMON_WALDEN, SPELL_WALDEN_INNER_FIRE, 1.0f,
        -799.80835f, 1340.446655f, 33.922699f, 3.51f, 500, 0ms
    };

    GuardianProfile const AshburyProfile =
    {
        SPELL_BATTLEFRONT_SUMMON_ASHBURY, SPELL_ASHBURY_FORM, 1.3f,
        -804.96f, 1344.01f, 33.87f, 4.83f, 1000, 0ms
    };

    struct npc_battlefront_guardian_base : public ScriptedAI
    {
        npc_battlefront_guardian_base(Creature* creature, GuardianProfile const& profile)
            : ScriptedAI(creature), _profile(profile), _checkTimer(profile.CheckIntervalMs) { }

        void Reset() override
        {
            _events.Reset();
            // An evade makes the core follow at its own angle; re-issue ours on the next check.
            _isFollowing = false;
        }

        void IsSummonedBy(WorldObject* summoner) override
        {
            DoCastSelf(_profile.SelfBuffSpell, true);
            me->SetReactState(REACT_PASSIVE);

            if (Player* player = summoner ? summoner->ToPlayer() : nullptr)
                _playerGUID = player->GetGUID();
        }

        void SetGUID(ObjectGuid const& guid, int32 id) override
        {
            if (!_playerGUID || guid != _playerGUID)
                return;

            if (id == ACTION_PING_MY_SUMMONS && !_duringScene)
                StartScene();
            else if (id == ACTION_PING_MY_SUMMONS_2 && _duringScene)
                EndScene();
        }

        void MovementInform(uint32 type, uint32 id) override
        {
            if (type == POINT_MOTION_TYPE && id == POINT_BATTLEFRONT_SCENE && _duringScene)
                me->SetFacingTo(_profile.SceneFacing);
        }

        void DamageTaken(Unit* attacker, uint32& /*damage*/, DamageEffectType /*damageType*/,
            SpellSchoolMask /*damageSchoolMask*/) override
        {
            if (!attacker || attacker == me || _despawning)
                return;

            Player* player = GetPlayer();
            if (player && player->GetVictim())
                return;

            // Source: hit back while the owner is not fighting. AC's UpdateVictim makes a REACT_PASSIVE unit stop
            // attacking, so the react state has to change with it.
            me->SetReactState(REACT_AGGRESSIVE);
            AttackStart(attacker);
        }

        void JustEngagedWith(Unit* /*who*/) override
        {
            if (me->GetReactState() == REACT_AGGRESSIVE)
                ScheduleCombatEvents();
        }

        void UpdateAI(uint32 diff) override
        {
            _scheduler.Update(diff);

            if (_checkTimer <= diff)
            {
                // Source: the timer was never re-armed, so this ran on every tick after the first.
                _checkTimer = _profile.CheckIntervalMs;
                if (!CheckOwner())
                    return;
            }
            else
                _checkTimer -= diff;

            if (!UpdateVictim())
                return;

            _events.Update(diff);

            if (me->HasUnitState(UNIT_STATE_CASTING))
                return;

            while (uint32 eventId = _events.ExecuteEvent())
                ExecuteCombatEvent(eventId);

            DoMeleeAttackIfReady();
        }

    protected:
        virtual void ScheduleCombatEvents() = 0;
        virtual void ExecuteCombatEvent(uint32 eventId) = 0;
        virtual void OnSceneStart() { }
        virtual void OnDespawnFromLeash() { }
        virtual void OnOwnerCheck(Player* /*player*/) { }

        Player* GetPlayer() const { return ObjectAccessor::GetPlayer(*me, _playerGUID); }
        bool IsDuringScene() const { return _duringScene; }

        void CastAtVictim(uint32 spellId)
        {
            if (Unit* victim = me->GetVictim())
                DoCast(victim, spellId);
        }

        EventMap _events;
        TaskScheduler _scheduler;

    private:
        // The source's periodic block. Returns false once the guardian is on its way out.
        bool CheckOwner()
        {
            if (_despawning || !_playerGUID)
                return !_despawning;

            Player* player = GetPlayer();
            if (!player)
            {
                _despawning = true;
                me->DespawnOrUnsummon();
                return false;
            }

            // Source: me->GetOwner()->isAlive() unguarded; zone 130 is 4935 on map 751.
            bool const leftZone = !player->IsAlive() || !IsInBattlefrontZone();
            if (leftZone || player->GetQuestStatus(QUEST_ON_HER_MAJESTY) == QUEST_STATUS_REWARDED)
            {
                _despawning = true;
                player->RemoveAurasDueToSpell(_profile.SummonMarkerSpell);
                OnDespawnFromLeash();
                me->DespawnOrUnsummon(leftZone ? _profile.DespawnDelay : 0ms);
                return false;
            }

            if (!me->GetVictim() && me->GetReactState() != REACT_AGGRESSIVE && player->GetVictim()
                && player->IsInCombat())
            {
                me->SetReactState(REACT_AGGRESSIVE);
                AttackStart(player->GetVictim());
            }

            if (me->GetReactState() != REACT_PASSIVE && !player->GetVictim() && !player->IsInCombat()
                && !_duringScene)
            {
                me->SetReactState(REACT_PASSIVE);
                DoCastSelf(SPELL_SANCTUARY_NO_COMBAT, true);
                FollowPlayer(player);
            }

            if (!_isFollowing && !_duringScene)
                FollowPlayer(player);

            OnOwnerCheck(player);
            return true;
        }

        bool IsInBattlefrontZone() const
        {
            uint32 const zone = me->GetZoneId();
            if (zone == SilverpineDC::ZONE_SILVERPINE_751)
                return true;

            return zone == ZONE_RUINS_OF_GILNEAS_751
                && me->IsWithinDist2d(BATTLEFRONT_SCENE_X, BATTLEFRONT_SCENE_Y, BATTLEFRONT_BORDER_RADIUS);
        }

        void FollowPlayer(Player* player)
        {
            me->GetMotionMaster()->MoveFollow(player, GUARDIAN_FOLLOW_DIST, _profile.FollowAnglePi * float(M_PI));
            _isFollowing = true;
        }

        void StartScene()
        {
            _duringScene = true;
            me->GetMotionMaster()->Clear();
            DoCastSelf(SPELL_SANCTUARY_NO_COMBAT, true);
            me->GetMotionMaster()->MovePoint(POINT_BATTLEFRONT_SCENE, _profile.SceneX, _profile.SceneY,
                _profile.SceneZ);
            OnSceneStart();
        }

        void EndScene()
        {
            _duringScene = false;
            if (Player* player = GetPlayer())
                FollowPlayer(player);
        }

        GuardianProfile const& _profile;
        ObjectGuid _playerGUID;
        uint32 _checkTimer;
        bool _duringScene = false;
        bool _isFollowing = false;
        bool _despawning = false;
    };

    // ######################### GODFREY #########################
    struct npc_godfrey_battlefront_guardian : public npc_battlefront_guardian_base
    {
        npc_godfrey_battlefront_guardian(Creature* creature)
            : npc_battlefront_guardian_base(creature, GodfreyProfile) { }

    protected:
        void OnSceneStart() override
        {
            // Source: CastSpell(lorna, SPELL_DUMMY_PING_2).
            if (Creature* lorna = me->FindNearestCreature(NPC_LORNA_MAJESTY_751, 60.0f))
            {
                _lornaGUID = lorna->GetGUID();
                if (lorna->IsAIEnabled)
                    lorna->AI()->SetGUID(me->GetGUID(), ACTION_LORNA_GODFREY_PING);
            }
        }

        void OnDespawnFromLeash() override
        {
            if (!IsDuringScene())
                return;

            if (Creature* lorna = ObjectAccessor::GetCreature(*me, _lornaGUID))
            {
                if (lorna->IsAIEnabled)
                {
                    lorna->AI()->EnterEvadeMode();
                    lorna->AI()->Reset();
                }
            }
        }

        void ScheduleCombatEvents() override
        {
            _events.ScheduleEvent(EVENT_GODFREY_FIREBALL, 0ms, 2s);
            _events.ScheduleEvent(EVENT_GODFREY_BLASTWAVE, 4s, 12s);
            _events.ScheduleEvent(EVENT_GODFREY_FLAMESTRIKE, 8s, 15s);
        }

        void ExecuteCombatEvent(uint32 eventId) override
        {
            switch (eventId)
            {
                case EVENT_GODFREY_FIREBALL:
                    CastAtVictim(SPELL_GODFREY_FIREBALL);
                    _events.ScheduleEvent(EVENT_GODFREY_FIREBALL, 3s, 6s);
                    break;
                case EVENT_GODFREY_BLASTWAVE:
                    CastAtVictim(SPELL_GODFREY_BLASTWAVE);
                    _events.ScheduleEvent(EVENT_GODFREY_BLASTWAVE, 8s, 15s);
                    break;
                case EVENT_GODFREY_FLAMESTRIKE:
                    CastAtVictim(SPELL_GODFREY_FLAMESTRIKE);
                    _events.ScheduleEvent(EVENT_GODFREY_FLAMESTRIKE, 12s, 15s);
                    break;
                default:
                    break;
            }
        }

    private:
        ObjectGuid _lornaGUID;
    };

    // ######################### WALDEN #########################
    struct npc_walden_battlefront_guardian : public npc_battlefront_guardian_base
    {
        npc_walden_battlefront_guardian(Creature* creature)
            : npc_battlefront_guardian_base(creature, WaldenProfile) { }

    protected:
        void ScheduleCombatEvents() override
        {
            _events.ScheduleEvent(EVENT_WALDEN_SMITE, 1s, 3s);
            _events.ScheduleEvent(EVENT_WALDEN_HOLYNOVA, 4s, 15s);
        }

        void ExecuteCombatEvent(uint32 eventId) override
        {
            switch (eventId)
            {
                case EVENT_WALDEN_SMITE:
                    CastAtVictim(SPELL_WALDEN_SMITE);
                    _events.ScheduleEvent(EVENT_WALDEN_SMITE, 3s, 6s);
                    break;
                case EVENT_WALDEN_HOLYNOVA:
                    CastAtVictim(SPELL_WALDEN_HOLYNOVA);
                    _events.ScheduleEvent(EVENT_WALDEN_HOLYNOVA, 8s, 12s);
                    break;
                default:
                    break;
            }
        }

        // Shield the player below 35% health, Penance a second later.
        void OnOwnerCheck(Player* player) override
        {
            if (player->GetHealthPct() <= 35.0f && !_lowHP)
            {
                _lowHP = true;
                _events.Reset();
                DoCast(player, SPELL_WALDEN_SHIELD);

                ObjectGuid const playerGuid = player->GetGUID();
                _scheduler.Schedule(1s, [this, playerGuid](TaskContext /*context*/)
                {
                    if (Player* target = ObjectAccessor::GetPlayer(*me, playerGuid))
                        DoCast(target, SPELL_WALDEN_PENANCE);

                    // Source: the _events.Reset() above left Walden without spells until the next pull.
                    if (me->IsInCombat() && me->GetReactState() == REACT_AGGRESSIVE)
                        ScheduleCombatEvents();
                });
            }
            else if (player->GetHealthPct() >= 36.0f && _lowHP)
                _lowHP = false;
        }

    private:
        bool _lowHP = false;
    };

    // ######################### ASHBURY #########################
    struct npc_ashbury_battlefront_guardian : public npc_battlefront_guardian_base
    {
        npc_ashbury_battlefront_guardian(Creature* creature)
            : npc_battlefront_guardian_base(creature, AshburyProfile) { }

    protected:
        void ScheduleCombatEvents() override
        {
            _events.ScheduleEvent(EVENT_ASHBURY_MINDBLAST, 2s, 6s);
            _events.ScheduleEvent(EVENT_ASHBURY_PAIN, 1s, 12s);
            _events.ScheduleEvent(EVENT_ASHBURY_PSYCHIC, 12s, 18s);
        }

        void ExecuteCombatEvent(uint32 eventId) override
        {
            switch (eventId)
            {
                case EVENT_ASHBURY_MINDBLAST:
                    CastAtVictim(SPELL_ASHBURY_MINDBLAST);
                    _events.ScheduleEvent(EVENT_ASHBURY_MINDBLAST, 3s, 6s);
                    break;
                case EVENT_ASHBURY_PAIN:
                    CastAtVictim(SPELL_ASHBURY_PAIN);
                    _events.ScheduleEvent(EVENT_ASHBURY_PAIN, 30s, 40s);
                    break;
                case EVENT_ASHBURY_PSYCHIC:
                    CastAtVictim(SPELL_ASHBURY_PSYCHIC);
                    _events.ScheduleEvent(EVENT_ASHBURY_PSYCHIC, 15s, 20s);
                    break;
                default:
                    break;
            }
        }
    };

    // ------------------------------------------------------------------------------------------------------
    // Cowering Trooper, quest 27547 "Of No Consequence" (source lines 4130-4250). Spellclick casts 56685 at
    // the trooper. Two times in three he is rescued (credit, flees, despawns); one time in three Godfrey,
    // if he is near, executes him for cowardice and there is no credit.
    // ------------------------------------------------------------------------------------------------------
    struct npc_cowering_trooper : public ScriptedAI
    {
        npc_cowering_trooper(Creature* creature) : ScriptedAI(creature) { }

        void Reset() override
        {
            if (!_clicked)
                me->SetEmoteState(EMOTE_STATE_COWER);
        }

        void JustRespawned() override
        {
            _clicked = false;
            _playerGUID.Clear();
            _events.Reset();
            _scheduler.CancelAll();
            me->SetNpcFlag(UNIT_NPC_FLAG_SPELLCLICK);
            Reset();
        }

        void SpellHit(Unit* caster, SpellInfo const* spellInfo) override
        {
            if (_clicked || !caster || spellInfo->Id != SPELL_DUMMY_SPELLCLICK)
                return;

            Player* player = caster->ToPlayer();
            if (!player)
                return;

            _clicked = true;
            _playerGUID = player->GetGUID();
            // Source removed the flag one update later; removing it now also stops a double click.
            me->RemoveNpcFlag(UNIT_NPC_FLAG_SPELLCLICK);
            _events.ScheduleEvent(urand(1, 3) == 3 ? EVENT_COWERINGTROPPER_2 : EVENT_COWERINGTROPPER_1, 0ms);
        }

        void UpdateAI(uint32 diff) override
        {
            _scheduler.Update(diff);
            _events.Update(diff);

            while (uint32 eventId = _events.ExecuteEvent())
            {
                switch (eventId)
                {
                    case EVENT_COWERINGTROPPER_1:
                        if (Player* player = ObjectAccessor::GetPlayer(*me, _playerGUID))
                        {
                            StopCowering(player);
                            player->KilledMonsterCredit(QuestCreditEntry(QUEST_OF_NO_CONSEQUENCE,
                                NPC_COWERING_TROOPER_751));
                            if (Creature* godfrey = FindGuardianOf(me, _playerGUID, NPC_GODFREY_GUARDIAN, 40.0f))
                                TalkFrom(godfrey, 0, 4s);
                        }
                        RunAwayAndDespawn();
                        break;
                    case EVENT_COWERINGTROPPER_2:
                    {
                        Player* player = ObjectAccessor::GetPlayer(*me, _playerGUID);
                        if (!player)
                        {
                            RunAwayAndDespawn();
                            break;
                        }

                        StopCowering(player);
                        if (FindGuardianOf(me, _playerGUID, NPC_GODFREY_GUARDIAN, 25.0f))
                            _events.ScheduleEvent(EVENT_COWERINGTROPPER_3, 2s);
                        else
                            RunAwayAndDespawn();
                        break;
                    }
                    case EVENT_COWERINGTROPPER_3:
                    {
                        Creature* godfrey = FindGuardianOf(me, _playerGUID, NPC_GODFREY_GUARDIAN, 30.0f);
                        if (!godfrey)
                        {
                            // Source: nothing, the trooper stood there without a spellclick for good.
                            RunAwayAndDespawn();
                            break;
                        }

                        godfrey->SetFacingToObject(me);
                        TalkFrom(godfrey, 1, 500ms);
                        Execute(godfrey->GetGUID());
                        break;
                    }
                    default:
                        break;
                }
            }
        }

    private:
        void StopCowering(Player* player)
        {
            me->SetFacingToObject(player);
            me->ClearEmoteState();
            Talk(0, player, 1s);
        }

        void RunAwayAndDespawn()
        {
            _scheduler.Schedule(3s, [this](TaskContext /*context*/)
            {
                DoCastSelf(SPELL_RUN_RANDOMLY, true);
            });
            me->DespawnOrUnsummon(8s);
        }

        void Execute(ObjectGuid godfreyGuid)
        {
            _scheduler.Schedule(500ms, [this, godfreyGuid](TaskContext context)
            {
                // The trooper is immune to players, and Godfrey is player-controlled.
                me->SetImmuneToAll(false);
                if (Creature* godfrey = ObjectAccessor::GetCreature(*me, godfreyGuid))
                    godfrey->CastSpell(me, SPELL_EXECUTION, true);

                // Execution is an overlay spell; make sure the scene ends with a body either way.
                context.Schedule(1500ms, [this](TaskContext /*context*/)
                {
                    if (me->IsAlive())
                        me->KillSelf();
                });
            });
        }

        EventMap _events;
        TaskScheduler _scheduler;
        ObjectGuid _playerGUID;
        bool _clicked = false;
    };

    // ------------------------------------------------------------------------------------------------------
    // Commander Lorna Crowley, quest 27594 "On Her Majesty's Secret Service" (source lines 4252-4420).
    // A player on the quest with all three guardians close walks up to her; the guardians take their marks,
    // Godfrey and Lorna talk for ~44 s, then she turns hostile and the guardians join the fight.
    // ------------------------------------------------------------------------------------------------------
    struct npc_lorna_majesty : public ScriptedAI
    {
        npc_lorna_majesty(Creature* creature) : ScriptedAI(creature) { }

        void Reset() override
        {
            me->SetImmuneToAll(true);
            _godfreyGUID.Clear();
            _playerGUID.Clear();
            // Source: _activated survived the reset, so after an evade the scene could never start again.
            _activated = false;
            _events.Reset();
            _scheduler.CancelAll();
        }

        void MoveInLineOfSight(Unit* who) override
        {
            if (_activated || !who || !me->IsAlive())
                return;

            Player* player = who->ToPlayer();
            if (!player || !me->IsWithinDistInMap(player, 10.0f))
                return;

            if (player->IsInCombat() || player->GetQuestStatus(QUEST_ON_HER_MAJESTY) != QUEST_STATUS_INCOMPLETE)
                return;

            ObjectGuid const playerGuid = player->GetGUID();
            for (uint32 entry : { NPC_GODFREY_GUARDIAN, NPC_WALDEN_GUARDIAN, NPC_ASHBURY_GUARDIAN })
                if (!FindGuardianOf(player, playerGuid, entry, 15.0f))
                    return;

            _playerGUID = playerGuid;
            _activated = true;
            PingGuardiansOf(player, ACTION_PING_MY_SUMMONS);
            Talk(0);
        }

        void SetGUID(ObjectGuid const& guid, int32 id) override
        {
            if (id == ACTION_LORNA_RESET_PING)
                OnResetPing();
            else if (id == ACTION_LORNA_GODFREY_PING)
                OnGodfreyPing(guid);
        }

        void SpellHit(Unit* caster, SpellInfo const* spellInfo) override
        {
            if (!caster)
                return;

            if (spellInfo->Id == SPELL_DUMMY_PING)
                OnResetPing();
            else if (spellInfo->Id == SPELL_DUMMY_PING_2)
                OnGodfreyPing(caster->GetGUID());
        }

        void JustEngagedWith(Unit* /*who*/) override
        {
            _events.ScheduleEvent(EVENT_LORNA_CHARGE, 0ms);
            _events.ScheduleEvent(EVENT_LORNA_THUNDERCLAP, 4s, 11s);
            _events.ScheduleEvent(EVENT_LORNA_CLEAVE, 2s, 8s);
        }

        void JustDied(Unit* /*killer*/) override
        {
            Talk(4);

            uint32 const credit = QuestCreditEntry(QUEST_ON_HER_MAJESTY, NPC_LORNA_CAPTURE_CREDIT);
            std::vector<Player*> players;
            Acore::AnyPlayerInObjectRangeCheck check(me, LORNA_CREDIT_RANGE);
            Acore::PlayerListSearcher<Acore::AnyPlayerInObjectRangeCheck> searcher(me, players, check);
            Cell::VisitObjects(me, searcher, LORNA_CREDIT_RANGE);
            for (Player* player : players)
                if (player->GetQuestStatus(QUEST_ON_HER_MAJESTY) == QUEST_STATUS_INCOMPLETE)
                    player->KilledMonsterCredit(credit);

            // The source also cast 29266 Permanent Feign Death here, on a corpse, where it cannot land.
            _activated = false;
            _events.Reset();
            _scheduler.CancelAll();

            TalkFrom(ObjectAccessor::GetCreature(*me, _godfreyGUID), 6, 2s);
        }

        void UpdateAI(uint32 diff) override
        {
            _scheduler.Update(diff);

            if (_activated)
            {
                if (_checkTimer <= diff)
                {
                    _checkTimer = 2000;
                    // Source: only a dead player ended the scene; a logged-out one left Lorna stuck.
                    Player* player = ObjectAccessor::GetPlayer(*me, _playerGUID);
                    if (!player || !player->IsAlive())
                    {
                        AbortScene();
                        return;
                    }
                }
                else
                    _checkTimer -= diff;
            }

            _events.Update(diff);

            while (uint32 eventId = _events.ExecuteEvent())
            {
                switch (eventId)
                {
                    case EVENT_LORNA_CHARGE:
                        CastAtVictim(SPELL_LORNA_CHARGE);
                        break;
                    case EVENT_LORNA_THUNDERCLAP:
                        CastAtVictim(SPELL_LORNA_THUNDERCLAP);
                        _events.ScheduleEvent(EVENT_LORNA_THUNDERCLAP, 15s, 28s);
                        break;
                    case EVENT_LORNA_CLEAVE:
                        CastAtVictim(SPELL_LORNA_CLEAVE);
                        _events.ScheduleEvent(EVENT_LORNA_CLEAVE, 20s, 25s);
                        break;
                    case EVENT_MAJESTY_1:
                        PlayMajestyScene();
                        break;
                    case EVENT_MAJESTY_2:
                        ConfrontPlayer();
                        break;
                    default:
                        break;
                }
            }

            if (!UpdateVictim())
                return;

            DoMeleeAttackIfReady();
        }

    private:
        void CastAtVictim(uint32 spellId)
        {
            if (Unit* victim = me->GetVictim())
                DoCast(victim, spellId);
        }

        void OnResetPing()
        {
            if (!_activated)
                return;

            Reset();
            EnterEvadeMode();
            DoCastSelf(SPELL_SANCTUARY_NO_COMBAT, true);
        }

        void OnGodfreyPing(ObjectGuid const& guid)
        {
            if (guid.GetEntry() != NPC_GODFREY_GUARDIAN)
                return;

            _godfreyGUID = guid;
            _events.ScheduleEvent(EVENT_MAJESTY_1, 3500ms);
        }

        void GodfreyTalk(uint8 group)
        {
            TalkFrom(ObjectAccessor::GetCreature(*me, _godfreyGUID), group);
        }

        // Source EVENT_MAJESTY_1: its TalkWithDelay / CastWithDelay chain, timed from this event.
        void PlayMajestyScene()
        {
            if (!ObjectAccessor::GetCreature(*me, _godfreyGUID))
            {
                AbortScene();
                return;
            }

            _scheduler.Schedule(1s, [this](TaskContext /*context*/) { GodfreyTalk(2); });
            _scheduler.Schedule(8s, [this](TaskContext /*context*/) { Talk(1); });
            _scheduler.Schedule(13s, [this](TaskContext /*context*/) { Talk(2); });
            _scheduler.Schedule(19500ms, [this](TaskContext /*context*/) { GodfreyTalk(3); });
            _scheduler.Schedule(24500ms, [this](TaskContext /*context*/) { GodfreyTalk(4); });
            _scheduler.Schedule(34500ms, [this](TaskContext /*context*/) { GodfreyTalk(5); });
            _scheduler.Schedule(40s, [this](TaskContext /*context*/) { Talk(3); });
            _scheduler.Schedule(42s, [this](TaskContext /*context*/)
            {
                DoCastSelf(SPELL_LORNA_COMMANDING_SHOUT, true);
            });
            _events.ScheduleEvent(EVENT_MAJESTY_2, 44s);
        }

        // Source EVENT_MAJESTY_2.
        void ConfrontPlayer()
        {
            Player* player = ObjectAccessor::GetPlayer(*me, _playerGUID);
            if (!player)
            {
                AbortScene();
                return;
            }

            me->SetImmuneToAll(false);
            AttackStart(player);
            PingGuardiansOf(player, ACTION_PING_MY_SUMMONS_2);
        }

        void AbortScene()
        {
            // Release the guardians from their marks, which the source left to the player's death.
            if (Player* player = ObjectAccessor::GetPlayer(*me, _playerGUID))
                PingGuardiansOf(player, ACTION_PING_MY_SUMMONS_2);

            EnterEvadeMode();
            Reset();
            DoCastSelf(SPELL_SANCTUARY_NO_COMBAT, true);
        }

        EventMap _events;
        TaskScheduler _scheduler;
        ObjectGuid _godfreyGUID;
        ObjectGuid _playerGUID;
        uint32 _checkTimer = 2000;
        bool _activated = false;
    };
}

void AddSC_dc_silverpine_battlefront()
{
    RegisterCreatureAI(npc_godfrey_battlefront_guardian);
    RegisterCreatureAI(npc_walden_battlefront_guardian);
    RegisterCreatureAI(npc_ashbury_battlefront_guardian);
    RegisterCreatureAI(npc_cowering_trooper);
    RegisterCreatureAI(npc_lorna_majesty);
}
