#include "Common.h"
#include "dc_addon_death_markers.h"

#include "dc_addon_namespace.h"

#include "Creature.h"
#include "DC/CrossSystem/CrossSystemMapCoords.h"
#include "DatabaseEnv.h"
#include "DBCStores.h"
#include "GameTime.h"
#include "ObjectMgr.h"
#include "Player.h"
#include "ScriptMgr.h"
#include "SpellInfo.h"
#include "SpellMgr.h"
#include "StringFormat.h"
#include "Unit.h"
#include "WorldSession.h"
#include "WorldSessionMgr.h"

#include <algorithm>
#include <limits>
#include <mutex>
#include <string>
#include <unordered_map>
#include <vector>

namespace DCAddon
{
namespace DeathMarkers
{
    namespace
    {
        constexpr uint32 MARKER_TTL_SECONDS = 24 * 60 * 60;

        struct DeathMarker
        {
            uint32 markerId = 0;
            std::string modeId;
            std::string modeLabel;

            uint32 victimGuid = 0;
            std::string victimName;
            uint8 victimLevel = 0;
            uint8 victimClass = 0;

            std::string killerType; // "creature" | "player" | "environment" | "unknown"
            uint32 killerEntry = 0;
            std::string killerName;
            uint32 killerLevel = 0;
            std::string killerRank; // "Elite" | "Rare Elite" | "Rare" | "Boss" (empty for a normal mob)
            std::string environmentType; // e.g. "Falling", "Lava" (only set when killerType == "environment")
            uint32 killingBlowDamage = 0;
            uint32 spellId = 0; // spell that landed the killing blow (0 for melee/environment)
            std::string spellName;
            std::string failureReason;

            uint32 mapId = 0;
            float nx = 0.0f;
            float ny = 0.0f;

            uint32 diedAt = 0;
            uint32 expiresAt = 0;
        };

        // Written from player-kill hooks (map-update worker threads) and read
        // from the world thread; every access must hold g_markersMutex.
        std::mutex g_markersMutex;
        std::vector<DeathMarker> g_markers;
        uint32 g_nextMarkerId = 1;

        // Caller must hold g_markersMutex.
        void PruneExpired(uint32 now)
        {
            g_markers.erase(
                std::remove_if(g_markers.begin(), g_markers.end(), [now](DeathMarker const& m)
                {
                    return m.expiresAt <= now;
                }),
                g_markers.end());
        }

        // Transient "what is about to kill this player" info, captured at the moment lethal
        // damage/cause is determined (Player::EnvironmentalDamage / Unit::DealDamage) and
        // consumed moments later by ResolveDeathContext(). Keyed by victim GUID counter.
        // Written from combat code (map-update worker threads); every access must hold g_pendingMutex.
        struct PendingDeathInfo
        {
            uint32 killingBlowDamage = 0;
            uint32 killingBlowSpellId = 0; // 0 = melee / environmental
            int16 environmentalType = -1;  // -1 = none captured; else an EnviromentalDamage enum value
            uint32 notedAt = 0;

            // Killer fields resolved while the attacker was still guaranteed alive; killerType is
            // empty when the damage was self-inflicted or had no attacker.
            DeathContext killer;
        };

        constexpr uint32 PENDING_TTL_SECONDS = 30;

        std::mutex g_pendingMutex;
        std::unordered_map<uint32, PendingDeathInfo> g_pending;

        // Caller must hold g_pendingMutex.
        void PrunePending(uint32 now)
        {
            for (auto it = g_pending.begin(); it != g_pending.end(); )
            {
                if (now - it->second.notedAt > PENDING_TTL_SECONDS)
                    it = g_pending.erase(it);
                else
                    ++it;
            }
        }

        void ClearPendingDeathInfo(uint32 guidCounter)
        {
            std::lock_guard<std::mutex> lock(g_pendingMutex);
            g_pending.erase(guidCounter);
        }

        // One row per environmental cause: the short token the client switches on, and the sentence
        // the failure reason is built from. Keeping both in one table is what stops the marker's
        // environmentType and its failureReason from ever describing different causes.
        struct EnvironmentalCauseText
        {
            char const* token;
            char const* phrase;
        };

        EnvironmentalCauseText EnvironmentalCauseTextFor(uint8 type)
        {
            switch (type)
            {
                case DAMAGE_EXHAUSTED:    return { "Fatigue",  "Succumbed to exhaustion." };
                case DAMAGE_DROWNING:     return { "Drowning", "Drowned." };
                case DAMAGE_FALL:         return { "Falling",  "Fell to their death." };
                case DAMAGE_LAVA:         return { "Lava",     "Burned alive in lava." };
                case DAMAGE_SLIME:        return { "Slime",    "Dissolved in slime." };
                case DAMAGE_FIRE:         return { "Fire",     "Burned to death." };
                // Shares the "Falling" token with DAMAGE_FALL, so it must share its phrase too -
                // the token is all that survives into BuildFailureReason().
                case DAMAGE_FALL_TO_VOID: return { "Falling",  "Fell to their death." };
                default:                  return { "",         "Killed by the environment." };
            }
        }

        char const* EnvironmentalTypeToString(uint8 type)
        {
            return EnvironmentalCauseTextFor(type).token;
        }

        // Reverse of EnvironmentalTypeToString(): the marker only carries the token, so the reason
        // is looked back up through the same table rather than a second hand-written switch.
        char const* EnvironmentalPhraseForToken(std::string const& token)
        {
            // DAMAGE_FALL_TO_VOID is deliberately absent: it shares DAMAGE_FALL's token, so it
            // could never be reached by a token lookup.
            static constexpr uint8 knownTypes[] =
            {
                DAMAGE_EXHAUSTED, DAMAGE_DROWNING, DAMAGE_FALL, DAMAGE_LAVA, DAMAGE_SLIME, DAMAGE_FIRE
            };

            if (!token.empty())
            {
                for (uint8 type : knownTypes)
                {
                    EnvironmentalCauseText const text = EnvironmentalCauseTextFor(type);
                    if (token == text.token)
                        return text.phrase;
                }
            }

            // Any token we cannot place (an older row, a cause added since) still gets a sentence.
            return EnvironmentalCauseTextFor(std::numeric_limits<uint8>::max()).phrase;
        }

        char const* CreatureRankToString(uint32 rank)
        {
            switch (rank)
            {
                case CREATURE_ELITE_ELITE:     return "Elite";
                case CREATURE_ELITE_RAREELITE: return "Rare Elite";
                case CREATURE_ELITE_WORLDBOSS: return "Boss";
                case CREATURE_ELITE_RARE:      return "Rare";
                default:                       return "";
            }
        }

        // Describe `killer` into the killer-related fields of `ctx`, leaving them untouched when
        // the damage was self-inflicted or had no attacker. Shared by the capture path
        // (NotePendingKillingBlow) and the resolve path so both describe a killer identically.
        void FillKillerFields(DeathContext& ctx, Unit const* victim, Unit const* killer)
        {
            // Environmental self-damage routes through Unit::DealDamage(this, this, ...), so the
            // "killer" is the victim itself rather than nullptr.
            if (!victim || !killer || killer->GetGUID() == victim->GetGUID())
                return;

            if (Creature const* creature = killer->ToCreature())
            {
                ctx.killerType = "creature";
                ctx.killerEntry = creature->GetEntry();
                ctx.killerName = creature->GetName();
                ctx.killerLevel = creature->GetLevel();
                ctx.killerRank = CreatureRankToString(creature->GetCreatureTemplate()->rank);

                // A pet/guardian/totem kill is really a kill by its owner; name both so the reason
                // does not read as if a nameless minion did it on its own.
                if (Unit const* owner = creature->GetCharmerOrOwner())
                    if (owner->GetGUID() != creature->GetGUID())
                        ctx.killerOwnerName = owner->GetName();
            }
            else if (killer->IsPlayer())
            {
                ctx.killerType = "player";
                ctx.killerName = killer->GetName();
                ctx.killerLevel = killer->GetLevel();
            }
        }

        Optional<std::pair<float, float>> TryGetNormalizedCoords(uint32 zoneId, float x, float y)
        {
            float nx = 0.0f;
            float ny = 0.0f;
            if (!DarkChaos::CrossSystem::MapCoords::TryComputeNormalized(zoneId, x, y, nx, ny))
                return {};

            return std::make_pair(nx, ny);
        }

        JsonValue Serialize(DeathMarker const& m)
        {
            JsonValue obj; obj.SetObject();
            obj.Set("markerId", JsonValue(static_cast<int32>(m.markerId)));
            obj.Set("modeId", JsonValue(m.modeId));
            obj.Set("modeLabel", JsonValue(m.modeLabel));

            obj.Set("victimGuid", JsonValue(static_cast<int32>(m.victimGuid)));
            obj.Set("victimName", JsonValue(m.victimName));
            obj.Set("victimLevel", JsonValue(static_cast<int32>(m.victimLevel)));
            obj.Set("victimClass", JsonValue(static_cast<int32>(m.victimClass)));

            obj.Set("killerType", JsonValue(m.killerType));
            if (m.killerEntry)
                obj.Set("killerEntry", JsonValue(static_cast<int32>(m.killerEntry)));
            if (!m.killerName.empty())
                obj.Set("killerName", JsonValue(m.killerName));
            if (m.killerLevel)
                obj.Set("killerLevel", JsonValue(static_cast<int32>(m.killerLevel)));
            if (!m.killerRank.empty())
                obj.Set("killerRank", JsonValue(m.killerRank));
            if (!m.environmentType.empty())
                obj.Set("environmentType", JsonValue(m.environmentType));
            if (m.killingBlowDamage)
                obj.Set("killingBlowDamage", JsonValue(static_cast<int32>(m.killingBlowDamage)));
            if (m.spellId)
                obj.Set("spellId", JsonValue(static_cast<int32>(m.spellId)));
            if (!m.spellName.empty())
                obj.Set("spellName", JsonValue(m.spellName));
            if (!m.failureReason.empty())
                obj.Set("failureReason", JsonValue(m.failureReason));

            obj.Set("mapId", JsonValue(static_cast<int32>(m.mapId)));
            obj.Set("nx", JsonValue(m.nx));
            obj.Set("ny", JsonValue(m.ny));

            obj.Set("diedAt", JsonValue(static_cast<int32>(m.diedAt)));
            obj.Set("expiresAt", JsonValue(static_cast<int32>(m.expiresAt)));
            return obj;
        }

        void BroadcastNewMarker(DeathMarker const& marker)
        {
            JsonValue one; one.SetArray();
            one.Push(Serialize(marker));

            JsonMessage upd(Module::WORLD, Opcode::World::SMSG_UPDATE);
            upd.Set("deaths", one);

            auto const& sessions = sWorldSessionMgr->GetAllSessions();
            for (auto const& pair : sessions)
            {
                if (WorldSession* session = pair.second)
                {
                    if (Player* player = session->GetPlayer())
                    {
                        if (player->IsInWorld())
                            upd.Send(player);
                    }
                }
            }
        }

        // Fire-and-forget persistence so markers survive a worldserver restart. Matches the
        // established local convention (raw escaped SQL, not PreparedStatement) used by the
        // sibling dc_character_challenge_mode_log / dc_prestige_challenges tables.
        void PersistMarker(DeathMarker const& m)
        {
            std::string modeIdEsc = m.modeId;
            CharacterDatabase.EscapeString(modeIdEsc);
            std::string modeLabelEsc = m.modeLabel;
            CharacterDatabase.EscapeString(modeLabelEsc);
            std::string victimNameEsc = m.victimName;
            CharacterDatabase.EscapeString(victimNameEsc);
            std::string killerTypeEsc = m.killerType;
            CharacterDatabase.EscapeString(killerTypeEsc);
            std::string killerNameEsc = m.killerName;
            CharacterDatabase.EscapeString(killerNameEsc);
            std::string killerRankEsc = m.killerRank;
            CharacterDatabase.EscapeString(killerRankEsc);
            std::string environmentTypeEsc = m.environmentType;
            CharacterDatabase.EscapeString(environmentTypeEsc);
            std::string spellNameEsc = m.spellName;
            CharacterDatabase.EscapeString(spellNameEsc);
            std::string failureReasonEsc = m.failureReason;
            CharacterDatabase.EscapeString(failureReasonEsc);

            CharacterDatabase.Execute(
                "INSERT INTO dc_death_markers "
                "(mode_id, mode_label, victim_guid, victim_name, victim_level, victim_class, "
                "killer_type, killer_entry, killer_name, killer_level, killer_rank, environment_type, "
                "killing_blow_damage, spell_id, spell_name, "
                "failure_reason, map_id, pos_x, pos_y, died_at, expires_at) "
                "VALUES ('{}', '{}', {}, '{}', {}, {}, '{}', {}, '{}', {}, '{}', '{}', {}, {}, '{}', '{}', {}, {}, {}, {}, {})",
                modeIdEsc, modeLabelEsc, m.victimGuid, victimNameEsc, m.victimLevel, m.victimClass,
                killerTypeEsc, m.killerEntry, killerNameEsc, m.killerLevel, killerRankEsc, environmentTypeEsc,
                m.killingBlowDamage, m.spellId, spellNameEsc,
                failureReasonEsc, m.mapId, m.nx, m.ny, m.diedAt, m.expiresAt);

            // Opportunistic cleanup, piggybacked on the same cadence as new deaths rather than a
            // separate scheduled task.
            CharacterDatabase.Execute("DELETE FROM dc_death_markers WHERE expires_at <= UNIX_TIMESTAMP()");
        }

        // Loads persisted, not-yet-expired markers into g_markers. Only meant to run once, from
        // WorldScript::OnStartup() before the world accepts any connections/updates, but still
        // takes g_markersMutex to keep every g_markers access uniformly guarded.
        void LoadPersistedMarkers()
        {
            uint32 now = static_cast<uint32>(GameTime::GetGameTime().count());

            QueryResult result = CharacterDatabase.Query(
                "SELECT id, mode_id, mode_label, victim_guid, victim_name, victim_level, victim_class, "
                "killer_type, killer_entry, killer_name, killer_level, killer_rank, environment_type, "
                "killing_blow_damage, spell_id, spell_name, "
                "failure_reason, map_id, pos_x, pos_y, died_at, expires_at "
                "FROM dc_death_markers WHERE expires_at > {} ORDER BY id",
                now);

            if (!result)
                return;

            std::vector<DeathMarker> loaded;
            uint32 maxId = 0;
            do
            {
                Field* fields = result->Fetch();

                DeathMarker marker;
                marker.markerId = fields[0].Get<uint32>();
                marker.modeId = fields[1].Get<std::string>();
                marker.modeLabel = fields[2].Get<std::string>();
                marker.victimGuid = fields[3].Get<uint32>();
                marker.victimName = fields[4].Get<std::string>();
                marker.victimLevel = fields[5].Get<uint8>();
                marker.victimClass = fields[6].Get<uint8>();
                marker.killerType = fields[7].Get<std::string>();
                marker.killerEntry = fields[8].Get<uint32>();
                marker.killerName = fields[9].Get<std::string>();
                marker.killerLevel = fields[10].Get<uint32>();
                marker.killerRank = fields[11].Get<std::string>();
                marker.environmentType = fields[12].Get<std::string>();
                marker.killingBlowDamage = fields[13].Get<uint32>();
                marker.spellId = fields[14].Get<uint32>();
                marker.spellName = fields[15].Get<std::string>();
                marker.failureReason = fields[16].Get<std::string>();
                marker.mapId = fields[17].Get<uint32>();
                marker.nx = fields[18].Get<float>();
                marker.ny = fields[19].Get<float>();
                marker.diedAt = fields[20].Get<uint32>();
                marker.expiresAt = fields[21].Get<uint32>();

                maxId = std::max(maxId, marker.markerId);
                loaded.push_back(std::move(marker));
            } while (result->NextRow());

            std::lock_guard<std::mutex> lock(g_markersMutex);
            for (DeathMarker& marker : loaded)
                g_markers.push_back(std::move(marker));
            g_nextMarkerId = std::max(g_nextMarkerId, maxId + 1);

            LOG_INFO("dc.addon", "DeathMarkers: loaded {} persisted marker(s) from dc_death_markers", loaded.size());
        }

    } // namespace

    void NotePendingEnvironmentalCause(Player* victim, uint8_t environmentalType)
    {
        if (!victim)
            return;

        uint32 guid = victim->GetGUID().GetCounter();
        uint32 now = static_cast<uint32>(GameTime::GetGameTime().count());

        std::lock_guard<std::mutex> lock(g_pendingMutex);
        PrunePending(now);
        PendingDeathInfo& info = g_pending[guid];
        info.environmentalType = static_cast<int16>(environmentalType);
        info.notedAt = now;
    }

    void NotePendingKillingBlow(Player* victim, Unit* attacker, uint32_t damage, uint32_t spellId)
    {
        if (!victim)
            return;

        uint32 guid = victim->GetGUID().GetCounter();
        uint32 now = static_cast<uint32>(GameTime::GetGameTime().count());

        // Describe the attacker now, while it is certainly still alive and in world - by the time
        // the death hooks run it may already have been despawned or freed.
        DeathContext killerInfo;
        FillKillerFields(killerInfo, victim, attacker);

        std::lock_guard<std::mutex> lock(g_pendingMutex);
        PrunePending(now);
        PendingDeathInfo& info = g_pending[guid];
        info.killingBlowDamage = damage;
        info.killingBlowSpellId = spellId;
        info.killer = std::move(killerInfo);
        info.notedAt = now;
    }

    DeathContext ResolveDeathContext(Player* victim, Unit* killer)
    {
        DeathContext ctx;
        if (!victim)
            return ctx;

        uint32 guid = victim->GetGUID().GetCounter();
        uint32 now = static_cast<uint32>(GameTime::GetGameTime().count());

        PendingDeathInfo pending;
        bool hasPending = false;
        {
            std::lock_guard<std::mutex> lock(g_pendingMutex);
            auto it = g_pending.find(guid);
            if (it != g_pending.end() && (now - it->second.notedAt) <= PENDING_TTL_SECONDS)
            {
                pending = it->second;
                hasPending = true;
            }
        }

        if (hasPending)
        {
            ctx.killingBlowDamage = pending.killingBlowDamage;
            ctx.spellId = pending.killingBlowSpellId;
            if (ctx.spellId)
            {
                if (SpellInfo const* spellInfo = sSpellMgr->GetSpellInfo(ctx.spellId))
                    if (spellInfo->SpellName[LOCALE_enUS] && spellInfo->SpellName[LOCALE_enUS][0])
                        ctx.spellName = spellInfo->SpellName[LOCALE_enUS];
            }
        }

        FillKillerFields(ctx, victim, killer);

        // OnPlayerJustDied() has no killer parameter and fires before the creature/PvP kill hooks,
        // so for anything acting on that hook the noted attacker is the only killer there is.
        if (ctx.killerType.empty() && hasPending && !pending.killer.killerType.empty())
        {
            ctx.killerType = pending.killer.killerType;
            ctx.killerEntry = pending.killer.killerEntry;
            ctx.killerName = pending.killer.killerName;
            ctx.killerOwnerName = pending.killer.killerOwnerName;
            ctx.killerLevel = pending.killer.killerLevel;
            ctx.killerRank = pending.killer.killerRank;
        }

        if (ctx.killerType.empty())
        {
            if (hasPending && pending.environmentalType >= 0)
            {
                ctx.killerType = "environment";
                ctx.environmentType = EnvironmentalTypeToString(static_cast<uint8>(pending.environmentalType));
            }
            else
            {
                ctx.killerType = "unknown";
            }
        }

        return ctx;
    }

    std::string BuildFailureReason(DeathContext const& ctx)
    {
        // A fatal fall or drowning has no killer and no spell to append; the cause is the sentence.
        if (ctx.killerType == "environment")
            return EnvironmentalPhraseForToken(ctx.environmentType);

        // "with <spell>" is only meaningful when a named spell landed the blow; a melee killing
        // blow carries no spell and must not be described as one.
        std::string spellClause;
        if (!ctx.spellName.empty())
            spellClause = Acore::StringFormat(" with {}", ctx.spellName);

        if (ctx.killerType == "creature" || ctx.killerType == "player")
        {
            std::string name = ctx.killerName.empty()
                ? (ctx.killerType == "player" ? std::string("another player") : std::string("an unknown foe"))
                : ctx.killerName;

            // "Ragnaros (Level 63 Boss)" / "Hogger (Level 11)" / "Fluffy, Bob's minion"
            std::string qualifier;
            if (!ctx.killerOwnerName.empty())
                qualifier = Acore::StringFormat(", {}'s minion", ctx.killerOwnerName);
            else if (ctx.killerLevel && !ctx.killerRank.empty())
                qualifier = Acore::StringFormat(" (Level {} {})", ctx.killerLevel, ctx.killerRank);
            else if (ctx.killerLevel)
                qualifier = Acore::StringFormat(" (Level {})", ctx.killerLevel);

            return Acore::StringFormat("Slain by {}{}{}.", name, qualifier, spellClause);
        }

        // Nothing identified the killer: a despawned caster, a DoT ticking after its source is
        // gone, a .die command. Report whatever fragment we do have rather than a bare "Died.".
        if (!ctx.spellName.empty())
            return Acore::StringFormat("Killed by {}.", ctx.spellName);

        return "Died to an unknown cause.";
    }

    void RecordChallengeDeath(Player* victim, Unit* killer, char const* modeId, char const* modeLabel, char const* failureReason)
    {
        if (!victim)
            return;

        uint32 now = static_cast<uint32>(GameTime::GetGameTime().count());

        DeathMarker marker;
        marker.modeId = modeId ? modeId : "challenge";
        marker.modeLabel = modeLabel ? modeLabel : "Challenge";

        marker.victimGuid = victim->GetGUID().GetCounter();
        marker.victimName = victim->GetName();
        marker.victimLevel = static_cast<uint8>(victim->GetLevel());
        marker.victimClass = static_cast<uint8>(victim->getClass());

        // Note: for client display, mapId is the server zone/area id.
        marker.mapId = victim->GetZoneId();
        marker.diedAt = now;
        marker.expiresAt = now + MARKER_TTL_SECONDS;

        DeathContext ctx = ResolveDeathContext(victim, killer);
        marker.killerType = ctx.killerType;
        marker.killerEntry = ctx.killerEntry;
        marker.killerName = ctx.killerName;
        marker.killerLevel = ctx.killerLevel;
        marker.killerRank = ctx.killerRank;
        marker.environmentType = ctx.environmentType;
        marker.killingBlowDamage = ctx.killingBlowDamage;
        marker.spellId = ctx.spellId;
        marker.spellName = ctx.spellName;

        // A caller-supplied reason wins; otherwise describe the death from what we just resolved.
        marker.failureReason = failureReason ? failureReason : BuildFailureReason(ctx);

        // Position -> nx/ny (0..1)
        float x = victim->GetPositionX();
        float y = victim->GetPositionY();
        if (auto norm = TryGetNormalizedCoords(marker.mapId, x, y))
        {
            marker.nx = norm->first;
            marker.ny = norm->second;
        }
        else
        {
            // If we can't normalize, we still record but it won't be placeable on the client map.
            marker.nx = 0.0f;
            marker.ny = 0.0f;
        }

        {
            std::lock_guard<std::mutex> lock(g_markersMutex);
            PruneExpired(now);
            marker.markerId = g_nextMarkerId++;
            g_markers.push_back(marker);
        }

        PersistMarker(marker);
        BroadcastNewMarker(marker);
        ClearPendingDeathInfo(marker.victimGuid);
    }

    JsonValue BuildDeathMarkersArray()
    {
        JsonValue arr; arr.SetArray();
        uint32 now = static_cast<uint32>(GameTime::GetGameTime().count());

        std::lock_guard<std::mutex> lock(g_markersMutex);
        PruneExpired(now);

        for (DeathMarker const& m : g_markers)
            arr.Push(Serialize(m));

        return arr;
    }

} // namespace DeathMarkers
} // namespace DCAddon

class DeathMarkersWorldScript : public WorldScript
{
public:
    DeathMarkersWorldScript() : WorldScript("DeathMarkersWorldScript") { }

    void OnStartup() override
    {
        DCAddon::DeathMarkers::LoadPersistedMarkers();
    }
};

void AddSC_dc_addon_death_markers()
{
    new DeathMarkersWorldScript();
}
