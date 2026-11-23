/*
 * Dark Chaos - Spell Charges
 * ==========================
 *
 * Retail-style charges for player spells listed in the world table
 * `dc_spell_charges`. Every cast spends a charge; charges come back one at a
 * time, each after the spell's recharge time. The spell is on cooldown only
 * while no charge is left, and that cooldown ends exactly when the next charge
 * returns.
 *
 * Mechanics ride on the stock cooldown, so they work for every client: while a
 * charge is left the cooldown the cast just started is cleared again
 * (SMSG_CLEAR_COOLDOWN, the CHEAT_COOLDOWN precedent in Spell::cast); at zero
 * charges the cooldown is moved to the next charge (SMSG_MODIFY_COOLDOWN, or a
 * new SMSG_SPELL_COOLDOWN when the spell had none). The old 32-bit client
 * simply sees the cooldown cleared while charges remain.
 *
 * A client that negotiated SPELL_CHARGES_NATIVE (the native x64 client) also
 * gets SMSG_DC_SPELL_CHARGES so it can show the count on the button:
 *
 *   uint8 flags            0x01 = full state: the client forgets every charge first
 *   uint8 count            entries that follow (max 255; a larger set is split and
 *                          only the first packet carries 0x01)
 *   count x {
 *     uint32 spellId
 *     uint8  maxCharges    0 = this spell no longer has charges (client forgets it)
 *     uint8  charges       charges available now (0..maxCharges)
 *     uint32 rechargeMs    duration of one recharge
 *     uint32 nextChargeMs  ms until the next charge returns; 0 when charges == maxCharges
 *   }
 *
 * The full state goes out after login, once the session negotiated the bit
 * (the handshake arrives after OnPlayerLogin), and after a talent spec switch;
 * single entries go out on every charged cast, learn and unlearn.
 *
 * State is kept per character across logout, so a relog does not refill
 * charges; it lives in memory only, so a server restart does. Entries that have
 * fully recharged are dropped by a periodic sweep.
 *
 * Not handled yet: cooldown-reset effects (Preparation, Readiness, arena
 * cooldown resets, .cooldown) clear the cooldown but do not restore charges, and
 * the recharge time ignores cooldown spell mods (talents, glyphs). Only the
 * exact spell ids in the table have charges (no rank expansion). Other spells
 * sharing the spell's category keep the category cooldown the cast started.
 *
 * Threads: OnSpellCast and the learn/unlearn/spec hooks run on map worker
 * threads; the login sync and the sweep run in WorldScript::OnUpdate on the
 * world thread. The charge state is shared between them under s_stateMutex.
 * DCAddon::SessionSupportsCapability is safe from any thread (its registry is
 * mutex guarded and a registry miss only queues an async warm-up).
 *
 * Copyright (C) 2026 Dark Chaos Development Team
 */

#include "dc_addon_namespace.h"
#include "Config.h"
#include "DC/CrossSystem/CrossSystemDbSchema.h"
#include "DatabaseEnv.h"
#include "GameTime.h"
#include "Log.h"
#include "ObjectAccessor.h"
#include "Player.h"
#include "ScriptMgr.h"
#include "Spell.h"
#include "SpellInfo.h"
#include "SpellMgr.h"
#include "WorldPacket.h"
#include "WorldSession.h"

#include <algorithm>
#include <mutex>
#include <unordered_map>
#include <vector>

namespace
{
    constexpr char const* TABLE_SPELL_CHARGES = "dc_spell_charges";

    constexpr uint8 FLAG_FULL_STATE = 0x01;
    constexpr size_t MAX_ENTRIES_PER_PACKET = 255;
    constexpr size_t ENTRY_WIRE_SIZE = 4 + 1 + 1 + 4 + 4;

    // A longer recharge would not fit the int32 cooldown delta of SMSG_MODIFY_COOLDOWN.
    constexpr uint32 MAX_RECHARGE_MS = 24 * 60 * 60 * 1000;

    constexpr uint32 SYNC_INTERVAL_MS = 500;
    constexpr uint64 SYNC_TIMEOUT_MS = 120 * 1000;
    constexpr uint32 SWEEP_INTERVAL_MS = 60 * 1000;

    struct ChargeDefinition
    {
        uint8 maxCharges = 0;
        uint32 rechargeMs = 0;     // effective: table value, else RecoveryTime, else CategoryRecoveryTime
    };

    struct ChargeState
    {
        uint8 used = 0;            // charges spent and not yet back
        uint64 rechargeStartMs = 0; // game time the recharge of the oldest spent charge started
    };

    struct ChargeEntry
    {
        uint32 spellId = 0;
        uint8 maxCharges = 0;
        uint8 charges = 0;
        uint32 rechargeMs = 0;
        uint32 nextChargeMs = 0;
    };

    struct PendingSync
    {
        ObjectGuid guid;
        uint64 queuedAtMs = 0;
    };

    // Loaded once in OnStartup on the world thread, before any player is
    // online; read-only afterwards, so the map threads read it unlocked.
    std::unordered_map<uint32, ChargeDefinition> s_definitions;
    bool s_enabled = false;

    // character -> spellId -> state; only spells with a charge spent are kept.
    std::unordered_map<ObjectGuid, std::unordered_map<uint32, ChargeState>> s_states;
    std::mutex s_stateMutex;

    // Characters waiting for their full state (the handshake comes after login).
    std::vector<PendingSync> s_pendingSyncs;
    std::mutex s_pendingMutex;

    uint64 NowMs()
    {
        return static_cast<uint64>(GameTime::GetGameTimeMS().count());
    }

    // Brings back every charge whose recharge finished by `now`.
    void Settle(ChargeState& state, uint32 rechargeMs, uint64 now)
    {
        while (state.used > 0 && now >= state.rechargeStartMs + rechargeMs)
        {
            --state.used;
            state.rechargeStartMs += rechargeMs;
        }
    }

    // `state` must be settled to `now` (or null for a spell with every charge available).
    ChargeEntry BuildEntry(uint32 spellId, ChargeDefinition const& def, ChargeState const* state, uint64 now)
    {
        ChargeEntry entry;
        entry.spellId = spellId;
        entry.maxCharges = def.maxCharges;
        entry.charges = def.maxCharges;
        entry.rechargeMs = def.rechargeMs;

        if (state && state->used > 0)
        {
            uint8 const used = std::min(state->used, def.maxCharges);
            entry.charges = static_cast<uint8>(def.maxCharges - used);

            uint64 const nextAt = state->rechargeStartMs + def.rechargeMs;
            entry.nextChargeMs = nextAt > now ? static_cast<uint32>(nextAt - now) : 0;
        }

        return entry;
    }

    // Bots have no client; a session without the bit gets the mechanics only.
    bool ClientShowsCharges(Player* player)
    {
        return player && !DCAddon::IsBotRecipient(player)
            && DCAddon::SessionSupportsCapability(player,
                DCAddon::ProtocolVersion::Capability::SPELL_CHARGES_NATIVE);
    }

    void SendEntries(Player* player, std::vector<ChargeEntry> const& entries, bool fullState)
    {
        if (entries.empty() && !fullState)
            return;

        size_t offset = 0;
        do
        {
            size_t const count = std::min(entries.size() - offset, MAX_ENTRIES_PER_PACKET);

            WorldPacket data(SMSG_DC_SPELL_CHARGES, 2 + count * ENTRY_WIRE_SIZE);
            data << uint8(fullState && offset == 0 ? FLAG_FULL_STATE : 0);
            data << uint8(count);

            for (size_t i = offset; i < offset + count; ++i)
            {
                ChargeEntry const& entry = entries[i];
                data << uint32(entry.spellId);
                data << uint8(entry.maxCharges);
                data << uint8(entry.charges);
                data << uint32(entry.rechargeMs);
                data << uint32(entry.nextChargeMs);
            }

            player->SendDirectMessage(&data);
            offset += count;
        } while (offset < entries.size());
    }

    // Settled entry for one spell; spends nothing.
    ChargeEntry CurrentEntry(Player* player, uint32 spellId, ChargeDefinition const& def, uint64 now)
    {
        std::lock_guard<std::mutex> lock(s_stateMutex);

        auto const playerItr = s_states.find(player->GetGUID());
        if (playerItr == s_states.end())
            return BuildEntry(spellId, def, nullptr, now);

        auto const stateItr = playerItr->second.find(spellId);
        if (stateItr == playerItr->second.end())
            return BuildEntry(spellId, def, nullptr, now);

        Settle(stateItr->second, def.rechargeMs, now);
        return BuildEntry(spellId, def, &stateItr->second, now);
    }

    // One entry per table spell the character knows; an empty set still clears the client.
    void SendFullState(Player* player)
    {
        uint64 const now = NowMs();

        std::vector<uint32> known;
        for (auto const& definition : s_definitions)
            if (player->HasSpell(definition.first))
                known.push_back(definition.first);

        std::vector<ChargeEntry> entries;
        entries.reserve(known.size());
        for (uint32 const spellId : known)
            entries.push_back(CurrentEntry(player, spellId, s_definitions.at(spellId), now));

        SendEntries(player, entries, true);
    }

    void QueueFullSync(ObjectGuid const& guid)
    {
        uint64 const now = NowMs();

        std::lock_guard<std::mutex> lock(s_pendingMutex);
        for (PendingSync& sync : s_pendingSyncs)
        {
            if (sync.guid == guid)
            {
                sync.queuedAtMs = now;
                return;
            }
        }

        s_pendingSyncs.push_back({ guid, now });
    }

    // World thread. Sends the full state to every queued character whose
    // session negotiated the bit; keeps the rest for up to SYNC_TIMEOUT_MS.
    void ProcessPendingSyncs()
    {
        std::vector<PendingSync> pending;
        {
            std::lock_guard<std::mutex> lock(s_pendingMutex);
            if (s_pendingSyncs.empty())
                return;

            pending.swap(s_pendingSyncs);
        }

        uint64 const now = NowMs();
        std::vector<PendingSync> retry;
        for (PendingSync const& sync : pending)
        {
            Player* player = ObjectAccessor::FindConnectedPlayer(sync.guid);
            if (!player)
                continue; // logged out

            if (player->IsInWorld() && ClientShowsCharges(player))
            {
                SendFullState(player);
                continue;
            }

            if (now - sync.queuedAtMs < SYNC_TIMEOUT_MS)
                retry.push_back(sync);
        }

        if (retry.empty())
            return;

        std::lock_guard<std::mutex> lock(s_pendingMutex);
        for (PendingSync const& sync : retry)
        {
            bool const requeued = std::any_of(s_pendingSyncs.begin(), s_pendingSyncs.end(),
                [&sync](PendingSync const& other) { return other.guid == sync.guid; });
            if (!requeued)
                s_pendingSyncs.push_back(sync);
        }
    }

    // World thread. Drops every entry whose charges are all back.
    void SweepRecharged()
    {
        uint64 const now = NowMs();

        std::lock_guard<std::mutex> lock(s_stateMutex);
        for (auto playerItr = s_states.begin(); playerItr != s_states.end();)
        {
            auto& spells = playerItr->second;
            for (auto spellItr = spells.begin(); spellItr != spells.end();)
            {
                auto const defItr = s_definitions.find(spellItr->first);
                if (defItr != s_definitions.end())
                    Settle(spellItr->second, defItr->second.rechargeMs, now);

                if (defItr == s_definitions.end() || spellItr->second.used == 0)
                    spellItr = spells.erase(spellItr);
                else
                    ++spellItr;
            }

            if (spells.empty())
                playerItr = s_states.erase(playerItr);
            else
                ++playerItr;
        }
    }

    // No charge left: the spell's cooldown ends exactly when the next charge returns.
    void HoldCooldownUntilNextCharge(Player* player, uint32 spellId, uint32 remainingMs)
    {
        if (!remainingMs)
            return;

        SpellCooldowns const& cooldowns = player->GetSpellCooldownMap();
        auto const itr = cooldowns.find(spellId);
        if (itr != cooldowns.end())
        {
            // SpellCooldown::end is the truncated uint32 game time in ms, as Player keeps it.
            uint32 const nowCd = static_cast<uint32>(GameTime::GetGameTimeMS().count());
            int32 const current = static_cast<int32>(itr->second.end - nowCd);
            int32 const delta = static_cast<int32>(remainingMs) - current;
            if (delta)
                player->ModifySpellCooldown(spellId, delta);
            return;
        }

        // needSendToClient: a relog sends it again in SMSG_INITIAL_SPELLS.
        player->AddSpellCooldown(spellId, 0, remainingMs, true);

        WorldPacket data;
        player->BuildCooldownPacket(data, SPELL_COOLDOWN_FLAG_NONE, spellId, remainingMs);
        player->SendDirectMessage(&data);
    }

    void LoadDefinitions()
    {
        s_definitions.clear();

        // A query on a missing table aborts the worldserver (1146), so the
        // feature stays off until the SQL update is applied.
        if (!DC::DbSchema::WorldTableExists(TABLE_SPELL_CHARGES))
        {
            LOG_ERROR("module.dc", "SpellCharges: table '{}' is missing, spell charges stay off "
                "until the world SQL update is applied", TABLE_SPELL_CHARGES);
            s_enabled = false;
            return;
        }

        QueryResult result = WorldDatabase.Query("SELECT spellId, maxCharges, rechargeMs FROM dc_spell_charges");
        if (result)
        {
            do
            {
                Field* fields = result->Fetch();
                uint32 const spellId = fields[0].Get<uint32>();
                uint8 const maxCharges = fields[1].Get<uint8>();
                uint32 const rechargeMs = fields[2].Get<uint32>();

                SpellInfo const* spellInfo = sSpellMgr->GetSpellInfo(spellId);
                if (!spellInfo)
                {
                    LOG_ERROR("module.dc", "dc_spell_charges: spell {} does not exist, skipped", spellId);
                    continue;
                }

                if (maxCharges < 1)
                {
                    LOG_ERROR("module.dc", "dc_spell_charges: spell {} has maxCharges 0, skipped", spellId);
                    continue;
                }

                if (spellInfo->IsPassive())
                {
                    LOG_ERROR("module.dc", "dc_spell_charges: spell {} is passive, skipped", spellId);
                    continue;
                }

                if (spellInfo->IsCooldownStartedOnEvent())
                {
                    LOG_ERROR("module.dc", "dc_spell_charges: spell {} starts its cooldown on an event, skipped",
                        spellId);
                    continue;
                }

                uint32 recharge = rechargeMs;
                if (!recharge)
                    recharge = spellInfo->RecoveryTime ? spellInfo->RecoveryTime : spellInfo->CategoryRecoveryTime;

                if (!recharge)
                {
                    LOG_ERROR("module.dc", "dc_spell_charges: spell {} has no recharge time (rechargeMs 0 and "
                        "no RecoveryTime or CategoryRecoveryTime), skipped", spellId);
                    continue;
                }

                if (recharge > MAX_RECHARGE_MS)
                {
                    LOG_ERROR("module.dc", "dc_spell_charges: spell {} recharge {} ms is longer than {} ms, skipped",
                        spellId, recharge, MAX_RECHARGE_MS);
                    continue;
                }

                ChargeDefinition& def = s_definitions[spellId];
                def.maxCharges = maxCharges;
                def.rechargeMs = recharge;
            } while (result->NextRow());
        }

        LOG_INFO("module.dc", "SpellCharges: loaded {} spell(s) with charges", s_definitions.size());
    }
}

class DCSpellChargesWorldScript : public WorldScript
{
public:
    DCSpellChargesWorldScript() : WorldScript("DCSpellChargesWorldScript",
        { WORLDHOOK_ON_STARTUP, WORLDHOOK_ON_UPDATE }) { }

    void OnStartup() override
    {
        s_enabled = sConfigMgr->GetOption<bool>("DC.SpellCharges.Enable", true);
        if (!s_enabled)
        {
            LOG_INFO("module.dc", "SpellCharges: disabled (DC.SpellCharges.Enable = 0)");
            return;
        }

        LoadDefinitions();
    }

    void OnUpdate(uint32 diff) override
    {
        if (!s_enabled)
            return;

        _syncTimer += diff;
        if (_syncTimer >= SYNC_INTERVAL_MS)
        {
            _syncTimer = 0;
            ProcessPendingSyncs();
        }

        _sweepTimer += diff;
        if (_sweepTimer >= SWEEP_INTERVAL_MS)
        {
            _sweepTimer = 0;
            SweepRecharged();
        }
    }

private:
    uint32 _syncTimer = 0;
    uint32 _sweepTimer = 0;
};

class DCSpellChargesPlayerScript : public PlayerScript
{
public:
    DCSpellChargesPlayerScript() : PlayerScript("DCSpellChargesPlayerScript",
        { PLAYERHOOK_ON_LOGIN, PLAYERHOOK_ON_LEARN_SPELL, PLAYERHOOK_ON_FORGOT_SPELL,
          PLAYERHOOK_ON_AFTER_SPEC_SLOT_CHANGED }) { }

    void OnPlayerLogin(Player* player) override
    {
        if (!s_enabled || !player || DCAddon::IsBotRecipient(player))
            return;

        QueueFullSync(player->GetGUID());
    }

    void OnPlayerLearnSpell(Player* player, uint32 spellID) override
    {
        if (!s_enabled || !player)
            return;

        auto const defItr = s_definitions.find(spellID);
        if (defItr == s_definitions.end() || !ClientShowsCharges(player))
            return;

        SendEntries(player, { CurrentEntry(player, spellID, defItr->second, NowMs()) }, false);
    }

    void OnPlayerForgotSpell(Player* player, uint32 spellID) override
    {
        if (!s_enabled || !player || !s_definitions.contains(spellID) || !ClientShowsCharges(player))
            return;

        // maxCharges 0: the client forgets the spell. The state is kept, so
        // learning it again does not refill spent charges.
        ChargeEntry entry;
        entry.spellId = spellID;
        SendEntries(player, { entry }, false);
    }

    void OnPlayerAfterSpecSlotChanged(Player* player, uint8 /*newSlot*/) override
    {
        if (!s_enabled || !player || !ClientShowsCharges(player))
            return;

        SendFullState(player);
    }
};

class DCSpellChargesSpellScript : public AllSpellScript
{
public:
    DCSpellChargesSpellScript() : AllSpellScript("DCSpellChargesSpellScript", { ALLSPELLHOOK_ON_CAST }) { }

    // Runs at the end of Spell::cast, after SendSpellCooldown() started the
    // spell's cooldown and SMSG_SPELL_GO went out.
    void OnSpellCast(Spell* spell, Unit* caster, SpellInfo const* spellInfo, bool /*skipCheck*/) override
    {
        if (!s_enabled || s_definitions.empty() || !spell || !caster || !spellInfo)
            return;

        Player* player = caster->ToPlayer();
        if (!player)
            return;

        auto const defItr = s_definitions.find(spellInfo->Id);
        if (defItr == s_definitions.end())
            return;

        // Triggered and item casts never spend a charge; .cheat cooldown has
        // already cleared the cooldown and must not get one back from here.
        if (spell->IsTriggered() || spell->m_CastItem || !spell->m_castItemGUID.IsEmpty()
            || player->GetCommandStatus(CHEAT_COOLDOWN))
            return;

        uint32 const spellId = spellInfo->Id;
        ChargeDefinition const& def = defItr->second;
        uint64 const now = NowMs();

        ChargeEntry entry;
        {
            std::lock_guard<std::mutex> lock(s_stateMutex);
            ChargeState& state = s_states[player->GetGUID()][spellId];
            Settle(state, def.rechargeMs, now);

            if (state.used == 0)
                state.rechargeStartMs = now;

            // At zero charges the spell can only have been cast because a
            // cooldown reset cleared it; that does not restore charges yet, so
            // the count stays at zero and the cooldown is set again below.
            if (state.used < def.maxCharges)
                ++state.used;

            entry = BuildEntry(spellId, def, &state, now);
        }

        if (entry.charges > 0)
            player->RemoveSpellCooldown(spellId, true); // castable again at once; the GCD stays
        else
            HoldCooldownUntilNextCharge(player, spellId, entry.nextChargeMs);

        if (ClientShowsCharges(player))
            SendEntries(player, { entry }, false);
    }
};

void AddSC_dc_addon_spellcharges()
{
    new DCSpellChargesWorldScript();
    new DCSpellChargesPlayerScript();
    new DCSpellChargesSpellScript();
}
