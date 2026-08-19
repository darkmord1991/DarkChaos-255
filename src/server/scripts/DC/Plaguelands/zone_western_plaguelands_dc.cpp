/*
 * Copyright (C) 2016+ DarkChaos <www.azerothcore.org>, released under AGPL v3.
 *
 * Scourge Cauldrons on the downported Plaguelands continent (map 751).
 *
 * WHY THIS EXISTS AS A SEPARATE FILE
 * ----------------------------------
 * Stock `EasternKingdoms/zone_western_plaguelands.cpp` tells the four cauldrons
 * apart with `switch (me->GetAreaId())` over four Western Plaguelands sub-areas
 * (Felstone Field, Dalson's Tears, Gahrron's Withering, The Writhing Haunt). That
 * is correct on Eastern Kingdoms and is left completely untouched — patching stock
 * files just to serve a downport makes every upstream merge painful.
 *
 * It cannot work on map 751: the downported terrain bakes ONE area id per zone into
 * every MCNK, so GetAreaId() there always returns 4932 (Western Plaguelands) and no
 * case ever matches. All four cauldrons sit inert and quests 5216/5219/5222/5225
 * (Alliance) and 5229/5231/5233/5235 (Horde) cannot be completed.
 *
 * HOW THE SITE IS IDENTIFIED HERE
 * -------------------------------
 * Map 751 preserves Eastern Kingdoms world coordinates, so the four cauldrons stand
 * on exactly the same spots as on map 0 and position identifies the site with no
 * ambiguity. The coordinates below are NOT guessed: they are the live spawn
 * positions of entry 3611152, each cross-checked against its own quest's POI
 * (quest_poi_points), which sits within ~5 yards:
 *
 *     site                  cauldron spawn      quest POI          quests (A / H)
 *     Felstone Field        1727 / -1179        5216 -> 1729/-1175   5216 / 5229
 *     Dalson's Tears        1867 / -1564        5219 -> 1865/-1569   5219 / 5231
 *     Gahrron's Withering   1681 / -2283        5225 -> 1679/-2278   5225 / 5235
 *     The Writhing Haunt    1475 / -1868        5222 -> 1473/-1863   5222 / 5233
 *
 * The sites are ~400 yards apart, so the match radius cannot pick the wrong one.
 *
 * The summoned Cauldron Lords use the +3,600,000 clone band, not the stock ids:
 * stock 11075-11078 are levels 53-58, which would be a trivial speed bump in a zone
 * banded to 148-153. 3611078 (Soulwrath) already existed from the original import;
 * the other three are created by
 * Custom/Custom feature SQLs/worlddb/Plaguelands/74_cauldron_lords.sql.
 *
 * The quests have no kill objective (RequiredNpcOrGo1 = 0) — the Cauldron Lord is
 * the obstacle defending the cauldron, not a credit target — so nothing here needs
 * to grant credit.
 */

#include "CreatureScript.h"
#include "Player.h"
#include "ScriptedCreature.h"
#include "ScriptMgr.h"

namespace
{
    constexpr uint32 CAULDRON_CLONE_OFFSET = 3600000;

    struct CauldronSite
    {
        float  X;
        float  Y;
        uint32 StockSummon;      // + CAULDRON_CLONE_OFFSET at summon time
        uint32 QuestAlliance;
        uint32 QuestHorde;
    };

    constexpr CauldronSite CauldronSites[] =
    {
        { 1727.0f, -1179.0f, 11075, 5216, 5229 },   // Felstone Field
        { 1867.0f, -1564.0f, 11077, 5219, 5231 },   // Dalson's Tears
        { 1681.0f, -2283.0f, 11078, 5225, 5235 },   // Gahrron's Withering
        { 1475.0f, -1868.0f, 11076, 5222, 5233 }    // The Writhing Haunt
    };

    // Sites are ~400 yd apart; 100 yd is generous and still unambiguous.
    constexpr float SITE_RADIUS = 100.0f;

    constexpr Milliseconds SUMMON_DESPAWN = Milliseconds(600000);
    constexpr uint32       MIN_RESPAWN_SECONDS = 600;
}

struct npc_dc_scourge_cauldron : public ScriptedAI
{
    npc_dc_scourge_cauldron(Creature* creature) : ScriptedAI(creature) { }

    void Reset() override { }

    void JustEngagedWith(Unit* /*who*/) override { }

    void MoveInLineOfSight(Unit* who) override
    {
        if (!who)
            return;

        Player* player = who->ToPlayer();
        if (!player)
            return;

        CauldronSite const* site = ResolveSite();
        if (!site)
            return;

        if (player->GetQuestStatus(site->QuestAlliance) != QUEST_STATUS_INCOMPLETE &&
            player->GetQuestStatus(site->QuestHorde)    != QUEST_STATUS_INCOMPLETE)
            return;

        me->SummonCreature(site->StockSummon + CAULDRON_CLONE_OFFSET,
                           0.0f, 0.0f, 0.0f, 0.0f,
                           TEMPSUMMON_TIMED_OR_DEAD_DESPAWN, SUMMON_DESPAWN.count());
        DoDie();
    }

private:
    [[nodiscard]] CauldronSite const* ResolveSite() const
    {
        for (auto const& site : CauldronSites)
            if (me->IsWithinDist2d(site.X, site.Y, SITE_RADIUS))
                return &site;

        return nullptr;
    }

    void DoDie()
    {
        // The summoner dies with the summon, exactly as the stock script does.
        Unit::DealDamage(me, me, me->GetHealth(), nullptr, DIRECT_DAMAGE,
                         SPELL_SCHOOL_MASK_NORMAL, nullptr, false);

        // Override any database `spawntimesecs` so the cauldron cannot be
        // re-triggered into duplicate summons.
        if (me->GetRespawnDelay() < MIN_RESPAWN_SECONDS)
            me->SetRespawnDelay(MIN_RESPAWN_SECONDS);
    }
};

void AddSC_dc_western_plaguelands()
{
    RegisterCreatureAI(npc_dc_scourge_cauldron);
}
