/*
 * Dark Chaos - Talent Build Addon Handler (TLNT)
 * ==============================================
 *
 * Server side of the DC-Talents addon (the retail talent UI ported to 3.3.5).
 * Retail stages talent changes and commits them as one build, points taken OUT
 * of the tree included; WotLK can only add points and needs a paid trainer
 * reset to remove any. This module applies a whole staged build in one message,
 * free of charge, out of combat.
 *
 * Wire contract (JSON; opcodes in Opcode::Talents, dc_addon_namespace.h):
 *   CMSG_HELLO           {}                        -> SMSG_HELLO {v, enabled, freeRespec, pet, max}
 *   CMSG_APPLY_BUILD     {req, spec, t:[{id, r}]}  -> SMSG_APPLY_RESULT
 *   CMSG_APPLY_PET_BUILD {req, t:[{id, r}]}        -> SMSG_APPLY_PET_RESULT
 *   both results: {req, ok, code, msg, spent, failed:[talentId]}
 *
 * `t` is the complete target build: Talent.dbc id -> 1-based rank, and a talent
 * that is not listed is rank 0. `spec` is the 1-based talent group the client
 * edited and must be the active one; only the active spec is ever touched.
 *
 * Nothing changes until the whole build is known to apply. The learn calls are
 * first replayed against a model of the tree with the exact checks of
 * Player::LearnTalent / Player::LearnPetTalent (free points, script hook,
 * prerequisite, tier gate), in the order they will really run, so a build that
 * passes cannot stop half-way. Then:
 *   - every rank >= current: only the missing ranks are learned, no reset;
 *   - any rank lower: the active spec (or the pet) is reset free of charge and
 *     the full build relearned. Gated on DC.Talents.FreeRespec.
 * SMSG_TALENTS_INFO goes out before the result, so the client's own talent data
 * is current by the time the result arrives.
 *
 * Copyright (C) 2026 Dark Chaos Development Team
 */

#include "dc_addon_namespace.h"
#include "Config.h"
#include "CreatureData.h"
#include "DBCStores.h"
#include "DatabaseEnv.h"
#include "InstanceScript.h"
#include "Item.h"
#include "Log.h"
#include "Map.h"
#include "Pet.h"
#include "Player.h"
#include "ScriptMgr.h"
#include "SpellAuraEffects.h"
#include "SpellAuras.h"
#include "SpellMgr.h"
#include "Timer.h"

#include <algorithm>
#include <array>
#include <cmath>
#include <limits>
#include <map>
#include <set>
#include <string>
#include <unordered_map>
#include <utility>
#include <vector>

namespace DCAddon
{
namespace Talents
{
    constexpr uint32 PROTOCOL_VERSION = 1;
    constexpr uint32 MAX_BUILD_ENTRIES = 150;   // same cap as CMSG_LEARN_PREVIEW_TALENTS
    constexpr uint32 APPLY_INTERVAL_MS = 1000;  // at most one apply per second, per build kind

    constexpr char const* PET_LOADING_TEXT = "Your pet is still being summoned. Try again in a moment.";

    static bool IsEnabled()
    {
        return sConfigMgr->GetOption<bool>("DC.AddonProtocol.Talents.Enable", true);
    }

    static bool IsFreeRespecEnabled()
    {
        return sConfigMgr->GetOption<bool>("DC.Talents.FreeRespec", true);
    }

    enum class BuildKind : uint8
    {
        Player = 0,
        Pet    = 1
    };

    // ------------------------------------------------------------------------
    // Result codes
    // ------------------------------------------------------------------------
    enum class ApplyCode : uint8
    {
        Ok,
        NoChange,
        Disabled,
        Busy,
        Dead,
        Combat,
        Battleground,
        Encounter,
        WrongSpec,
        BadRequest,
        BadTalent,
        BadRank,
        Duplicate,
        TooMany,
        NotEnoughPoints,
        TierLocked,
        Prereq,
        ScriptBlocked,
        RespecDisabled,
        NoPet,
        Partial
    };

    struct ApplyCodeInfo
    {
        char const* name;
        char const* text;
    };

    static ApplyCodeInfo GetCodeInfo(ApplyCode code)
    {
        switch (code)
        {
            case ApplyCode::Ok:
                return { "OK", "" };
            case ApplyCode::NoChange:
                return { "NO_CHANGE", "No talent changes to apply." };
            case ApplyCode::Disabled:
                return { "DISABLED", "Talent changes are disabled on this server." };
            case ApplyCode::Busy:
                return { "BUSY", "You are changing talents too quickly. Try again in a moment." };
            case ApplyCode::Dead:
                return { "DEAD", "You can't change talents while dead." };
            case ApplyCode::Combat:
                return { "COMBAT", "You can't change talents while in combat." };
            case ApplyCode::Battleground:
                return { "BATTLEGROUND", "You can't change talents in a battleground or arena." };
            case ApplyCode::Encounter:
                return { "ENCOUNTER", "You can't change talents while an encounter is in progress." };
            case ApplyCode::WrongSpec:
                return { "WRONG_SPEC", "Your active specialization has changed. Please try again." };
            case ApplyCode::BadRequest:
                return { "BAD_REQUEST", "The talent request was malformed." };
            case ApplyCode::BadTalent:
                return { "BAD_TALENT", "The build contains a talent you can't learn." };
            case ApplyCode::BadRank:
                return { "BAD_RANK", "The build contains an invalid talent rank." };
            case ApplyCode::Duplicate:
                return { "DUPLICATE", "The build lists a talent more than once." };
            case ApplyCode::TooMany:
                return { "TOO_MANY", "The build lists too many talents." };
            case ApplyCode::NotEnoughPoints:
                return { "NOT_ENOUGH_POINTS", "You don't have enough talent points for this build." };
            case ApplyCode::TierLocked:
                return { "TIER_LOCKED", "A talent needs more points spent in its tree first." };
            case ApplyCode::Prereq:
                return { "PREREQ", "A talent is missing its prerequisite." };
            case ApplyCode::ScriptBlocked:
                return { "SCRIPT_BLOCKED", "A talent in this build can't be learned right now." };
            case ApplyCode::RespecDisabled:
                return { "RESPEC_DISABLED", "Removing talent points is disabled on this server." };
            case ApplyCode::NoPet:
                return { "NO_PET", "You have no pet that can learn talents." };
            case ApplyCode::Partial:
                return { "PARTIAL", "Some talents could not be applied." };
        }

        return { "FAILED", "Your talent changes could not be applied." };
    }

    struct ApplyResult
    {
        ApplyCode code = ApplyCode::Ok;
        std::vector<uint32> failed; // talents that did not (or would not) reach their target rank
        std::string text;           // overrides the code's default text when set
    };

    static ApplyResult MakeResult(ApplyCode code, std::vector<uint32> failed = {}, std::string text = {})
    {
        ApplyResult result;
        result.code = code;
        result.failed = std::move(failed);
        result.text = std::move(text);
        return result;
    }

    // Talent.dbc id -> 1-based rank. Ordered, so builds compare and log deterministically.
    using RankMap = std::map<uint32, uint8>;

    static uint8 GetRank(RankMap const& ranks, uint32 talentId)
    {
        auto const itr = ranks.find(talentId);
        return itr != ranks.end() ? itr->second : uint8(0);
    }

    static uint32 SumRanks(RankMap const& ranks)
    {
        uint32 total = 0;
        for (auto const& entry : ranks)
            total += entry.second;
        return total;
    }

    // ------------------------------------------------------------------------
    // Request parsing
    // ------------------------------------------------------------------------

    // JsonValue::AsUInt32 is a bare cast; negative, fractional or oversized input must
    // be refused, not wrapped.
    static bool TryReadUInt(JsonValue const& value, uint32 maxValue, uint32& out)
    {
        if (!value.IsNumber())
            return false;

        double const number = value.AsNumber();
        if (!(number >= 0.0) || number > static_cast<double>(maxValue) || std::floor(number) != number)
            return false;

        out = static_cast<uint32>(number);
        return true;
    }

    static uint32 ReadRequestId(JsonValue const& json)
    {
        uint32 req = 0;
        TryReadUInt(json["req"], std::numeric_limits<uint32>::max(), req);
        return req;
    }

    // The inbound JSON parser is lenient: a body cut short still parses, with however many
    // array entries made it. For a build that reads as "unlearn everything after the cut",
    // so the body must be exactly one closed object with balanced brackets.
    static bool IsCompleteJsonObject(ParsedMessage const& msg)
    {
        if (!IsJsonMessage(msg))
            return false;

        std::string const body = msg.GetString(1);
        std::size_t const first = body.find_first_not_of(" \t\r\n");
        if (first == std::string::npos || body[first] != '{')
            return false;

        std::size_t const last = body.find_last_not_of(" \t\r\n");
        std::string closers;
        bool inString = false;
        for (std::size_t i = first; i <= last; ++i)
        {
            char const c = body[i];
            if (inString)
            {
                if (c == '\\')
                    ++i;
                else if (c == '"')
                    inString = false;
                continue;
            }

            switch (c)
            {
                case '"':
                    inString = true;
                    break;
                case '{':
                    closers.push_back('}');
                    break;
                case '[':
                    closers.push_back(']');
                    break;
                case '}':
                case ']':
                    if (closers.empty() || closers.back() != c)
                        return false;
                    closers.pop_back();
                    if (closers.empty())
                        return i == last;
                    break;
                default:
                    break;
            }
        }

        return false;
    }

    static bool TabBelongsTo(TalentTabEntry const* tab, BuildKind kind, uint32 ownerMask)
    {
        if (kind == BuildKind::Pet)
            return (tab->petTalentMask & ownerMask) != 0;

        return !tab->petTalentMask && (tab->ClassMask & ownerMask) != 0;
    }

    // Learnable ranks: LearnPetTalent stops at MAX_PET_TALENT_RANK, and neither learn
    // function accepts a rank index whose RankID is 0.
    static uint8 GetRankCount(TalentEntry const* talent, BuildKind kind)
    {
        uint8 const limit = kind == BuildKind::Pet ? MAX_PET_TALENT_RANK : MAX_TALENT_RANK;
        uint8 count = 0;
        for (uint8 rank = 0; rank < limit; ++rank)
            if (talent->RankID[rank])
                ++count;

        return count;
    }

    // Resolves and validates every entry before anything is touched. `ownerMask` is the
    // player's class mask, or the pet family's talent-tab bit for pet builds.
    static ApplyResult ParseBuild(JsonValue const& list, BuildKind kind, uint32 ownerMask, RankMap& ranks)
    {
        // An empty Lua table encodes as {} rather than [], so that is an empty build.
        if (list.IsObject() && !list.Size())
            return {};

        if (!list.IsArray())
            return MakeResult(ApplyCode::BadRequest);

        if (list.Size() > MAX_BUILD_ENTRIES)
            return MakeResult(ApplyCode::TooMany);

        for (JsonValue const& entry : list.AsArray())
        {
            uint32 talentId = 0;
            if (!entry.IsObject() || !TryReadUInt(entry["id"], std::numeric_limits<uint32>::max(), talentId))
                return MakeResult(ApplyCode::BadTalent);

            TalentEntry const* talent = sTalentStore.LookupEntry(talentId);
            TalentTabEntry const* tab = talent ? sTalentTabStore.LookupEntry(talent->TalentTab) : nullptr;
            if (!tab || !TabBelongsTo(tab, kind, ownerMask))
                return MakeResult(ApplyCode::BadTalent, { talentId });

            uint32 rank = 0;
            if (!TryReadUInt(entry["r"], MAX_TALENT_RANK, rank) || !rank || rank > uint32(GetRankCount(talent, kind))
                || !talent->RankID[rank - 1] || !sSpellMgr->GetSpellInfo(talent->RankID[rank - 1]))
                return MakeResult(ApplyCode::BadRank, { talentId });

            if (!ranks.emplace(talentId, static_cast<uint8>(rank)).second)
                return MakeResult(ApplyCode::Duplicate, { talentId });
        }

        return {};
    }

    // ------------------------------------------------------------------------
    // Current state
    // ------------------------------------------------------------------------

    // Active-spec ranks, read the way Player::LearnTalent reads them.
    static RankMap ReadPlayerRanks(Player* player)
    {
        RankMap ranks;
        uint8 const spec = player->GetActiveSpec();
        for (auto const& [spellId, talent] : player->GetTalentMap())
        {
            if (talent->State == PLAYERSPELL_REMOVED || !talent->IsInSpec(spec))
                continue;

            TalentSpellPos const* pos = GetTalentSpellPos(spellId);
            if (!pos)
                continue;

            uint8 const rank = pos->rank + 1;
            auto const [itr, inserted] = ranks.emplace(pos->talent_id, rank);
            if (!inserted && rank < itr->second)
                itr->second = rank; // LearnTalent takes the lowest rank it finds
        }

        return ranks;
    }

    // The player's hunter pet and its family's talent-tab bit, or nullptr. Pet builds follow
    // LearnPetTalent, which only serves hunter pets of a family that has a talent tree.
    static Pet* GetTalentPet(Player* player, uint32& familyMask)
    {
        Pet* pet = player->GetPet();
        if (!pet || pet->getPetType() != HUNTER_PET)
            return nullptr;

        CreatureTemplate const* creature = pet->GetCreatureTemplate();
        CreatureFamilyEntry const* family = creature ? sCreatureFamilyStore.LookupEntry(creature->family) : nullptr;
        if (!family || family->petTalentType < 0)
            return nullptr;

        familyMask = 1u << family->petTalentType;
        return pet;
    }

    // Pet ranks, read the way Player::LearnPetTalent reads them (highest known rank).
    static RankMap ReadPetRanks(Pet* pet, uint32 familyMask)
    {
        RankMap ranks;
        for (uint32 talentId = 0; talentId < sTalentStore.GetNumRows(); ++talentId)
        {
            TalentEntry const* talent = sTalentStore.LookupEntry(talentId);
            if (!talent)
                continue;

            TalentTabEntry const* tab = sTalentTabStore.LookupEntry(talent->TalentTab);
            if (!tab || !(tab->petTalentMask & familyMask))
                continue;

            for (uint8 rank = MAX_TALENT_RANK; rank-- > 0;)
            {
                if (talent->RankID[rank] && pet->HasSpell(talent->RankID[rank]))
                {
                    ranks[talent->TalentID] = rank + 1;
                    break;
                }
            }
        }

        return ranks;
    }

    // Talents the build takes points out of. Any at all means a reset.
    static std::vector<uint32> GetLoweredTalents(RankMap const& target, RankMap const& current)
    {
        std::vector<uint32> lowered;
        for (auto const& [talentId, rank] : current)
            if (GetRank(target, talentId) < rank)
                lowered.push_back(talentId);

        return lowered;
    }

    // Talents whose rank after the apply differs from the build.
    static std::vector<uint32> GetMismatches(RankMap const& target, RankMap const& before, RankMap const& after)
    {
        std::set<uint32> talentIds;
        for (RankMap const* ranks : { &target, &before, &after })
            for (auto const& entry : *ranks)
                talentIds.insert(entry.first);

        std::vector<uint32> failed;
        for (uint32 talentId : talentIds)
            if (GetRank(after, talentId) != GetRank(target, talentId))
                failed.push_back(talentId);

        return failed;
    }

    // ------------------------------------------------------------------------
    // Learn order and validation
    // ------------------------------------------------------------------------
    struct BuildStep
    {
        TalentEntry const* talent;
        TalentTabEntry const* tab;
        uint8 rank; // 1-based target rank
    };

    // Within one tier: column order, except that a prerequisite sitting in the SAME tier
    // (the horizontal arrows) must be learned before its dependent.
    static void OrderTierByPrerequisites(std::vector<BuildStep>::iterator first, std::vector<BuildStep>::iterator last)
    {
        std::vector<BuildStep> pending(first, last);
        for (auto out = first; out != last; ++out)
        {
            auto next = std::find_if(pending.begin(), pending.end(), [&pending](BuildStep const& step)
            {
                return std::none_of(pending.begin(), pending.end(), [&step](BuildStep const& other)
                {
                    return other.talent->TalentID == step.talent->DependsOn;
                });
            });

            // Only a broken Talent.dbc has a prerequisite cycle; keep column order and let
            // the validation report the entry as PREREQ.
            if (next == pending.end())
                next = pending.begin();

            *out = *next;
            pending.erase(next);
        }
    }

    // The learn calls in the order they will run: tab, tier, then OrderTierByPrerequisites.
    // Only talents the build raises above `start` get a call.
    static std::vector<BuildStep> OrderSteps(RankMap const& target, RankMap const& start)
    {
        std::vector<BuildStep> steps;
        for (auto const& [talentId, rank] : target)
        {
            if (rank <= GetRank(start, talentId))
                continue;

            TalentEntry const* talent = sTalentStore.LookupEntry(talentId);
            steps.push_back({ talent, sTalentTabStore.LookupEntry(talent->TalentTab), rank });
        }

        std::sort(steps.begin(), steps.end(), [](BuildStep const& a, BuildStep const& b)
        {
            if (a.tab->tabpage != b.tab->tabpage)
                return a.tab->tabpage < b.tab->tabpage;
            if (a.talent->TalentTab != b.talent->TalentTab)
                return a.talent->TalentTab < b.talent->TalentTab;
            if (a.talent->Row != b.talent->Row)
                return a.talent->Row < b.talent->Row;
            if (a.talent->Col != b.talent->Col)
                return a.talent->Col < b.talent->Col;
            return a.talent->TalentID < b.talent->TalentID;
        });

        for (auto first = steps.begin(); first != steps.end();)
        {
            auto const last = std::find_if(first, steps.end(), [first](BuildStep const& step)
            {
                return step.talent->TalentTab != first->talent->TalentTab || step.talent->Row != first->talent->Row;
            });

            OrderTierByPrerequisites(first, last);
            first = last;
        }

        return steps;
    }

    // LearnTalent / LearnPetTalent: the DependsOn talent must be known at 0-based rank
    // DependsOnRank or higher. A DependsOn missing from Talent.dbc is no requirement.
    static bool HasPrerequisite(TalentEntry const* talent, RankMap const& model)
    {
        if (!talent->DependsOn)
            return true;

        TalentEntry const* prerequisite = sTalentStore.LookupEntry(talent->DependsOn);
        if (!prerequisite)
            return true;

        return uint32(GetRank(model, prerequisite->TalentID)) > talent->DependsOnRank;
    }

    struct LearnRules
    {
        uint32 pointsPerTier; // MAX_TALENT_RANK for players, MAX_PET_TALENT_RANK for pets
        Player* scriptOwner;  // runs OnPlayerCanLearnTalent like LearnTalent; nullptr for pets
    };

    // Replays the learn calls against a model of the tree, with the checks of
    // Player::LearnTalent / Player::LearnPetTalent in their order. A failed step is left
    // unlearned, as the core would leave it, and the replay goes on, so `failed` lists
    // everything that would not apply; `code` is the first failure.
    static ApplyResult ValidateBuild(std::vector<BuildStep> const& steps, RankMap model, uint32 pool,
        LearnRules const& rules)
    {
        uint32 needed = 0;
        for (BuildStep const& step : steps)
            needed += step.rank - GetRank(model, step.talent->TalentID);

        if (needed > pool)
            return MakeResult(ApplyCode::NotEnoughPoints);

        // The tier gate counts every point in the tab, the step's own tier included.
        std::unordered_map<uint32, uint32> tabSpent;
        for (auto const& [talentId, rank] : model)
            if (TalentEntry const* talent = sTalentStore.LookupEntry(talentId))
                tabSpent[talent->TalentTab] += rank;

        ApplyResult result;
        auto const fail = [&result](ApplyCode code, uint32 talentId)
        {
            if (result.code == ApplyCode::Ok)
                result.code = code;
            result.failed.push_back(talentId);
        };

        for (BuildStep const& step : steps)
        {
            TalentEntry const* talent = step.talent;
            uint32 const cost = uint32(step.rank) - GetRank(model, talent->TalentID);

            if (!pool)
                fail(ApplyCode::NotEnoughPoints, talent->TalentID);
            else if (rules.scriptOwner && !sScriptMgr->OnPlayerCanLearnTalent(rules.scriptOwner, talent, step.rank - 1))
                fail(ApplyCode::ScriptBlocked, talent->TalentID);
            else if (pool < cost)
                fail(ApplyCode::NotEnoughPoints, talent->TalentID);
            else if (!HasPrerequisite(talent, model))
                fail(ApplyCode::Prereq, talent->TalentID);
            else if (tabSpent[talent->TalentTab] < talent->Row * rules.pointsPerTier)
                fail(ApplyCode::TierLocked, talent->TalentID);
            else
            {
                model[talent->TalentID] = step.rank;
                tabSpent[talent->TalentTab] += cost;
                pool -= cost;
            }
        }

        return result;
    }

    // ------------------------------------------------------------------------
    // Guards
    // ------------------------------------------------------------------------
    struct ApplyThrottle : public DataMap::Base
    {
        std::array<uint32, 2> lastApplyMs{};
        std::array<bool, 2> applied{};
    };

    // Player and pet builds are throttled separately, so one "apply" that changes both
    // is not refused half-way.
    static bool TryConsumeApplySlot(Player* player, BuildKind kind)
    {
        ApplyThrottle* throttle = player->CustomData.GetDefault<ApplyThrottle>("DCTalentsApplyThrottle");
        std::size_t const index = static_cast<std::size_t>(kind);
        uint32 const now = getMSTime();
        if (throttle->applied[index] && getMSTimeDiff(throttle->lastApplyMs[index], now) < APPLY_INTERVAL_MS)
            return false;

        throttle->applied[index] = true;
        throttle->lastApplyMs[index] = now;
        return true;
    }

    static bool IsInBattlegroundOrArena(Player* player)
    {
        if (player->InBattleground() || player->InArena())
            return true;

        Map* map = player->FindMap();
        return map && map->IsBattlegroundOrArena();
    }

    static bool IsEncounterInProgress(Player* player)
    {
        Map* map = player->FindMap();
        InstanceMap* instance = map ? map->ToInstanceMap() : nullptr;
        InstanceScript* script = instance ? instance->GetInstanceScript() : nullptr;
        return script && script->IsEncounterInProgress();
    }

    // Guards shared by player and pet builds, in the order of their codes.
    static ApplyResult CheckPlayerState(Player* player)
    {
        if (!player->IsInWorld())
            return MakeResult(ApplyCode::Busy, {}, "Please wait until you have finished loading.");

        if (!player->IsAlive())
            return MakeResult(ApplyCode::Dead);

        if (player->IsInCombat())
            return MakeResult(ApplyCode::Combat);

        if (IsInBattlegroundOrArena(player))
            return MakeResult(ApplyCode::Battleground);

        if (IsEncounterInProgress(player))
            return MakeResult(ApplyCode::Encounter);

        return {};
    }

    // ------------------------------------------------------------------------
    // Free reset of the active spec
    // ------------------------------------------------------------------------
    // Player::resetTalents(true) charges nothing and leaves m_resetTalentsCost,
    // m_resetTalentsTime and the reset achievements alone: noResetCost skips that whole
    // block, and CONFIG_NO_RESET_TALENT_COST is only read when a cost would be charged.
    // Its side effects are what the helpers below undo once the build is relearned.

    using SpellButtons = std::vector<std::pair<uint8, uint32>>;

    // What the reset takes away for a moment.
    struct ResetState
    {
        SpellButtons knownButtons;   // spell buttons whose spell was known before the reset
        ObjectGuid offhand;          // equipped off-hand, in case the reset unequips it
        uint32 parkedPet = 0;        // pet number held back from resetTalents()
        bool parkedHere = false;     // this apply unsummoned the pet and summons it back
    };

    // The pet is unsummoned below and read back with async queries. With
    // CharacterDatabase.WorkerThreads > 1 those reads can overtake the unsummon's own
    // async save and load the last periodic save instead (pet talents and cooldowns rolled
    // back). Commit the live state first: the unsummon's save then rewrites the same rows,
    // so the reload sees current data whichever order the workers run in.
    static void FlushPetState(Pet* pet)
    {
        CharacterDatabaseTransaction trans = CharacterDatabase.BeginTransaction();
        pet->_SaveAuras(trans);
        pet->_SaveSpells(trans);
        pet->_SaveSpellCooldowns(trans);
        CharacterDatabase.DirectCommitTransaction(trans);
    }

    // resetTalents() dismisses the pet for good (RemovePet(nullptr, PET_SAVE_NOT_IN_SLOT,
    // true): unslotted, reagents refunded). Park it the way mounting does instead:
    // UnsummonPetTemporaryIfAny() saves it as the current pet and keeps its number.
    static void ParkPet(Player* player, ResetState& state)
    {
        Pet* pet = player->GetPet();
        if (!pet)
        {
            // Parked by a mount, vehicle or taxi (or no pet at all): it stays parked and
            // the core summons it back when that ends.
            state.parkedPet = player->GetTemporaryUnsummonedPetNumber();
            return;
        }

        // Temporary summons (the 60 s ghoul, an unglyphed Water Elemental), and a live pet
        // next to a stale parked number, go the stock way: resetTalents() dismisses them.
        if (!pet->isControlled() || pet->isTemporarySummoned() || player->GetTemporaryUnsummonedPetNumber())
            return;

        FlushPetState(pet);
        player->UnsummonPetTemporaryIfAny();
        state.parkedPet = player->GetTemporaryUnsummonedPetNumber();
        state.parkedHere = state.parkedPet != 0;
    }

    static void RestorePet(Player* player, ResetState const& state)
    {
        if (!state.parkedPet || player->GetTemporaryUnsummonedPetNumber() != state.parkedPet || player->GetPetGUID())
            return;

        // The pet came from a talent this build dropped (Summon Felguard, Master of Ghouls,
        // Summon Water Elemental) and cannot come back: dismiss it as a trainer reset would,
        // reagent refund included.
        if (!player->CanResummonPet(player->GetLastPetSpell()))
            player->RemovePet(nullptr, PET_SAVE_NOT_IN_SLOT, true);
        else if (state.parkedHere)
            player->ResummonPetTemporaryUnSummonedIfAny();
    }

    // The reset unlearns every talent ability (SMSG_REMOVED_SPELL) and relearning one never
    // puts it back on the client's bars. Do what Player::ActivateSpec does around a spec
    // swap: clear the client bars (state 2) before unlearning and resend the server layout
    // (state 1) afterwards. removeSpell never edits that layout, so it still holds them.
    static SpellButtons ClearActionBars(Player* player)
    {
        SpellButtons known;
        for (uint8 button = 0; button < MAX_ACTION_BUTTONS; ++button)
            if (ActionButton const* action = player->GetActionButton(button))
                if (action->GetType() == ACTION_BUTTON_SPELL && player->HasSpell(action->GetAction()))
                    known.emplace_back(button, action->GetAction());

        player->SendActionButtons(2);
        return known;
    }

    // Buttons whose spell the new build really dropped go, as the next login would drop them.
    static void RestoreActionBars(Player* player, SpellButtons const& knownBefore)
    {
        for (auto const& [button, spellId] : knownBefore)
            if (!player->HasSpell(spellId))
                player->removeActionButton(button);

        player->SendActionButtons(1);
    }

    // resetTalents() drops Titan's Grip and the shaman Dual Wield talent for a moment, and
    // AutoUnequipOffhandIfNeed() moves the off-hand into the bags. Put it back if the new
    // build still allows it. Mailed (bags full) or no longer allowed: it stays where the
    // reset put it, exactly as after a trainer reset.
    static void RestoreOffhand(Player* player, ObjectGuid offhandGuid)
    {
        if (!offhandGuid || player->GetItemByPos(INVENTORY_SLOT_BAG_0, EQUIPMENT_SLOT_OFFHAND))
            return;

        Item* item = player->GetItemByGuid(offhandGuid);
        if (!item || !Player::IsInventoryPos(item->GetPos()))
            return;

        uint16 dest = 0;
        if (player->CanEquipItem(EQUIPMENT_SLOT_OFFHAND, dest, item, false) != EQUIP_ERR_OK)
            return;

        player->RemoveItem(item->GetBagSlot(), item->GetSlot(), true);
        player->EquipItem(dest, item, true);
        player->AutoUnequipOffhandIfNeed();
    }

    // A single-target aura cast from a talent the build dropped (Earth Shield, Beacon of
    // Light, Vigilance, Focus Magic) would otherwise stay on its target. Same rule as
    // Player::ActivateSpec, limited to talent-derived spells.
    static void RemoveDroppedTalentAuras(Player* player)
    {
        Unit::AuraList& singleCast = player->GetSingleCastAuras();
        for (Unit::AuraList::iterator itr = singleCast.begin(); itr != singleCast.end();)
        {
            Aura* aura = *itr;
            uint32 const firstRank = sSpellMgr->GetFirstSpellInChain(aura->GetId());
            bool const fromTalent = GetTalentSpellCost(firstRank) > 0 || sSpellMgr->IsAdditionalTalentSpell(firstRank);
            if (fromTalent && !aura->GetCastItemGUID() && !player->HasActiveSpell(aura->GetId())
                && !player->HasTalent(aura->GetId(), player->GetActiveSpec()))
            {
                aura->Remove();
                itr = singleCast.begin();
            }
            else
                ++itr;
        }
    }

    // Form-tied talent bonuses (Master Shapeshifter, Leader of the Pack) are cast on form
    // entry and survive the reset; recompute them for the form the player is in, as
    // Player::ActivateSpec does.
    static void RefreshShapeshiftBonuses(Player* player)
    {
        Unit::AuraEffectList const& shapeshiftAuras = player->GetAuraEffectsByType(SPELL_AURA_MOD_SHAPESHIFT);
        for (AuraEffect* aurEff : shapeshiftAuras)
        {
            aurEff->HandleShapeshiftBoosts(player, false);
            aurEff->HandleShapeshiftBoosts(player, true);
        }
    }

    static ResetState ResetActiveSpec(Player* player)
    {
        ResetState state;
        if (Item* offhand = player->GetItemByPos(INVENTORY_SLOT_BAG_0, EQUIPMENT_SLOT_OFFHAND))
            state.offhand = offhand->GetGUID();

        ParkPet(player, state);
        state.knownButtons = ClearActionBars(player);

        // Hide the parked number: RemovePet(nullptr, ..., true) inside resetTalents() would
        // refund the pet's reagents (a free soul shard per apply for a demon that comes
        // straight back) and forget the number. It still removes any live temporary summon.
        player->SetTemporaryUnsummonedPetNumber(0);
        if (!player->resetTalents(true))
            LOG_ERROR("scripts.dc", "TLNT: resetTalents refused for {} with talents learned",
                player->GetGUID().ToString());
        player->SetTemporaryUnsummonedPetNumber(state.parkedPet);

        return state;
    }

    static void FinishReset(Player* player, ResetState const& state)
    {
        RestoreOffhand(player, state.offhand);
        RestorePet(player, state);
        RestoreActionBars(player, state.knownButtons);
        RemoveDroppedTalentAuras(player);
        RefreshShapeshiftBonuses(player);
    }

    // ------------------------------------------------------------------------
    // Apply
    // ------------------------------------------------------------------------
    static ApplyResult ApplyPlayerBuild(Player* player, ParsedMessage const& msg, JsonValue const& json)
    {
        if (!IsEnabled())
            return MakeResult(ApplyCode::Disabled);

        if (!TryConsumeApplySlot(player, BuildKind::Player))
            return MakeResult(ApplyCode::Busy);

        ApplyResult guard = CheckPlayerState(player);
        if (guard.code != ApplyCode::Ok)
            return guard;

        if (!IsCompleteJsonObject(msg) || !json.IsObject())
            return MakeResult(ApplyCode::BadRequest);

        uint32 spec = 0;
        if (!TryReadUInt(json["spec"], MAX_TALENT_SPECS, spec) || spec != uint32(player->GetActiveSpec()) + 1)
            return MakeResult(ApplyCode::WrongSpec);

        RankMap target;
        ApplyResult parsed = ParseBuild(json["t"], BuildKind::Player, player->getClassMask(), target);
        if (parsed.code != ApplyCode::Ok)
            return parsed;

        RankMap const current = ReadPlayerRanks(player);
        if (target == current)
            return MakeResult(ApplyCode::NoChange);

        std::vector<uint32> lowered = GetLoweredTalents(target, current);
        bool const reset = !lowered.empty();
        if (reset && !IsFreeRespecEnabled())
            return MakeResult(ApplyCode::RespecDisabled, std::move(lowered));

        // After a reset LearnTalent starts from an empty tree with the full pool; otherwise
        // it adds the missing ranks out of the free points.
        RankMap const start = reset ? RankMap() : current;
        uint32 const pool = reset ? player->CalculateTalentsPoints() : player->GetFreeTalentPoints();
        std::vector<BuildStep> const steps = OrderSteps(target, start);

        ApplyResult validated = ValidateBuild(steps, start, pool, { MAX_TALENT_RANK, player });
        if (validated.code != ApplyCode::Ok)
            return validated;

        // A resummoned pet is in the world before its spells are loaded; parking it again
        // now would save that empty state.
        Pet* pet = player->GetPet();
        if (reset && pet && pet->isBeingLoaded())
            return MakeResult(ApplyCode::Busy, {}, PET_LOADING_TEXT);

        ResetState state;
        if (reset)
            state = ResetActiveSpec(player);

        // LearnTalent's rank is 0-based; it charges target - current + 1 points.
        for (BuildStep const& step : steps)
            player->LearnTalent(step.talent->TalentID, step.rank - 1);

        if (reset)
            FinishReset(player, state);

        std::vector<uint32> failed = GetMismatches(target, current, ReadPlayerRanks(player));
        player->SendTalentsInfoData(false);

        if (!failed.empty())
            return MakeResult(ApplyCode::Partial, std::move(failed));

        return {};
    }

    static ApplyResult ApplyPetBuild(Player* player, ParsedMessage const& msg, JsonValue const& json)
    {
        if (!IsEnabled())
            return MakeResult(ApplyCode::Disabled);

        if (!TryConsumeApplySlot(player, BuildKind::Pet))
            return MakeResult(ApplyCode::Busy);

        ApplyResult guard = CheckPlayerState(player);
        if (guard.code != ApplyCode::Ok)
            return guard;

        uint32 familyMask = 0;
        Pet* pet = GetTalentPet(player, familyMask);
        if (!pet)
            return MakeResult(ApplyCode::NoPet);

        // A freshly summoned pet gets its spells, talents included, from an async query.
        if (pet->isBeingLoaded())
            return MakeResult(ApplyCode::Busy, {}, PET_LOADING_TEXT);

        if (pet->IsInCombat())
            return MakeResult(ApplyCode::Combat);

        if (!IsCompleteJsonObject(msg) || !json.IsObject())
            return MakeResult(ApplyCode::BadRequest);

        RankMap target;
        ApplyResult parsed = ParseBuild(json["t"], BuildKind::Pet, familyMask, target);
        if (parsed.code != ApplyCode::Ok)
            return parsed;

        RankMap const current = ReadPetRanks(pet, familyMask);
        if (target == current)
            return MakeResult(ApplyCode::NoChange);

        std::vector<uint32> lowered = GetLoweredTalents(target, current);
        bool const reset = !lowered.empty();
        if (reset && !IsFreeRespecEnabled())
            return MakeResult(ApplyCode::RespecDisabled, std::move(lowered));

        // Pet::resetTalents() asks this hook first and does nothing when it refuses.
        if (reset && !sScriptMgr->CanResetTalents(pet))
            return MakeResult(ApplyCode::ScriptBlocked);

        RankMap const start = reset ? RankMap() : current;
        uint32 const pool = reset ? pet->GetMaxTalentPointsForLevel(pet->GetLevel()) : pet->GetFreeTalentPoints();
        std::vector<BuildStep> const steps = OrderSteps(target, start);

        ApplyResult validated = ValidateBuild(steps, start, pool, { MAX_PET_TALENT_RANK, nullptr });
        if (validated.code != ApplyCode::Ok)
            return validated;

        // Unlike the player's, the pet's reset keeps it summoned and charges nothing.
        if (reset)
            pet->resetTalents();

        // LearnPetTalent's rank is 0-based as well.
        ObjectGuid const petGuid = pet->GetGUID();
        for (BuildStep const& step : steps)
            player->LearnPetTalent(petGuid, step.talent->TalentID, step.rank - 1);

        std::vector<uint32> failed = GetMismatches(target, current, ReadPetRanks(pet, familyMask));
        player->SendTalentsInfoData(true);

        if (!failed.empty())
            return MakeResult(ApplyCode::Partial, std::move(failed));

        return {};
    }

    // ------------------------------------------------------------------------
    // Outbound
    // ------------------------------------------------------------------------
    static void SendApplyResult(Player* player, uint8 opcode, uint32 req, ApplyResult const& result, uint32 spent)
    {
        ApplyCodeInfo const info = GetCodeInfo(result.code);

        JsonValue failed;
        failed.SetArray(result.failed.size());
        for (uint32 talentId : result.failed)
            failed.Push(JsonValue(talentId));

        std::string text;
        if (result.code != ApplyCode::Ok)
            text = result.text.empty() ? info.text : result.text;

        JsonMessage reply(Module::TALENTS, opcode);
        reply.Set("req", req);
        reply.Set("ok", result.code == ApplyCode::Ok || result.code == ApplyCode::NoChange);
        reply.Set("code", info.name);
        reply.Set("msg", text);
        reply.Set("spent", spent);
        reply.Set("failed", std::move(failed));
        reply.Send(player);

        LOG_DEBUG("scripts.dc", "TLNT: {} {} build -> {} (req {}, spent {}, {} failed)",
            player->GetGUID().ToString(), opcode == Opcode::Talents::SMSG_APPLY_PET_RESULT ? "pet" : "player",
            info.name, req, spent, result.failed.size());
    }

    // ------------------------------------------------------------------------
    // Inbound
    // ------------------------------------------------------------------------
    static void HandleHello(Player* player, ParsedMessage const& /*msg*/)
    {
        if (!player)
            return;

        JsonMessage reply(Module::TALENTS, Opcode::Talents::SMSG_HELLO);
        reply.Set("v", PROTOCOL_VERSION);
        reply.Set("enabled", IsEnabled());
        reply.Set("freeRespec", IsFreeRespecEnabled());
        reply.Set("pet", true);
        reply.Set("max", MAX_BUILD_ENTRIES);
        reply.Send(player);
    }

    static void HandleApplyBuild(Player* player, ParsedMessage const& msg)
    {
        if (!player)
            return;

        JsonValue const json = GetJsonData(msg);
        ApplyResult const result = ApplyPlayerBuild(player, msg, json);
        uint32 const spent = SumRanks(ReadPlayerRanks(player));
        SendApplyResult(player, Opcode::Talents::SMSG_APPLY_RESULT, ReadRequestId(json), result, spent);
    }

    static void HandleApplyPetBuild(Player* player, ParsedMessage const& msg)
    {
        if (!player)
            return;

        JsonValue const json = GetJsonData(msg);
        ApplyResult const result = ApplyPetBuild(player, msg, json);

        uint32 familyMask = 0;
        Pet* pet = GetTalentPet(player, familyMask);
        uint32 const spent = pet ? SumRanks(ReadPetRanks(pet, familyMask)) : 0;
        SendApplyResult(player, Opcode::Talents::SMSG_APPLY_PET_RESULT, ReadRequestId(json), result, spent);
    }

    static void RegisterTalentHandlers()
    {
        // Routed even with DC.AddonProtocol.Talents.Enable off: HELLO has to be able to say
        // enabled=false and a build has to get DISABLED, not the router's generic "module
        // disabled" error. Both config keys are read per request, so .reload config applies.
        MessageRouter::Instance().SetModuleEnabled(Module::TALENTS, true);

        DC_REGISTER_HANDLER(Module::TALENTS, Opcode::Talents::CMSG_HELLO, HandleHello);
        DC_REGISTER_HANDLER(Module::TALENTS, Opcode::Talents::CMSG_APPLY_BUILD, HandleApplyBuild);
        DC_REGISTER_HANDLER(Module::TALENTS, Opcode::Talents::CMSG_APPLY_PET_BUILD, HandleApplyPetBuild);
    }
} // namespace Talents
} // namespace DCAddon

void AddSC_dc_addon_talents()
{
    DCAddon::Talents::RegisterTalentHandlers();
}
