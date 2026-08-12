// -----------------------------------------------------------------------------
// hlbg_npc_varian.cpp
// -----------------------------------------------------------------------------
// Hinterland BG - King Varian Wrynn, the Alliance faction boss (creature 810003).
//
// Varian anchors the Alliance base. Killing him drains
// HinterlandBG.ResourcesLoss.NpcBoss from the Alliance pool (default 200 of
// 450), making him the highest-value objective on the map for the Horde.
//
// The fight itself lives in HLBGBoss::FactionBossAI, shared with Thrall so both
// faction bosses stay mechanically identical. See hlbg_faction_boss.h.
// -----------------------------------------------------------------------------

#include "CreatureScript.h"
#include "hlbg_constants.h"
#include "hlbg_faction_boss.h"

using namespace HinterlandBGConstants;

namespace
{
    // Warrior-flavoured kit. Mirrors Thrall's slot-for-slot.
    constexpr uint32 SPELL_CLEAVE = 15284;         // strike
    constexpr uint32 SPELL_WHIRLWIND = 15589;      // melee-range AoE
    constexpr uint32 SPELL_MORTAL_STRIKE = 16856;  // signature

    HLBGBoss::Config const& GetVarianConfig()
    {
        static HLBGBoss::Config const config = []
        {
            HLBGBoss::Config built;
            built.strikeSpell = SPELL_CLEAVE;
            built.aoeSpell = SPELL_WHIRLWIND;
            built.signatureSpell = SPELL_MORTAL_STRIKE;
            built.defenderEntries = {
                Alliance_Healer, Alliance_Infantry, Alliance_Squadleader, Alliance_Battlewarden,
                Alliance_Sentry, Alliance_Scout, Alliance_GryphonHerald, Alliance_BannerBearer,
                Alliance_WatchCaptain, Alliance_Marksman, Alliance_Pathfinder, Alliance_RoostTender
            };
            built.displayName = "King Varian Wrynn";
            built.engageText = "The King is under attack! Defend the Alliance camp!";
            built.rallyText = "Varian rallies the Alliance defenders!";
            built.enrageText = "Varian enters a battle rage - his strikes land harder!";
            built.slainText = "The King has fallen! Alliance resources are draining!";
            built.resetText = "Varian breaks off and returns to his post.";
            return built;
        }();

        return config;
    }

    struct npc_Varian_hinterlandbgAI : public HLBGBoss::FactionBossAI
    {
        explicit npc_Varian_hinterlandbgAI(Creature* creature)
            : HLBGBoss::FactionBossAI(creature, GetVarianConfig())
        {
        }
    };
}

class npc_Varian_hinterlandbg : public CreatureScript
{
public:
    npc_Varian_hinterlandbg() : CreatureScript("npc_Varian_hinterlandbg") { }

    CreatureAI* GetAI(Creature* creature) const override
    {
        return new npc_Varian_hinterlandbgAI(creature);
    }
};

void AddSC_hinterlandbg_Varian_wrynn()
{
    new npc_Varian_hinterlandbg();
}
