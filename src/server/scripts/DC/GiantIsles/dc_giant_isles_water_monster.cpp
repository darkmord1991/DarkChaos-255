#include "ScriptMgr.h"
#include "Player.h"
#include "Creature.h"
#include "GameObject.h"
#include "Group.h"
#include "ScriptedCreature.h"
#include "ScriptedGossip.h"
#include "SpellScript.h"
#include "World.h"
#include "WorldSession.h"
#include "WorldSessionMgr.h"
#include "MoveSplineInit.h"
#include "ObjectMgr.h"
#include "../AddonExtension/dc_addon_namespace.h"
#include <fmt/format.h>

using namespace std::chrono_literals;

enum WaterMonsterData
{
    NPC_GIANT_WATER_MONSTER     = 400350,
    NPC_CORRUPTED_ELEMENTAL     = 400351, // New NPC for adds
    GO_ANCIENT_STONE            = 700015,
    EVENT_ID_WATER_MONSTER      = 100,

    // Spells
    SPELL_THROW_VISUAL          = 51361,
    SPELL_WATER_BOLT_VOLLEY     = 34449, // AoE Frost damage
    SPELL_GEYSER                = 10987, // Knockup
    SPELL_TIDAL_WAVE            = 16455, // Knockback + Damage
    SPELL_ENRAGE                = 50630, // Damage increase
    SPELL_SUBMERGE_VISUAL       = 46355, // Visual for submerging (if applicable) or just hide
    SPELL_SUMMON_ELEMENTALS     = 31687, // Visual or actual summon spell

    // Actions
    ACTION_ELEMENTAL_DIED       = 1
};

static constexpr uint32 DESPAWN_IF_NOT_ATTACKED_MS = 2 * MINUTE * IN_MILLISECONDS;

static Position const GiantWaterMonsterPath[] =
{
    // Map 1405 (Giant Isles) - water path collected via .gps
    { 5637.1016f, 813.9706f,  -1.4170057f, 0.2791047f },
    { 5653.81f,   819.66077f, -1.4170057f, 0.35214677f },
    { 5667.1074f, 824.54706f, -1.4170057f, 0.35214677f },
    { 5678.1885f, 828.61896f, -1.4170057f, 0.35214677f },
    { 5687.053f,  831.87646f, -1.4170057f, 0.35214677f },
    { 5695.9185f, 835.134f,   -1.4170057f, 0.35214677f },
    { 5702.567f,  837.5771f,  -1.4170057f, 0.35214677f },
    { 5711.4316f, 840.83466f, -1.4170057f, 0.35214677f },
    { 5722.5127f, 844.9065f,  -1.4170057f, 0.35214677f },
    { 5731.378f,  848.16406f, -1.4170057f, 0.35214677f },
    { 5740.2427f, 851.4216f,  -1.4170057f, 0.35214677f },
    { 5749.1074f, 854.6791f,  -1.4170057f, 0.35214677f },
    { 5753.54f,   856.30786f, -1.4170057f, 0.35214677f },
    { 5759.9004f, 858.6451f,  -1.4170057f, 0.35214677f },
};

static void SendEventUpdate(uint8 opcode, std::string state, uint8 wave = 1, uint8 maxWaves = 1)
{
    DCAddon::JsonValue data; data.SetObject();
    data.Set("id", DCAddon::JsonValue(static_cast<int32>(EVENT_ID_WATER_MONSTER)));
    data.Set("name", DCAddon::JsonValue("Ancient Terror"));
    data.Set("zone", DCAddon::JsonValue("Giant Isles"));
    data.Set("type", DCAddon::JsonValue("event"));
    data.Set("state", DCAddon::JsonValue(state));
    data.Set("active", DCAddon::JsonValue(state == "active"));

    if (state == "active")
    {
        data.Set("wave", DCAddon::JsonValue(wave));
        data.Set("maxWaves", DCAddon::JsonValue(maxWaves));
        data.Set("timeRemaining", DCAddon::JsonValue(600)); // 10 mins
    }

    DCAddon::JsonMessage msg(DCAddon::Module::EVENTS, opcode, data);

    WorldSessionMgr::SessionMap const& sessions = sWorldSessionMgr->GetAllSessions();
    for (WorldSessionMgr::SessionMap::const_iterator itr = sessions.begin(); itr != sessions.end(); ++itr)
    {
        if (Player* player = itr->second->GetPlayer())
        {
            msg.Send(player);
        }
    }
}

class go_ancient_stone : public GameObjectScript
{
public:
    go_ancient_stone() : GameObjectScript("go_ancient_stone") { }

    bool CanGameObjectGossipHello(Player* /*player*/, GameObject* go)
    {
        return go->GetEntry() == GO_ANCIENT_STONE;
    }

    bool OnGossipHello(Player* player, GameObject* go) override
    {
        LOG_INFO("go_ancient_stone", "OnGossipHello by {}.", player->GetName());

        // Allow GMs to bypass group requirements for testing
        Group* group = player->GetGroup();
        if (!player->IsGameMaster())
        {
            if (!group)
            {
                player->SendSystemMessage("You need a group of 2-5 players to disturb the water.");
                return true;
            }

            uint8 memberCount = group->GetMembersCount();
            if (memberCount < 2 || memberCount > 5)
            {
                player->SendSystemMessage("You need a group of 2-5 players to disturb the water.");
                return true;
            }
        }

        // Check if already spawned (non-GMs are prevented from starting if boss is active)
        if (!player->IsGameMaster() && go->FindNearestCreature(NPC_GIANT_WATER_MONSTER, 200.0f, true))
        {
            player->SendSystemMessage("The ancient terror is already awake!");
            return true;
        }

        AddGossipItemFor(player, GOSSIP_ICON_INTERACT_1, "Throw the stone into the water", GOSSIP_SENDER_MAIN, GOSSIP_ACTION_INFO_DEF + 1);
        SendGossipMenuFor(player, DEFAULT_GOSSIP_MESSAGE, go->GetGUID());
        return true;
    }

    bool OnGossipSelect(Player* player, GameObject* go, uint32 sender, uint32 action) override
    {
        ClearGossipMenuFor(player);

        LOG_INFO("go_ancient_stone", "OnGossipSelect called by {} (sender={}, action={})", player->GetName(), sender, action);

        if (action == GOSSIP_ACTION_INFO_DEF + 1)
        {
            LOG_INFO("go_ancient_stone", "OnGossipSelect by {}, attempting spawn.", player->GetName());

            player->CastSpell(player, SPELL_THROW_VISUAL, true);

            // Intro: a scream is heard, the monster appears after 10 seconds and swims in.
            player->SendSystemMessage("A terrifying scream echoes from the deep...");

            // Preflight template/model checks. Missing models will cause SummonCreature to fail.
            CreatureTemplate const* tpl = sObjectMgr->GetCreatureTemplate(NPC_GIANT_WATER_MONSTER);
            if (!tpl)
            {
                player->SendSystemMessage("Failed to summon Ancient Terror (missing creature_template entry). See server logs.");
                LOG_ERROR("go_ancient_stone", "Missing CreatureTemplate for entry {} (player={}, goEntry={}, map={}).",
                    NPC_GIANT_WATER_MONSTER, player->GetName(), go->GetEntry(), go->GetMapId());
                return true;
            }

            CreatureModel const* chosenModel = ObjectMgr::ChooseDisplayId(tpl, nullptr);
            if (!chosenModel || chosenModel->CreatureDisplayID == 0)
            {
                player->SendSystemMessage("Failed to summon Ancient Terror (no model configured). Check creature_template_model for entry 400350.");
                LOG_ERROR("go_ancient_stone", "CreatureTemplate {} has no valid model (Models.size={} chosenModel={} displayId={}). Player={}.",
                    NPC_GIANT_WATER_MONSTER,
                    tpl->Models.size(),
                    (chosenModel ? "yes" : "no"),
                    (chosenModel ? chosenModel->CreatureDisplayID : 0u),
                    player->GetName());
                return true;
            }

            // Spawn at the start of the water path (boss AI handles the delayed appearance + pathing)
            Position const& start = GiantWaterMonsterPath[0];
            if (Creature* monster = go->SummonCreature(NPC_GIANT_WATER_MONSTER, start.GetPositionX(), start.GetPositionY(), start.GetPositionZ(), start.GetOrientation(), TEMPSUMMON_TIMED_OR_DEAD_DESPAWN, 10 * MINUTE * IN_MILLISECONDS))
            {
                // Hard-enforce the intro state immediately (prevents a 1-tick visible spawn before AI::IsSummonedBy runs)
                monster->AttackStop();
                monster->SetReactState(REACT_PASSIVE);
                monster->SetVisible(false);
                monster->SetFlag(UNIT_FIELD_FLAGS, UNIT_FLAG_NON_ATTACKABLE | UNIT_FLAG_NOT_SELECTABLE);

                uint32 const pathCount = static_cast<uint32>(sizeof(GiantWaterMonsterPath) / sizeof(GiantWaterMonsterPath[0]));
                Position const& last = GiantWaterMonsterPath[pathCount - 1];
                monster->SetHomePosition(last.GetPositionX(), last.GetPositionY(), last.GetPositionZ(), last.GetOrientation());
                SendEventUpdate(DCAddon::Opcode::Events::SMSG_EVENT_SPAWN, "active");
                go->SetGoState(GO_STATE_ACTIVE);
            }
            else
            {
                player->SendSystemMessage("Failed to summon Ancient Terror.");
                LOG_ERROR("go_ancient_stone", "SummonCreature returned null (entry={}, map={}, goEntry={}, player={}, pos=({}, {}, {})).",
                    NPC_GIANT_WATER_MONSTER, go->GetMapId(), go->GetEntry(), player->GetName(),
                    start.GetPositionX(), start.GetPositionY(), start.GetPositionZ());
            }
        }
        else
        {
            // Pre-format message to avoid fmt::format template deduction issues in macro
            std::string warnMsg = fmt::format("go_ancient_stone: Unexpected gossip action {} (sender {}) from {}.", action, sender, player->GetName());
            LOG_WARN("go_ancient_stone", "{}", warnMsg);
        }

        return true;
    }
};

class npc_giant_water_monster : public CreatureScript
{
public:
    npc_giant_water_monster() : CreatureScript("npc_giant_water_monster") { }

    struct npc_giant_water_monsterAI : public ScriptedAI
    {
        npc_giant_water_monsterAI(Creature* creature) : ScriptedAI(creature), summons(creature) { }

        EventMap events;
        SummonList summons;
        bool phaseSubmerged;
        bool enraged;
        bool introInProgress;
        bool introCompleted;
        bool eventSummon;
        bool introMovementLaunched;
        uint32 despawnIfNotAttackedTimer;

        static constexpr uint32 EVENT_INTRO_APPEAR = 1000;

        void ScheduleCombatEvents()
        {
            events.ScheduleEvent(1, 8s);  // Water Bolt Volley
            events.ScheduleEvent(2, 15s); // Geyser
            events.ScheduleEvent(3, 25s); // Tidal Wave
        }

        void StartIntro()
        {
            events.Reset();
            summons.DespawnAll();
            phaseSubmerged = false;
            enraged = false;

            introInProgress = true;
            introCompleted = false;
            introMovementLaunched = false;
            despawnIfNotAttackedTimer = 0;

            me->AttackStop();
            me->SetReactState(REACT_PASSIVE);
            me->SetVisible(false);
            me->SetFlag(UNIT_FIELD_FLAGS, UNIT_FLAG_NON_ATTACKABLE | UNIT_FLAG_NOT_SELECTABLE);

            events.ScheduleEvent(EVENT_INTRO_APPEAR, 10s);
        }

        void FinishIntro()
        {
            introInProgress = false;
            introCompleted = true;

            // Start countdown only once the boss can actually be attacked.
            despawnIfNotAttackedTimer = DESPAWN_IF_NOT_ATTACKED_MS;

            me->RemoveFlag(UNIT_FIELD_FLAGS, UNIT_FLAG_NON_ATTACKABLE | UNIT_FLAG_NOT_SELECTABLE);
            me->SetReactState(REACT_AGGRESSIVE);

            events.Reset();
            ScheduleCombatEvents();
        }

        void Reset() override
        {
            events.Reset();
            summons.DespawnAll();
            phaseSubmerged = false;
            enraged = false;
            // Always initialize state (these are not guaranteed to be zero-initialized)
            introInProgress = false;
            introCompleted = false;
            eventSummon = false;
            introMovementLaunched = false;
            despawnIfNotAttackedTimer = 0;
            // If this boss was summoned by the Ancient Stone and the intro hasn't finished,
            // keep it in the intro state (prevents early attackable + stopping at waypoint).
            if (eventSummon && !introCompleted)
            {
                StartIntro();
                return;
            }

            introInProgress = false;
            me->SetVisible(true);
            me->RemoveFlag(UNIT_FIELD_FLAGS, UNIT_FLAG_NON_ATTACKABLE | UNIT_FLAG_NOT_SELECTABLE);
            me->SetReactState(REACT_AGGRESSIVE);

            ScheduleCombatEvents();
        }

        void IsSummonedBy(WorldObject* summoner) override
        {
            eventSummon = (summoner && summoner->IsGameObject() && summoner->GetEntry() == GO_ANCIENT_STONE);
            StartIntro();
        }

        void JustEngagedWith(Unit* /*who*/) override
        {
            // Cancel the idle despawn once anyone attacks it.
            despawnIfNotAttackedTimer = 0;
        }

        void JustDied(Unit* /*killer*/) override
        {
            summons.DespawnAll();
            SendEventUpdate(DCAddon::Opcode::Events::SMSG_EVENT_REMOVE, "victory");
        }

        void JustDespawned()
        {
            summons.DespawnAll();
            if (me->IsAlive())
            {
                SendEventUpdate(DCAddon::Opcode::Events::SMSG_EVENT_REMOVE, "ended");
            }
        }

        void JustSummoned(Creature* summon) override
        {
            summons.Summon(summon);
            if (summon->GetEntry() == NPC_CORRUPTED_ELEMENTAL)
            {
                summon->AI()->AttackStart(me->GetVictim());
            }
        }

        void SummonedCreatureDespawn(Creature* summon) override
        {
            summons.Despawn(summon);
        }

        void SummonedCreatureDies(Creature* summon, Unit* /*killer*/) override
        {
            if (phaseSubmerged && summon->GetEntry() == NPC_CORRUPTED_ELEMENTAL)
            {
                // Check if all elementals are dead
                bool anyAlive = false;
                for (auto const& guid : summons)
                {
                    if (Creature* c = ObjectAccessor::GetCreature(*me, guid))
                    {
                        if (c->IsAlive() && c->GetEntry() == NPC_CORRUPTED_ELEMENTAL)
                        {
                            anyAlive = true;
                            break;
                        }
                    }
                }

                if (!anyAlive)
                {
                    // End Submerge Phase
                    phaseSubmerged = false;
                    me->SetVisible(true);
                    me->RemoveFlag(UNIT_FIELD_FLAGS, UNIT_FLAG_NON_ATTACKABLE | UNIT_FLAG_NOT_SELECTABLE);
                    me->SetReactState(REACT_AGGRESSIVE);
                    me->Say("I return to crush you!", LANG_UNIVERSAL);

                    // Enrage
                    if (!enraged)
                    {
                        DoCast(me, SPELL_ENRAGE);
                        enraged = true;
                    }

                    // Resume events
                    events.ScheduleEvent(1, 5s);
                    events.ScheduleEvent(2, 10s);
                    events.ScheduleEvent(3, 15s);
                }
            }
        }

        void DamageTaken(Unit* /*attacker*/, uint32& damage, DamageEffectType /*damagetype*/, SpellSchoolMask /*damageSchoolMask*/) override
        {
            (void)damage;
            if (!phaseSubmerged && HealthBelowPct(50) && !enraged)
            {
                // Start Submerge Phase
                phaseSubmerged = true;
                me->SetVisible(false);
                me->SetFlag(UNIT_FIELD_FLAGS, UNIT_FLAG_NON_ATTACKABLE | UNIT_FLAG_NOT_SELECTABLE);
                me->SetReactState(REACT_PASSIVE);
                me->AttackStop();
                me->Say("The depths will consume you!", LANG_UNIVERSAL);

                // Spawn 4 Elementals around
                for (int i = 0; i < 4; ++i)
                {
                    float angle = i * (M_PI / 2.0f);
                    float dist = 10.0f;
                    float x = me->GetPositionX() + dist * cos(angle);
                    float y = me->GetPositionY() + dist * sin(angle);
                    float z = me->GetPositionZ();
                    me->SummonCreature(NPC_CORRUPTED_ELEMENTAL, x, y, z, 0, TEMPSUMMON_TIMED_DESPAWN_OUT_OF_COMBAT, 60000);
                }

                // Cancel main events, schedule submerge events
                events.CancelEvent(1);
                events.CancelEvent(2);
                events.CancelEvent(3);
                events.ScheduleEvent(4, 5s); // Periodic Tidal Wave while submerged
            }
        }

        void UpdateAI(uint32 diff) override
        {
            events.Update(diff);

            if (introInProgress)
            {
                while (uint32 eventId = events.ExecuteEvent())
                {
                    if (eventId == EVENT_INTRO_APPEAR)
                    {
                        // Monster appears (still unattackable) and starts swimming along the full waypoint spline
                        me->SetVisible(true);
                        me->Say("RROOOAAARRR!!!", LANG_UNIVERSAL);

                        Movement::PointsArray path;
                        path.reserve(sizeof(GiantWaterMonsterPath) / sizeof(GiantWaterMonsterPath[0]));
                        for (Position const& p : GiantWaterMonsterPath)
                            path.emplace_back(p.GetPositionX(), p.GetPositionY(), p.GetPositionZ());

                        if (path.size() <= 1)
                            FinishIntro();
                        else
                        {
                            Movement::MoveSplineInit init(me);
                            init.MovebyPath(path);
                            init.SetSmooth();
                            init.Launch();
                            introMovementLaunched = true;
                        }
                    }
                }

                // When the spline finishes, the boss becomes attackable at the end point.
                if (introMovementLaunched && me->movespline->Finalized())
                {
                    uint32 const pathCount = static_cast<uint32>(sizeof(GiantWaterMonsterPath) / sizeof(GiantWaterMonsterPath[0]));
                    Position const& last = GiantWaterMonsterPath[pathCount - 1];
                    me->SetHomePosition(last.GetPositionX(), last.GetPositionY(), last.GetPositionZ(), last.GetOrientation());
                    me->SetFacingTo(last.GetOrientation());
                    FinishIntro();
                }

                return;
            }

            // Despawn after 2 minutes if nobody attacks it (timer starts when it becomes attackable).
            if (despawnIfNotAttackedTimer)
            {
                if (me->IsInCombat())
                {
                    despawnIfNotAttackedTimer = 0;
                }
                else if (despawnIfNotAttackedTimer <= diff)
                {
                    despawnIfNotAttackedTimer = 0;
                    me->DespawnOrUnsummon(1s);
                    return;
                }
                else
                {
                    despawnIfNotAttackedTimer -= diff;
                }
            }

            if (!UpdateVictim() && !phaseSubmerged)
                return;

            if (phaseSubmerged)
            {
                if (events.ExecuteEvent() == 4)
                {
                    // Cast Tidal Wave from hidden boss position (or random player location)
                    if (Unit* target = SelectTarget(SelectTargetMethod::Random, 0, 100.0f, true))
                    {
                        me->CastSpell(target, SPELL_TIDAL_WAVE, true);
                    }
                    events.ScheduleEvent(4, 8s);
                }
                return;
            }

            if (me->HasUnitState(UNIT_STATE_CASTING))
                return;

            while (uint32 eventId = events.ExecuteEvent())
            {
                switch (eventId)
                {
                    case 1: // Water Bolt Volley
                        DoCastAOE(SPELL_WATER_BOLT_VOLLEY);
                        events.ScheduleEvent(1, 12s);
                        break;
                    case 2: // Geyser
                        if (Unit* target = SelectTarget(SelectTargetMethod::Random, 0, 50.0f, true))
                        {
                            DoCast(target, SPELL_GEYSER);
                        }
                        events.ScheduleEvent(2, 20s);
                        break;
                    case 3: // Tidal Wave
                        if (Unit* target = SelectTarget(SelectTargetMethod::Random, 0, 50.0f, true))
                        {
                            DoCast(target, SPELL_TIDAL_WAVE);
                        }
                        events.ScheduleEvent(3, 25s);
                        break;
                }
            }

            DoMeleeAttackIfReady();
        }
    };

    CreatureAI* GetAI(Creature* creature) const override
    {
        return new npc_giant_water_monsterAI(creature);
    }
};

class npc_corrupted_elemental : public CreatureScript
{
public:
    npc_corrupted_elemental() : CreatureScript("npc_corrupted_elemental") { }

    struct npc_corrupted_elementalAI : public ScriptedAI
    {
        npc_corrupted_elementalAI(Creature* creature) : ScriptedAI(creature) { }

        void UpdateAI(uint32 diff) override
        {
            (void)diff;
            if (!UpdateVictim())
                return;

            // Simple melee add, maybe add a frostbolt later
            DoMeleeAttackIfReady();
        }
    };

    CreatureAI* GetAI(Creature* creature) const override
    {
        return new npc_corrupted_elementalAI(creature);
    }
};

void AddSC_dc_giant_isles_water_monster()
{
    new go_ancient_stone();
    new npc_giant_water_monster();
    new npc_corrupted_elemental();
}
