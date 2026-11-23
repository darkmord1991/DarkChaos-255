#include "GameTime.h"
#include "ScriptMgr.h"
#include "ScriptedCreature.h"
#include "SpellAuraEffects.h"
#include "SpellScript.h"
#include "Player.h"
#include "naxx40_instance.h"
#include <unordered_map>

class npc_naxx40_area_trigger : public CreatureScript
{
public:
    npc_naxx40_area_trigger() : CreatureScript("npc_naxx40_area_trigger") {}

    struct npc_naxx40_area_triggerAI: public ScriptedAI
    {
        npc_naxx40_area_triggerAI(Creature* creature) : ScriptedAI(creature)
        {
            me->SetDisplayId(11686); // Invisible
        }

        // MoveInLineOfSight fires on every move in range; refusal messages go out once per 10 s per player.
        bool ShouldNotify(Player const* player)
        {
            Seconds const now = GameTime::GetGameTime();
            auto itr = _lastNotice.find(player->GetGUID());
            if (itr != _lastNotice.end() && now - itr->second < 10s)
                return false;

            _lastNotice[player->GetGUID()] = now;
            return true;
        }

        void MoveInLineOfSight(Unit* who) override
        {
            if (who && me->GetDistance2d(who) < 5.0f)
            {
                if (Player* player = who->ToPlayer())
                {
                    if (Naxx40MeetsAttunement(player) && Naxx40PrepareRaidDifficulty(player, ShouldNotify(player)))
                        player->TeleportTo(NaxxramasMapId, 3005.51f, -3434.64f, 304.195f, 6.2831f);
                }

            }
            else if (who && me->GetDistance2d(who) < 20.0f)
            {
                if (Player* player = who->ToPlayer())
                {
                    if (Naxx40MeetsAttunement(player))
                    {
                        GameObject* door = me->FindNearestGameObject(GO_STRATH_GATE_40, 100.0f);
                        if (door)
                        {
                            door->SetGoState(GO_STATE_ACTIVE);
                        }
                    }
                }
            }
        }

    private:
        std::unordered_map<ObjectGuid, Seconds> _lastNotice;
    };

    CreatureAI* GetAI(Creature* creature) const override
    {
        return new npc_naxx40_area_triggerAI(creature);
    }
};

class boss_heigan_eye_stalk_40 : public CreatureScript
{
public:
    boss_heigan_eye_stalk_40() : CreatureScript("boss_heigan_eye_stalk_40") { }

    CreatureAI* GetAI(Creature* creature) const override
    {
        return GetNaxxramasAI<boss_heigan_eye_stalk_40AI>(creature);
    }

    struct boss_heigan_eye_stalk_40AI : public ScriptedAI
    {
        explicit boss_heigan_eye_stalk_40AI(Creature* creature) : ScriptedAI(creature)
        {
            timeSinceSpawn = 0;
            haveSubmerged = false;
            haveCastSubmerge = false;
        }

        uint32 timeSinceSpawn;
        bool haveSubmerged;
        bool haveCastSubmerge;
        const uint32 SPELL_MIND_FLAY = 29407;

        void Reset() override
        {
            me->SetNoCallAssistance(true);
            me->SetUnitFlag(UNIT_FLAG_DISABLE_MOVE);
        }

        void KilledUnit(Unit* who) override
        {
            if (who->IsPlayer() && me->GetInstanceScript())
                me->GetInstanceScript()->StorePersistentData(PERSISTENT_DATA_IMMORTAL_FAIL, 1);
        }

        void MoveInLineOfSight(Unit* who) override
        {
            if (timeSinceSpawn < 3000)
                return;

            if (!who || !(who->GetDistance2d(me) <= 19.0f))
                return;

            if (me->HasReactState(REACT_AGGRESSIVE) && me->CanStartAttack(who))
            {
                if (!me->IsWithinLOSInMap(who))
                {
                    return;
                }
                me->SetNoCallAssistance(true);
                if (!me->GetVictim())
                {
                    AttackStart(who);
                }
                else if (me->GetMap()->IsDungeon())
                {
                    who->SetInCombatWith(me);
                    me->AddThreat(who, 0.0f);
                }
            }
        }

        void UpdateAI(uint32 diff) override
        {
            me->SetNoCallAssistance(true);
            timeSinceSpawn += std::min(diff, std::numeric_limits<uint32>::max() - timeSinceSpawn);

            if (haveSubmerged)
            {
                if (!haveCastSubmerge)
                {
                    haveCastSubmerge = true;
                    me->CastSpell(me, 26234, false);
                }
                return;
            }

            if (!UpdateVictim())
                return;

            if (!me->IsNonMeleeSpellCast(false))
            {
                if (me->GetDistance(me->GetVictim()) < 35.0f)
                {
                    int32 bp0 = 750; // damage
                    int32 bp1 = -20; // movement speed
                    me->CastCustomSpell(me->GetVictim(), SPELL_MIND_FLAY, &bp0, &bp1, 0, false, nullptr, nullptr, ObjectGuid::Empty);
                }
                else
                {
                    DoStopAttack();
                }
            }
            DoMeleeAttackIfReady();
        }
    };
};

void AddSC_custom_creatures_40()
{
    new npc_naxx40_area_trigger();
    new boss_heigan_eye_stalk_40();
}
