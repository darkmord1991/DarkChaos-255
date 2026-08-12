// -----------------------------------------------------------------------------
// hlbg_npc_thrall_warchief.cpp
// -----------------------------------------------------------------------------
// Hinterland BG - Thrall, the Horde faction boss (creature 810002).
//
// Thrall anchors the Horde base. Killing him drains
// HinterlandBG.ResourcesLoss.NpcBoss from the Horde pool (default 200 of 450),
// making him the highest-value objective on the map for the Alliance.
//
// The fight itself lives in HLBGBoss::FactionBossAI, shared with Varian so both
// faction bosses stay mechanically identical. See hlbg_faction_boss.h.
// -----------------------------------------------------------------------------

#include "CreatureScript.h"
#include "hlbg_constants.h"
#include "hlbg_faction_boss.h"

using namespace HinterlandBGConstants;

namespace
{
    // Shaman-flavoured kit. Mirrors Varian's slot-for-slot.
    constexpr uint32 SPELL_EARTH_SHOCK = 16034;      // strike
    constexpr uint32 SPELL_THUNDERCLAP = 23931;      // melee-range AoE
    constexpr uint32 SPELL_CHAIN_LIGHTNING = 16033;  // signature

    HLBGBoss::Config const& GetThrallConfig()
    {
        static HLBGBoss::Config const config = []
        {
            HLBGBoss::Config built;
            built.strikeSpell = SPELL_EARTH_SHOCK;
            built.aoeSpell = SPELL_THUNDERCLAP;
            built.signatureSpell = SPELL_CHAIN_LIGHTNING;
            built.defenderEntries = {
                Horde_Heal, Horde_Infantry, Horde_Squadleader, Horde_Warcaller,
                Horde_Watchblade, Horde_Spiritmender, Horde_BannerSinger, Horde_Drumkeeper,
                Horde_FiresideShaman, Horde_Headhunter, Horde_Ritespeaker, Horde_BonfireTender
            };
            built.displayName = "Thrall";
            built.engageText = "The Warchief is under attack! Defend the Horde camp!";
            built.rallyText = "Thrall rallies the Horde defenders!";
            built.enrageText = "Thrall roars in fury - the elements answer him!";
            built.slainText = "The Warchief has fallen! Horde resources are draining!";
            built.resetText = "Thrall breaks off and returns to his post.";
            return built;
        }();

        return config;
    }

    struct npc_thrall_hinterlandbgAI : public HLBGBoss::FactionBossAI
    {
        explicit npc_thrall_hinterlandbgAI(Creature* creature)
            : HLBGBoss::FactionBossAI(creature, GetThrallConfig())
        {
        }
    };
}

class npc_thrall_hinterlandbg : public CreatureScript
{
public:
    npc_thrall_hinterlandbg() : CreatureScript("npc_thrall_hinterlandbg") { }

    CreatureAI* GetAI(Creature* creature) const override
    {
        return new npc_thrall_hinterlandbgAI(creature);
    }
};

void AddSC_npc_thrall_hinterlandbg()
{
    new npc_thrall_hinterlandbg();
}
