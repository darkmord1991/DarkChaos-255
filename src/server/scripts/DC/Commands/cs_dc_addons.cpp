/*
 * Consolidated DC addon-related commands.
 *
 * Commands (single entry: .dc):
 *  - .dc send <playername>
 *      Send the current server XP snapshot to <playername> (addon-style whisper)
 *  - .dc sendforce <playername> | .dc sendforce-self
 *      Force-send the current server XP snapshot, bypassing throttles. Use -self to target yourself.
 *  - .dc grant <playername> <amount>
 *      Grant <amount> XP to <playername> using server GiveXP path.
 *  - .dc grantself <amount>
 *      Grant <amount> XP to your own character.
 *  - .dc givexp <playername> <amount>  (alias form exposed via .dc)
 *  - .dc givexp self <amount>
 *
 * Examples:
 *  .dc send Alice
 *  .dc sendforce-self
 *  .dc grant Bob 100000
 *  .dc givexp self 50000
 *
 * Notes:
 *  - This file consolidates DC-related GM commands into a single top-level command
 *    (".dc") to keep addon administration in one place. After changing this C++ file
 *    you must rebuild the server so the command is compiled and registered.
 */
#include "CommandScript.h"
#include "Chat.h"
#include "Metric.h"
#include "Player.h"
#include "ObjectAccessor.h"
#include "ScriptMgr.h"
#include "Map.h"
#include "Group.h"
#include "DC/MythicPlus/dc_mythicplus_difficulty_scaling.h"

// forward declaration of helpers implemented in DC_AddonHelpers.cpp
void SendXPAddonToPlayer(Player* player, uint32 xp, uint32 xpMax, uint32 level, const char* context = "XP");
void SendXPAddonToPlayerForce(Player* player, uint32 xp, uint32 xpMax, uint32 level, const char* context = "XP");
bool HandleDcPartitionSubcommand(ChatHandler* handler, std::vector<std::string_view> const& args, std::vector<std::string_view>::iterator& it);

using namespace Acore::ChatCommands;

class dc_addons_commandscript : public CommandScript
{
public:
    dc_addons_commandscript() : CommandScript("dc_addons_commandscript") { }

    ChatCommandTable GetCommands() const override
    {
        static ChatCommandTable commandTable =
        {
            // Single consolidated entry: .dc <subcommand> ...
            { "dc", HandleDCRXPCommand, SEC_GAMEMASTER, Console::No }
        };
        return commandTable;
    }

    // DCRXP commands (send, sendforce, grant, grantself)
    static bool HandleDCRXPCommand(ChatHandler* handler, std::vector<std::string_view> args)
    {
        if (args.empty())
        {
            handler->PSendSysMessage("Usage: .dc send <playername> | sendforce <playername>|sendforce-self | grant <player> <amt> | grantself <amt> | givexp <player|self> <amt> | difficulty <normal|heroic|mythic|info> | reload mythic | partition status");
            handler->SetSentErrorMessage(true);
            return false;
        }

        auto it = args.begin();
        std::string_view sub = *it;
        std::string subNorm;
        subNorm.reserve(sub.size());
        for (char c : sub)
        {
            if (c == '-' || c == '_' || c == ' ') continue;
            subNorm.push_back(std::tolower(static_cast<unsigned char>(c)));
        }

        if (subNorm == "send")
        {
            ++it;
            if (it == args.end())
            {
                handler->PSendSysMessage("Usage: .dc send <playername>");
                handler->SetSentErrorMessage(true);
                return false;
            }

            std::string playerName((*it).data(), (*it).size());
            Player* target = ObjectAccessor::FindPlayerByName(playerName, false);
            if (!target)
            {
                handler->PSendSysMessage("Player '{}' not found.", playerName);
                handler->SetSentErrorMessage(true);
                return false;
            }

            uint32 xp = target->GetUInt32Value(PLAYER_XP);
            uint32 xpMax = target->GetUInt32Value(PLAYER_NEXT_LEVEL_XP);
            uint32 level = target->GetLevel();
            SendXPAddonToPlayer(target, xp, xpMax, level);
            handler->PSendSysMessage("Sent DCRXP addon message to {} (xp={} xpMax={} level={})", playerName, xp, xpMax, level);
            return true;
        }


        if (subNorm == "partition")
        {
            return HandleDcPartitionSubcommand(handler, args, it);
        }

        if (subNorm == "regen")
        {
            ++it;
            Player* target = nullptr;
            if (it == args.end() || *it == "self")
                target = handler->GetSession() ? handler->GetSession()->GetPlayer() : nullptr;
            else
            {
                std::string playerName((*it).data(), (*it).size());
                target = ObjectAccessor::FindPlayerByName(playerName, false);
            }

            if (!target)
            {
                handler->PSendSysMessage("Player not found.");
                handler->SetSentErrorMessage(true);
                return false;
            }

            handler->SendSysMessage("|cff00ff00=== Regen Diagnostics ===|r");
            handler->PSendSysMessage("Player: {} ({})", target->GetName(), target->GetGUID().ToString());
            handler->PSendSysMessage("Map: {} | Zone: {} | InCombat: {}", target->GetMapId(), target->GetZoneId(), target->IsInCombat() ? "YES" : "NO");
            handler->PSendSysMessage("RegenTimer: {} ms | RegenTimerCount: {} ms", target->GetRegenTimer(), target->GetRegenTimerCount());

            handler->PSendSysMessage("Health: {}/{} | BaseHealthRegen: {}", target->GetHealth(), target->GetMaxHealth(), target->GetBaseHealthRegen());
            handler->PSendSysMessage("Mana: {}/{} | BaseManaRegen: {}", target->GetPower(POWER_MANA), target->GetMaxPower(POWER_MANA), target->GetBaseManaRegen());

            handler->PSendSysMessage("Prevent Mana Regen Aura: {}", target->HasAuraTypeWithMiscvalue(SPELL_AURA_PREVENT_REGENERATE_POWER, POWER_MANA + 1) ? "YES" : "NO");
            handler->PSendSysMessage("Prevent Health Regen Aura: {}", target->HasInterruptRegenAura() ? "YES" : "NO");
            handler->PSendSysMessage("Regen During Combat Aura: {}", target->HasRegenDuringCombatAura() ? "YES" : "NO");
            handler->PSendSysMessage("Health Regen In Combat Aura: {}", target->HasHealthRegenInCombatAura() ? "YES" : "NO");

            handler->PSendSysMessage("Mana Regen Flat: {:.3f}", target->GetFloatValue(static_cast<uint16>(UNIT_FIELD_POWER_REGEN_FLAT_MODIFIER) + AsUnderlyingType(POWER_MANA)));
            handler->PSendSysMessage("Mana Regen Interrupted: {:.3f}", target->GetFloatValue(static_cast<uint16>(UNIT_FIELD_POWER_REGEN_INTERRUPTED_FLAT_MODIFIER) + AsUnderlyingType(POWER_MANA)));
            handler->PSendSysMessage("Energy Regen Flat: {:.3f}", target->GetFloatValue(static_cast<uint16>(UNIT_FIELD_POWER_REGEN_FLAT_MODIFIER) + AsUnderlyingType(POWER_ENERGY)));
            handler->PSendSysMessage("Energy Regen Interrupted: {:.3f}", target->GetFloatValue(static_cast<uint16>(UNIT_FIELD_POWER_REGEN_INTERRUPTED_FLAT_MODIFIER) + AsUnderlyingType(POWER_ENERGY)));

            handler->PSendSysMessage("Has UNIT_FLAG2_REGENERATE_POWER: {}", target->HasUnitFlag2(UNIT_FLAG2_REGENERATE_POWER) ? "YES" : "NO");
            return true;
        }

        if (subNorm == "info")
        {
            ++it;
            Player* target = nullptr;
            if (it == args.end() || *it == "self")
                target = handler->GetSession() ? handler->GetSession()->GetPlayer() : nullptr;
            else
            {
                std::string playerName((*it).data(), (*it).size());
                target = ObjectAccessor::FindPlayerByName(playerName, false);
            }
            if (!target)
            {
                handler->PSendSysMessage("Player not found.");
                handler->SetSentErrorMessage(true);
                return false;
            }
            uint32 curXP = target->GetUInt32Value(PLAYER_XP);
            uint32 nextXP = target->GetUInt32Value(PLAYER_NEXT_LEVEL_XP);
            uint32 level = target->GetLevel();
            bool noXp = target->HasPlayerFlag(PLAYER_FLAGS_NO_XP_GAIN);
            // Print a fuller, correctly-formatted info line so admins can diagnose XP issues.
            handler->PSendSysMessage("Info: {} guid={} level={} xp={} xpMax={} XPBlocked={}",
                                     target->GetName(), target->GetGUID().GetCounter(), level, curXP, nextXP, noXp ? 1 : 0);
            return true;
        }

        if (subNorm == "sendforce" || subNorm == "sendforceself")
        {
            ++it;
            bool targetIsSelf = (subNorm.find("self") != std::string::npos);
            if (!targetIsSelf && it == args.end())
            {
                handler->PSendSysMessage("Usage: .dc sendforce <playername>");
                handler->SetSentErrorMessage(true);
                return false;
            }
            Player* target = nullptr;
            if (targetIsSelf)
            {
                target = handler->GetSession() ? handler->GetSession()->GetPlayer() : nullptr;
            }
            else
            {
                std::string playerName((*it).data(), (*it).size());
                target = ObjectAccessor::FindPlayerByName(playerName, false);
            }

            if (!target)
            {
                handler->PSendSysMessage("Player not found or invalid target.");
                handler->SetSentErrorMessage(true);
                return false;
            }

            uint32 xp = target->GetUInt32Value(PLAYER_XP);
            uint32 xpMax = target->GetUInt32Value(PLAYER_NEXT_LEVEL_XP);
            uint32 level = target->GetLevel();
            // Force-send bypasses any server-side throttles or level-based guards
            SendXPAddonToPlayerForce(target, xp, xpMax, level);
            handler->PSendSysMessage("Force-sent DCRXP addon message to {} (xp={} xpMax={} level={})", target->GetName(), xp, xpMax, level);
            return true;
        }

        if (subNorm == "dedupe" || subNorm == "dedupestate")
        {
            ++it;
            Player* target = nullptr;
            if (it == args.end() || *it == "self")
                target = handler->GetSession() ? handler->GetSession()->GetPlayer() : nullptr;
            else
            {
                std::string playerName((*it).data(), (*it).size());
                target = ObjectAccessor::FindPlayerByName(playerName, false);
            }
            if (!target)
            {
                handler->PSendSysMessage("Player not found.");
                handler->SetSentErrorMessage(true);
                return false;
            }
            std::string const& key = target->GetLastDCRXPPayload();
            uint32 t = target->GetLastDCRXPPayloadTime();
            if (key.empty())
            {
                handler->PSendSysMessage("DCRXP dedupe: no recent payload recorded for %s", target->GetName());
            }
            else
            {
                time_t now = time(nullptr);
                uint32 age = (now > (time_t)t) ? uint32(now - (time_t)t) : 0;
                handler->PSendSysMessage("DCRXP dedupe for %s: key='%s' age=%u s (timestamp=%u)", target->GetName(), key.c_str(), age, t);
            }
            return true;
        }

        if (subNorm == "grant")
        {
            ++it;
            if (it == args.end())
            {
                handler->PSendSysMessage("Usage: .dc grant <playername> <amount>");
                handler->SetSentErrorMessage(true);
                return false;
            }

            std::string playerName((*it).data(), (*it).size());
            ++it;
            if (it == args.end())
            {
                handler->PSendSysMessage("Usage: .dc grant <playername> <amount>");
                handler->SetSentErrorMessage(true);
                return false;
            }

            std::string amountStr((*it).data(), (*it).size());
            uint64 amount = 0;
            try { amount = std::stoull(amountStr); } catch (...) { amount = 0; }
            if (amount == 0)
            {
                handler->PSendSysMessage("Invalid amount '{}'", amountStr);
                handler->SetSentErrorMessage(true);
                return false;
            }

            Player* receiver = ObjectAccessor::FindPlayerByName(playerName, false);
            if (!receiver)
            {
                handler->PSendSysMessage("Player '{}' not found.", playerName);
                handler->SetSentErrorMessage(true);
                return false;
            }

            uint32 beforeXP = receiver->GetUInt32Value(PLAYER_XP);
            // Use admin force-give so we can grant XP even if the player has NO_XP_GAIN set.
            receiver->GiveXPForce(uint32(amount), nullptr, 1.0f, false);
            uint32 afterXP = receiver->GetUInt32Value(PLAYER_XP);
            if (afterXP == beforeXP)
            {
                handler->PSendSysMessage("No XP applied to {} (maybe at max level or XP blocked). Current xp={} xpMax={}", playerName, afterXP, receiver->GetUInt32Value(PLAYER_NEXT_LEVEL_XP));
            }
            else
            {
                // Immediately send an addon snapshot so client can update right away
                SendXPAddonToPlayer(receiver, afterXP, receiver->GetUInt32Value(PLAYER_NEXT_LEVEL_XP), receiver->GetLevel());
                handler->PSendSysMessage("Granted {} XP to {} (now xp={} xpMax={})", uint32(amount), playerName, afterXP, receiver->GetUInt32Value(PLAYER_NEXT_LEVEL_XP));
            }
            return true;
        }

        if (subNorm == "grantself")
        {
            ++it;
            if (it == args.end())
            {
                handler->PSendSysMessage("Usage: .dc grantself <amount>");
                handler->SetSentErrorMessage(true);
                return false;
            }

            std::string amountStr((*it).data(), (*it).size());
            uint64 amount = 0;
            try { amount = std::stoull(amountStr); } catch (...) { amount = 0; }
            if (amount == 0)
            {
                handler->PSendSysMessage("Invalid amount '{}'", amountStr);
                handler->SetSentErrorMessage(true);
                return false;
            }

            Player* self = handler->GetSession() ? handler->GetSession()->GetPlayer() : nullptr;
            if (!self)
            {
                handler->PSendSysMessage("Couldn't identify your player session.");
                handler->SetSentErrorMessage(true);
                return false;
            }

            Player* selfPlayer = self;
            uint32 beforeSelfXP = selfPlayer->GetUInt32Value(PLAYER_XP);
            selfPlayer->GiveXPForce(uint32(amount), nullptr, 1.0f, false);
            uint32 afterSelfXP = selfPlayer->GetUInt32Value(PLAYER_XP);
            if (afterSelfXP == beforeSelfXP)
            {
                handler->PSendSysMessage("No XP applied to yourself (maybe at max level or XP blocked). Current xp={} xpMax={}", afterSelfXP, selfPlayer->GetUInt32Value(PLAYER_NEXT_LEVEL_XP));
            }
            else
            {
                SendXPAddonToPlayer(selfPlayer, afterSelfXP, selfPlayer->GetUInt32Value(PLAYER_NEXT_LEVEL_XP), selfPlayer->GetLevel());
                handler->PSendSysMessage("Granted {} XP to yourself (now xp={} xpMax={})", uint32(amount), afterSelfXP, selfPlayer->GetUInt32Value(PLAYER_NEXT_LEVEL_XP));
            }
            return true;
        }

        if (subNorm == "clearflag")
        {
            ++it;
            Player* target = nullptr;
            if (it == args.end() || *it == "self")
                target = handler->GetSession() ? handler->GetSession()->GetPlayer() : nullptr;
            else
            {
                std::string playerName((*it).data(), (*it).size());
                target = ObjectAccessor::FindPlayerByName(playerName, false);
            }

            if (!target)
            {
                handler->PSendSysMessage("Player not found.");
                handler->SetSentErrorMessage(true);
                return false;
            }

            if (!target->HasPlayerFlag(PLAYER_FLAGS_NO_XP_GAIN))
            {
                handler->PSendSysMessage("Player {} does not have the NO_XP_GAIN flag set.", target->GetName());
                return true;
            }

            target->RemovePlayerFlag(PLAYER_FLAGS_NO_XP_GAIN);
            handler->PSendSysMessage("Cleared NO_XP_GAIN flag for {} (guid={}).", target->GetName(), target->GetGUID().GetCounter());
            // Immediately send an addon snapshot so client refreshes
            uint32 curXP = target->GetUInt32Value(PLAYER_XP);
            uint32 nextXP = target->GetUInt32Value(PLAYER_NEXT_LEVEL_XP);
            SendXPAddonToPlayer(target, curXP, nextXP, target->GetLevel());
            return true;
        }

        if (subNorm == "difficulty")
        {
            ++it;
            if (it == args.end())
            {
                handler->PSendSysMessage("Usage: .dc difficulty <normal|heroic|mythic|info>");
                handler->SetSentErrorMessage(true);
                return false;
            }

            Player* player = handler->GetSession()->GetPlayer();
            if (!player)
            {
                handler->PSendSysMessage("You must be in-game to use this command.");
                handler->SetSentErrorMessage(true);
                return false;
            }

            std::string diffArg((*it).data(), (*it).size());
            std::string diffNorm;
            for (char c : diffArg)
                diffNorm.push_back(std::tolower(static_cast<unsigned char>(c)));

            if (diffNorm == "info")
            {
                Group* group = player->GetGroup();
                Difficulty currentDiff = player->GetDungeonDifficulty();
                std::string difficultyName;
                switch (currentDiff)
                {
                    case DUNGEON_DIFFICULTY_NORMAL:
                        difficultyName = "|cffffffffNormal|r";
                        break;
                    case DUNGEON_DIFFICULTY_HEROIC:
                        difficultyName = "|cff0070ddHeroic|r";
                        break;
                    case DUNGEON_DIFFICULTY_EPIC:
                        difficultyName = "|cffff8000Mythic|r";
                        break;
                    default:
                        difficultyName = "Unknown";
                        break;
                }
                handler->SendSysMessage("|cff00ff00=== Dungeon Difficulty Info ===");
                handler->SendSysMessage(("Current difficulty: " + difficultyName).c_str());
                if (group)
                {
                    std::string leaderStatus = group->IsLeader(player->GetGUID()) ? "|cff00ff00Yes|r" : "|cffff0000No|r";
                    handler->SendSysMessage(("Group leader: " + leaderStatus).c_str());
                    handler->PSendSysMessage("Group size: %u players", group->GetMembersCount());
                }
                else
                    handler->SendSysMessage("You are |cffff9900not|r in a group");
                handler->SendSysMessage("|cffaaaaaa=== Available Commands ===");
                handler->SendSysMessage(".dc difficulty normal  - Set Normal difficulty");
                handler->SendSysMessage(".dc difficulty heroic  - Set Heroic difficulty");
                handler->SendSysMessage(".dc difficulty mythic  - Set Mythic (req. level 80)");
                handler->SendSysMessage(" ");
                handler->SendSysMessage("|cffaaaaaa=== How It Works ===");
                handler->SendSysMessage("Solo: Change difficulty anytime (outside dungeon)");
                handler->SendSysMessage("Group: Only leader can change for entire group");
                return true;
            }

            // Check if inside instance
            if (player->GetMap()->IsDungeon() || player->GetMap()->IsRaid())
            {
                handler->PSendSysMessage("Cannot change difficulty inside an instance. Exit first.");
                handler->SetSentErrorMessage(true);
                return false;
            }

            Group* group = player->GetGroup();
            // In a group: only leader (or GM) can change difficulty
            // Solo: player can always change their own difficulty
            bool isGM = handler->GetSession()->GetSecurity() >= SEC_GAMEMASTER;
            if (group && !group->IsLeader(player->GetGUID()) && !isGM)
            {
                handler->PSendSysMessage("Only the group leader can change difficulty.");
                handler->SetSentErrorMessage(true);
                return false;
            }
            // Solo players can always proceed

            Difficulty newDiff;
            std::string diffName;

            if (diffNorm == "normal")
            {
                newDiff = DUNGEON_DIFFICULTY_NORMAL;
                diffName = "|cffffffffNormal|r";
            }
            else if (diffNorm == "heroic")
            {
                newDiff = DUNGEON_DIFFICULTY_HEROIC;
                diffName = "|cff0070ddHeroic|r";
            }
            else if (diffNorm == "mythic")
            {
                // GMs bypass level requirement for testing
                bool isGM = handler->GetSession()->GetSecurity() >= SEC_GAMEMASTER;
                if (player->GetLevel() < 80 && !isGM)
                {
                    handler->PSendSysMessage("|cffff0000You must be level 80 to use Mythic difficulty.|r");
                    handler->SetSentErrorMessage(true);
                    return false;
                }
                newDiff = DUNGEON_DIFFICULTY_EPIC;
                diffName = "|cffff8000Mythic|r";
            }
            else
            {
                handler->PSendSysMessage("Unknown difficulty. Use: normal, heroic, or mythic");
                handler->SetSentErrorMessage(true);
                return false;
            }

            if (group)
            {
                group->SetDungeonDifficulty(newDiff);
                group->SendUpdate();
                std::string msg = "|cff00ff00[Group]|r Difficulty set to " + diffName + " by " + player->GetName();
                handler->SendSysMessage(msg.c_str());
            }
            else
            {
                player->SetDungeonDifficulty(newDiff);
                player->SendDungeonDifficulty(false);
                std::string msg = "|cff00ff00Difficulty set to " + diffName;
                handler->SendSysMessage(msg.c_str());
            }
            return true;
        }

        if (subNorm == "reload")
        {
            ++it;
            if (it == args.end())
            {
                handler->PSendSysMessage("Usage: .dc reload mythic");
                handler->SetSentErrorMessage(true);
                return false;
            }

            std::string reloadArg((*it).data(), (*it).size());
            std::string reloadNorm;
            for (char c : reloadArg)
                reloadNorm.push_back(std::tolower(static_cast<unsigned char>(c)));

            if (reloadNorm == "mythic" || reloadNorm == "mythicplus" || reloadNorm == "m+")
            {
                handler->SendSysMessage("|cff00ff00Reloading Mythic+ dungeon profiles...");
                sMythicScaling->LoadDungeonProfiles();
                handler->SendSysMessage("|cff00ff00Mythic+ profiles reloaded successfully!");
                handler->PSendSysMessage("Note: Existing creatures in instances will use old scaling. New creatures will use updated values.");
                return true;
            }

            handler->PSendSysMessage("Unknown reload target. Usage: .dc reload mythic");
            handler->SetSentErrorMessage(true);
            return false;
        }

        handler->PSendSysMessage("Unknown subcommand. Usage: .dc send <playername> | sendforce <playername>|sendforce-self | grant <player> <amt> | grantself <amt> | givexp <player|self> <amt> | difficulty <normal|heroic|mythic|info> | reload mythic");
        handler->SetSentErrorMessage(true);
        return false;
    }
};

void AddSC_dc_addons_commandscript()
{
    new dc_addons_commandscript();
    LOG_INFO("scripts.dc_addons", "dc_addons command script registered");
}
