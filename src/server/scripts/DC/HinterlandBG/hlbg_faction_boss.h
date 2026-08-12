// -----------------------------------------------------------------------------
// hlbg_faction_boss.h
// -----------------------------------------------------------------------------
// Shared AI for the two Hinterland BG faction bosses (Thrall for the Horde,
// Varian for the Alliance).
//
// Both sides run the *identical* mechanical kit - a single-target strike, a
// melee-range AoE, a heavy signature hit, a guard rally and an enrage - so
// neither faction has an easier objective to defend. Only the spell ids and the
// flavour text differ; the shared mechanics (rally, enrage) deliberately use the
// same spell on both sides.
//
// Killing a boss is the single largest swing in the match: BattlegroundHLBG
// classifies these entries as bosses, so the death drains
// HinterlandBG.ResourcesLoss.NpcBoss (default 200 of 450) from the owning team
// and credits the killer with a BossKill. That accounting lives in
// BattlegroundHLBG::HandleKillUnit - this AI only drives the fight itself.
// -----------------------------------------------------------------------------
#ifndef DC_HLBG_FACTION_BOSS_H
#define DC_HLBG_FACTION_BOSS_H

#include "Battleground.h"
#include "Chat.h"
#include "Creature.h"
#include "Map.h"
#include "Player.h"
#include "ScriptedCreature.h"
#include "StringFormat.h"

#include <string>
#include <vector>

namespace HLBGBoss
{
    // Shared across both bosses so the two sides stay mechanically identical.
    constexpr uint32 SPELL_BOSS_RALLY = 46763;  // Battle Shout
    constexpr uint32 SPELL_BOSS_ENRAGE = 8599;  // Enrage

    constexpr float RALLY_RADIUS = 45.0f;
    // Bosses guard a base; without this they can be dragged across the map and
    // killed away from their defenders.
    constexpr float LEASH_RADIUS = 70.0f;

    constexpr uint8 RALLY_HEALTH_PCT = 50;
    constexpr uint8 ENRAGE_HEALTH_PCT = 30;

    struct Config
    {
        uint32 strikeSpell = 0;     // single target, frequent
        uint32 aoeSpell = 0;        // punishes the melee pile
        uint32 signatureSpell = 0;  // the heavy hit

        // Guards this boss rallies. Entries come from HinterlandBGConstants so
        // the list stays in step with the battleground's own NPC classification.
        std::vector<uint32> defenderEntries;

        char const* displayName = "";
        char const* engageText = "";
        char const* rallyText = "";
        char const* enrageText = "";
        char const* slainText = "";
        char const* resetText = "";
    };

    class FactionBossAI : public ScriptedAI
    {
    public:
        FactionBossAI(Creature* creature, Config const& config)
            : ScriptedAI(creature), _config(config)
        {
        }

        void Reset() override
        {
            scheduler.CancelAll();
            _rallied = false;
            _enraged = false;
        }

        void JustEngagedWith(Unit* /*who*/) override
        {
            AnnounceToBattleground(_config.engageText);
            ScheduleCombatAbilities();
        }

        void DamageTaken(Unit* /*attacker*/, uint32& damage, DamageEffectType /*damageType*/,
            SpellSchoolMask /*damageSchoolMask*/) override
        {
            if (!_rallied && me->HealthBelowPctDamaged(RALLY_HEALTH_PCT, damage))
            {
                _rallied = true;
                RallyDefenders(true);
            }

            if (!_enraged && me->HealthBelowPctDamaged(ENRAGE_HEALTH_PCT, damage))
            {
                _enraged = true;
                DoCastSelf(SPELL_BOSS_ENRAGE, true);
                AnnounceToBattleground(_config.enrageText);
            }
        }

        void JustDied(Unit* /*killer*/) override
        {
            scheduler.CancelAll();
            // The resource swing and the BossKill credit are applied by
            // BattlegroundHLBG::HandleKillUnit off the core kill hook.
            AnnounceToBattleground(_config.slainText);
        }

        void EnterEvadeMode(EvadeReason why) override
        {
            // Only worth announcing when the boss actually gives up a fight.
            if (me->IsInCombat())
                AnnounceToBattleground(_config.resetText);

            scheduler.CancelAll();
            ScriptedAI::EnterEvadeMode(why);
        }

        void UpdateAI(uint32 diff) override
        {
            if (!UpdateVictim())
                return;

            if (me->GetDistance(me->GetHomePosition()) > LEASH_RADIUS)
            {
                EnterEvadeMode(EVADE_REASON_BOUNDARY);
                return;
            }

            scheduler.Update(diff, [this] { DoMeleeAttackIfReady(); });
        }

    private:
        void ScheduleCombatAbilities()
        {
            if (_config.strikeSpell)
            {
                scheduler.Schedule(4s, 7s, [this](TaskContext context)
                {
                    DoCastVictim(_config.strikeSpell);
                    context.Repeat(8s, 12s);
                });
            }

            if (_config.aoeSpell)
            {
                scheduler.Schedule(9s, 13s, [this](TaskContext context)
                {
                    DoCastAOE(_config.aoeSpell);
                    context.Repeat(13s, 18s);
                });
            }

            if (_config.signatureSpell)
            {
                scheduler.Schedule(16s, 21s, [this](TaskContext context)
                {
                    DoCastVictim(_config.signatureSpell);
                    context.Repeat(20s, 26s);
                });
            }

            scheduler.Schedule(20s, 28s, [this](TaskContext context)
            {
                RallyDefenders(false);
                context.Repeat(30s, 40s);
            });
        }

        // Buffs the boss's own guards. Deliberately limited to NPCs: handing a
        // player-facing buff to one side would tilt the battleground.
        //
        // `announce` is only set for the one-off rally at RALLY_HEALTH_PCT. The
        // periodic top-up stays silent - it fires every 30-40s for the whole
        // fight, and broadcasting that to every participant is pure spam.
        void RallyDefenders(bool announce)
        {
            if (_config.defenderEntries.empty())
                return;

            std::list<Creature*> defenders;
            me->GetCreatureListWithEntryInGrid(defenders, _config.defenderEntries, RALLY_RADIUS);

            for (Creature* defender : defenders)
            {
                if (!defender->IsAlive() || defender->HasAura(SPELL_BOSS_RALLY))
                    continue;

                defender->CastSpell(defender, SPELL_BOSS_RALLY, true);
            }

            if (announce)
                AnnounceToBattleground(_config.rallyText);
        }

        [[nodiscard]] Battleground* GetBattleground() const
        {
            // Null outside a battleground instance - these creatures also have
            // open-world spawns, which must not run battleground logic.
            if (BattlegroundMap* battlegroundMap = me->GetMap()->ToBattlegroundMap())
                return battlegroundMap->GetBG();

            return nullptr;
        }

        void AnnounceToBattleground(char const* message) const
        {
            if (!message || !*message)
                return;

            Battleground* battleground = GetBattleground();
            if (!battleground)
                return;

            std::string const text = Acore::StringFormat("|cffffd700[{}]|r {}", _config.displayName, message);
            for (auto const& playerEntry : battleground->GetPlayers())
            {
                Player* player = playerEntry.second;
                if (player && player->GetSession())
                    ChatHandler(player->GetSession()).SendSysMessage(text);
            }
        }

        Config const& _config;
        bool _rallied = false;
        bool _enraged = false;
    };
}

#endif // DC_HLBG_FACTION_BOSS_H
