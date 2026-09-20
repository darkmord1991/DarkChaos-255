/*
 * Copyright (C) 2016+ AzerothCore <www.azerothcore.org>
 * Released under GNU AGPL v3 License
 *
 * DarkChaos-255 Prestige Talents
 *
 * A perk tree bought with prestige points, modelled on the WoW Forever "Legacy"
 * system (see Blizzard_LegacySystem in the Forever UI source):
 * - Points are earned ACCOUNT-WIDE from two sources:
 *     * every prestige level on any character (Prestige.Talents.PointsPerPrestigeLevel)
 *     * "challenges": achievements mapped to points in world.dc_prestige_talent_challenges,
 *       each counted once per account however many characters earned it
 * - Every character spends that pool independently (spending on one character does
 *   not consume points for another), capped at Prestige.Talents.MaxSpentPoints.
 * - Points beyond the cap still count toward the reward track
 *   (world.dc_prestige_talent_rewards): cosmetic items unlocked by the account total,
 *   claimed once per account and delivered by mail.
 * - Three trees (Ascension / Fortune / Might). Nodes hang off prerequisite nodes and
 *   unlock once ANY prerequisite is at max rank.
 * - The client stages changes and commits them with ApplyTalents; refunds only go
 *   through a full reset.
 *
 * Talent definitions live in this file (effects need code anyway); challenges and
 * rewards are data in the world DB. The client receives all of them over the PRES
 * addon module, so the UI never hard-codes them.
 *
 * Effects are applied from script hooks and read a per-player cache stored in
 * Player::CustomData, so hot paths (damage hooks) never touch the database.
 */

#include "AchievementMgr.h"
#include "Chat.h"
#include "Config.h"
#include "Creature.h"
#include "DatabaseEnv.h"
#include "Item.h"
#include "Log.h"
#include "LootMgr.h"
#include "Mail.h"
#include "ObjectAccessor.h"
#include "ObjectMgr.h"
#include "Player.h"
#include "Random.h"
#include "ScriptMgr.h"
#include "SpellInfo.h"
#include "WorldSession.h"
#include "dc_prestige_api.h"
#include "DC/AddonExtension/dc_addon_namespace.h"
#include "DC/AddonExtension/dc_addon_prestige_notify.h"
#include <array>
#include <memory>
#include <unordered_map>
#include <unordered_set>

using namespace PrestigeAPI;

namespace
{
    // ------------------------------------------------------------------
    // Talent definitions
    // ------------------------------------------------------------------
    // id, tree, row, column, maxRank, prereqs (any one at max rank unlocks), effect,
    // valuePerRank, name, description ("{v}" = rank * valuePerRank), icon
    std::vector<PrestigeTalentDef> const TALENTS =
    {
        // Ascension - every prestige is a re-level from 1 to 255, so this tree makes that trip faster.
        { 101, PRESTIGE_TREE_ASCENSION, 1, 1, 5, { 0, 0 },     PRESTIGE_EFFECT_XP_KILL_PCT,        4.0f,
          "Swift Ascent", "Increases experience gained from killing creatures by {v}%.", "Ability_Rogue_Sprint" },
        { 102, PRESTIGE_TREE_ASCENSION, 1, 3, 5, { 0, 0 },     PRESTIGE_EFFECT_XP_QUEST_PCT,       4.0f,
          "Lorekeeper", "Increases experience gained from quests and exploration by {v}%.", "INV_Misc_Book_09" },
        { 103, PRESTIGE_TREE_ASCENSION, 2, 2, 3, { 101, 102 }, PRESTIGE_EFFECT_RESET_LEVEL_BONUS, 10.0f,
          "Head Start", "When you prestige, you restart {v} levels higher.", "Spell_Holy_BorrowedTime" },
        { 104, PRESTIGE_TREE_ASCENSION, 3, 2, 1, { 103, 0 },   PRESTIGE_EFFECT_XP_ALL_PCT,        10.0f,
          "Echoes of Mastery", "Increases all experience gained by {v}%.", "Spell_Arcane_MindMastery" },

        // Fortune - economy and professions.
        { 201, PRESTIGE_TREE_FORTUNE, 1, 1, 5, { 0, 0 },     PRESTIGE_EFFECT_REPUTATION_PCT,         3.0f,
          "Diplomat", "Increases reputation gained by {v}%.", "Achievement_Reputation_01" },
        { 202, PRESTIGE_TREE_FORTUNE, 1, 3, 5, { 0, 0 },     PRESTIGE_EFFECT_LOOT_GOLD_PCT,          4.0f,
          "Treasure Hunter", "Increases looted gold by {v}%.", "INV_Misc_Bag_10" },
        { 203, PRESTIGE_TREE_FORTUNE, 2, 1, 3, { 201, 0 },   PRESTIGE_EFFECT_REPAIR_DISCOUNT_PCT,   10.0f,
          "Frugal Upkeep", "Reduces repair costs by {v}%.", "Trade_BlackSmithing" },
        { 204, PRESTIGE_TREE_FORTUNE, 2, 3, 3, { 202, 0 },   PRESTIGE_EFFECT_PROFESSION_CHANCE_PCT, 10.0f,
          "Master Artisan", "Gives a {v}% chance to gain an extra skill point whenever a gathering or crafting skill increases.", "INV_Misc_Gear_01" },
        { 205, PRESTIGE_TREE_FORTUNE, 3, 2, 1, { 203, 204 }, PRESTIGE_EFFECT_LOOT_GOLD_PCT,         10.0f,
          "Fortune's Favor", "Increases looted gold by an additional {v}%.", "INV_Misc_Coin_17" },

        // Might - small PvE combat bonuses (PvP only when Prestige.Talents.AffectPvP = 1).
        { 301, PRESTIGE_TREE_MIGHT, 1, 1, 5, { 0, 0 },     PRESTIGE_EFFECT_DAMAGE_DONE_PCT,  1.0f,
          "Prestigious Might", "Increases damage dealt by you and your pets by {v}%.", "Ability_Warrior_InnerRage" },
        { 302, PRESTIGE_TREE_MIGHT, 1, 3, 5, { 0, 0 },     PRESTIGE_EFFECT_DAMAGE_TAKEN_PCT, 1.0f,
          "Unbroken", "Reduces damage taken by you and your pets by {v}%.", "Ability_Warrior_ShieldWall" },
        { 303, PRESTIGE_TREE_MIGHT, 2, 2, 3, { 301, 302 }, PRESTIGE_EFFECT_KILL_RESTORE_PCT, 1.0f,
          "Thrill of the Hunt", "Killing an enemy that yields experience or honor restores {v}% of your maximum health and mana.", "Spell_Nature_Rejuvenation" },
        { 304, PRESTIGE_TREE_MIGHT, 3, 2, 2, { 303, 0 },   PRESTIGE_EFFECT_BOSS_DAMAGE_PCT,  3.0f,
          "Legend's Wrath", "Increases damage dealt to dungeon, raid and world bosses by {v}%.", "Ability_Warrior_Rampage" },
    };

    char const* const TREE_NAMES[MAX_PRESTIGE_TREES] = { "Ascension", "Fortune", "Might" };
    char const* const TREE_ICONS[MAX_PRESTIGE_TREES] = { "Achievement_Level_80", "INV_Misc_Coin_02", "Spell_Holy_SealOfMight" };

    // Damage taken reduction never goes past this, whatever the definitions say.
    constexpr float MAX_DAMAGE_TAKEN_REDUCTION_PCT = 50.0f;

    // Challenges and rewards come from the world DB (loaded at startup).
    std::vector<PrestigeChallengeDef> g_challenges;
    std::unordered_map<uint32, uint32> g_challengePoints; // achievement id -> points
    std::vector<PrestigeRewardDef> g_rewards;

    // Bosses the core does not recognise. IsDungeonBoss() only covers creatures with
    // an instance_encounters kill credit (which needs a DungeonEncounter.dbc row), so
    // most custom/imported dungeons and raids (SFK Cata, Emerald Sanctum, Castle
    // Nathria councils, DC Strat/Scholo clones, ...) would never count. Built once at
    // startup, read-only afterwards, so map threads can read it without locking.
    std::unordered_set<uint32> g_extraBossEntries;

    std::unordered_map<uint16, size_t> const& TalentIndex()
    {
        static std::unordered_map<uint16, size_t> const index = []
        {
            std::unordered_map<uint16, size_t> map;
            for (size_t i = 0; i < TALENTS.size(); ++i)
                map[TALENTS[i].id] = i;
            return map;
        }();
        return index;
    }

    PrestigeTalentDef const* FindTalent(uint16 id, size_t* outIndex = nullptr)
    {
        auto const& index = TalentIndex();
        auto it = index.find(id);
        if (it == index.end())
            return nullptr;
        if (outIndex)
            *outIndex = it->second;
        return &TALENTS[it->second];
    }

    PrestigeRewardDef const* FindReward(uint32 threshold)
    {
        for (PrestigeRewardDef const& reward : g_rewards)
            if (reward.threshold == threshold)
                return &reward;
        return nullptr;
    }

    // ------------------------------------------------------------------
    // Config
    // ------------------------------------------------------------------
    struct TalentConfig
    {
        bool enabled = true;
        uint32 pointsPerPrestigeLevel = 1;
        uint32 maxSpentPoints = 20;   // 0 = no cap
        uint32 resetCost = 0;         // copper
        bool affectPvP = false;
    } g_config;

    // ------------------------------------------------------------------
    // Per-player state (Player::CustomData)
    // ------------------------------------------------------------------
    using RankVector = std::vector<uint8>;

    struct PrestigeTalentState : public DataMap::Base
    {
        bool loaded = false;
        bool pushWhenLoaded = false;
        uint32 accountPrestigeLevels = 0;              // SUM(prestige_level) over the account
        std::unordered_set<uint32> completedChallenges; // account-wide, achievement ids
        std::unordered_set<uint32> claimedRewards;      // account-wide, thresholds
        RankVector ranks = RankVector(TALENTS.size(), 0);
        std::array<float, MAX_PRESTIGE_EFFECTS> effects{};

        uint32 PrestigePoints() const
        {
            return accountPrestigeLevels * g_config.pointsPerPrestigeLevel;
        }

        uint32 ChallengePoints() const
        {
            uint32 points = 0;
            for (uint32 achievementId : completedChallenges)
            {
                auto it = g_challengePoints.find(achievementId);
                if (it != g_challengePoints.end())
                    points += it->second;
            }
            return points;
        }

        uint32 AccountPoints() const
        {
            return PrestigePoints() + ChallengePoints();
        }

        uint32 SpendCap() const
        {
            uint32 points = AccountPoints();
            if (g_config.maxSpentPoints)
                points = std::min(points, g_config.maxSpentPoints);
            return points;
        }

        uint32 TreeSpent(RankVector const& r, uint8 tree) const
        {
            uint32 spent = 0;
            for (size_t i = 0; i < TALENTS.size(); ++i)
                if (TALENTS[i].tree == tree)
                    spent += r[i];
            return spent;
        }

        uint32 Spent() const
        {
            return Spent(ranks);
        }

        static uint32 Spent(RankVector const& r)
        {
            uint32 spent = 0;
            for (uint8 rank : r)
                spent += rank;
            return spent;
        }

        static bool IsUnlocked(RankVector const& r, PrestigeTalentDef const& def)
        {
            bool hasPrereq = false;
            for (uint16 prereqId : def.prereqs)
            {
                if (!prereqId)
                    continue;

                hasPrereq = true;
                size_t index = 0;
                PrestigeTalentDef const* prereq = FindTalent(prereqId, &index);
                if (prereq && r[index] >= prereq->maxRank)
                    return true;
            }
            return !hasPrereq;
        }

        bool IsValid(RankVector const& r) const
        {
            if (Spent(r) > SpendCap())
                return false;

            for (size_t i = 0; i < TALENTS.size(); ++i)
            {
                if (!r[i])
                    continue;
                if (r[i] > TALENTS[i].maxRank || !IsUnlocked(r, TALENTS[i]))
                    return false;
            }
            return true;
        }

        bool IsValid() const
        {
            return IsValid(ranks);
        }

        void RecalculateEffects()
        {
            effects.fill(0.0f);
            for (size_t i = 0; i < TALENTS.size(); ++i)
                effects[TALENTS[i].effect] += ranks[i] * TALENTS[i].valuePerRank;
        }
    };

    std::string const STATE_KEY = "dc.prestige.talents";

    PrestigeTalentState* GetState(Player const* player)
    {
        return player ? player->CustomData.Get<PrestigeTalentState>(STATE_KEY) : nullptr;
    }

    PrestigeTalentState* GetOrCreateState(Player* player)
    {
        return player->CustomData.GetDefault<PrestigeTalentState>(STATE_KEY);
    }

    float Effect(Player const* player, PrestigeTalentEffect effect)
    {
        if (!g_config.enabled)
            return 0.0f;

        PrestigeTalentState const* state = GetState(player);
        if (!state || !state->loaded)
            return 0.0f;

        return state->effects[effect];
    }

    void RefundAll(Player* player, PrestigeTalentState* state, char const* message)
    {
        std::fill(state->ranks.begin(), state->ranks.end(), 0);
        state->RecalculateEffects();
        CharacterDatabase.Execute("DELETE FROM dc_character_prestige_talents WHERE guid = {}",
            player->GetGUID().GetCounter());
        ChatHandler(player->GetSession()).PSendSysMessage("|cFFFFD700[Prestige]|r {}", message);
    }

    // ------------------------------------------------------------------
    // World data (challenges + reward track)
    // ------------------------------------------------------------------
    void LoadWorldData()
    {
        g_challenges.clear();
        g_challengePoints.clear();
        g_rewards.clear();

        // Separate queries per table: a missing table only costs its own feature.
        if (QueryResult result = WorldDatabase.Query(
            "SELECT achievement_id, points, category, sort_order FROM dc_prestige_talent_challenges "
            "WHERE points > 0 ORDER BY sort_order, achievement_id"))
        {
            do
            {
                Field* fields = result->Fetch();
                PrestigeChallengeDef def;
                def.achievementId = fields[0].Get<uint32>();
                def.points = fields[1].Get<uint32>();
                def.category = fields[2].Get<std::string>();
                def.sortOrder = fields[3].Get<uint32>();

                if (!sAchievementMgr->GetAchievement(def.achievementId))
                {
                    LOG_ERROR("sql.sql", "dc_prestige_talent_challenges: achievement {} does not exist, skipped", def.achievementId);
                    continue;
                }

                g_challengePoints[def.achievementId] = def.points;
                g_challenges.push_back(std::move(def));
            } while (result->NextRow());
        }

        if (QueryResult result = WorldDatabase.Query(
            "SELECT threshold, item_entry, item_count, reward_type FROM dc_prestige_talent_rewards ORDER BY threshold"))
        {
            do
            {
                Field* fields = result->Fetch();
                PrestigeRewardDef def;
                def.threshold = fields[0].Get<uint32>();
                def.itemEntry = fields[1].Get<uint32>();
                def.itemCount = std::max<uint32>(fields[2].Get<uint32>(), 1);
                def.rewardType = fields[3].Get<std::string>();

                if (!sObjectMgr->GetItemTemplate(def.itemEntry))
                {
                    LOG_ERROR("sql.sql", "dc_prestige_talent_rewards: item {} (threshold {}) does not exist, skipped",
                        def.itemEntry, def.threshold);
                    continue;
                }

                g_rewards.push_back(std::move(def));
            } while (result->NextRow());
        }

        // rank 3 = "boss" in creature_template; elite creatures with a boss_ script.
        // Only counted inside dungeons/raids (see IsBoss), which keeps rank-3 vendors
        // and quest givers in the open world out.
        g_extraBossEntries.clear();
        if (QueryResult result = WorldDatabase.Query(
            "SELECT entry FROM creature_template WHERE `rank` = 3 OR (`rank` >= 1 AND LEFT(ScriptName, 5) = 'boss_')"))
        {
            do
                g_extraBossEntries.insert(result->Fetch()[0].Get<uint32>());
            while (result->NextRow());
        }

        LOG_INFO("server.loading", ">> Loaded {} prestige talent challenges, {} reward track entries and {} extra boss entries",
            g_challenges.size(), g_rewards.size(), g_extraBossEntries.size());
    }

    std::string BuildChallengeIdList()
    {
        std::string list;
        for (PrestigeChallengeDef const& def : g_challenges)
        {
            if (!list.empty())
                list += ',';
            list += std::to_string(def.achievementId);
        }
        return list;
    }

    // ------------------------------------------------------------------
    // Loading
    // ------------------------------------------------------------------
    struct LoadedAccountData
    {
        uint32 prestigeLevels = 0;
        std::vector<std::pair<uint16, uint8>> ranks;
        std::vector<uint32> challenges;
        std::vector<uint32> claims;
    };

    void FinishLoad(Player* player, LoadedAccountData const& data)
    {
        PrestigeTalentState* state = GetOrCreateState(player);
        state->accountPrestigeLevels = data.prestigeLevels;
        // Merge rather than overwrite: achievements earned while the load was in
        // flight were already recorded by the hook.
        state->completedChallenges.insert(data.challenges.begin(), data.challenges.end());
        state->claimedRewards.insert(data.claims.begin(), data.claims.end());
        std::fill(state->ranks.begin(), state->ranks.end(), 0);

        for (auto const& [talentId, rank] : data.ranks)
        {
            size_t index = 0;
            if (!FindTalent(talentId, &index))
            {
                LOG_WARN("scripts.dc", "PrestigeTalents: {} has unknown talent {} stored, ignoring it",
                    player->GetGUID().ToString(), talentId);
                continue;
            }
            state->ranks[index] = rank;
        }

        // The pool can shrink (character deleted, config lowered) and definitions can
        // change between releases. Rather than guessing which ranks to drop, refund
        // everything and let the player spend again.
        if (!state->IsValid())
        {
            RefundAll(player, state, "Your prestige talents no longer fit your account's points and have been refunded.");
            LOG_INFO("scripts.dc", "PrestigeTalents: refunded invalid allocation for {}", player->GetGUID().ToString());
        }

        state->RecalculateEffects();
        state->loaded = true;

        if (state->pushWhenLoaded)
        {
            state->pushWhenLoaded = false;
            DCPrestigeAddon::SendTalents(player);
        }
    }

    // Four small async reads chained on the world thread: prestige pool, this
    // character's ranks, the account's completed challenges, the account's claims.
    void LoadTalentsAsync(Player* player)
    {
        ObjectGuid const playerGuid = player->GetGUID();
        uint32 const accountId = player->GetSession()->GetAccountId();
        auto data = std::make_shared<LoadedAccountData>();

        auto loadClaims = [playerGuid, accountId, data]()
        {
            DCAddon::EnqueueQueryCallback(CharacterDatabase.AsyncQuery(Acore::StringFormat(
                "SELECT threshold FROM dc_account_prestige_rewards WHERE account_id = {}", accountId))
                .WithCallback([playerGuid, data](QueryResult result)
            {
                if (result)
                {
                    do
                        data->claims.push_back(result->Fetch()[0].Get<uint32>());
                    while (result->NextRow());
                }

                Player* player = ObjectAccessor::FindPlayer(playerGuid);
                if (!player || !player->GetSession())
                    return;

                FinishLoad(player, *data);
            }));
        };

        auto loadChallenges = [accountId, data, loadClaims]()
        {
            std::string const idList = BuildChallengeIdList();
            if (idList.empty())
            {
                loadClaims();
                return;
            }

            // Deleted characters have account = 0, so their achievements stop counting.
            DCAddon::EnqueueQueryCallback(CharacterDatabase.AsyncQuery(Acore::StringFormat(
                "SELECT DISTINCT ca.achievement FROM character_achievement ca "
                "INNER JOIN characters c ON c.guid = ca.guid WHERE c.account = {} AND ca.achievement IN ({})",
                accountId, idList)) // sql-ok: numeric ids from the world DB
                .WithCallback([data, loadClaims](QueryResult result)
            {
                if (result)
                {
                    do
                        data->challenges.push_back(result->Fetch()[0].Get<uint32>());
                    while (result->NextRow());
                }
                loadClaims();
            }));
        };

        auto loadRanks = [playerGuid, data, loadChallenges]()
        {
            DCAddon::EnqueueQueryCallback(CharacterDatabase.AsyncQuery(Acore::StringFormat(
                "SELECT talent_id, `rank` FROM dc_character_prestige_talents WHERE guid = {}",
                playerGuid.GetCounter()))
                .WithCallback([data, loadChallenges](QueryResult result)
            {
                if (result)
                {
                    do
                    {
                        Field* fields = result->Fetch();
                        data->ranks.emplace_back(fields[0].Get<uint16>(), fields[1].Get<uint8>());
                    } while (result->NextRow());
                }
                loadChallenges();
            }));
        };

        // Deleted characters have account = 0, so their prestige stops counting.
        DCAddon::EnqueueQueryCallback(CharacterDatabase.AsyncQuery(Acore::StringFormat(
            "SELECT CAST(COALESCE(SUM(p.prestige_level), 0) AS UNSIGNED) FROM dc_character_prestige p "
            "INNER JOIN characters c ON c.guid = p.guid WHERE c.account = {}", accountId))
            .WithCallback([data, loadRanks](QueryResult result)
        {
            data->prestigeLevels = result ? static_cast<uint32>(result->Fetch()[0].Get<uint64>()) : 0;
            loadRanks();
        }));
    }

    // ------------------------------------------------------------------
    // Damage helpers
    // ------------------------------------------------------------------
    bool IsBoss(Unit const* unit)
    {
        Creature const* creature = unit ? unit->ToCreature() : nullptr;
        if (!creature)
            return false;

        if (creature->isWorldBoss() || creature->IsDungeonBoss())
            return true;

        Map const* map = creature->GetMap();
        return map && map->IsDungeon() && g_extraBossEntries.count(creature->GetEntry());
    }

    template<typename T>
    void ApplyDamageTalents(Unit* target, Unit* attacker, T& damage)
    {
        if (!g_config.enabled || !target || !attacker || !(damage > 0))
            return;

        Player* attackerPlayer = attacker->GetCharmerOrOwnerPlayerOrPlayerItself();
        Player* targetPlayer = target->GetCharmerOrOwnerPlayerOrPlayerItself();
        if (!attackerPlayer && !targetPlayer)
            return;

        if (attackerPlayer == targetPlayer)
            return; // self damage

        if (attackerPlayer && targetPlayer && !g_config.affectPvP)
            return;

        float done = 0.0f;
        if (attackerPlayer)
        {
            done = Effect(attackerPlayer, PRESTIGE_EFFECT_DAMAGE_DONE_PCT);
            if (IsBoss(target))
                done += Effect(attackerPlayer, PRESTIGE_EFFECT_BOSS_DAMAGE_PCT);
        }

        float taken = targetPlayer ? Effect(targetPlayer, PRESTIGE_EFFECT_DAMAGE_TAKEN_PCT) : 0.0f;
        taken = std::min(taken, MAX_DAMAGE_TAKEN_REDUCTION_PCT);

        if (done <= 0.0f && taken <= 0.0f)
            return;

        float multiplier = (1.0f + done / 100.0f) * (1.0f - taken / 100.0f);
        damage = static_cast<T>(damage * multiplier);
    }

    bool IsPeriodicHealSpell(SpellInfo const* spellInfo)
    {
        // The periodic heal tick also calls ModifyPeriodicDamageAurasTick.
        return spellInfo && (spellInfo->HasAura(SPELL_AURA_PERIODIC_HEAL) || spellInfo->HasAura(SPELL_AURA_OBS_MOD_HEALTH));
    }
}

// ----------------------------------------------------------------------
// Scripts
// ----------------------------------------------------------------------
class PrestigeTalentsPlayerScript : public PlayerScript
{
public:
    PrestigeTalentsPlayerScript() : PlayerScript("PrestigeTalentsPlayerScript", {
        PLAYERHOOK_ON_LOGIN,
        PLAYERHOOK_ON_GIVE_EXP,
        PLAYERHOOK_ON_GIVE_REPUTATION,
        PLAYERHOOK_ON_BEFORE_LOOT_MONEY,
        PLAYERHOOK_ON_BEFORE_DURABILITY_REPAIR,
        PLAYERHOOK_ON_UPDATE_GATHERING_SKILL,
        PLAYERHOOK_ON_UPDATE_CRAFTING_SKILL,
        PLAYERHOOK_ON_CREATURE_KILL,
        PLAYERHOOK_ON_ACHI_COMPLETE,
        PLAYERHOOK_ON_DELETE_FROM_DB
    }) { }

    void OnPlayerLogin(Player* player) override
    {
        if (!g_config.enabled || !PrestigeAPI::IsEnabled())
            return;

        LoadTalentsAsync(player);
    }

    void OnPlayerAchievementComplete(Player* player, AchievementEntry const* achievement) override
    {
        if (!g_config.enabled || !achievement)
            return;

        auto it = g_challengePoints.find(achievement->ID);
        if (it == g_challengePoints.end())
            return;

        PrestigeTalentState* state = GetOrCreateState(player);
        if (!state->completedChallenges.insert(achievement->ID).second)
            return; // another character of the account already counted it

        if (!state->loaded)
            return; // the login load merges into the same set

        ChatHandler(player->GetSession()).PSendSysMessage(
            "|cFFFFD700[Prestige]|r Challenge complete! Your account earned {} prestige talent point(s). "
            "Available on this character: {}/{}.",
            it->second, state->SpendCap() - state->Spent(), state->SpendCap());
        DCPrestigeAddon::NotifyChallengeEarned(player, achievement->ID, it->second, state->AccountPoints());
    }

    void OnPlayerGiveXP(Player* player, uint32& amount, Unit* /*victim*/, uint8 xpSource) override
    {
        float pct = Effect(player, PRESTIGE_EFFECT_XP_ALL_PCT);
        if (xpSource == XPSOURCE_KILL)
            pct += Effect(player, PRESTIGE_EFFECT_XP_KILL_PCT);
        else if (xpSource == XPSOURCE_QUEST || xpSource == XPSOURCE_QUEST_DF || xpSource == XPSOURCE_EXPLORE)
            pct += Effect(player, PRESTIGE_EFFECT_XP_QUEST_PCT);

        if (pct > 0.0f && amount)
            amount += static_cast<uint32>(amount * pct / 100.0f);
    }

    void OnPlayerGiveReputation(Player* player, int32 /*factionID*/, float& amount, ReputationSource /*repSource*/) override
    {
        float pct = Effect(player, PRESTIGE_EFFECT_REPUTATION_PCT);
        if (pct > 0.0f && amount > 0.0f)
            amount *= 1.0f + pct / 100.0f;
    }

    void OnPlayerBeforeLootMoney(Player* player, Loot* loot) override
    {
        float pct = Effect(player, PRESTIGE_EFFECT_LOOT_GOLD_PCT);
        if (pct > 0.0f && loot && loot->gold)
            loot->gold += static_cast<uint32>(loot->gold * pct / 100.0f);
    }

    void OnPlayerBeforeDurabilityRepair(Player* player, ObjectGuid /*npcGUID*/, ObjectGuid /*itemGUID*/, float& discountMod, uint8 /*guildBank*/) override
    {
        float pct = std::min(Effect(player, PRESTIGE_EFFECT_REPAIR_DISCOUNT_PCT), 100.0f);
        if (pct > 0.0f)
            discountMod *= 1.0f - pct / 100.0f;
    }

    void OnPlayerUpdateGatheringSkill(Player* player, uint32 /*skillId*/, uint32 /*current*/, uint32 /*gray*/, uint32 /*green*/, uint32 /*yellow*/, uint32& gain) override
    {
        RollExtraSkillPoint(player, gain);
    }

    void OnPlayerUpdateCraftingSkill(Player* player, SkillLineAbilityEntry const* /*skill*/, uint32 /*currentLevel*/, uint32& gain) override
    {
        RollExtraSkillPoint(player, gain);
    }

    void OnPlayerCreatureKill(Player* killer, Creature* killed) override
    {
        float pct = Effect(killer, PRESTIGE_EFFECT_KILL_RESTORE_PCT);
        if (pct <= 0.0f || !killer->IsAlive() || !killer->isHonorOrXPTarget(killed))
            return;

        killer->ModifyHealth(static_cast<int32>(CalculatePct(killer->GetMaxHealth(), pct)));
        if (killer->GetMaxPower(POWER_MANA))
            killer->ModifyPower(POWER_MANA, static_cast<int32>(CalculatePct(killer->GetMaxPower(POWER_MANA), pct)));
    }

    void OnPlayerDeleteFromDB(CharacterDatabaseTransaction trans, uint32 guid) override
    {
        trans->Append("DELETE FROM dc_character_prestige_talents WHERE guid = {}", guid);
    }

private:
    static void RollExtraSkillPoint(Player* player, uint32& gain)
    {
        float pct = Effect(player, PRESTIGE_EFFECT_PROFESSION_CHANCE_PCT);
        if (gain && pct > 0.0f && roll_chance_f(pct))
            ++gain;
    }
};

class PrestigeTalentsUnitScript : public UnitScript
{
public:
    PrestigeTalentsUnitScript() : UnitScript("PrestigeTalentsUnitScript", true, {
        UNITHOOK_MODIFY_MELEE_DAMAGE,
        UNITHOOK_MODIFY_SPELL_DAMAGE_TAKEN,
        UNITHOOK_MODIFY_PERIODIC_DAMAGE_AURAS_TICK
    }) { }

    void ModifyMeleeDamage(Unit* target, Unit* attacker, uint32& damage) override
    {
        ApplyDamageTalents(target, attacker, damage);
    }

    void ModifySpellDamageTaken(Unit* target, Unit* attacker, int32& damage, SpellInfo const* /*spellInfo*/) override
    {
        ApplyDamageTalents(target, attacker, damage);
    }

    void ModifyPeriodicDamageAurasTick(Unit* target, Unit* attacker, uint32& damage, SpellInfo const* spellInfo) override
    {
        if (IsPeriodicHealSpell(spellInfo))
            return;

        ApplyDamageTalents(target, attacker, damage);
    }
};

class PrestigeTalentsWorldScript : public WorldScript
{
public:
    PrestigeTalentsWorldScript() : WorldScript("PrestigeTalentsWorldScript", { WORLDHOOK_ON_AFTER_CONFIG_LOAD, WORLDHOOK_ON_STARTUP }) { }

    void OnAfterConfigLoad(bool /*reload*/) override
    {
        LoadConfig();
    }

    void OnStartup() override
    {
        LoadConfig();
        LoadWorldData();
    }

private:
    static void LoadConfig()
    {
        g_config.enabled = sConfigMgr->GetOption<bool>("Prestige.Talents.Enable", true);
        g_config.pointsPerPrestigeLevel = sConfigMgr->GetOption<uint32>("Prestige.Talents.PointsPerPrestigeLevel", 1);
        g_config.maxSpentPoints = sConfigMgr->GetOption<uint32>("Prestige.Talents.MaxSpentPoints", 20);
        g_config.resetCost = sConfigMgr->GetOption<uint32>("Prestige.Talents.ResetCost", 0);
        g_config.affectPvP = sConfigMgr->GetOption<bool>("Prestige.Talents.AffectPvP", false);

        uint32 maxRanks = 0;
        for (PrestigeTalentDef const& def : TALENTS)
            maxRanks += def.maxRank;

        LOG_INFO("scripts.dc", "PrestigeTalents: {} ({} talents, {} ranks total, {} point(s) per prestige level, spend cap {})",
            g_config.enabled ? "enabled" : "disabled", TALENTS.size(), maxRanks,
            g_config.pointsPerPrestigeLevel, g_config.maxSpentPoints ? std::to_string(g_config.maxSpentPoints) : "none");
    }
};

void AddSC_dc_prestige_talents()
{
    new PrestigeTalentsPlayerScript();
    new PrestigeTalentsUnitScript();
    new PrestigeTalentsWorldScript();
}

// ----------------------------------------------------------------------
// API
// ----------------------------------------------------------------------
namespace PrestigeAPI
{
    bool IsTalentsEnabled()
    {
        return g_config.enabled && IsEnabled();
    }

    std::vector<PrestigeTalentDef> const& GetTalentDefinitions()
    {
        return TALENTS;
    }

    std::vector<PrestigeChallengeDef> const& GetChallengeDefinitions()
    {
        return g_challenges;
    }

    std::vector<PrestigeRewardDef> const& GetRewardDefinitions()
    {
        return g_rewards;
    }

    char const* GetTalentTreeName(uint8 tree)
    {
        return tree < MAX_PRESTIGE_TREES ? TREE_NAMES[tree] : "";
    }

    char const* GetTalentTreeIcon(uint8 tree)
    {
        return tree < MAX_PRESTIGE_TREES ? TREE_ICONS[tree] : "";
    }

    uint32 GetTalentResetCost()
    {
        return g_config.resetCost;
    }

    PrestigeTalentSnapshot GetTalentSnapshot(Player* player)
    {
        PrestigeTalentSnapshot snapshot;
        PrestigeTalentState const* state = GetState(player);
        if (!state || !state->loaded)
            return snapshot;

        snapshot.loaded = true;
        snapshot.prestigePoints = state->PrestigePoints();
        snapshot.challengePoints = state->ChallengePoints();
        snapshot.accountPoints = state->AccountPoints();
        snapshot.spendCap = state->SpendCap();
        snapshot.spent = state->Spent();
        for (uint8 tree = 0; tree < MAX_PRESTIGE_TREES; ++tree)
            snapshot.treeSpent[tree] = state->TreeSpent(state->ranks, tree);
        for (size_t i = 0; i < TALENTS.size(); ++i)
            if (state->ranks[i])
                snapshot.ranks.emplace_back(TALENTS[i].id, state->ranks[i]);
        snapshot.completedChallenges.assign(state->completedChallenges.begin(), state->completedChallenges.end());
        snapshot.claimedRewards.assign(state->claimedRewards.begin(), state->claimedRewards.end());
        return snapshot;
    }

    PrestigeTalentResult LearnTalent(Player* player, uint16 talentId)
    {
        PrestigeTalentState const* state = GetState(player);
        if (!state || !state->loaded)
            return IsTalentsEnabled() ? PrestigeTalentResult::NotLoaded : PrestigeTalentResult::Disabled;

        size_t index = 0;
        if (!FindTalent(talentId, &index))
            return PrestigeTalentResult::UnknownTalent;

        return ApplyTalents(player, { { talentId, uint8(state->ranks[index] + 1) } });
    }

    PrestigeTalentResult ApplyTalents(Player* player, std::vector<std::pair<uint16, uint8>> const& target)
    {
        if (!IsTalentsEnabled())
            return PrestigeTalentResult::Disabled;

        PrestigeTalentState* state = GetState(player);
        if (!state || !state->loaded)
            return PrestigeTalentResult::NotLoaded;

        RankVector wanted = state->ranks;
        for (auto const& [talentId, rank] : target)
        {
            size_t index = 0;
            PrestigeTalentDef const* def = FindTalent(talentId, &index);
            if (!def)
                return PrestigeTalentResult::UnknownTalent;
            if (rank > def->maxRank)
                return PrestigeTalentResult::MaxRank;
            if (rank < state->ranks[index])
                return PrestigeTalentResult::CannotRefund;
            wanted[index] = rank;
        }

        if (wanted == state->ranks)
            return PrestigeTalentResult::NoChanges;

        if (PrestigeTalentState::Spent(wanted) > state->SpendCap())
            return PrestigeTalentResult::NoPoints;

        for (size_t i = 0; i < TALENTS.size(); ++i)
            if (wanted[i] && !PrestigeTalentState::IsUnlocked(wanted, TALENTS[i]))
                return PrestigeTalentResult::TreeLocked;

        CharacterDatabaseTransaction trans = CharacterDatabase.BeginTransaction();
        for (size_t i = 0; i < TALENTS.size(); ++i)
        {
            if (wanted[i] == state->ranks[i])
                continue;

            trans->Append(
                "INSERT INTO dc_character_prestige_talents (guid, talent_id, `rank`) VALUES ({}, {}, {}) "
                "ON DUPLICATE KEY UPDATE `rank` = VALUES(`rank`)",
                player->GetGUID().GetCounter(), TALENTS[i].id, wanted[i]);
        }
        CharacterDatabase.CommitTransaction(trans);

        state->ranks = std::move(wanted);
        state->RecalculateEffects();
        return PrestigeTalentResult::Ok;
    }

    PrestigeTalentResult ResetTalents(Player* player)
    {
        if (!IsTalentsEnabled())
            return PrestigeTalentResult::Disabled;

        PrestigeTalentState* state = GetState(player);
        if (!state || !state->loaded)
            return PrestigeTalentResult::NotLoaded;

        if (!state->Spent())
            return PrestigeTalentResult::NothingToReset;

        if (player->IsInCombat())
            return PrestigeTalentResult::InCombat;

        if (g_config.resetCost)
        {
            if (!player->HasEnoughMoney(g_config.resetCost))
                return PrestigeTalentResult::NotEnoughGold;
            player->ModifyMoney(-static_cast<int32>(g_config.resetCost));
        }

        std::fill(state->ranks.begin(), state->ranks.end(), 0);
        state->RecalculateEffects();

        CharacterDatabase.Execute("DELETE FROM dc_character_prestige_talents WHERE guid = {}",
            player->GetGUID().GetCounter());

        return PrestigeTalentResult::Ok;
    }

    PrestigeTalentResult ClaimReward(Player* player, uint32 threshold)
    {
        if (!IsTalentsEnabled())
            return PrestigeTalentResult::Disabled;

        PrestigeTalentState* state = GetState(player);
        if (!state || !state->loaded)
            return PrestigeTalentResult::NotLoaded;

        PrestigeRewardDef const* reward = FindReward(threshold);
        if (!reward)
            return PrestigeTalentResult::UnknownReward;

        if (state->AccountPoints() < reward->threshold)
            return PrestigeTalentResult::RewardLocked;

        if (state->claimedRewards.count(reward->threshold))
            return PrestigeTalentResult::RewardClaimed;

        Item* item = Item::CreateItem(reward->itemEntry, reward->itemCount, player);
        if (!item)
            return PrestigeTalentResult::RewardFailed;

        // Record the claim and send the mail in one transaction, so a crash cannot
        // hand out the item twice or lose it.
        CharacterDatabaseTransaction trans = CharacterDatabase.BeginTransaction();
        trans->Append(
            "INSERT INTO dc_account_prestige_rewards (account_id, threshold, guid, claim_time) "
            "VALUES ({}, {}, {}, UNIX_TIMESTAMP())",
            player->GetSession()->GetAccountId(), reward->threshold, player->GetGUID().GetCounter());

        item->SaveToDB(trans);
        MailDraft draft("Prestige Reward Track",
            Acore::StringFormat("Your account reached {} prestige talent points. Enjoy your reward!", reward->threshold));
        draft.AddItem(item);
        draft.SendMailTo(trans, MailReceiver(player), MailSender(MAIL_NORMAL, 0, MAIL_STATIONERY_GM));
        CharacterDatabase.CommitTransaction(trans);

        state->claimedRewards.insert(reward->threshold);
        LOG_INFO("scripts.dc", "PrestigeTalents: account {} claimed reward track {} (item {}) on {}",
            player->GetSession()->GetAccountId(), reward->threshold, reward->itemEntry, player->GetGUID().ToString());
        return PrestigeTalentResult::Ok;
    }

    char const* GetTalentResultText(PrestigeTalentResult result)
    {
        switch (result)
        {
            case PrestigeTalentResult::Ok:             return "";
            case PrestigeTalentResult::Disabled:       return "Prestige talents are disabled.";
            case PrestigeTalentResult::NotLoaded:      return "Your prestige talents are still loading, try again in a moment.";
            case PrestigeTalentResult::UnknownTalent:  return "Unknown prestige talent.";
            case PrestigeTalentResult::MaxRank:        return "That talent is already at its maximum rank.";
            case PrestigeTalentResult::NoPoints:       return "You do not have enough prestige talent points.";
            case PrestigeTalentResult::TreeLocked:     return "Max out a connected talent first to unlock that one.";
            case PrestigeTalentResult::InCombat:       return "You cannot do that while in combat.";
            case PrestigeTalentResult::NotEnoughGold:  return "You cannot afford to reset your prestige talents.";
            case PrestigeTalentResult::NothingToReset: return "You have not spent any prestige talent points.";
            case PrestigeTalentResult::NoChanges:      return "There are no changes to apply.";
            case PrestigeTalentResult::CannotRefund:   return "Spent points can only be refunded with a full reset.";
            case PrestigeTalentResult::UnknownReward:  return "Unknown reward.";
            case PrestigeTalentResult::RewardLocked:   return "Your account has not earned enough prestige talent points for that reward yet.";
            case PrestigeTalentResult::RewardClaimed:  return "Your account has already claimed that reward.";
            case PrestigeTalentResult::RewardFailed:   return "The reward could not be created. Please contact a GM.";
        }
        return "";
    }

    float GetTalentEffect(Player* player, PrestigeTalentEffect effect)
    {
        return effect < MAX_PRESTIGE_EFFECTS ? Effect(player, effect) : 0.0f;
    }

    void QueueTalentPush(Player* player)
    {
        if (player)
            GetOrCreateState(player)->pushWhenLoaded = true;
    }

    void OnPrestigeLevelChanged(Player* player, uint32 oldLevel, uint32 newLevel)
    {
        PrestigeTalentState* state = GetState(player);
        if (!state || !state->loaded)
            return; // login load still in flight; it reads the new level from the DB

        // Adjust arithmetically: a re-query could race the pending prestige write.
        int64 levels = int64(state->accountPrestigeLevels) + int64(newLevel) - int64(oldLevel);
        state->accountPrestigeLevels = static_cast<uint32>(std::max<int64>(levels, 0));

        if (!state->IsValid())
        {
            RefundAll(player, state, "Your prestige talents have been refunded.");
        }
        else if (newLevel > oldLevel)
        {
            uint32 gained = (newLevel - oldLevel) * g_config.pointsPerPrestigeLevel;
            ChatHandler(player->GetSession()).PSendSysMessage(
                "|cFFFFD700[Prestige]|r Your account earned {} prestige talent point(s). Available on this character: {}/{}.",
                gained, state->SpendCap() - state->Spent(), state->SpendCap());
        }
    }
}
