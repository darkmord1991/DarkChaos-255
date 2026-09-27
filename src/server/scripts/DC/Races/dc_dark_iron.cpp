/*
 * Dark Chaos - Dark Iron Dwarf (27) racials that need code
 * ========================================================
 *
 * Everything else about the race is data: Custom/Custom feature SQLs/worlddb/Tier1Reskins/ holds
 * the race rows and the racial spell definitions, and
 * CharacterCreation/03_custom_racials_skilllineability.sql grants the racials the stock way.
 *
 * This file covers the one racial data cannot express:
 *  - Dungeon Delver (265223): "While indoors, you move 4% faster." No 3.3.5 aura attribute follows
 *    indoor/outdoor, so 265223 is an inert DUMMY passive (the spellbook entry) and the speed is a
 *    separate passive aura, 265227 (MOD_SPEED_ALWAYS +4%), kept on the player while indoors and
 *    removed outdoors. WorldObject::IsOutdoors() is the cached position-data flag, so the check is
 *    cheap, and every other race leaves after one compare.
 */

#include "Player.h"
#include "ScriptMgr.h"

enum DarkIronSpells
{
    SPELL_DUNGEON_DELVER       = 265223,   // passive marker, granted with the other racials
    SPELL_DUNGEON_DELVER_SPEED = 265227    // +4% run speed while indoors, never granted
};

class dc_dark_iron_player : public PlayerScript
{
public:
    dc_dark_iron_player() : PlayerScript("dc_dark_iron_player", { PLAYERHOOK_ON_UPDATE }) { }

    void OnPlayerUpdate(Player* player, uint32 /*diff*/) override
    {
        if (player->getRace() != RACE_DARK_IRON_DWARF)
            return;

        bool const wanted = player->IsAlive() && !player->IsOutdoors() && player->HasSpell(SPELL_DUNGEON_DELVER);
        bool const applied = player->HasAura(SPELL_DUNGEON_DELVER_SPEED);

        if (wanted && !applied)
            player->AddAura(SPELL_DUNGEON_DELVER_SPEED, player);
        else if (!wanted && applied)
            player->RemoveAurasDueToSpell(SPELL_DUNGEON_DELVER_SPEED);
    }
};

void AddSC_dc_dark_iron()
{
    new dc_dark_iron_player();
}
