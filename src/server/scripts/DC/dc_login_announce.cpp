#include "ScriptMgr.h"
#include "Chat.h"
#include "Player.h"
#include "World.h"
#include <array>
#include <string>

namespace
{
    // Class color hexes by Class enum index (1..11 used here)
    static constexpr std::array<char const*, 12> kClassHex = {
        "",         // 0 unused
        "C79C6E",  // 1 Warrior
        "F58CBA",  // 2 Paladin
        "ABD473",  // 3 Hunter
        "FFF569",  // 4 Rogue
        "FFFFFF",  // 5 Priest
        "C41F3B",  // 6 Death Knight
        "0070DE",  // 7 Shaman
        "69CCF0",  // 8 Mage
        "9482C9",  // 9 Warlock
        "",         // 10 (unused in WotLK: Monk)
        "FF7d0A"   // 11 Druid
    };

    static std::string MakeClassColoredName(Player* player)
    {
    uint8 cls = player->getClass();
        char const* hex = (cls < kClassHex.size() && kClassHex[cls] && *kClassHex[cls]) ? kClassHex[cls] : "FFFFFF";
        // |cffHEX|Hplayer:|h [Name]|h|r
        std::string out = "|cff";
        out += hex;
        out += "|Hplayer:|h [";
        out += player->GetName();
        out += "]|h|r";
        return out;
    }
}

class DC_LoginAnnounce : public PlayerScript
{
public:
    DC_LoginAnnounce() : PlayerScript("DC_LoginAnnounce") { }

    void OnPlayerLogin(Player* player) override
    {
        std::string colored = MakeClassColoredName(player);
        std::string suffix;
        if (player->IsGameMaster())
            suffix = " - |cffDF01D7[Owner]|h|r has logged in."; // matches lua color/tag
        else if (player->GetTeamId(true) == TEAM_HORDE)
            suffix = " - |cff610B0B[Horde]|h|r has logged in.";
        else
            suffix = " - |cff0101DF[Alliance]|h|r has logged in.";

        sWorld->SendServerMessage(SERVER_MSG_STRING, (colored + suffix).c_str());
    }

    void OnPlayerLogout(Player* player) override
    {
        // Simpler logout line like the Lua version
        std::string tag;
        if (player->IsGameMaster())
            tag = "GM";
        else
            tag = (player->GetTeamId(true) == TEAM_HORDE) ? "Horde" : "Alliance";

        std::string msg = "[" + player->GetName() + " - " + tag + "] has logged out.";
        sWorld->SendServerMessage(SERVER_MSG_STRING, msg.c_str());
    }
};

void AddSC_dc_login_announce()
{
    new DC_LoginAnnounce();
}
