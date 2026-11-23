/*
 * DarkChaos: flexible raid scaling for DC custom raids.
 *
 * Playerbots fill raids, so DC's own raids run at whatever size the group
 * happens to have. This scales boss health and boss loot by the number of
 * players in the instance instead of by the size the difficulty assumes.
 * The design follows Ascension CoA (mod-coa-raid-difficulty: FlexHealth,
 * FlexLoot, FlexItems), adapted to DC: CoA stores health per player per boss
 * in a table, this keeps the boss's own health and multiplies it, so the
 * Mythic+ difficulty profile and anything else already in the creature's
 * health is kept.
 *
 * Scope: only the map:difficulty pairs listed in DC.RaidFlex.Maps. The
 * default list holds the DC custom raids. Stock raids (levels 1-80 keep
 * WotLK balance) are never touched unless someone adds them to the list.
 *
 * Boss health
 *  - Applied when a boss engages (UnitScript OnUnitEnterCombat, fired from
 *    Creature::AtEngage after the AI's JustEngagedWith). It is a generic
 *    hook, so no DC raid script had to change.
 *  - Who is a boss: IsDungeonBoss() (the creature is an instance_encounters
 *    kill credit), isWorldBoss() (boss type flag), rank 3, or an AI derived
 *    from BossAI. instance_encounters alone misses councils and rotating
 *    bosses (Lethon, Emeriss and Taerar in Emerald Sanctum, Lord Stavros and
 *    Castellan Niklaus in Castle Nathria, the Four Horsemen in Naxx40), and
 *    rank alone misses the rank-1 Blackwing Descent bosses, so the signals
 *    are combined. DC.RaidFlex.ExtraBossEntries / ExcludeEntries adjust it.
 *  - Headcount: Map::GetPlayersCountExceptGMs() (bots are players and count;
 *    GMs and spectators do not), clamped to the rule's min..max.
 *  - factor = (clamped / nominal) ^ DC.RaidFlex.HealthExponent, where
 *    nominal is the difficulty's own size from MapDifficulty.dbc (10, 25,
 *    20, or 40 for Naxx40) unless the rule names one.
 *  - The factor multiplies the creature's UNIT_MOD_HEALTH base value as it
 *    stands at engage, which already holds the template, the rank rate and
 *    the Mythic+ difficulty profile (Timbermaw Hold and Emerald Sanctum
 *    Heroic/Mythic scale health there at spawn). Health auras still apply on
 *    top, so everything composes multiplicatively. Health percent is kept.
 *  - Once per pull. A player or bot who zones in mid-fight does not change
 *    the boss, and leaving the instance cannot shrink it. A mid-fight
 *    re-engage (a script that drops combat for an intermission) re-reads the
 *    headcount, still keeping the percent.
 *  - The original values are kept on the creature (CustomData) and put back
 *    on evade and on death. A new pull always scales from the original, so
 *    pulls never compound, even if a script resets the boss without going
 *    through the evade hook. If something else rewrote the base value in the
 *    meantime (UpdateEntry, SelectLevel), that value wins and the snapshot is
 *    dropped.
 *
 * Bonus loot
 *  - MiscScript OnAfterLootTemplateProcess: runs inside Loot::FillLoot right
 *    after the loot template was rolled and before group loot rights and the
 *    quality threshold are assigned, so the extra items are ordinary group
 *    loot in the boss's loot window. Nobody gets an item granted directly.
 *  - The extra items come from the boss's own loot template: it is rolled
 *    again into a scratch Loot and items that did not drop yet are picked
 *    from that roll (quality >= MinQuality, non-stacking, not quest items).
 *  - The count follows DC.RaidFlex.BonusLoot.Tiers (players:items), using
 *    the headcount the boss was scaled for. Boss chests (Cache of the Sun
 *    King, the Four Horsemen chest) are listed in ChestEntries and use the
 *    live headcount.
 *
 * Threading: every hook runs on the map thread that owns the creature, and
 * the per-boss state lives in that creature's CustomData, so no state is
 * shared between maps. The parsed config is shared and is swapped under a
 * mutex (.reload config can run on a map thread when a GM types it).
 */

#include "Config.h"
#include "Creature.h"
#include "DataMap.h"
#include "GameObject.h"
#include "ItemTemplate.h"
#include "Log.h"
#include "LootMgr.h"
#include "Map.h"
#include "ObjectMgr.h"
#include "Player.h"
#include "ScriptMgr.h"
#include "ScriptedCreature.h"
#include "StringConvert.h"
#include "Tokenize.h"
#include <algorithm>
#include <atomic>
#include <cmath>
#include <limits>
#include <memory>
#include <mutex>
#include <string>
#include <string_view>
#include <unordered_map>
#include <unordered_set>
#include <vector>

namespace
{
    constexpr char const* FLEX_STATE_KEY = "dc.raidflex";

    // The DC custom raids and their difficulties (Map.dbc InstanceType 2, MapDifficulty.dbc sizes):
    //   2296 Castle Nathria     0/1/2/3 = 10/25/10/25
    //    669 Blackwing Descent  0/1/2/3 = 10/25/10/25
    //   2921 Naxxramas (40)     2       = 40 (Naxx40PrepareRaidDifficulty forces 10-man heroic)
    //    819 Timbermaw Hold     0/1/2   = 20 (Normal/Heroic/Mythic)
    //    824 Emerald Sanctum    0/1/2   = 20 (Normal/Heroic/Mythic)
    // Crescent Grove (823) is a 5-player dungeon, not a raid.
    constexpr char const* DEFAULT_MAPS =
        "2296:0:5:10 2296:1:10:25 2296:2:5:10 2296:3:10:25 "
        "669:0:5:10 669:1:10:25 669:2:5:10 669:3:10:25 "
        "2921:2:15:40 "
        "819:0:10:20 819:1:10:20 819:2:10:20 "
        "824:0:10:20 824:1:10:20 824:2:10:20";

    constexpr char const* DEFAULT_LOOT_TIERS = "15:1 20:2 30:3";

    // Cache of the Sun King (Castle Nathria), Four Horsemen chest (Naxx40).
    constexpr char const* DEFAULT_CHESTS = "357752 361000";

    // How often the loot template is re-rolled to find items that did not drop yet.
    constexpr uint32 BONUS_LOOT_ROLL_ATTEMPTS = 4;

    constexpr float MAX_HEALTH_EXPONENT = 4.0f;

    struct FlexRule
    {
        uint32 minPlayers = 0;
        uint32 maxPlayers = 0;
        uint32 nominal = 0;   // 0 = the difficulty's size from MapDifficulty.dbc
    };

    struct LootTier
    {
        uint32 minPlayers = 0;
        uint32 extraItems = 0;
    };

    struct RaidFlexConfig
    {
        bool enabled = false;
        float healthExponent = 1.0f;
        std::unordered_map<uint32, FlexRule> rules;   // key: RuleKey(map, difficulty)
        std::unordered_set<uint32> extraBossEntries;
        std::unordered_set<uint32> excludedEntries;
        bool bonusLootEnabled = false;
        std::vector<LootTier> lootTiers;              // ascending by minPlayers
        uint32 bonusLootMinQuality = ITEM_QUALITY_RARE;
        std::unordered_set<uint32> chestEntries;
    };

    std::mutex sConfigLock;
    std::shared_ptr<RaidFlexConfig const> sConfig;
    std::atomic<bool> sEnabled{false};

    std::shared_ptr<RaidFlexConfig const> GetConfig()
    {
        std::lock_guard<std::mutex> guard(sConfigLock);
        return sConfig;
    }

    uint32 RuleKey(uint32 mapId, uint32 difficulty)
    {
        return (mapId << 8) | (difficulty & 0xFF);
    }

    // Per-boss state, kept on the creature itself.
    struct FlexState : public DataMap::Base
    {
        uint32 entry = 0;                 // entry the snapshot was taken for
        float originalBase = 0.0f;        // UNIT_MOD_HEALTH BASE_VALUE before scaling
        uint32 originalCreateHealth = 0;  // UNIT_FIELD_BASE_HEALTH before scaling
        float appliedBase = 0.0f;         // BASE_VALUE this script wrote
        uint32 headcount = 0;             // clamped headcount of the pull
        bool scaled = false;
    };

    struct ResolvedRule
    {
        uint32 minPlayers = 0;
        uint32 maxPlayers = 0;
        uint32 nominal = 0;
    };

    // ---------------------------------------------------------------- config

    std::string NormalizeSeparators(std::string text)
    {
        std::replace_if(text.begin(), text.end(), [](char c) { return c == ',' || c == ';' || c == '\t'; }, ' ');
        return text;
    }

    std::unordered_set<uint32> ParseEntrySet(std::string const& key, std::string const& text)
    {
        std::unordered_set<uint32> result;
        std::string const normalized = NormalizeSeparators(text);
        for (std::string_view token : Acore::Tokenize(normalized, ' ', false))
        {
            if (Optional<uint32> entry = Acore::StringTo<uint32>(token))
                result.insert(*entry);
            else
                LOG_WARN("scripts.dc", "RaidFlex: {} has an invalid entry '{}', skipped.", key, token);
        }
        return result;
    }

    void ParseMapRules(std::string const& text, std::unordered_map<uint32, FlexRule>& rules)
    {
        std::string const normalized = NormalizeSeparators(text);
        for (std::string_view token : Acore::Tokenize(normalized, ' ', false))
        {
            std::vector<std::string_view> fields = Acore::Tokenize(token, ':', true);
            if (fields.size() != 4 && fields.size() != 5)
            {
                LOG_WARN("scripts.dc", "RaidFlex: DC.RaidFlex.Maps entry '{}' is not map:difficulty:min:max[:nominal], "
                    "skipped.", token);
                continue;
            }

            Optional<uint32> mapId = Acore::StringTo<uint32>(fields[0]);
            Optional<uint32> difficulty = Acore::StringTo<uint32>(fields[1]);
            Optional<uint32> minPlayers = Acore::StringTo<uint32>(fields[2]);
            Optional<uint32> maxPlayers = Acore::StringTo<uint32>(fields[3]);
            Optional<uint32> nominal = fields.size() == 5 ? Acore::StringTo<uint32>(fields[4]) : Optional<uint32>(0);

            if (!mapId || !difficulty || !minPlayers || !maxPlayers || !nominal || *difficulty >= MAX_RAID_DIFFICULTY
                || !*minPlayers || *maxPlayers < *minPlayers || *mapId > 0xFFFFFF)
            {
                LOG_WARN("scripts.dc", "RaidFlex: DC.RaidFlex.Maps entry '{}' has invalid values (difficulty 0-3, "
                    "1 <= min <= max), skipped.", token);
                continue;
            }

            FlexRule& rule = rules[RuleKey(*mapId, *difficulty)];
            rule.minPlayers = *minPlayers;
            rule.maxPlayers = *maxPlayers;
            rule.nominal = *nominal;
        }
    }

    std::vector<LootTier> ParseLootTiers(std::string const& text)
    {
        std::vector<LootTier> tiers;
        std::string const normalized = NormalizeSeparators(text);
        for (std::string_view token : Acore::Tokenize(normalized, ' ', false))
        {
            std::vector<std::string_view> fields = Acore::Tokenize(token, ':', true);
            Optional<uint32> players = fields.size() == 2 ? Acore::StringTo<uint32>(fields[0]) : Optional<uint32>();
            Optional<uint32> items = fields.size() == 2 ? Acore::StringTo<uint32>(fields[1]) : Optional<uint32>();
            if (!players || !items || !*players)
            {
                LOG_WARN("scripts.dc", "RaidFlex: DC.RaidFlex.BonusLoot.Tiers entry '{}' is not players:items, "
                    "skipped.", token);
                continue;
            }

            tiers.push_back({ *players, std::min<uint32>(*items, MAX_NR_LOOT_ITEMS) });
        }

        std::sort(tiers.begin(), tiers.end(), [](LootTier const& a, LootTier const& b)
        {
            return a.minPlayers < b.minPlayers;
        });
        return tiers;
    }

    void LoadConfig()
    {
        auto config = std::make_shared<RaidFlexConfig>();

        config->enabled = sConfigMgr->GetOption<bool>("DC.RaidFlex.Enable", true);
        config->healthExponent = std::clamp(sConfigMgr->GetOption<float>("DC.RaidFlex.HealthExponent", 1.0f), 0.0f,
            MAX_HEALTH_EXPONENT);
        ParseMapRules(sConfigMgr->GetOption<std::string>("DC.RaidFlex.Maps", DEFAULT_MAPS), config->rules);
        config->extraBossEntries = ParseEntrySet("DC.RaidFlex.ExtraBossEntries",
            sConfigMgr->GetOption<std::string>("DC.RaidFlex.ExtraBossEntries", ""));
        config->excludedEntries = ParseEntrySet("DC.RaidFlex.ExcludeEntries",
            sConfigMgr->GetOption<std::string>("DC.RaidFlex.ExcludeEntries", ""));

        config->bonusLootEnabled = sConfigMgr->GetOption<bool>("DC.RaidFlex.BonusLoot.Enable", true);
        config->lootTiers = ParseLootTiers(sConfigMgr->GetOption<std::string>("DC.RaidFlex.BonusLoot.Tiers",
            DEFAULT_LOOT_TIERS));
        config->bonusLootMinQuality = std::min<uint32>(sConfigMgr->GetOption<uint32>("DC.RaidFlex.BonusLoot.MinQuality",
            ITEM_QUALITY_RARE), MAX_ITEM_QUALITY - 1);
        config->chestEntries = ParseEntrySet("DC.RaidFlex.BonusLoot.ChestEntries",
            sConfigMgr->GetOption<std::string>("DC.RaidFlex.BonusLoot.ChestEntries", DEFAULT_CHESTS));

        if (!config->enabled)
            LOG_INFO("scripts.dc", "RaidFlex: disabled (DC.RaidFlex.Enable = 0).");
        else
            LOG_INFO("scripts.dc", "RaidFlex: {} map rules, health exponent {:.2f}, bonus loot {} ({} tiers, "
                "{} chests).", config->rules.size(), config->healthExponent,
                config->bonusLootEnabled ? "on" : "off", config->lootTiers.size(), config->chestEntries.size());

        bool const enabled = config->enabled && !config->rules.empty();
        {
            std::lock_guard<std::mutex> guard(sConfigLock);
            sConfig = std::move(config);
        }
        sEnabled.store(enabled, std::memory_order_release);
    }

    // ----------------------------------------------------------------- rules

    bool ResolveRule(RaidFlexConfig const& config, Map* map, ResolvedRule& out)
    {
        if (!map || !map->IsRaid())
            return false;

        auto itr = config.rules.find(RuleKey(map->GetId(), map->GetSpawnMode()));
        if (itr == config.rules.end())
            return false;

        out.minPlayers = itr->second.minPlayers;
        out.maxPlayers = itr->second.maxPlayers;
        out.nominal = itr->second.nominal;

        if (!out.nominal)
            if (InstanceMap* instance = map->ToInstanceMap())
                out.nominal = instance->GetMaxPlayers();

        if (!out.nominal)
            out.nominal = map->Is25ManRaid() ? 25 : 10;

        return true;
    }

    uint32 ClampedHeadcount(Map* map, ResolvedRule const& rule)
    {
        return std::clamp(map->GetPlayersCountExceptGMs(), rule.minPlayers, rule.maxPlayers);
    }

    bool IsFlexBoss(RaidFlexConfig const& config, Creature* creature)
    {
        uint32 const entry = creature->GetEntry();
        uint32 const templateEntry = creature->GetCreatureTemplate()->Entry;

        if (config.excludedEntries.count(entry) || config.excludedEntries.count(templateEntry))
            return false;

        if (config.extraBossEntries.count(entry) || config.extraBossEntries.count(templateEntry))
            return true;

        if (creature->IsPet() || creature->IsTotem() || creature->IsTrigger() || creature->IsCritter())
            return false;

        if (creature->GetCharmerOrOwnerGUID().IsPlayer())
            return false;

        if (creature->IsDungeonBoss() || creature->isWorldBoss())
            return true;

        if (creature->GetCreatureTemplate()->rank == CREATURE_ELITE_WORLDBOSS)
            return true;

        return dynamic_cast<BossAI const*>(creature->AI()) != nullptr;
    }

    // ---------------------------------------------------------------- health

    bool NearlyEqual(float a, float b)
    {
        return std::fabs(a - b) <= std::max(1.0f, std::fabs(b) * 1e-5f);
    }

    void SetHealthKeepingPct(Creature* creature, float pct)
    {
        if (!creature->IsAlive())
            return;

        uint32 const maxHealth = creature->GetMaxHealth();
        if (!maxHealth)
            return;

        // llround, not lround: long is 32 bits on Windows and boss health can exceed it.
        uint32 const health = uint32(std::min<long long>(std::llround(double(maxHealth) * double(pct) / 100.0),
            maxHealth));
        creature->SetHealth(std::clamp<uint32>(health, 1, maxHealth));
    }

    void WriteHealthBase(Creature* creature, float base, uint32 createHealth)
    {
        float const pct = creature->GetMaxHealth() ? creature->GetHealthPct() : 100.0f;

        creature->SetCreateHealth(createHealth);
        creature->SetStatFlatModifier(UNIT_MOD_HEALTH, BASE_VALUE, base);
        creature->UpdateMaxHealth();

        SetHealthKeepingPct(creature, pct);
    }

    void ApplyFlexHealth(RaidFlexConfig const& config, Creature* creature)
    {
        Map* map = creature->GetMap();
        ResolvedRule rule;
        if (!ResolveRule(config, map, rule) || !IsFlexBoss(config, creature))
            return;

        // A boss scripted to fight NPCs before anyone has zoned in is not a pull. Scaling it to
        // the minimum here would stick, because the real pull then fires no second engage.
        uint32 const players = map->GetPlayersCountExceptGMs();
        if (!players)
            return;

        float const currentBase = creature->GetFlatModifierValue(UNIT_MOD_HEALTH, BASE_VALUE);
        FlexState* state = creature->CustomData.Get<FlexState>(FLEX_STATE_KEY);

        // Still carrying an earlier scale (combat dropped mid-fight, or a script reset the boss
        // without the evade hook): scale from the snapshot, never from the scaled value.
        bool const stillScaled = state && state->scaled && state->entry == creature->GetEntry()
            && NearlyEqual(currentBase, state->appliedBase);

        if (!stillScaled)
        {
            // A script that set max health directly (SetMaxHealth without the stat modifier) would
            // lose that value in UpdateMaxHealth. Leave such a creature alone.
            float const statMax = creature->GetTotalAuraModValue(UNIT_MOD_HEALTH);
            if (std::fabs(statMax - float(creature->GetMaxHealth())) > std::max(1.0f, statMax * 0.01f))
            {
                LOG_DEBUG("scripts.dc", "RaidFlex: {} ({}) has max health {} set outside the stat system ({:.0f}), "
                    "not scaled", creature->GetName(), creature->GetEntry(), creature->GetMaxHealth(), statMax);
                return;
            }

            if (!state)
                state = creature->CustomData.GetDefault<FlexState>(FLEX_STATE_KEY);

            state->entry = creature->GetEntry();
            state->originalBase = currentBase;
            state->originalCreateHealth = creature->GetCreateHealth();
            state->appliedBase = currentBase;
            state->scaled = false;
        }

        uint32 const clamped = std::clamp(players, rule.minPlayers, rule.maxPlayers);
        state->headcount = clamped;

        if (state->originalBase < 1.0f)
            return;

        double const factor = std::pow(double(clamped) / double(rule.nominal), double(config.healthExponent));
        bool const identity = std::fabs(factor - 1.0) < 0.001;

        if (identity && !stillScaled)
            return;

        // Upscaling (max above nominal) must not overflow the uint32 health field.
        double const cap = std::max<double>(state->originalBase, double(std::numeric_limits<int32>::max()));
        double const newBase = identity ? state->originalBase : std::clamp(state->originalBase * factor, 1.0, cap);
        double const newCreate = identity ? double(state->originalCreateHealth)
            : std::clamp(double(state->originalCreateHealth) * factor, 1.0, cap);

        uint32 const oldMax = creature->GetMaxHealth();
        WriteHealthBase(creature, float(newBase), uint32(newCreate));

        state->appliedBase = creature->GetFlatModifierValue(UNIT_MOD_HEALTH, BASE_VALUE);
        state->scaled = !identity;

        LOG_DEBUG("scripts.dc", "RaidFlex: {} ({}) map {} difficulty {}: {} players (clamped {}), nominal {}, "
            "factor {:.3f}, max health {} -> {}", creature->GetName(), creature->GetEntry(), map->GetId(),
            uint32(map->GetSpawnMode()), players, clamped, rule.nominal, factor, oldMax, creature->GetMaxHealth());
    }

    void RestoreFlexHealth(Creature* creature)
    {
        FlexState* state = creature->CustomData.Get<FlexState>(FLEX_STATE_KEY);
        if (!state)
            return;

        float const currentBase = creature->GetFlatModifierValue(UNIT_MOD_HEALTH, BASE_VALUE);
        if (state->scaled && state->entry == creature->GetEntry() && NearlyEqual(currentBase, state->appliedBase))
        {
            uint32 const oldMax = creature->GetMaxHealth();
            WriteHealthBase(creature, state->originalBase, state->originalCreateHealth);

            LOG_DEBUG("scripts.dc", "RaidFlex: {} ({}) restored, max health {} -> {}", creature->GetName(),
                creature->GetEntry(), oldMax, creature->GetMaxHealth());
        }

        // Anything else rewrote the base meanwhile (UpdateEntry, SelectLevel): that value stands.
        creature->CustomData.Erase(FLEX_STATE_KEY);
    }

    // ------------------------------------------------------------------ loot

    uint32 ExtraItemsFor(RaidFlexConfig const& config, uint32 headcount)
    {
        uint32 extra = 0;
        for (LootTier const& tier : config.lootTiers)
            if (headcount >= tier.minPlayers)
                extra = tier.extraItems;
        return extra;
    }

    bool IsBonusEligible(RaidFlexConfig const& config, LootItem const& item)
    {
        if (item.needs_quest || item.freeforall)
            return false;

        ItemTemplate const* proto = sObjectMgr->GetItemTemplate(item.itemid);
        if (!proto || proto->Class == ITEM_CLASS_QUEST || proto->HasFlag(ITEM_FLAG_MULTI_DROP))
            return false;

        // Stacking items are currencies and materials, not boss drops worth a slot.
        return proto->Quality >= config.bonusLootMinQuality && proto->GetMaxStackSize() == 1;
    }

    uint32 AddBonusItems(RaidFlexConfig const& config, Loot& loot, LootTemplate const& tab, LootStore const& store,
        Player* lootOwner, uint16 lootMode, uint32 wanted)
    {
        struct Candidate
        {
            uint32 itemId;
            ConditionList conditions;
        };

        std::vector<Candidate> candidates;
        auto const isTaken = [&loot, &candidates](uint32 itemId)
        {
            return std::any_of(loot.items.begin(), loot.items.end(),
                       [itemId](LootItem const& li) { return li.itemid == itemId; })
                || std::any_of(candidates.begin(), candidates.end(),
                       [itemId](Candidate const& c) { return c.itemId == itemId; });
        };

        for (uint32 attempt = 0; attempt < BONUS_LOOT_ROLL_ATTEMPTS && candidates.size() < wanted; ++attempt)
        {
            Loot scratch;
            scratch.lootOwnerGUID = loot.lootOwnerGUID;
            scratch.sourceWorldObjectGUID = loot.sourceWorldObjectGUID;
            tab.Process(scratch, store, lootMode, lootOwner);

            for (LootItem const& item : scratch.items)
            {
                if (candidates.size() >= wanted)
                    break;

                if (!IsBonusEligible(config, item) || isTaken(item.itemid))
                    continue;

                candidates.push_back({ item.itemid, item.conditions });
            }
        }

        uint32 added = 0;
        for (Candidate const& candidate : candidates)
        {
            if (loot.items.size() >= MAX_NR_LOOT_ITEMS)
                break;

            LootStoreItem storeItem(candidate.itemId, 0, 100.0f, false, LOOT_MODE_DEFAULT, 0, 1, 1);
            storeItem.conditions = candidate.conditions;

            size_t const before = loot.items.size();
            loot.AddItem(storeItem);
            if (loot.items.size() > before)
                ++added;
        }

        return added;
    }

    // --------------------------------------------------------------- scripts

    class dc_raid_flex_world : public WorldScript
    {
    public:
        dc_raid_flex_world() : WorldScript("dc_raid_flex_world", { WORLDHOOK_ON_AFTER_CONFIG_LOAD }) { }

        void OnAfterConfigLoad(bool /*reload*/) override
        {
            LoadConfig();
        }
    };

    class dc_raid_flex_unit : public UnitScript
    {
    public:
        dc_raid_flex_unit() : UnitScript("dc_raid_flex_unit", true,
            { UNITHOOK_ON_UNIT_ENTER_COMBAT, UNITHOOK_ON_UNIT_ENTER_EVADE_MODE, UNITHOOK_ON_UNIT_DEATH }) { }

        void OnUnitEnterCombat(Unit* unit, Unit* /*victim*/) override
        {
            if (!sEnabled.load(std::memory_order_acquire) || !unit || !unit->IsCreature())
                return;

            Map* map = unit->GetMap();
            if (!map || !map->IsRaid())
                return;

            std::shared_ptr<RaidFlexConfig const> config = GetConfig();
            if (!config || !config->enabled)
                return;

            ApplyFlexHealth(*config, unit->ToCreature());
        }

        // Restoring is not gated on DC.RaidFlex.Enable: a boss scaled before a config reload
        // turned the feature off still has to get its health back.
        void OnUnitEnterEvadeMode(Unit* unit, uint8 /*evadeReason*/) override
        {
            Restore(unit);
        }

        // Unit::Kill fills the loot before this hook, so the headcount is still there for it.
        void OnUnitDeath(Unit* unit, Unit* /*killer*/) override
        {
            Restore(unit);
        }

    private:
        static void Restore(Unit* unit)
        {
            if (!unit || !unit->IsCreature())
                return;

            Map* map = unit->GetMap();
            if (!map || !map->IsRaid())
                return;

            RestoreFlexHealth(unit->ToCreature());
        }
    };

    class dc_raid_flex_loot : public MiscScript
    {
    public:
        dc_raid_flex_loot() : MiscScript("dc_raid_flex_loot", { MISCHOOK_ON_AFTER_LOOT_TEMPLATE_PROCESS }) { }

        void OnAfterLootTemplateProcess(Loot* loot, LootTemplate const* tab, LootStore const& store, Player* lootOwner,
            bool /*personal*/, bool /*noEmptyError*/, uint16 lootMode) override
        {
            // Fires for every loot fill on the server: structural tests first.
            if (!sEnabled.load(std::memory_order_acquire) || !loot || !tab || !lootOwner)
                return;

            bool const fromCreature = &store == &LootTemplates_Creature;
            if (!fromCreature && &store != &LootTemplates_Gameobject)
                return;

            Map* map = lootOwner->FindMap();
            if (!map || !map->IsRaid())
                return;

            std::shared_ptr<RaidFlexConfig const> config = GetConfig();
            if (!config || !config->enabled || !config->bonusLootEnabled || config->lootTiers.empty())
                return;

            ResolvedRule rule;
            if (!ResolveRule(*config, map, rule))
                return;

            uint32 headcount = 0;
            uint32 sourceEntry = 0;
            if (fromCreature)
            {
                Creature* creature = map->GetCreature(loot->sourceWorldObjectGUID);
                if (!creature || !IsFlexBoss(*config, creature))
                    return;

                if (FlexState const* state = creature->CustomData.Get<FlexState>(FLEX_STATE_KEY))
                    headcount = state->headcount;

                sourceEntry = creature->GetEntry();
            }
            else
            {
                GameObject* chest = map->GetGameObject(loot->sourceWorldObjectGUID);
                if (!chest || !config->chestEntries.count(chest->GetEntry()))
                    return;

                sourceEntry = chest->GetEntry();
            }

            if (!headcount)
                headcount = ClampedHeadcount(map, rule);

            uint32 const wanted = ExtraItemsFor(*config, headcount);
            if (!wanted)
                return;

            uint32 const added = AddBonusItems(*config, *loot, *tab, store, lootOwner, lootMode, wanted);

            LOG_DEBUG("scripts.dc", "RaidFlex: bonus loot for {} {} on map {} difficulty {}: {} players, {} of {} "
                "extra items added", fromCreature ? "creature" : "chest", sourceEntry, map->GetId(),
                uint32(map->GetSpawnMode()), headcount, added, wanted);
        }
    };
}

void AddSC_dc_raid_flex()
{
    new dc_raid_flex_world();
    new dc_raid_flex_unit();
    new dc_raid_flex_loot();
}
