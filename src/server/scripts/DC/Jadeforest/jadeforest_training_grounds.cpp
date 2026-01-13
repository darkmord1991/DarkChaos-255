/*
 * This file is part of the AzerothCore Project. See AUTHORS file for Copyright information
 *
 * This program is free software; you can redistribute it and/or modify it
 * under the terms of the GNU Affero General Public License as published by
 * the Free Software Foundation; either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 * GNU Affero General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License along
 * with this program. If not, see <http://www.gnu.org/licenses/>.
 */

#include "ScriptMgr.h"
#include "ScriptedCreature.h"
#include "ScriptedGossip.h"
#include "Player.h"
#include "MotionMaster.h"
#include "ObjectAccessor.h"
#include "ObjectMgr.h"
#include "Chat.h"
#include "Containers.h"

#include <algorithm>
#include <cmath>
#include <unordered_map>
#include <vector>

namespace
{
    constexpr uint32 SPELL_STUN_PERMANENT = 61204;

    // ---------------------------------------------------------------------
    // Entries (DB)
    // ---------------------------------------------------------------------
    // NOTE: Per request, all Training Grounds NPC entries start at 800028.
    // 800028 is reserved for the boss-display dummy (pads).
    constexpr uint32 NPC_BOSS_DISPLAY_DUMMY   = 800028;
    constexpr uint32 NPC_TRAINING_MASTER     = 800029;
    constexpr uint32 NPC_BOSS_TRAINING_DUMMY = 800030;
    constexpr uint32 NPC_TRAINING_ADD        = 800031;
    constexpr uint32 NPC_TRAINING_TOTEM      = 800032;

    // ---------------------------------------------------------------------
    // Spells (stock WotLK IDs; feel free to replace in DB/patches)
    // ---------------------------------------------------------------------
    constexpr uint32 SPELL_CLEAVE             = 15284; // creature cleave
    constexpr uint32 SPELL_SUNDER_ARMOR       = 25225; // stacking debuff
    constexpr uint32 SPELL_DEATH_AND_DECAY    = 43265; // ground AoE (DK)
    constexpr uint32 SPELL_SHADOW_BOLT        = 695;   // small penalty

    // ---------------------------------------------------------------------
    // Mechanics
    // ---------------------------------------------------------------------
    enum class TrainingProfile : uint8
    {
        None = 0,
        Cleave = 1,
        VoidZone = 2,
        StackingDebuff = 3,
        AddBeforeTotem = 4,
        MixedRandom = 5,
    };

    enum class ArmorMode : uint8
    {
        Normal = 0,
        Low = 1,
        Bossy = 2,
    };

    struct TrainingConfig
    {
        TrainingProfile profile = TrainingProfile::MixedRandom;
        ArmorMode armor = ArmorMode::Normal;
        bool moving = false;
        uint8 multiTargetCount = 1; // 1/2/3/5
        bool levelMatchPlayer = true;
        uint8 fixedLevel = 80;
        bool randomBossVisual = true;
    };

    struct TrainingSession
    {
        std::vector<ObjectGuid> spawned;
    };

    static std::unordered_map<ObjectGuid, TrainingConfig> s_configByPlayer;
    static std::unordered_map<ObjectGuid, TrainingSession> s_sessionByPlayer;

    // Small fallback set in case the boss-display pool wasn't loaded (e.g., SQL missing).
    // These are creature template entries, from which we take a valid display id.
    static constexpr uint32 BossVisualFallbackEntries[] =
    {
        10184, // Onyxia
        15990, // Kel'Thuzad
        28859, // Malygos
        31125, // Archavon
        33113, // Flame Leviathan
        33271, // General Vezax
    };

    uint32 TryGetBossDisplayId(uint32 bossEntry)
    {
        if (CreatureTemplate const* tmpl = sObjectMgr->GetCreatureTemplate(bossEntry))
        {
            if (tmpl->Modelid1)
                return tmpl->Modelid1;
            if (tmpl->Modelid2)
                return tmpl->Modelid2;
            if (tmpl->Modelid3)
                return tmpl->Modelid3;
            if (tmpl->Modelid4)
                return tmpl->Modelid4;
        }

        return 0;
    }

    std::vector<uint32> BuildBossDisplayIdPoolFromAllBossTemplates()
    {
        std::vector<uint32> displayIds;

        CreatureTemplateContainer const* ctc = sObjectMgr->GetCreatureTemplates();
        if (!ctc)
            return displayIds;

        // Rough reservation; we'll de-dup at the end.
        displayIds.reserve(4096);

        for (auto const& kv : *ctc)
        {
            CreatureTemplate const& ct = kv.second;

            // Avoid our own custom entries.
            if (ct.Entry >= NPC_BOSS_DISPLAY_DUMMY && ct.Entry <= NPC_TRAINING_TOTEM)
                continue;

            // Heuristic: include bosses/elites.
            if (ct.rank != 2 && ct.rank != 3)
                continue;

            for (CreatureModel const& model : ct.Models)
            {
                uint32 displayId = model.CreatureDisplayID;
                if (!displayId)
                    continue;

                if (CreatureModelInfo const* modelInfo = sObjectMgr->GetCreatureModelInfo(displayId))
                {
                    if (modelInfo->is_trigger)
                        continue;
                }

                displayIds.push_back(displayId);
            }
        }

        // Best-effort de-dup
        std::sort(displayIds.begin(), displayIds.end());
        displayIds.erase(std::unique(displayIds.begin(), displayIds.end()), displayIds.end());
        return displayIds;
    }

    std::vector<uint32> const& GetBossDisplayIdPool()
    {
        static std::vector<uint32> s_pool;
        static bool s_built = false;

        if (!s_built)
        {
            s_built = true;
            s_pool = BuildBossDisplayIdPoolFromAllBossTemplates();
        }

        return s_pool;
    }

    uint32 TryPickBossDisplayIdFallback()
    {
        std::vector<uint32> candidates;
        candidates.reserve(sizeof(BossVisualFallbackEntries) / sizeof(BossVisualFallbackEntries[0]));

        for (uint32 bossEntry : BossVisualFallbackEntries)
        {
            if (CreatureTemplate const* tmpl = sObjectMgr->GetCreatureTemplate(bossEntry))
            {
                if (tmpl->Modelid1)
                    candidates.push_back(tmpl->Modelid1);
                if (tmpl->Modelid2)
                    candidates.push_back(tmpl->Modelid2);
                if (tmpl->Modelid3)
                    candidates.push_back(tmpl->Modelid3);
                if (tmpl->Modelid4)
                    candidates.push_back(tmpl->Modelid4);
            }
        }

        if (candidates.empty())
            return 0;

        return candidates[urand(0, uint32(candidates.size() - 1))];
    }

    uint32 TryPickBossDisplayId()
    {
        std::vector<uint32> const& pool = GetBossDisplayIdPool();
        if (!pool.empty())
            return pool[urand(0, uint32(pool.size() - 1))];

        return TryPickBossDisplayIdFallback();
    }

    float GetArmorMultiplier(ArmorMode mode)
    {
        switch (mode)
        {
            case ArmorMode::Low:
                return 0.35f;
            case ArmorMode::Bossy:
                return 2.25f;
            case ArmorMode::Normal:
            default:
                return 1.0f;
        }
    }

    uint8 ClampLevel(uint32 level)
    {
        if (level < 1)
            return 1;
        if (level > 255)
            return 255;
        return uint8(level);
    }

    TrainingConfig& GetOrCreateConfig(Player* player)
    {
        auto it = s_configByPlayer.find(player->GetGUID());
        if (it == s_configByPlayer.end())
            it = s_configByPlayer.emplace(player->GetGUID(), TrainingConfig{}).first;
        return it->second;
    }

    void DespawnSession(Player* player)
    {
        auto it = s_sessionByPlayer.find(player->GetGUID());
        if (it == s_sessionByPlayer.end())
            return;

        for (ObjectGuid guid : it->second.spawned)
        {
            if (Creature* c = ObjectAccessor::GetCreature(*player, guid))
                c->DespawnOrUnsummon(1);
        }

        it->second.spawned.clear();
    }

    void TrackSpawn(Player* player, Creature* creature)
    {
        s_sessionByPlayer[player->GetGUID()].spawned.push_back(creature->GetGUID());
    }

    void ApplyBossDummyConfig(Creature* me, Player* owner, TrainingConfig const& cfg)
    {
        // Cosmetic level toggle (we don't rebuild creature base stats here, since dummies are invulnerable).
        uint8 level = cfg.levelMatchPlayer ? ClampLevel(owner->GetLevel()) : ClampLevel(cfg.fixedLevel);
        me->SetLevel(level);

        // Armor/resist modifiers.
        float baseArmor = me->GetFlatModifierValue(UNIT_MOD_ARMOR, BASE_VALUE);
        float mult = GetArmorMultiplier(cfg.armor);
        me->SetStatFlatModifier(UNIT_MOD_ARMOR, BASE_VALUE, std::max(1.0f, baseArmor * mult));

        // Keep resists modest, but allow "bossy" to feel tankier in PvE parses.
        if (cfg.armor == ArmorMode::Bossy)
        {
            me->SetStatFlatModifier(UNIT_MOD_RESISTANCE_SHADOW, BASE_VALUE, 75.0f);
            me->SetStatFlatModifier(UNIT_MOD_RESISTANCE_FIRE, BASE_VALUE, 75.0f);
            me->SetStatFlatModifier(UNIT_MOD_RESISTANCE_FROST, BASE_VALUE, 75.0f);
        }
        else
        {
            me->SetStatFlatModifier(UNIT_MOD_RESISTANCE_SHADOW, BASE_VALUE, 0.0f);
            me->SetStatFlatModifier(UNIT_MOD_RESISTANCE_FIRE, BASE_VALUE, 0.0f);
            me->SetStatFlatModifier(UNIT_MOD_RESISTANCE_FROST, BASE_VALUE, 0.0f);
        }

        me->UpdateAllStats();

        // Visual: optionally copy a boss model.
        if (cfg.randomBossVisual)
        {
            if (uint32 displayId = TryPickBossDisplayId())
                me->SetDisplayId(displayId);
        }

        // Passive dummy behavior baseline.
        me->SetReactState(REACT_PASSIVE);
        me->SetCombatMovement(false);
    }

    TrainingProfile ResolveProfile(TrainingProfile configured)
    {
        if (configured != TrainingProfile::MixedRandom)
            return configured;

        // Randomly pick 2 mechanics and run them together.
        // We implement this as: pick one of the core types, with a chance to enable the add mechanic.
        uint32 roll = urand(1, 100);
        if (roll <= 25)
            return TrainingProfile::Cleave;
        if (roll <= 50)
            return TrainingProfile::VoidZone;
        if (roll <= 75)
            return TrainingProfile::StackingDebuff;
        return TrainingProfile::AddBeforeTotem;
    }

    // ---------------------------------------------------------------------
    // Gossip actions
    // ---------------------------------------------------------------------
    enum GossipAction : uint32
    {
        ACTION_SPAWN = 100,
        ACTION_DESPAWN = 101,

        ACTION_PROFILE_NONE = 200,
        ACTION_PROFILE_CLEAVE = 201,
        ACTION_PROFILE_VOID = 202,
        ACTION_PROFILE_STACK = 203,
        ACTION_PROFILE_ADD = 204,
        ACTION_PROFILE_MIXED = 205,

        ACTION_ARMOR_NORMAL = 300,
        ACTION_ARMOR_LOW = 301,
        ACTION_ARMOR_BOSSY = 302,

        ACTION_MOVE_TOGGLE = 400,

        ACTION_MULTI_1 = 500,
        ACTION_MULTI_2 = 501,
        ACTION_MULTI_3 = 502,
        ACTION_MULTI_5 = 503,

        ACTION_LEVEL_MATCH = 600,
        ACTION_LEVEL_80 = 601,
        ACTION_LEVEL_255 = 602,

        ACTION_VISUAL_TOGGLE = 700,
    };

    void BuildMainMenu(Player* player, Creature* creature)
    {
        TrainingConfig const& cfg = GetOrCreateConfig(player);

        AddGossipItemFor(player, GOSSIP_ICON_BATTLE, "Spawn boss-training dummy", GOSSIP_SENDER_MAIN, ACTION_SPAWN);
        AddGossipItemFor(player, GOSSIP_ICON_CHAT, "Despawn my training dummies", GOSSIP_SENDER_MAIN, ACTION_DESPAWN);

        AddGossipItemFor(player, GOSSIP_ICON_TRAINER, "Profile: None", GOSSIP_SENDER_MAIN, ACTION_PROFILE_NONE);
        AddGossipItemFor(player, GOSSIP_ICON_TRAINER, "Profile: Frontal cleave", GOSSIP_SENDER_MAIN, ACTION_PROFILE_CLEAVE);
        AddGossipItemFor(player, GOSSIP_ICON_TRAINER, "Profile: Targeted void zones", GOSSIP_SENDER_MAIN, ACTION_PROFILE_VOID);
        AddGossipItemFor(player, GOSSIP_ICON_TRAINER, "Profile: Stacking debuff", GOSSIP_SENDER_MAIN, ACTION_PROFILE_STACK);
        AddGossipItemFor(player, GOSSIP_ICON_TRAINER, "Profile: Kill add before totem", GOSSIP_SENDER_MAIN, ACTION_PROFILE_ADD);
        AddGossipItemFor(player, GOSSIP_ICON_TRAINER, "Profile: Mixed (random)", GOSSIP_SENDER_MAIN, ACTION_PROFILE_MIXED);

        AddGossipItemFor(player, GOSSIP_ICON_INTERACT_1, "Armor: Normal", GOSSIP_SENDER_MAIN, ACTION_ARMOR_NORMAL);
        AddGossipItemFor(player, GOSSIP_ICON_INTERACT_1, "Armor: Low", GOSSIP_SENDER_MAIN, ACTION_ARMOR_LOW);
        AddGossipItemFor(player, GOSSIP_ICON_INTERACT_1, "Armor: Bossy", GOSSIP_SENDER_MAIN, ACTION_ARMOR_BOSSY);

        AddGossipItemFor(player, GOSSIP_ICON_CHAT, cfg.moving ? "Movement: Moving (toggle)" : "Movement: Stationary (toggle)", GOSSIP_SENDER_MAIN, ACTION_MOVE_TOGGLE);

        AddGossipItemFor(player, GOSSIP_ICON_VENDOR, "Targets: 1", GOSSIP_SENDER_MAIN, ACTION_MULTI_1);
        AddGossipItemFor(player, GOSSIP_ICON_VENDOR, "Targets: 2", GOSSIP_SENDER_MAIN, ACTION_MULTI_2);
        AddGossipItemFor(player, GOSSIP_ICON_VENDOR, "Targets: 3", GOSSIP_SENDER_MAIN, ACTION_MULTI_3);
        AddGossipItemFor(player, GOSSIP_ICON_VENDOR, "Targets: 5", GOSSIP_SENDER_MAIN, ACTION_MULTI_5);

        AddGossipItemFor(player, GOSSIP_ICON_CHAT, "Level: Match player", GOSSIP_SENDER_MAIN, ACTION_LEVEL_MATCH);
        AddGossipItemFor(player, GOSSIP_ICON_CHAT, "Level: 80", GOSSIP_SENDER_MAIN, ACTION_LEVEL_80);
        AddGossipItemFor(player, GOSSIP_ICON_CHAT, "Level: 255", GOSSIP_SENDER_MAIN, ACTION_LEVEL_255);

        AddGossipItemFor(player, GOSSIP_ICON_CHAT, cfg.randomBossVisual ? "Visual: Random boss (toggle)" : "Visual: Dummy model (toggle)", GOSSIP_SENDER_MAIN, ACTION_VISUAL_TOGGLE);

        SendGossipMenuFor(player, player->GetGossipTextId(creature), creature->GetGUID());
    }

    Position RandomPosAround(Position const& center, float radius)
    {
        static constexpr float TwoPi = 6.28318530718f;
        float angle = frand(0.0f, TwoPi);
        float dist = frand(2.0f, radius);
        Position p;
        p.m_positionX = center.m_positionX + std::cos(angle) * dist;
        p.m_positionY = center.m_positionY + std::sin(angle) * dist;
        p.m_positionZ = center.m_positionZ;
        p.m_orientation = center.m_orientation;
        return p;
    }

    // Fixed boss-dummy pads (user provided)
    struct PadCoord
    {
        float x;
        float y;
        float z;
        float o;
    };

    static constexpr PadCoord BossPadCoords[3] =
    {
        {1262.8073f, -2434.2676f, 143.60002f, 5.3048515f},
        {1302.2822f, -2493.2632f, 143.59904f, 2.7208662f},
        {1263.06f,   -2525.243f,  143.59987f, 1.3307040f},
    };

    static ObjectGuid s_bossPadGuids[3];

    void DespawnBossPadDummies(Player* player)
    {
        for (ObjectGuid& guid : s_bossPadGuids)
        {
            if (!guid.IsEmpty())
            {
                if (Creature* c = ObjectAccessor::GetCreature(*player, guid))
                    c->DespawnOrUnsummon(1);
                guid.Clear();
            }
        }
    }

    void EnsureBossPadDummies(Player* player)
    {
        if (!player || player->GetMapId() != 745)
            return;

        // If all three exist, do nothing.
        bool allPresent = true;
        for (ObjectGuid const& guid : s_bossPadGuids)
        {
            if (guid.IsEmpty() || !ObjectAccessor::GetCreature(*player, guid))
            {
                allPresent = false;
                break;
            }
        }

        if (allPresent)
            return;

        DespawnBossPadDummies(player);

        std::vector<uint32> displayPool = GetBossDisplayIdPool();
        if (displayPool.size() < 3)
            return;

        Acore::Containers::RandomShuffle(displayPool);

        // Spawn 3 distinct entries on the 3 fixed pads.
        for (uint8 i = 0; i < 3; ++i)
        {
            uint32 displayId = displayPool[i];
            Position pos;
            pos.m_positionX = BossPadCoords[i].x;
            pos.m_positionY = BossPadCoords[i].y;
            pos.m_positionZ = BossPadCoords[i].z;
            pos.m_orientation = BossPadCoords[i].o;

            if (Creature* dummy = player->SummonCreature(NPC_BOSS_DISPLAY_DUMMY, pos, TEMPSUMMON_MANUAL_DESPAWN, 0))
            {
                dummy->SetDisplayId(displayId);
                s_bossPadGuids[i] = dummy->GetGUID();
            }
        }
    }
}

// -------------------------------------------------------------------------
// Training Add (killable runner)
// -------------------------------------------------------------------------
class jadeforest_training_add : public CreatureScript
{
public:
    jadeforest_training_add() : CreatureScript("jadeforest_training_add") { }

    struct jadeforest_training_addAI : public ScriptedAI
    {
        jadeforest_training_addAI(Creature* creature) : ScriptedAI(creature) { }

        ObjectGuid totemGuid;
        ObjectGuid playerGuid;
        uint32 checkTimer = 250;

        void SetGUID(ObjectGuid guid, int32 id = 0) override
        {
            if (id == 1)
                totemGuid = guid;
            else if (id == 2)
                playerGuid = guid;
        }

        void Reset() override
        {
            me->SetReactState(REACT_AGGRESSIVE);
        }

        void UpdateAI(uint32 diff) override
        {
            if (checkTimer <= diff)
            {
                checkTimer = 250;

                if (!totemGuid.IsEmpty())
                {
                    if (Creature* totem = ObjectAccessor::GetCreature(*me, totemGuid))
                    {
                        if (me->GetDistance(totem) <= 1.5f)
                        {
                            // Notify the player and apply a small penalty.
                            if (Player* player = ObjectAccessor::FindPlayer(playerGuid))
                            {
                                ChatHandler(player->GetSession()).PSendSysMessage("Training failed: add reached the totem!");
                                me->CastSpell(player, SPELL_SHADOW_BOLT, true);
                            }

                            me->DespawnOrUnsummon(1);
                            return;
                        }
                    }
                }
            }
            else
                checkTimer -= diff;

            DoMeleeAttackIfReady();
        }
    };

    CreatureAI* GetAI(Creature* creature) const override
    {
        return new jadeforest_training_addAI(creature);
    }
};

// -------------------------------------------------------------------------
// Boss Training Dummy (invulnerable, mechanic emitter)
// -------------------------------------------------------------------------
class jadeforest_boss_training_dummy : public CreatureScript
{
public:
    jadeforest_boss_training_dummy() : CreatureScript("jadeforest_boss_training_dummy") { }

    struct jadeforest_boss_training_dummyAI : public ScriptedAI
    {
        jadeforest_boss_training_dummyAI(Creature* creature) : ScriptedAI(creature)
        {
            me->ApplySpellImmune(0, IMMUNITY_EFFECT, SPELL_EFFECT_KNOCK_BACK, true);
        }

        uint32 cleaveTimer = 7000;
        uint32 voidZoneTimer = 12000;
        uint32 stackTimer = 6000;
        uint32 moveTimer = 3500;
        uint32 addSpawnTimer = 15000;
        ObjectGuid totemGuid;
        TrainingProfile resolvedProfile = TrainingProfile::None;

        TrainingConfig GetConfigSafe(Player* owner)
        {
            auto it = s_configByPlayer.find(owner->GetGUID());
            if (it == s_configByPlayer.end())
                return TrainingConfig{};
            return it->second;
        }

        void Reset() override
        {
            cleaveTimer = 7000;
            voidZoneTimer = 12000;
            stackTimer = 6000;
            moveTimer = 3500;
            addSpawnTimer = 15000;

            totemGuid.Clear();

            ObjectGuid summonerGuid;
            if (TempSummon* ts = me->ToTempSummon())
                summonerGuid = ts->GetSummonerGUID();
            else
                summonerGuid = me->GetOwnerGUID();

            if (Player* owner = ObjectAccessor::FindPlayer(summonerGuid))
            {
                TrainingConfig cfg = GetConfigSafe(owner);
                ApplyBossDummyConfig(me, owner, cfg);
                resolvedProfile = ResolveProfile(cfg.profile);

                if (resolvedProfile == TrainingProfile::AddBeforeTotem)
                {
                    Position p = me->GetPosition();
                    p.m_positionZ += 0.25f;
                    if (Creature* totem = me->SummonCreature(NPC_TRAINING_TOTEM, p, TEMPSUMMON_TIMED_DESPAWN, 300000))
                    {
                        totem->SetReactState(REACT_PASSIVE);
                        totem->SetUnitFlag(UNIT_FLAG_NON_ATTACKABLE);
                        totem->SetUnitFlag(UNIT_FLAG_NOT_SELECTABLE);
                        totemGuid = totem->GetGUID();
                    }
                }
            }
        }

        void EnterEvadeMode(EvadeReason why) override
        {
            if (!_EnterEvadeMode(why))
                return;

            // Keep spawned dummy alive, but reset mechanics.
            Reset();
        }

        void DamageTaken(Unit*, uint32& damage, DamageEffectType, SpellSchoolMask) override
        {
            damage = 0;
        }

        void UpdateAI(uint32 diff) override
        {
            if (!UpdateVictim())
                return;

            ObjectGuid summonerGuid;
            if (TempSummon* ts = me->ToTempSummon())
                summonerGuid = ts->GetSummonerGUID();
            else
                summonerGuid = me->GetOwnerGUID();

            Player* owner = ObjectAccessor::FindPlayer(summonerGuid);
            if (!owner)
                return;

            TrainingConfig cfg = GetConfigSafe(owner);

            // Optional movement: orbit/relocate around the victim.
            if (cfg.moving)
            {
                if (moveTimer <= diff)
                {
                    moveTimer = 3500;

                    if (Unit* victim = me->GetVictim())
                    {
                        Position vp = victim->GetPosition();
                        Position rp = RandomPosAround(vp, 8.0f);
                        me->GetMotionMaster()->MovePoint(1, rp);
                    }
                }
                else
                    moveTimer -= diff;
            }

            Unit* victim = me->GetVictim();
            if (!victim)
                return;

            // Profile mechanics.
            if (resolvedProfile == TrainingProfile::Cleave)
            {
                if (cleaveTimer <= diff)
                {
                    cleaveTimer = 7000;
                    static constexpr float CleaveArc = 1.256637061f; // ~ PI / 2.5
                    if (me->IsWithinMeleeRange(victim) && me->HasInArc(CleaveArc, victim))
                        DoCastVictim(SPELL_CLEAVE, true);
                }
                else
                    cleaveTimer -= diff;
            }

            if (resolvedProfile == TrainingProfile::VoidZone)
            {
                if (voidZoneTimer <= diff)
                {
                    voidZoneTimer = 12000;
                    me->CastSpell(victim, SPELL_DEATH_AND_DECAY, true);
                }
                else
                    voidZoneTimer -= diff;
            }

            if (resolvedProfile == TrainingProfile::StackingDebuff)
            {
                if (stackTimer <= diff)
                {
                    stackTimer = 6000;
                    DoCast(victim, SPELL_SUNDER_ARMOR, true);
                }
                else
                    stackTimer -= diff;
            }

            if (resolvedProfile == TrainingProfile::AddBeforeTotem)
            {
                if (addSpawnTimer <= diff)
                {
                    addSpawnTimer = 15000;

                    if (!totemGuid.IsEmpty())
                    {
                        if (Creature* totem = ObjectAccessor::GetCreature(*me, totemGuid))
                        {
                            Position spawn = RandomPosAround(totem->GetPosition(), 18.0f);
                            if (Creature* add = me->SummonCreature(NPC_TRAINING_ADD, spawn, TEMPSUMMON_TIMED_DESPAWN, 60000))
                            {
                                add->SetReactState(REACT_AGGRESSIVE);
                                add->GetMotionMaster()->MovePoint(1, totem->GetPosition());

                                // Pass totem GUID to the add AI for reach-check.
                                if (CreatureAI* ai = add->AI())
                                {
                                    ai->SetGUID(totemGuid, 1);
                                    ai->SetGUID(owner->GetGUID(), 2);
                                }
                            }
                        }
                    }
                }
                else
                    addSpawnTimer -= diff;
            }

            // Keep dummy responsive.
            DoMeleeAttackIfReady();
        }

        void MoveInLineOfSight(Unit* /*who*/) override { }
    };

    CreatureAI* GetAI(Creature* creature) const override
    {
        return new jadeforest_boss_training_dummyAI(creature);
    }
};

// -------------------------------------------------------------------------
// Boss Display Dummy (800028+) - invulnerable training dummy with fixed boss model
// -------------------------------------------------------------------------
class jadeforest_boss_display_dummy : public CreatureScript
{
public:
    jadeforest_boss_display_dummy() : CreatureScript("jadeforest_boss_display_dummy") { }

    struct jadeforest_boss_display_dummyAI : ScriptedAI
    {
        jadeforest_boss_display_dummyAI(Creature* creature) : ScriptedAI(creature)
        {
            me->SetCombatMovement(false);
            me->ApplySpellImmune(0, IMMUNITY_EFFECT, SPELL_EFFECT_KNOCK_BACK, true);
        }

        uint32 resetTimer = 5000;

        void Reset() override
        {
            me->CastSpell(me, SPELL_STUN_PERMANENT, true);
            resetTimer = 5000;

            // If this creature was spawned without a chosen display, pick one from the pool.
            if (me->GetDisplayId() == me->GetNativeDisplayId())
            {
                if (uint32 displayId = TryPickBossDisplayId())
                    me->SetDisplayId(displayId);
            }
        }

        void EnterEvadeMode(EvadeReason why) override
        {
            if (!_EnterEvadeMode(why))
                return;

            Reset();
        }

        void DamageTaken(Unit*, uint32& damage, DamageEffectType, SpellSchoolMask) override
        {
            resetTimer = 5000;
            damage = 0;
        }

        void UpdateAI(uint32 diff) override
        {
            if (!UpdateVictim())
                return;

            if (resetTimer <= diff)
            {
                EnterEvadeMode(EVADE_REASON_NO_HOSTILES);
                resetTimer = 5000;
            }
            else
                resetTimer -= diff;
        }

        void MoveInLineOfSight(Unit* /*who*/) override { }
    };

    CreatureAI* GetAI(Creature* creature) const override
    {
        return new jadeforest_boss_display_dummyAI(creature);
    }
};

// -------------------------------------------------------------------------
// Training Master (gossip spawner)
// -------------------------------------------------------------------------
class jadeforest_training_master : public CreatureScript
{
public:
    jadeforest_training_master() : CreatureScript("jadeforest_training_master") { }

    bool OnGossipHello(Player* player, Creature* creature) override
    {
        ClearGossipMenuFor(player);
        BuildMainMenu(player, creature);
        return true;
    }

    bool OnGossipSelect(Player* player, Creature* creature, uint32 /*sender*/, uint32 action) override
    {
        ClearGossipMenuFor(player);

        TrainingConfig& cfg = GetOrCreateConfig(player);

        switch (action)
        {
            case ACTION_SPAWN:
            {
                DespawnSession(player);

                uint8 count = cfg.multiTargetCount;
                Position center = creature->GetPosition();

                for (uint8 i = 0; i < count; ++i)
                {
                    Position pos = RandomPosAround(center, 8.0f);
                    if (Creature* dummy = player->SummonCreature(NPC_BOSS_TRAINING_DUMMY, pos, TEMPSUMMON_TIMED_DESPAWN_OUT_OF_COMBAT, 300000))
                    {
                        TrackSpawn(player, dummy);
                    }
                }

                ChatHandler(player->GetSession()).PSendSysMessage("Spawned %u training dummy(ies).", count);
                break;
            }

            case ACTION_DESPAWN:
                DespawnSession(player);
                ChatHandler(player->GetSession()).PSendSysMessage("Despawned your training dummies.");
                break;

            case ACTION_PROFILE_NONE: cfg.profile = TrainingProfile::None; break;
            case ACTION_PROFILE_CLEAVE: cfg.profile = TrainingProfile::Cleave; break;
            case ACTION_PROFILE_VOID: cfg.profile = TrainingProfile::VoidZone; break;
            case ACTION_PROFILE_STACK: cfg.profile = TrainingProfile::StackingDebuff; break;
            case ACTION_PROFILE_ADD: cfg.profile = TrainingProfile::AddBeforeTotem; break;
            case ACTION_PROFILE_MIXED: cfg.profile = TrainingProfile::MixedRandom; break;

            case ACTION_ARMOR_NORMAL: cfg.armor = ArmorMode::Normal; break;
            case ACTION_ARMOR_LOW: cfg.armor = ArmorMode::Low; break;
            case ACTION_ARMOR_BOSSY: cfg.armor = ArmorMode::Bossy; break;

            case ACTION_MOVE_TOGGLE: cfg.moving = !cfg.moving; break;

            case ACTION_MULTI_1: cfg.multiTargetCount = 1; break;
            case ACTION_MULTI_2: cfg.multiTargetCount = 2; break;
            case ACTION_MULTI_3: cfg.multiTargetCount = 3; break;
            case ACTION_MULTI_5: cfg.multiTargetCount = 5; break;

            case ACTION_LEVEL_MATCH:
                cfg.levelMatchPlayer = true;
                break;
            case ACTION_LEVEL_80:
                cfg.levelMatchPlayer = false;
                cfg.fixedLevel = 80;
                break;
            case ACTION_LEVEL_255:
                cfg.levelMatchPlayer = false;
                cfg.fixedLevel = 255;
                break;

            case ACTION_VISUAL_TOGGLE:
                cfg.randomBossVisual = !cfg.randomBossVisual;
                break;

            default:
                break;
        }

        BuildMainMenu(player, creature);
        return true;
    }
};

// -------------------------------------------------------------------------
// Cleanup on logout / map change
// -------------------------------------------------------------------------
class jadeforest_training_ground_player_cleanup : public PlayerScript
{
public:
    jadeforest_training_ground_player_cleanup() : PlayerScript("jadeforest_training_ground_player_cleanup") { }

    void OnLogin(Player* player) override
    {
        EnsureBossPadDummies(player);
    }

    void OnLogout(Player* player) override
    {
        DespawnSession(player);
        s_sessionByPlayer.erase(player->GetGUID());
        s_configByPlayer.erase(player->GetGUID());
    }

    void OnMapChanged(Player* player) override
    {
        // Avoid leaving training summons behind when teleporting away.
        DespawnSession(player);

        // Ensure random boss-display dummies exist when entering the training map.
        EnsureBossPadDummies(player);
    }
};

void AddSC_jadeforest_training_grounds()
{
    new jadeforest_training_master();
    new jadeforest_boss_training_dummy();
    new jadeforest_training_add();
    new jadeforest_boss_display_dummy();
    new jadeforest_training_ground_player_cleanup();
}
