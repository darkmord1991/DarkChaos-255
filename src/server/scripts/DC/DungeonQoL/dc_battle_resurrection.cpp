/*
 * Copyright (C) 2016+ AzerothCore <www.azerothcore.org>, released under GNU AGPL v3 license
 * Copyright (C) 2025+ DarkChaos-255 Custom Scripts
 *
 * Battle resurrection charges (retail-style shared combat-res budget).
 *
 * Scope (DC content only):
 *   - Active Mythic+ run: 1 charge for the run, +1 every
 *     DC.BattleRes.MythicPlusRechargeMinutes of run time (0 = never). Counted
 *     whenever the caster is in combat or a boss encounter is in progress.
 *   - Raid maps listed in DC.BattleRes.RaidMaps: 2 charges (<= 15 players in
 *     the instance at the pull) or 3 (16+), reset whenever a boss encounter
 *     enters IN_PROGRESS while no other encounter is running. As on retail the
 *     raid budget only applies while an encounter is in progress; trash combat
 *     resurrections are free.
 *
 * A battle resurrection is a player-cast, non-triggered spell with
 * SPELL_EFFECT_RESURRECT / RESURRECT_NEW (Rebirth, Jumper Cables...) or
 * SPELL_EFFECT_SELF_RESURRECT (soulstone, Reincarnation/Ankh). Raise Ally is not one: in 3.3.5 it only lends the dead
 * player a ghoul and brings nobody back, so it stays free. Out of the
 * combat context above it is free.
 *
 * The charge is spent when the spell is cast (Spell::cast), like the CoA
 * reference: a declined resurrection still costs its charge, because the core
 * keeps no record of whether a request was accepted. A cast on a target that
 * already has a resurrection pending is refused instead, so a second Rebirth on
 * the same corpse cannot burn a charge for nothing.
 *
 * With no charge left the cast fails with a notification. Self-resurrections
 * (PLAYER_SELF_RES_SPELL) of dead players are parked while no charge is
 * available, which greys out the "Use Soulstone" button of the 3.3.5 death
 * popup, and are handed back once a charge is available or combat ends.
 */

#include "dc_dungeon_qol.h"
#include "Chat.h"
#include "Corpse.h"
#include "DC/MythicPlus/dc_mythicplus_run_manager.h"
#include "DataMap.h"
#include "GameTime.h"
#include "InstanceScript.h"
#include "Log.h"
#include "Map.h"
#include "ObjectAccessor.h"
#include "Player.h"
#include "ScriptMgr.h"
#include "Spell.h"
#include "SpellInfo.h"
#include "StringFormat.h"

#include <string>
#include <unordered_map>

namespace
{
    using namespace DC::DungeonQoL;

    constexpr uint32 MYTHIC_PLUS_BASE_CHARGES = 1;
    constexpr uint32 RAID_LARGE_GROUP_PLAYERS = 16;
    constexpr uint32 RAID_SMALL_CHARGES = 2;
    constexpr uint32 RAID_LARGE_CHARGES = 3;
    constexpr uint32 EVALUATE_INTERVAL_MS = 1000;

    std::string const BATTLE_RES_STATE_KEY = "dc_battle_res";

    enum class BattleResKind : uint8
    {
        None,
        Targeted,   // resurrects another player
        Self        // the dead caster resurrects themselves
    };

    enum class BudgetScope : uint8
    {
        None,
        MythicPlus,
        Raid
    };

    struct BattleResState : DataMap::Base
    {
        // Raid: budget of the encounter that is (or was last) in progress.
        bool raidStarted = false;
        uint32 raidTotal = 0;
        uint32 raidUsed = 0;

        // Mythic+: charges spent in the run identified by its start time.
        uint64 mythicRunStart = 0;
        uint32 mythicUsed = 0;
        uint32 mythicAnnouncedTotal = 0;

        // Self-resurrection spell ids taken off dead players while no charge is available.
        std::unordered_map<ObjectGuid, uint32> parkedSelfRes;

        uint32 evaluateTimer = 0;
    };

    struct Budget
    {
        BudgetScope scope = BudgetScope::None;
        uint32 total = 0;
        uint32 used = 0;

        [[nodiscard]] uint32 Remaining() const { return total > used ? total - used : 0; }
    };

    BattleResKind Classify(SpellInfo const* spellInfo)
    {
        if (!spellInfo)
            return BattleResKind::None;

        if (spellInfo->HasEffect(SPELL_EFFECT_SELF_RESURRECT))
            return BattleResKind::Self;

        if (spellInfo->HasEffect(SPELL_EFFECT_RESURRECT) || spellInfo->HasEffect(SPELL_EFFECT_RESURRECT_NEW))
            return BattleResKind::Targeted;

        return BattleResKind::None;
    }

    bool IsListedRaid(Map const* map, Settings const& settings)
    {
        return map->IsRaid() && settings.battleResRaidMaps.contains(map->GetId());
    }

    // The instance's state; created only where a budget can apply, so stock
    // dungeons never get a state (nor the per-second sweep that comes with one).
    BattleResState* FindState(Map* map, Settings const& settings)
    {
        if (BattleResState* state = map->CustomData.Get<BattleResState>(BATTLE_RES_STATE_KEY))
            return state;

        if (!IsListedRaid(map, settings) && !sMythicRuns->IsMythicPlusActive(map))
            return nullptr;

        return map->CustomData.GetDefault<BattleResState>(BATTLE_RES_STATE_KEY);
    }

    void StartRaidBudget(Map* map, BattleResState& state)
    {
        state.raidStarted = true;
        state.raidUsed = 0;
        state.raidTotal = map->GetPlayersCountExceptGMs() >= RAID_LARGE_GROUP_PLAYERS
            ? RAID_LARGE_CHARGES : RAID_SMALL_CHARGES;
    }

    Budget ResolveBudget(Map* map, BattleResState& state, Settings const& settings)
    {
        Budget budget;
        if (!settings.battleResEnable || !map || !map->IsDungeon())
            return budget;

        // GetRunState returns a pointer into the run manager; it is only read here,
        // on the map thread that owns this instance, and never kept.
        if (MythicPlusRunManager::InstanceState const* run = sMythicRuns->GetRunState(map))
        {
            if (run->keystoneLevel && !run->completed && !run->failed)
            {
                uint64 const startedAt = run->startedAt; // 0 while the countdown runs
                if (state.mythicRunStart != startedAt)
                {
                    state.mythicRunStart = startedAt;
                    state.mythicUsed = 0;
                    state.mythicAnnouncedTotal = 0;
                }

                budget.scope = BudgetScope::MythicPlus;
                budget.total = MYTHIC_PLUS_BASE_CHARGES;
                uint64 const now = static_cast<uint64>(GameTime::GetGameTime().count());
                uint64 const rechargeSeconds = uint64(settings.battleResRechargeMinutes) * MINUTE;
                if (startedAt && rechargeSeconds && now > startedAt)
                    budget.total += static_cast<uint32>((now - startedAt) / rechargeSeconds);

                budget.used = state.mythicUsed;
                return budget;
            }
        }

        if (IsListedRaid(map, settings))
        {
            // Normally started by the encounter hook; this covers an encounter that
            // was already running when the state was first needed.
            if (!state.raidStarted)
                StartRaidBudget(map, state);

            budget.scope = BudgetScope::Raid;
            budget.total = state.raidTotal;
            budget.used = state.raidUsed;
        }

        return budget;
    }

    // Whether a resurrection of this kind counts against the budget right now.
    bool InCombatContext(Map* map, BudgetScope scope, BattleResKind kind, Unit const* caster)
    {
        bool const encounter = IsEncounterInProgress(map);
        if (scope == BudgetScope::Raid)
            return encounter;

        if (encounter)
            return true;

        // A dead caster (soulstone, Ankh) is never in combat itself: use the group's state.
        if (kind == BattleResKind::Self)
            return IsAnyPlayerInCombat(map);

        return caster && caster->IsInCombat();
    }

    Player* ResolveResurrectTarget(Spell* spell, Player const* caster)
    {
        if (Unit* unit = spell->m_targets.GetUnitTarget())
            return unit->ToPlayer();

        if (Corpse* corpse = spell->m_targets.GetCorpseTarget())
            return ObjectAccessor::GetPlayer(*caster, corpse->GetOwnerGUID());

        return nullptr;
    }

    void AnnounceToInstance(Map* map, std::string const& chatText, std::string const& notification)
    {
        map->DoForAllPlayers([&chatText, &notification](Player* player)
        {
            ChatHandler handler(player->GetSession());
            handler.SendSysMessage(chatText);
            if (!notification.empty())
                handler.SendNotification(notification);
        });
    }

    // Recharge announcements and parking / un-parking of self-resurrections.
    void Evaluate(Map* map, BattleResState& state, Settings const& settings)
    {
        Budget const budget = ResolveBudget(map, state, settings);

        if (budget.scope == BudgetScope::MythicPlus)
        {
            if (state.mythicAnnouncedTotal && budget.total > state.mythicAnnouncedTotal)
            {
                std::string const text = Acore::StringFormat(
                    "|cffff8000[Battle Res]|r A battle resurrection charge was gained ({} available).",
                    budget.Remaining());
                AnnounceToInstance(map, text, "");
            }

            state.mythicAnnouncedTotal = budget.total;
        }

        bool const blocked = budget.scope != BudgetScope::None && !budget.Remaining()
            && InCombatContext(map, budget.scope, BattleResKind::Self, nullptr);

        if (!blocked && state.parkedSelfRes.empty())
            return;

        for (auto const& ref : map->GetPlayers())
        {
            Player* player = ref.GetSource();
            if (!player)
                continue;

            ObjectGuid const guid = player->GetGUID();
            // Alive (resurrected another way) or released: a self-resurrection no longer applies.
            if (player->IsAlive() || player->HasPlayerFlag(PLAYER_FLAGS_GHOST))
            {
                state.parkedSelfRes.erase(guid);
                continue;
            }

            uint32 const selfResSpell = player->GetUInt32Value(PLAYER_SELF_RES_SPELL);
            auto itr = state.parkedSelfRes.find(guid);
            if (blocked && selfResSpell)
            {
                state.parkedSelfRes[guid] = selfResSpell;
                player->SetUInt32Value(PLAYER_SELF_RES_SPELL, 0);
                ChatHandler(player->GetSession()).SendSysMessage(
                    "|cffff8000[Battle Res]|r No battle resurrection charge is left: your self-resurrection is on hold "
                    "until a charge is available or combat ends.");
            }
            else if (!blocked && itr != state.parkedSelfRes.end())
            {
                if (!selfResSpell)
                {
                    player->SetUInt32Value(PLAYER_SELF_RES_SPELL, itr->second);
                    ChatHandler(player->GetSession()).SendSysMessage(
                        "|cff00ff00[Battle Res]|r Your self-resurrection can be used again "
                        "(type /reload if the release window is gone).");
                }

                state.parkedSelfRes.erase(itr);
            }
        }

        // Players who left the instance keep nothing: the field is not saved anyway.
        std::erase_if(state.parkedSelfRes, [map](auto const& entry)
        {
            return !ObjectAccessor::GetPlayer(map, entry.first);
        });
    }

    class dc_battle_res_spells : public AllSpellScript
    {
    public:
        dc_battle_res_spells() : AllSpellScript("dc_battle_res_spells",
            { ALLSPELLHOOK_ON_SPELL_CHECK_CAST, ALLSPELLHOOK_ON_CAST }) { }

        void OnSpellCheckCast(Spell* spell, bool /*strict*/, SpellCastResult& res) override
        {
            if (res != SPELL_CAST_OK || !spell || spell->IsTriggered())
                return;

            BattleResKind const kind = Classify(spell->GetSpellInfo());
            if (kind == BattleResKind::None)
                return;

            Player* caster = spell->GetCaster() ? spell->GetCaster()->ToPlayer() : nullptr;
            Map* map = caster ? caster->GetMap() : nullptr;
            if (!map || !map->IsDungeon())
                return;

            std::shared_ptr<Settings const> const settings = GetSettings();
            if (!settings->battleResEnable)
                return;

            BattleResState* state = FindState(map, *settings);
            if (!state)
                return;

            Budget const budget = ResolveBudget(map, *state, *settings);
            if (budget.scope == BudgetScope::None || !InCombatContext(map, budget.scope, kind, caster))
                return;

            if (kind == BattleResKind::Targeted)
            {
                // Stock EffectResurrect silently does nothing for a target with a
                // pending request; refuse here so the charge is not spent for it.
                Player* target = ResolveResurrectTarget(spell, caster);
                if (target && !target->IsAlive() && target->isResurrectRequested())
                {
                    res = SPELL_FAILED_DONT_REPORT;
                    ChatHandler(caster->GetSession()).SendNotification(
                        Acore::StringFormat("{} already has a resurrection pending.", target->GetName()));
                    return;
                }
            }

            if (budget.Remaining())
                return;

            res = SPELL_FAILED_DONT_REPORT;
            ChatHandler(caster->GetSession()).SendNotification(std::string("No battle resurrection charges left."));

            if (kind == BattleResKind::Self)
            {
                // CMSG_SELF_RES clears PLAYER_SELF_RES_SPELL right after this refusal;
                // park it so Evaluate hands it back later.
                state->parkedSelfRes[caster->GetGUID()] = spell->GetSpellInfo()->Id;
                ChatHandler(caster->GetSession()).SendSysMessage(
                    "|cffff8000[Battle Res]|r No battle resurrection charge is left. Your self-resurrection is kept "
                    "for when a charge is available or combat ends (type /reload if the release window is gone).");
            }
        }

        void OnSpellCast(Spell* spell, Unit* caster, SpellInfo const* spellInfo, bool /*skipCheck*/) override
        {
            if (!spell || spell->IsTriggered())
                return;

            BattleResKind const kind = Classify(spellInfo);
            if (kind == BattleResKind::None)
                return;

            Player* player = caster ? caster->ToPlayer() : nullptr;
            Map* map = player ? player->GetMap() : nullptr;
            if (!map || !map->IsDungeon())
                return;

            std::shared_ptr<Settings const> const settings = GetSettings();
            if (!settings->battleResEnable)
                return;

            BattleResState* state = FindState(map, *settings);
            if (!state)
                return;

            Budget const budget = ResolveBudget(map, *state, *settings);
            if (budget.scope == BudgetScope::None || !InCombatContext(map, budget.scope, kind, player))
                return;

            if (!budget.Remaining())
            {
                // CheckCast refuses this; reaching it means the context changed between check and cast.
                LOG_DEBUG("scripts.dc", "Battle res: {} cast spell {} with no charge left on map {} instance {}.",
                    player->GetName(), spellInfo->Id, map->GetId(), map->GetInstanceId());
                return;
            }

            if (budget.scope == BudgetScope::MythicPlus)
                ++state->mythicUsed;
            else
                ++state->raidUsed;

            uint32 const left = budget.Remaining() - 1;

            std::string chatText;
            if (kind == BattleResKind::Targeted)
            {
                Player* target = ResolveResurrectTarget(spell, player);
                chatText = Acore::StringFormat(
                    "|cffff8000[Battle Res]|r {} used a battle resurrection on {} ({} left).",
                    player->GetName(), target ? target->GetName() : std::string("a fallen ally"), left);
            }
            else
                chatText = Acore::StringFormat("|cffff8000[Battle Res]|r {} used a self-resurrection ({} left).",
                    player->GetName(), left);

            AnnounceToInstance(map, chatText, Acore::StringFormat("Battle resurrection used ({} left)", left));

            LOG_INFO("scripts.dc", "Battle res: {} used spell {} on map {} instance {} ({}): {} of {} charges left.",
                player->GetName(), spellInfo->Id, map->GetId(), map->GetInstanceId(),
                budget.scope == BudgetScope::MythicPlus ? "Mythic+" : "raid", left, budget.total);

            // Grey out the remaining soulstones at once rather than on the next sweep.
            if (!left)
                Evaluate(map, *state, *settings);
        }
    };

    class dc_battle_res_encounters : public GlobalScript
    {
    public:
        dc_battle_res_encounters()
            : GlobalScript("dc_battle_res_encounters", { GLOBALHOOK_ON_BEFORE_SET_BOSS_STATE }) { }

        void OnBeforeSetBossState(uint32 id, EncounterState newState, EncounterState oldState, Map* instance) override
        {
            // TO_BE_DECIDED is the instance loading its saved states, not a pull.
            if (!instance || newState != IN_PROGRESS || oldState == IN_PROGRESS || oldState == TO_BE_DECIDED)
                return;

            if (!instance->IsRaid())
                return;

            std::shared_ptr<Settings const> const settings = GetSettings();
            if (!settings->battleResEnable || !settings->battleResRaidMaps.contains(instance->GetId()))
                return;

            // Called before the new state is stored: a hit here is another boss
            // already in progress, and a boss pulled into that fight shares its budget.
            if (IsEncounterInProgress(instance))
                return;

            BattleResState* state = instance->CustomData.GetDefault<BattleResState>(BATTLE_RES_STATE_KEY);
            StartRaidBudget(instance, *state);

            LOG_DEBUG("scripts.dc", "Battle res: encounter {} pulled on map {} instance {} with {} charges.",
                id, instance->GetId(), instance->GetInstanceId(), state->raidTotal);
        }
    };

    class dc_battle_res_map : public AllMapScript
    {
    public:
        dc_battle_res_map() : AllMapScript("dc_battle_res_map", { ALLMAPHOOK_ON_MAP_UPDATE }) { }

        void OnMapUpdate(Map* map, uint32 diff) override
        {
            if (!map || !map->IsDungeon())
                return;

            // Created on the first battle res check or raid pull; nothing to do before that.
            BattleResState* state = map->CustomData.Get<BattleResState>(BATTLE_RES_STATE_KEY);
            if (!state)
                return;

            state->evaluateTimer += diff;
            if (state->evaluateTimer < EVALUATE_INTERVAL_MS)
                return;

            state->evaluateTimer = 0;
            Evaluate(map, *state, *GetSettings());
        }
    };
}

namespace DC::DungeonQoL
{
    bool GetBattleResCharges(Map* map, uint32& remaining, uint32& total)
    {
        if (!map || !map->IsDungeon())
            return false;

        std::shared_ptr<Settings const> const settings = GetSettings();
        if (!settings->battleResEnable)
            return false;

        BattleResState* state = FindState(map, *settings);
        if (!state)
            return false;

        Budget const budget = ResolveBudget(map, *state, *settings);
        if (budget.scope == BudgetScope::None)
            return false;

        remaining = budget.Remaining();
        total = budget.total;
        return true;
    }

    void RegisterBattleResurrectionScripts()
    {
        new dc_battle_res_spells();
        new dc_battle_res_encounters();
        new dc_battle_res_map();
    }
}
