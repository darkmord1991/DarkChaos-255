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
#include "DatabaseEnv.h"
#include "StringFormat.h"

#include <array>
#include <algorithm>
#include <cmath>
#include <limits>
#include <unordered_map>
#include <unordered_set>
#include <vector>

namespace
{
    constexpr uint32 SPELL_STUN_PERMANENT = 61204;

    // ---------------------------------------------------------------------
    // Entries (DB)
    // ---------------------------------------------------------------------
    // NOTE: Per request, all Training Grounds NPC entries start at 800028.
    // Boss-display dummies (pads): three different creature templates, each with a model pool in DB
    // (creature_template_model supports up to 4 models via Idx 0..3).
    constexpr uint32 NPC_BOSS_DISPLAY_PAD_A = 800028;
    constexpr uint32 NPC_BOSS_DISPLAY_PAD_B = 800033;
    constexpr uint32 NPC_BOSS_DISPLAY_PAD_C = 800034;
    constexpr uint32 NPC_BOSS_TRAINING_DUMMY = 800030;
    constexpr uint32 NPC_TRAINING_ADD        = 800031;
    constexpr uint32 NPC_TRAINING_TOTEM      = 800032;

    // Pads are meant to be DB-spawned (persistent). Keep summon fallback off to avoid duplicates
    // if someone places the pads manually or via SQL.
    constexpr bool SUMMON_PADS_IF_MISSING = false;

    // Training dummy spawn anchor (requested).
    struct SpawnCoord
    {
        float x;
        float y;
        float z;
        float o;
    };

    static constexpr SpawnCoord TRAINING_SPAWN_ANCHOR = { 1204.1191f, -2456.6824f, 139.72493f, 5.9718385f };
    static constexpr float TRAINING_SPAWN_Z_OFFSET = 0.5f;

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
        enum class SpawnLocation : uint8
        {
            Anchor = 0,
            NearMaster = 1,
            NearPlayer = 2,
            NearestPad = 3,
        };
        SpawnLocation spawnLocation = SpawnLocation::Anchor;
    };

    struct TrainingSession
    {
        std::vector<ObjectGuid> spawned;
    };

    static std::unordered_map<ObjectGuid, TrainingConfig> s_configByPlayer;
    static std::unordered_map<ObjectGuid, TrainingSession> s_sessionByPlayer;

    // Personal phasing to avoid players seeing each other's spawned configurations.
    // Uses a small set of high bits to reduce collision with existing content.
    static constexpr uint32 PERSONAL_PHASE_BITS[] =
    {
        (1u << 30), (1u << 29), (1u << 28), (1u << 27), (1u << 26),
        (1u << 25), (1u << 24), (1u << 23), (1u << 22), (1u << 21), (1u << 20)
    };

    static std::unordered_map<ObjectGuid, uint32> s_personalPhaseByPlayer;
    static std::unordered_set<uint32> s_usedPersonalPhaseBits;

    uint32 EnsurePlayerPersonalPhase(Player* player)
    {
        if (!player)
            return 0;

        auto it = s_personalPhaseByPlayer.find(player->GetGUID());
        if (it != s_personalPhaseByPlayer.end())
        {
            // Ensure the player retains the bit (in case some other system updated phase mask).
            uint32 bit = it->second;
            if (bit)
                player->SetPhaseMask(player->GetPhaseMask() | bit, true);
            return bit;
        }

        for (uint32 bit : PERSONAL_PHASE_BITS)
        {
            if (bit && !s_usedPersonalPhaseBits.count(bit))
            {
                s_usedPersonalPhaseBits.insert(bit);
                s_personalPhaseByPlayer[player->GetGUID()] = bit;
                player->SetPhaseMask(player->GetPhaseMask() | bit, true);
                return bit;
            }
        }

        // No free bit available.
        return 0;
    }

    void ReleasePlayerPersonalPhase(Player* player)
    {
        if (!player)
            return;

        auto it = s_personalPhaseByPlayer.find(player->GetGUID());
        if (it == s_personalPhaseByPlayer.end())
            return;

        uint32 bit = it->second;
        s_personalPhaseByPlayer.erase(it);
        if (bit)
        {
            s_usedPersonalPhaseBits.erase(bit);
            player->SetPhaseMask(player->GetPhaseMask() & ~bit, true);
        }
    }

    Position GetTrainingSpawnCenter()
    {
        Position p;
        p.m_positionX = TRAINING_SPAWN_ANCHOR.x;
        p.m_positionY = TRAINING_SPAWN_ANCHOR.y;
        p.m_positionZ = TRAINING_SPAWN_ANCHOR.z + TRAINING_SPAWN_Z_OFFSET;
        p.m_orientation = TRAINING_SPAWN_ANCHOR.o;
        return p;
    }


    enum class BossDisplayPoolId : uint8
    {
        Vanilla = 0,
        TBC = 1,
        WotLK = 2,
    };

    struct WeightedDisplay
    {
        uint32 displayId = 0;
        float weight = 1.0f;
    };

    static std::array<std::vector<WeightedDisplay>, 3> s_bossDisplayPools;
    static std::array<bool, 3> s_bossDisplayPoolsLoaded = { false, false, false };

    uint8 PoolIndex(BossDisplayPoolId pool)
    {
        return uint8(pool);
    }

    void LoadBossDisplayPoolIfNeeded(BossDisplayPoolId pool)
    {
        uint8 idx = PoolIndex(pool);
        if (idx >= s_bossDisplayPools.size() || s_bossDisplayPoolsLoaded[idx])
            return;

        s_bossDisplayPools[idx].clear();
        s_bossDisplayPoolsLoaded[idx] = true;

        std::string sql = Acore::StringFormat(
            "SELECT display_id, weight FROM dc_training_boss_display_pool WHERE pool_id = {}",
            uint32(idx));

        QueryResult result = WorldDatabase.Query(sql.c_str());
        if (!result)
        {
            LOG_INFO("server.loading", "Loaded 0 boss display pool entries for pool_id={}", uint32(idx));
            return;
        }

        do
        {
            Field* fields = result->Fetch();
            uint32 displayId = fields[0].Get<uint32>();
            float weight = fields[1].Get<float>();

            if (!displayId || weight <= 0.0f)
                continue;

            if (CreatureModelInfo const* info = sObjectMgr->GetCreatureModelInfo(displayId))
                if (info->is_trigger != 0.0f)
                    continue;

            s_bossDisplayPools[idx].push_back({ displayId, weight });
        } while (result->NextRow());

        LOG_INFO("server.loading", "Loaded {} boss display pool entries for pool_id={}", s_bossDisplayPools[idx].size(), uint32(idx));
    }

    uint32 PickFromBossDisplayPool(BossDisplayPoolId pool)
    {
        LoadBossDisplayPoolIfNeeded(pool);
        uint8 idx = PoolIndex(pool);
        if (idx >= s_bossDisplayPools.size() || s_bossDisplayPools[idx].empty())
            return 0;

        float total = 0.0f;
        for (WeightedDisplay const& e : s_bossDisplayPools[idx])
            total += e.weight;

        if (total <= 0.0f)
            return 0;

        float roll = frand(0.0f, total);
        for (WeightedDisplay const& e : s_bossDisplayPools[idx])
        {
            roll -= e.weight;
            if (roll <= 0.0f)
                return e.displayId;
        }

        return s_bossDisplayPools[idx].back().displayId;
    }

    void ApplyDisplayId(Creature* creature, uint32 displayId)
    {
        if (!creature || !displayId)
            return;

        creature->SetDisplayId(displayId);
        creature->SetNativeDisplayId(displayId);
    }

    uint32 TryPickBossVisualDisplayId()
    {
        // Pick an expansion pool at random.
        BossDisplayPoolId pool = BossDisplayPoolId(urand(0, 2));
        return PickFromBossDisplayPool(pool);
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
                c->DespawnOrUnsummon(Milliseconds(1));
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
            if (uint32 displayId = TryPickBossVisualDisplayId())
                ApplyDisplayId(me, displayId);
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

        ACTION_SPAWNLOC_ANCHOR = 800,
        ACTION_SPAWNLOC_MASTER = 801,
        ACTION_SPAWNLOC_PLAYER = 802,
        ACTION_SPAWNLOC_PAD    = 803,
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

        // Spawn location
        char const* spawnLocText = "Spawn: Anchor";
        switch (cfg.spawnLocation)
        {
            case TrainingConfig::SpawnLocation::NearMaster: spawnLocText = "Spawn: Near master"; break;
            case TrainingConfig::SpawnLocation::NearPlayer: spawnLocText = "Spawn: Near player"; break;
            case TrainingConfig::SpawnLocation::NearestPad: spawnLocText = "Spawn: Nearest pad"; break;
            case TrainingConfig::SpawnLocation::Anchor:
            default: spawnLocText = "Spawn: Anchor"; break;
        }
        AddGossipItemFor(player, GOSSIP_ICON_CHAT, spawnLocText, GOSSIP_SENDER_MAIN, ACTION_SPAWNLOC_ANCHOR);
        AddGossipItemFor(player, GOSSIP_ICON_CHAT, "Spawn location: Anchor", GOSSIP_SENDER_MAIN, ACTION_SPAWNLOC_ANCHOR);
        AddGossipItemFor(player, GOSSIP_ICON_CHAT, "Spawn location: Near master", GOSSIP_SENDER_MAIN, ACTION_SPAWNLOC_MASTER);
        AddGossipItemFor(player, GOSSIP_ICON_CHAT, "Spawn location: Near player", GOSSIP_SENDER_MAIN, ACTION_SPAWNLOC_PLAYER);
        AddGossipItemFor(player, GOSSIP_ICON_CHAT, "Spawn location: Nearest pad", GOSSIP_SENDER_MAIN, ACTION_SPAWNLOC_PAD);

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

    Position MakePosition(float x, float y, float z, float o)
    {
        Position p;
        p.m_positionX = x;
        p.m_positionY = y;
        p.m_positionZ = z;
        p.m_orientation = o;
        return p;
    }

    Position OffsetPosition(Position const& base, float forward, float right)
    {
        // Local-space offsets relative to orientation.
        float o = base.m_orientation;
        float cosO = std::cos(o);
        float sinO = std::sin(o);

        Position p = base;
        p.m_positionX += cosO * forward - sinO * right;
        p.m_positionY += sinO * forward + cosO * right;
        return p;
    }

    Position GetNearestBossPadPosition(Creature* master)
    {
        if (!master)
            return MakePosition(BossPadCoords[0].x, BossPadCoords[0].y, BossPadCoords[0].z, BossPadCoords[0].o);

        float bestDist = std::numeric_limits<float>::max();
        uint8 bestIdx = 0;

        for (uint8 i = 0; i < 3; ++i)
        {
            float dist = master->GetDistance(BossPadCoords[i].x, BossPadCoords[i].y, BossPadCoords[i].z);
            if (dist < bestDist)
            {
                bestDist = dist;
                bestIdx = i;
            }
        }

        return MakePosition(BossPadCoords[bestIdx].x, BossPadCoords[bestIdx].y, BossPadCoords[bestIdx].z, BossPadCoords[bestIdx].o);
    }

    static ObjectGuid s_bossPadGuids[3];

    Creature* FindExistingPadCreature(std::list<Creature*>& candidates, Position const& padPos)
    {
        Creature* best = nullptr;
        float bestDist = 999999.0f;

        for (Creature* c : candidates)
        {
            if (!c)
                continue;

            float dist = c->GetDistance(padPos.m_positionX, padPos.m_positionY, padPos.m_positionZ);
            if (dist < bestDist)
            {
                bestDist = dist;
                best = c;
            }
        }

        // Require it to be close to the intended pad.
        // Keep this lenient so minor coordinate tweaks still get adopted.
        if (best && bestDist <= 25.0f)
            return best;

        return nullptr;
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

        // Prefer DB-spawned pads if they exist near the intended coordinates.
        static constexpr uint32 PadEntries[3] = { NPC_BOSS_DISPLAY_PAD_A, NPC_BOSS_DISPLAY_PAD_B, NPC_BOSS_DISPLAY_PAD_C };

        // Gather nearby pad candidates of ANY of the three entries.
        std::list<Creature*> padCandidates;
        player->GetCreatureListWithEntryInGrid(padCandidates, std::vector<uint32>{ PadEntries[0], PadEntries[1], PadEntries[2] }, 300.0f);

        for (uint8 pad = 0; pad < 3; ++pad)
        {
            // If we already track a live pad creature, keep it.
            if (!s_bossPadGuids[pad].IsEmpty())
                if (ObjectAccessor::GetCreature(*player, s_bossPadGuids[pad]))
                    continue;

            Position pos;
            pos.m_positionX = BossPadCoords[pad].x;
            pos.m_positionY = BossPadCoords[pad].y;
            pos.m_positionZ = BossPadCoords[pad].z;
            pos.m_orientation = BossPadCoords[pad].o;

            // Adopt existing DB spawn if present (any of the pad entries).
            if (Creature* existing = FindExistingPadCreature(padCandidates, pos))
            {
                s_bossPadGuids[pad] = existing->GetGUID();
                padCandidates.remove(existing);
                continue;
            }

            if (!SUMMON_PADS_IF_MISSING)
                continue;

            // Optional fallback: summon a temporary pad dummy (disabled by default).
            std::unordered_set<uint32> usedDisplayIds;
            if (!sObjectMgr->GetCreatureTemplate(PadEntries[pad]))
                continue;

            if (Creature* dummy = player->SummonCreature(PadEntries[pad], pos, TEMPSUMMON_MANUAL_DESPAWN, 0))
            {
                s_bossPadGuids[pad] = dummy->GetGUID();

                BossDisplayPoolId pool = BossDisplayPoolId(pad); // 0=vanilla, 1=TBC, 2=WotLK

                // Try to keep the three pads visually distinct.
                uint32 displayId = 0;
                for (uint8 attempt = 0; attempt < 20; ++attempt)
                {
                    displayId = PickFromBossDisplayPool(pool);
                    if (!displayId || usedDisplayIds.count(displayId))
                        continue;
                    break;
                }

                if (displayId)
                {
                    usedDisplayIds.insert(displayId);
                    if (dummy->AI())
                        dummy->AI()->SetData(1, displayId);
                    else
                        ApplyDisplayId(dummy, displayId);
                }
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

        void SetGUID(ObjectGuid const& guid, int32 id = 0) override
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

                            me->DespawnOrUnsummon(Milliseconds(1));
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

        static constexpr uint32 INACTIVITY_DESPAWN_MS = 5u * 60u * 1000u; // 5 minutes

        uint32 cleaveTimer = 7000;
        uint32 voidZoneTimer = 12000;
        uint32 stackTimer = 6000;
        uint32 moveTimer = 3500;
        uint32 addSpawnTimer = 15000;
        uint32 inactivityTimer = INACTIVITY_DESPAWN_MS;
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
            inactivityTimer = INACTIVITY_DESPAWN_MS;

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
                        totem->SetPhaseMask(me->GetPhaseMask(), true);
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

        void JustEngagedWith(Unit* /*who*/) override
        {
            inactivityTimer = INACTIVITY_DESPAWN_MS;
        }

        void DamageTaken(Unit*, uint32& damage, DamageEffectType, SpellSchoolMask) override
        {
            damage = 0;
            inactivityTimer = INACTIVITY_DESPAWN_MS;
        }

        void UpdateAI(uint32 diff) override
        {
            // Despawn after a period of inactivity/out of combat.
            // We tick this even if there is no victim, so passive dummies still clean up.
            if (me->IsInCombat())
            {
                inactivityTimer = INACTIVITY_DESPAWN_MS;
            }
            else
            {
                if (inactivityTimer <= diff)
                {
                    me->DespawnOrUnsummon(Milliseconds(1));
                    return;
                }
                inactivityTimer -= diff;
            }

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
                                add->SetPhaseMask(me->GetPhaseMask(), true);
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

        static constexpr uint32 DISPLAY_REROLL_INTERVAL_MS = 60u * 60u * 1000u; // 1 hour

        uint32 resetTimer = 5000;
        uint32 rerollTimer = DISPLAY_REROLL_INTERVAL_MS;
        uint32 forcedDisplayId = 0;

        void SetData(uint32 type, uint32 data) override
        {
            if (type != 1)
                return;

            forcedDisplayId = data;
            ApplyDisplayId(me, forcedDisplayId);
        }

        void Reset() override
        {
            me->CastSpell(me, SPELL_STUN_PERMANENT, true);
            resetTimer = 5000;
            rerollTimer = DISPLAY_REROLL_INTERVAL_MS;

            // If this creature was DB-spawned, it won't receive SetData(1, displayId).
            // In that case, choose a display from the pool based on entry and keep it stable.
            if (!forcedDisplayId)
            {
                // If this is a pad dummy, choose the pool based on the closest pad location.
                BossDisplayPoolId pool = BossDisplayPoolId(urand(0, 2));
                float bestDist = 999999.0f;
                int8 bestPad = -1;
                for (int8 i = 0; i < 3; ++i)
                {
                    float dist = me->GetDistance(BossPadCoords[i].x, BossPadCoords[i].y, BossPadCoords[i].z);
                    if (dist < bestDist)
                    {
                        bestDist = dist;
                        bestPad = i;
                    }
                }

                if (bestPad >= 0 && bestDist <= 25.0f)
                    pool = BossDisplayPoolId(uint8(bestPad)); // 0=Vanilla, 1=TBC, 2=WotLK

                forcedDisplayId = PickFromBossDisplayPool(pool);
            }

            if (forcedDisplayId)
                ApplyDisplayId(me, forcedDisplayId);

            // Keep it effectively unkillable, but still allow damage to show up in meters.
            me->SetHealth(me->GetMaxHealth());
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

            // Prevent death while still letting the damage be applied/logged.
            if (damage >= me->GetHealth())
                damage = me->GetHealth() > 1 ? (me->GetHealth() - 1) : 0;
        }

        void UpdateAI(uint32 diff) override
        {
            // Reroll visuals every hour, but only when out of combat.
            if (!me->IsInCombat())
            {
                if (rerollTimer <= diff)
                {
                    BossDisplayPoolId pool = BossDisplayPoolId(urand(0, 2));
                    float bestDist = 999999.0f;
                    int8 bestPad = -1;
                    for (int8 i = 0; i < 3; ++i)
                    {
                        float dist = me->GetDistance(BossPadCoords[i].x, BossPadCoords[i].y, BossPadCoords[i].z);
                        if (dist < bestDist)
                        {
                            bestDist = dist;
                            bestPad = i;
                        }
                    }

                    if (bestPad >= 0 && bestDist <= 25.0f)
                        pool = BossDisplayPoolId(uint8(bestPad)); // 0=Vanilla, 1=TBC, 2=WotLK

                    // Try to pick a different display than the current one.
                    uint32 newDisplayId = 0;
                    for (uint8 attempt = 0; attempt < 20; ++attempt)
                    {
                        newDisplayId = PickFromBossDisplayPool(pool);
                        if (!newDisplayId)
                            break;
                        if (newDisplayId != me->GetDisplayId())
                            break;
                    }

                    if (newDisplayId)
                    {
                        forcedDisplayId = newDisplayId;
                        ApplyDisplayId(me, forcedDisplayId);
                        me->SetHealth(me->GetMaxHealth());
                    }

                    rerollTimer = DISPLAY_REROLL_INTERVAL_MS;
                }
                else
                    rerollTimer -= diff;
            }
            else
            {
                // Only count down the reroll timer while out of combat.
                rerollTimer = DISPLAY_REROLL_INTERVAL_MS;
            }

            // Combat behavior: keep it full HP and reset after a short time with no hostiles.
            if (me->IsInCombat())
            {
                UpdateVictim();

                // Instantly restore health so the dummy stays "full" while still producing real damage numbers.
                if (me->GetHealth() < me->GetMaxHealth())
                    me->SetHealth(me->GetMaxHealth());

                if (resetTimer <= diff)
                {
                    EnterEvadeMode(EVADE_REASON_NO_HOSTILES);
                    resetTimer = 5000;
                }
                else
                    resetTimer -= diff;
            }
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

                if (player->GetMapId() != 745)
                {
                    ChatHandler(player->GetSession()).PSendSysMessage("This Training Master only works in the Jade Forest training grounds (map 745).");
                    break;
                }

                // Put the player in a personal phase bit (adds to their phase mask) so spawned dummies
                // can be hidden from other players without writing any DB spawns.
                uint32 personalPhaseBit = EnsurePlayerPersonalPhase(player);

                uint8 count = cfg.multiTargetCount;
                Position center;
                switch (cfg.spawnLocation)
                {
                    case TrainingConfig::SpawnLocation::NearMaster:
                        center = creature ? creature->GetPosition() : GetTrainingSpawnCenter();
                        break;
                    case TrainingConfig::SpawnLocation::NearPlayer:
                        center = player->GetPosition();
                        center.m_positionZ += TRAINING_SPAWN_Z_OFFSET;
                        break;
                    case TrainingConfig::SpawnLocation::NearestPad:
                        center = GetNearestBossPadPosition(creature);
                        break;
                    case TrainingConfig::SpawnLocation::Anchor:
                    default:
                        center = GetTrainingSpawnCenter();
                        break;
                }

                uint8 chosenLevel = cfg.levelMatchPlayer ? ClampLevel(player->GetLevel()) : ClampLevel(cfg.fixedLevel);

                for (uint8 i = 0; i < count; ++i)
                {
                    Position pos = center;

                    // Deterministic, anchor-based offsets so spawns don't end up player-relative.
                    static constexpr float kOffsetsExactCenter[5][2] =
                    {
                        // First dummy spawns exactly at the configured center (requested teleport coords).
                        { 0.0f,  0.0f },
                        { 4.0f,  0.0f },
                        { -4.0f, 0.0f },
                        { 0.0f,  4.0f },
                        { 0.0f, -4.0f },
                    };

                    static constexpr float kOffsetsAvoidCaster[5][2] =
                    {
                        // Avoid spawning exactly on the caster/master.
                        { 6.0f,  0.0f },
                        { 6.0f,  4.0f },
                        { 6.0f, -4.0f },
                        { 10.0f,  0.0f },
                        { 10.0f,  4.0f },
                    };

                    uint8 offIdx = (i < 5) ? i : (i % 5);
                    bool avoidCaster = (cfg.spawnLocation == TrainingConfig::SpawnLocation::NearMaster) || (cfg.spawnLocation == TrainingConfig::SpawnLocation::NearPlayer);
                    float forward = avoidCaster ? kOffsetsAvoidCaster[offIdx][0] : kOffsetsExactCenter[offIdx][0];
                    float right   = avoidCaster ? kOffsetsAvoidCaster[offIdx][1] : kOffsetsExactCenter[offIdx][1];
                    pos = OffsetPosition(pos, forward, right);

                    if (Creature* dummy = player->SummonCreature(NPC_BOSS_TRAINING_DUMMY, pos, TEMPSUMMON_TIMED_DESPAWN_OUT_OF_COMBAT, 300000, 0, nullptr, true))
                    {
                        // Keep personal phase behavior, but ensure the creature matches the player's full phase mask.
                        if (personalPhaseBit)
                            dummy->SetPhaseMask(player->GetPhaseMask(), true);
                        else
                            dummy->SetPhaseMask(player->GetPhaseMask(), true);

                        // Apply level immediately (in case AI Reset hasn't run yet).
                        dummy->SetLevel(chosenLevel);
                        dummy->UpdateAllStats();

                        if (player->IsGameMaster())
                        {
                            float dist = player->GetDistance(dummy);
                            ChatHandler(player->GetSession()).PSendSysMessage(
                                "Boss dummy spawned at: {} {} {} (dist {:.1f}). Player phase: {} Dummy phase: {}.",
                                dummy->GetPositionX(), dummy->GetPositionY(), dummy->GetPositionZ(), dist,
                                uint32(player->GetPhaseMask()), uint32(dummy->GetPhaseMask()));
                        }

                        TrackSpawn(player, dummy);
                    }
                }

                uint32 spawnedCount = count;
                ChatHandler(player->GetSession()).PSendSysMessage("Spawned {} training {}.", spawnedCount, spawnedCount == 1 ? "dummy" : "dummies");
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

            case ACTION_SPAWNLOC_ANCHOR:
                cfg.spawnLocation = TrainingConfig::SpawnLocation::Anchor;
                break;
            case ACTION_SPAWNLOC_MASTER:
                cfg.spawnLocation = TrainingConfig::SpawnLocation::NearMaster;
                break;
            case ACTION_SPAWNLOC_PLAYER:
                cfg.spawnLocation = TrainingConfig::SpawnLocation::NearPlayer;
                break;
            case ACTION_SPAWNLOC_PAD:
                cfg.spawnLocation = TrainingConfig::SpawnLocation::NearestPad;
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

    void OnPlayerLogin(Player* player) override
    {
        if (player && player->GetMapId() == 745)
            EnsurePlayerPersonalPhase(player);
        EnsureBossPadDummies(player);
    }

    void OnPlayerLogout(Player* player) override
    {
        DespawnSession(player);
        ReleasePlayerPersonalPhase(player);
        s_sessionByPlayer.erase(player->GetGUID());
        s_configByPlayer.erase(player->GetGUID());
    }

    void OnPlayerMapChanged(Player* player) override
    {
        // Avoid leaving training summons behind when teleporting away.
        DespawnSession(player);

        if (player && player->GetMapId() == 745)
            EnsurePlayerPersonalPhase(player);
        else
            ReleasePlayerPersonalPhase(player);

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
