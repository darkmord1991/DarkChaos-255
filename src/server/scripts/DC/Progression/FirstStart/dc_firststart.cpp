/*
 * Dark Chaos - First Start Experience System (DC-FirstStart)
 * ===========================================================
 *
 * Comprehensive first-login experience system that handles:
 * - New character initialization (BoA gear, bags, gold, skills)
 * - DC-Welcome addon triggering
 * - Season/Prestige account-wide bonuses
 *
 * Based on: https://github.com/Brian-Aldridge/mod-customlogin
 * Extended with: DC-Welcome addon triggers, Prestige bonuses, Seasonal tokens
 *
 * Features:
 * 1. First-login BoA gear distribution (class-specific)
 * 2. Starting bags, gold, professions, mounts
 * 3. Weapon skills and special abilities
 * 4. Reputation configuration
 * 5. DC-Welcome addon trigger (shows welcome popup)
 * 6. Seasonal starter tokens
 * 7. Prestige account-wide bonus application
 * 8. Progressive tutorial triggers
 *
 * Copyright (C) 2025 Dark Chaos Development Team
 * Based on mod-customlogin by Brian Aldridge (MIT License)
 */

#include "ScriptMgr.h"
#include "Player.h"
#include "Config.h"
#include "Chat.h"
#include "DC/ItemUpgrades/ItemUpgradeManager.h"
#include "World.h"
#include "WorldSession.h"
#include "SpellMgr.h"
#include "ObjectMgr.h"
#include "CharacterDatabase.h"
#include "DatabaseEnv.h"
#include "Log.h"
#include "dc_firststart_learnspells.h"
#include <sstream>
#include <map>
#include <vector>

namespace DCCustomLogin
{
    // Configuration keys (matches darkchaos-custom.conf.dist)
    namespace Config
    {
        // Master toggles
        constexpr const char* ENABLE = "DCCustomLogin.Enable";
        constexpr const char* DEBUG = "DCCustomLogin.Debug";
        constexpr const char* ANNOUNCE = "DCCustomLogin.Announce";
        constexpr const char* ANNOUNCE_MESSAGE = "DCCustomLogin.AnnounceMessage";
        constexpr const char* PLAYER_ANNOUNCE = "DCCustomLogin.PlayerAnnounce";

        // BoA Items
        constexpr const char* BOA_ENABLE = "DCCustomLogin.BoA";

        // Skills
        constexpr const char* SKILLS_ENABLE = "DCCustomLogin.Skills";
        constexpr const char* SKILLS_LIST = "DCCustomLogin.Skills.List";

        // Starting Gold
        constexpr const char* GOLD_ENABLE = "DCCustomLogin.StartingGold.Enable";
        constexpr const char* GOLD_GOLD = "DCCustomLogin.StartingGold.Gold";
        constexpr const char* GOLD_SILVER = "DCCustomLogin.StartingGold.Silver";
        constexpr const char* GOLD_COPPER = "DCCustomLogin.StartingGold.Copper";

        // Starting Mount
        constexpr const char* MOUNT_ENABLE = "DCCustomLogin.StartingMount.Enable";
        constexpr const char* MOUNT_SPELL = "DCCustomLogin.StartingMount.Spell";
        constexpr const char* MOUNT_SKILL = "DCCustomLogin.StartingMount.Skill";
        constexpr const char* MOUNT_MIN_LEVEL = "DCCustomLogin.StartingMount.MinLevel";

        // Starting Professions
        constexpr const char* PROF_ENABLE = "DCCustomLogin.StartingProfessions.Enable";
        constexpr const char* PROF_LIST = "DCCustomLogin.StartingProfessions.List";

        // Bags
        constexpr const char* BAGS_DEFAULT = "DCCustomLogin.Bags.Default";
        constexpr const char* BAGS_HUNTER = "DCCustomLogin.Bags.Hunter";
        constexpr const char* BAGS_WARLOCK = "DCCustomLogin.Bags.Warlock";
        constexpr const char* BAGS_ROGUE = "DCCustomLogin.Bags.Rogue";

        // Special Abilities
        constexpr const char* SPECIAL_ENABLE = "DCCustomLogin.SpecialAbility";
        constexpr const char* SPECIAL_SPELL1 = "DCCustomLogin.SpecialAbility.Spell1";
        constexpr const char* SPECIAL_SPELL2 = "DCCustomLogin.SpecialAbility.Spell2";
        constexpr const char* SPECIAL_TITLE = "DCCustomLogin.SpecialAbility.Title";
        constexpr const char* SPECIAL_MOUNT = "DCCustomLogin.SpecialAbility.Mount";

        // Reputation
        constexpr const char* REP_ENABLE = "DCCustomLogin.Reputation";

        // DC Integrations
        constexpr const char* DC_WELCOME_TRIGGER = "DCCustomLogin.TriggerWelcome";
        constexpr const char* DC_SEASONAL_TOKENS = "DCCustomLogin.SeasonalTokens.Enable";
        constexpr const char* DC_SEASONAL_TOKENS_AMOUNT = "DCCustomLogin.SeasonalTokens.Amount";
        constexpr const char* DC_PRESTIGE_BONUSES = "DCCustomLogin.PrestigeBonuses";
        constexpr const char* DC_MOBILE_TELEPORTER = "DCCustomLogin.MobileTeleporter.Enable";
        constexpr const char* DC_MOBILE_TELEPORTER_ITEM = "DCCustomLogin.MobileTeleporter.ItemId";

        // Dual Spec
        constexpr const char* DUALSPEC_ENABLE = "DCCustomLogin.DualSpec.Enable";
        constexpr const char* DUALSPEC_LEVEL = "DCCustomLogin.DualSpec.Level";
    }

    // Class names for config lookups
    const std::vector<std::pair<uint8, std::string>> CLASS_NAMES = {
        {CLASS_WARRIOR, "Warrior"},
        {CLASS_PALADIN, "Paladin"},
        {CLASS_HUNTER, "Hunter"},
        {CLASS_ROGUE, "Rogue"},
        {CLASS_PRIEST, "Priest"},
        {CLASS_DEATH_KNIGHT, "DeathKnight"},
        {CLASS_SHAMAN, "Shaman"},
        {CLASS_MAGE, "Mage"},
        {CLASS_WARLOCK, "Warlock"},
        {CLASS_DRUID, "Druid"}
    };

    // Slot names for config lookups
    const std::vector<std::string> ITEM_SLOTS = {
        "Shoulders", "Chest", "Trinket", "Weapon1", "Weapon2", "Weapon3"
    };

    // Reputation faction IDs and config keys
    const std::map<uint32, std::string> REPUTATION_FACTIONS = {
        // Alliance
        {72, "Stormwind"},
        {47, "Ironforge"},
        {69, "Darnassus"},
        {54, "Gnomeregan"},
        {930, "Exodar"},
        // Horde
        {76, "Orgrimmar"},
        {81, "ThunderBluff"},
        {68, "Undercity"},
        {530, "DarkspearTrolls"},
        {911, "Silvermoon"},
        // Neutral
        {529, "ArgentDawn"},
        {609, "CenarionCircle"},
        {576, "TimbermawHold"},
        {270, "ZandalarTribe"},
        {87, "BloodsailBuccaneers"},
        {21, "SteamwheedleCartel"},
        // TBC
        {935, "ShaTar"},
        {1011, "LowerCity"},
        {942, "CenarionExpedition"},
        {932, "TheAldor"},
        {934, "TheScryers"},
        {933, "TheConsortium"},
        {941, "TheMaghar"},
        {978, "Kurenai"},
        {970, "Sporeggar"},
        {1015, "Netherwing"},
        // WotLK
        {1106, "ArgentCrusade"},
        {1104, "FrenzyheartTribe"},
        {1105, "TheOracles"},
        {1090, "KirinTor"},
        {1091, "TheWyrmrestAccord"},
        {1052, "HordeExpedition"},
        {1037, "AllianceVanguard"},
        {1119, "TheSonsOfHodir"},
        {1156, "TheAshenVerdict"}
    };

    // Helper: Parse comma-separated list of IDs
    std::vector<uint32> ParseIdList(const std::string& list)
    {
        std::vector<uint32> result;
        if (list.empty())
            return result;

        std::istringstream iss(list);
        std::string token;
        while (std::getline(iss, token, ','))
        {
            // Trim whitespace
            token.erase(0, token.find_first_not_of(" \t\n\r"));
            token.erase(token.find_last_not_of(" \t\n\r") + 1);
            if (token.empty())
                continue;

            try
            {
                uint32 id = static_cast<uint32>(std::stoul(token));
                if (id > 0)
                    result.push_back(id);
            }
            catch (...)
            {
                // Skip invalid tokens
            }
        }
        return result;
    }

    // Get class name for config lookup
    std::string GetClassName(uint8 classId)
    {
        for (auto const& pair : CLASS_NAMES)
        {
            if (pair.first == classId)
                return pair.second;
        }
        return "";
    }

    bool HasFirstLoginMarker(ObjectGuid guid)
    {
        QueryResult result = CharacterDatabase.Query(
            "SELECT 1 FROM dc_player_welcome WHERE guid = {} LIMIT 1",
            guid.GetCounter()
        );

        return result != nullptr;
    }

    void MarkFirstLoginComplete(ObjectGuid guid)
    {
        CharacterDatabase.Execute(
            "INSERT IGNORE INTO dc_player_welcome (guid, is_new_character, created_at) VALUES ({}, 1, NOW())",
            guid.GetCounter()
        );
    }

    // Grant starting professions
    void GrantProfessions(Player* player, bool debug)
    {
        if (!sConfigMgr->GetOption<bool>(Config::PROF_ENABLE, false))
            return;

        std::string profList = sConfigMgr->GetOption<std::string>(Config::PROF_LIST, "");
        auto profIds = ParseIdList(profList);

        for (uint32 profId : profIds)
        {
            if (!sSpellMgr->GetSpellInfo(profId))
            {
                if (debug)
                    LOG_WARN("module.dc", "[DCCustomLogin] Profession spell {} not found", profId);
                continue;
            }

            player->learnSpell(profId, false);
            if (debug)
                LOG_INFO("module.dc", "[DCCustomLogin] Granted profession {} to {}", profId, player->GetName());
        }
    }

    // Grant weapon/extra skills
    void GrantSkills(Player* player, bool debug)
    {
        if (!sConfigMgr->GetOption<bool>(Config::SKILLS_ENABLE, false))
            return;

        std::string className = GetClassName(player->getClass());
        std::string skillsKey = "DCCustomLogin.Skills." + className;
        std::string skillsList = sConfigMgr->GetOption<std::string>(skillsKey, "");

        // Fall back to global list if no class-specific
        if (skillsList.empty())
            skillsList = sConfigMgr->GetOption<std::string>(Config::SKILLS_LIST, "");

        if (skillsList.empty())
            return;

        auto skillIds = ParseIdList(skillsList);
        for (uint32 skillId : skillIds)
        {
            if (!sSpellMgr->GetSpellInfo(skillId))
            {
                if (debug)
                    LOG_WARN("module.dc", "[DCCustomLogin] Skill spell {} not found", skillId);
                continue;
            }

            player->learnSpell(skillId, false);
            if (debug)
                LOG_INFO("module.dc", "[DCCustomLogin] Granted skill {} to {}", skillId, player->GetName());
        }
    }

    // Grant starting mount and riding skill
    void GrantMount(Player* player, bool debug)
    {
        if (!sConfigMgr->GetOption<bool>(Config::MOUNT_ENABLE, false))
            return;

        uint32 minLevel = sConfigMgr->GetOption<uint32>(Config::MOUNT_MIN_LEVEL, 10);
        if (player->GetLevel() < minLevel)
            return;

        uint32 ridingSkill = sConfigMgr->GetOption<uint32>(Config::MOUNT_SKILL, 0);
        uint32 mountSpell = sConfigMgr->GetOption<uint32>(Config::MOUNT_SPELL, 0);

        if (ridingSkill && sSpellMgr->GetSpellInfo(ridingSkill))
        {
            player->learnSpell(ridingSkill, false);
            if (debug)
                LOG_INFO("module.dc", "[DCCustomLogin] Granted riding skill {} to {}", ridingSkill, player->GetName());
        }

        if (mountSpell && sSpellMgr->GetSpellInfo(mountSpell))
        {
            player->learnSpell(mountSpell, false);
            if (debug)
                LOG_INFO("module.dc", "[DCCustomLogin] Granted mount {} to {}", mountSpell, player->GetName());
        }
    }

    void GrantDualSpec(Player* player, bool debug)
    {
        if (!sConfigMgr->GetOption<bool>(Config::DUALSPEC_ENABLE, true))
            return;

        uint32 level = sConfigMgr->GetOption<uint32>(Config::DUALSPEC_LEVEL, 10);
        if (player->GetLevel() < level)
            return;

        if (player->GetSpecsCount() >= 2)
            return;

        player->UpdateSpecCount(2);

        if (debug)
            LOG_INFO("module.dc", "[DCCustomLogin] Granted free dual spec to {}", player->GetName());
    }

    // Grant starting bags
    void GrantBags(Player* player, bool debug)
    {
        std::string defaultBags = sConfigMgr->GetOption<std::string>(Config::BAGS_DEFAULT, "");
        auto bagIds = ParseIdList(defaultBags);

        int slot = 19;  // Bag slots 19-22
        for (uint32 bagId : bagIds)
        {
            if (slot > 22)
                break;

            if (bagId > 0 && !player->GetItemByPos(INVENTORY_SLOT_BAG_0, slot))
            {
                if (Item* bag = Item::CreateItem(bagId, 1, player))
                {
                    player->EquipItem(slot, bag, true);
                    if (debug)
                        LOG_INFO("module.dc", "[DCCustomLogin] Equipped bag {} in slot {}", bagId, slot);
                }
            }
            slot++;
        }

        // Class-specific bag
        uint32 classBagId = 0;
        switch (player->getClass())
        {
            case CLASS_HUNTER:
                classBagId = sConfigMgr->GetOption<uint32>(Config::BAGS_HUNTER, 0);
                break;
            case CLASS_WARLOCK:
                classBagId = sConfigMgr->GetOption<uint32>(Config::BAGS_WARLOCK, 0);
                break;
            case CLASS_ROGUE:
                classBagId = sConfigMgr->GetOption<uint32>(Config::BAGS_ROGUE, 0);
                break;
            default:
                break;
        }

        if (classBagId > 0)
        {
            for (int s = 19; s <= 22; ++s)
            {
                if (!player->GetItemByPos(INVENTORY_SLOT_BAG_0, s))
                {
                    if (Item* bag = Item::CreateItem(classBagId, 1, player))
                    {
                        player->EquipItem(s, bag, true);
                        if (debug)
                            LOG_INFO("module.dc", "[DCCustomLogin] Equipped class bag {} in slot {}", classBagId, s);
                    }
                    break;
                }
            }
        }
    }

    // Grant starting gold
    void GrantGold(Player* player, bool debug)
    {
        if (!sConfigMgr->GetOption<bool>(Config::GOLD_ENABLE, false))
            return;

        uint32 gold = sConfigMgr->GetOption<uint32>(Config::GOLD_GOLD, 0);
        uint32 silver = sConfigMgr->GetOption<uint32>(Config::GOLD_SILVER, 0);
        uint32 copper = sConfigMgr->GetOption<uint32>(Config::GOLD_COPPER, 0);

        uint32 totalCopper = (gold * 10000) + (silver * 100) + copper;
        if (totalCopper > 0)
        {
            player->ModifyMoney(totalCopper);
            if (debug)
                LOG_INFO("module.dc", "[DCCustomLogin] Granted {}g {}s {}c to {}", gold, silver, copper, player->GetName());
        }
    }

    // Grant BoA items based on class
    void GrantBoAItems(Player* player, bool debug)
    {
        if (!sConfigMgr->GetOption<bool>(Config::BOA_ENABLE, true))
            return;

        std::string className = GetClassName(player->getClass());
        if (className.empty())
            return;

        for (auto const& slot : ITEM_SLOTS)
        {
            std::string key = "DCCustomLogin." + className + "." + slot;
            uint32 itemId = sConfigMgr->GetOption<uint32>(key, 0);

            if (itemId > 0)
            {
                player->AddItem(itemId, 1);
                if (debug)
                    LOG_INFO("module.dc", "[DCCustomLogin] Added BoA item {} ({}) to {}", itemId, slot, player->GetName());
            }
        }

        ChatHandler(player->GetSession()).SendSysMessage("|cffFF0000[DarkChaos]:|cffFF8000 You have received heirloom starting gear!");
    }

    // Grant special abilities (spells, title, mount)
    void GrantSpecialAbilities(Player* player, bool debug)
    {
        if (!sConfigMgr->GetOption<bool>(Config::SPECIAL_ENABLE, false))
            return;

        uint32 spell1 = sConfigMgr->GetOption<uint32>(Config::SPECIAL_SPELL1, 0);
        uint32 spell2 = sConfigMgr->GetOption<uint32>(Config::SPECIAL_SPELL2, 0);
        uint32 title = sConfigMgr->GetOption<uint32>(Config::SPECIAL_TITLE, 0);
        uint32 mount = sConfigMgr->GetOption<uint32>(Config::SPECIAL_MOUNT, 0);

        if (spell1 && sSpellMgr->GetSpellInfo(spell1))
        {
            player->learnSpell(spell1, false);
            if (debug)
                LOG_INFO("module.dc", "[DCCustomLogin] Granted special spell1 {} to {}", spell1, player->GetName());
        }

        if (spell2 && sSpellMgr->GetSpellInfo(spell2))
        {
            player->learnSpell(spell2, false);
            if (debug)
                LOG_INFO("module.dc", "[DCCustomLogin] Granted special spell2 {} to {}", spell2, player->GetName());
        }

        if (title)
        {
            if (CharTitlesEntry const* titleEntry = sCharTitlesStore.LookupEntry(title))
            {
                player->SetTitle(titleEntry);
                if (debug)
                    LOG_INFO("module.dc", "[DCCustomLogin] Granted title {} to {}", title, player->GetName());
            }
        }

        if (mount && sSpellMgr->GetSpellInfo(mount))
        {
            player->learnSpell(mount, false);
            if (debug)
                LOG_INFO("module.dc", "[DCCustomLogin] Granted special mount {} to {}", mount, player->GetName());
        }
    }

    // Set starting reputations
    void SetReputations(Player* player, bool debug)
    {
        if (!sConfigMgr->GetOption<bool>(Config::REP_ENABLE, false))
            return;

        for (auto const& [factionId, name] : REPUTATION_FACTIONS)
        {
            std::string key = "DCCustomLogin.Reputation." + name;
            uint32 repValue = sConfigMgr->GetOption<uint32>(key, 0);

            if (repValue > 0)
            {
                player->SetReputation(factionId, repValue);
                if (debug)
                    LOG_INFO("module.dc", "[DCCustomLogin] Set {} reputation to {} for {}", name, repValue, player->GetName());
            }
        }
    }

    // DC Integration: Grant seasonal tokens
    void GrantSeasonalTokens(Player* player, bool debug)
    {
        if (!sConfigMgr->GetOption<bool>(Config::DC_SEASONAL_TOKENS, false))
            return;

        uint32 amount = sConfigMgr->GetOption<uint32>(Config::DC_SEASONAL_TOKENS_AMOUNT, 100);

        // Get the seasonal token item ID
        // Priority: UseCanonicalCurrency -> DarkChaos.Seasonal.TokenItemID
        //           Otherwise -> DCCustomLogin.SeasonalTokens.ItemId
        bool useCanonical = sConfigMgr->GetOption<bool>("DCCustomLogin.SeasonalTokens.UseCanonicalCurrency", true);
        uint32 tokenItemId;

        if (useCanonical)
        {
            // Use canonical seasonal token from DarkChaos.Seasonal.TokenItemID
            tokenItemId = DarkChaos::ItemUpgrade::GetUpgradeTokenItemId();
        }
        else
        {
            // Use custom token item ID
            tokenItemId = sConfigMgr->GetOption<uint32>("DCCustomLogin.SeasonalTokens.ItemId", 0);
        }

        if (tokenItemId > 0)
        {
            player->AddItem(tokenItemId, amount);
            if (debug)
                LOG_INFO("module.dc", "[DCCustomLogin] Granted {} seasonal tokens (item {}) to {}",
                         amount, tokenItemId, player->GetName());

            ChatHandler(player->GetSession()).PSendSysMessage(
                "|cff00ff00[Season]:|r You received |cfffff000%u|r seasonal starter tokens!", amount);
        }
        else if (debug)
        {
            LOG_WARN("module.dc", "[DCCustomLogin] SeasonalTokens not configured (UseCanonical={}, ItemId={}), skipping token grant",
                     useCanonical, tokenItemId);
        }
    }

    // DC Integration: Grant mobile teleporter
    void GrantMobileTeleporter(Player* player, bool debug)
    {
        if (!sConfigMgr->GetOption<bool>(Config::DC_MOBILE_TELEPORTER, true))
            return;

        uint32 itemId = sConfigMgr->GetOption<uint32>(Config::DC_MOBILE_TELEPORTER_ITEM, 0);

        if (itemId > 0)
        {
            player->AddItem(itemId, 1);
            if (debug)
                LOG_INFO("module.dc", "[DCCustomLogin] Granted mobile teleporter {} to {}", itemId, player->GetName());

            ChatHandler(player->GetSession()).SendSysMessage(
                "|cff00ccff[DarkChaos]:|r You received a |cffff8000Mobile Teleporter|r - use it to travel anywhere!");
        }
    }

    // DC Integration: Apply account-wide prestige bonuses
    void ApplyPrestigeBonuses(Player* player, bool debug)
    {
        if (!sConfigMgr->GetOption<bool>(Config::DC_PRESTIGE_BONUSES, true))
            return;

        uint32 accountId = player->GetSession()->GetAccountId();

        // Check for account prestige level
        QueryResult result = CharacterDatabase.Query(
            "SELECT MAX(prestige_level) FROM dc_prestige_players WHERE account_id = {}", accountId);

        if (result)
        {
            Field* fields = result->Fetch();
            uint32 prestigeLevel = fields[0].Get<uint32>();

            if (prestigeLevel > 0)
            {
                // Apply account-wide bonuses (these are passive and don't require spells)
                // The prestige system will handle actual bonus application
                // Here we just notify the player
                ChatHandler(player->GetSession()).PSendSysMessage(
                    "|cffa335ee[Prestige]:|r Your account has Prestige Level |cffffd700%u|r! "
                    "Bonuses are applied automatically.", prestigeLevel);

                if (debug)
                    LOG_INFO("module.dc", "[DCCustomLogin] Player {} has account prestige level {}",
                             player->GetName(), prestigeLevel);
            }
        }
    }

    // DC Integration: Trigger DC-Welcome addon
    void TriggerWelcomeAddon(Player* player, bool debug)
    {
        if (!sConfigMgr->GetOption<bool>(Config::DC_WELCOME_TRIGGER, true))
            return;

        // This is handled by the DC-Welcome PlayerScript (OnFirstLogin)
        // We just set a flag so the welcome system knows this is a fresh character
        CharacterDatabase.Execute(
            "INSERT IGNORE INTO dc_player_welcome (guid, is_new_character, created_at) VALUES ({}, 1, NOW())",
            player->GetGUID().GetCounter()
        );

        if (debug)
            LOG_INFO("module.dc", "[DCCustomLogin] Marked {} for DC-Welcome first-login trigger", player->GetName());
    }

    // Main function: Give all first login rewards
    void GiveFirstLoginRewards(Player* player)
    {
        bool debug = sConfigMgr->GetOption<bool>(Config::DEBUG, false);

        if (debug)
            LOG_INFO("module.dc", "[DCCustomLogin] Processing first login for {}", player->GetName());

        // Standard rewards (from mod-customlogin)
        GrantProfessions(player, debug);
        GrantSkills(player, debug);
        LearnSpells::GrantClassSpells(player, debug);
        GrantMount(player, debug);
        GrantBags(player, debug);
        GrantGold(player, debug);
        GrantBoAItems(player, debug);
        GrantSpecialAbilities(player, debug);
        SetReputations(player, debug);
        GrantDualSpec(player, debug);

        // DC-specific integrations
        GrantSeasonalTokens(player, debug);
        GrantMobileTeleporter(player, debug);
        ApplyPrestigeBonuses(player, debug);
        TriggerWelcomeAddon(player, debug);

        if (debug)
            LOG_INFO("module.dc", "[DCCustomLogin] Completed first login rewards for {}", player->GetName());
    }

} // namespace DCCustomLogin

// =============================================================================
// Player Script
// =============================================================================

class DCCustomLogin_PlayerScript : public PlayerScript
{
public:
    DCCustomLogin_PlayerScript() : PlayerScript("DCCustomLogin_PlayerScript") { }

    void OnPlayerLogin(Player* player) override
    {
        if (!sConfigMgr->GetOption<bool>(DCCustomLogin::Config::ENABLE, true))
            return;

        bool debug = sConfigMgr->GetOption<bool>(DCCustomLogin::Config::DEBUG, false);

        bool hasFirstLoginMarker = DCCustomLogin::HasFirstLoginMarker(player->GetGUID());

        // Check for first login using marker + total played time
        if (!hasFirstLoginMarker && player->GetTotalPlayedTime() == 0)
        {
            if (debug)
                LOG_INFO("module.dc", "[DCCustomLogin] First login detected for {}", player->GetName());

            DCCustomLogin::GiveFirstLoginRewards(player);
            DCCustomLogin::MarkFirstLoginComplete(player->GetGUID());
        }

        // Announce module if enabled
        bool announce = sConfigMgr->GetOption<bool>(DCCustomLogin::Config::ANNOUNCE, false);
        if (announce)
        {
            std::string msg = sConfigMgr->GetOption<std::string>(
                DCCustomLogin::Config::ANNOUNCE_MESSAGE,
                "Welcome to |cff00ff00DarkChaos-255|r! Type |cfffff000/welcome|r to get started.");
            ChatHandler(player->GetSession()).SendSysMessage(msg);
        }

        // Player announce (faction-colored login message)
        bool playerAnnounce = sConfigMgr->GetOption<bool>(DCCustomLogin::Config::PLAYER_ANNOUNCE, false);
        if (playerAnnounce)
        {
            std::ostringstream ss;
            if (player->GetTeamId() == TEAM_ALLIANCE)
            {
                ss << "|cffFFFFFF[|cff2897FF Alliance |cffFFFFFF]:|cff4CFF00 "
                   << player->GetName() << "|cffFFFFFF has come online.";
            }
            else
            {
                ss << "|cffFFFFFF[|cffFF0000 Horde |cffFFFFFF]:|cff4CFF00 "
                   << player->GetName() << "|cffFFFFFF has come online.";
            }
            ChatHandler(nullptr).SendGlobalSysMessage(ss.str().c_str());
        }
    }

    void OnPlayerLogout(Player* player) override
    {
        bool playerAnnounce = sConfigMgr->GetOption<bool>(DCCustomLogin::Config::PLAYER_ANNOUNCE, false);
        if (playerAnnounce)
        {
            std::ostringstream ss;
            if (player->GetTeamId() == TEAM_ALLIANCE)
            {
                ss << "|cffFFFFFF[|cff2897FF Alliance |cffFFFFFF]|cff4CFF00 "
                   << player->GetName() << "|cffFFFFFF has left the game.";
            }
            else
            {
                ss << "|cffFFFFFF[|cffFF0000 Horde |cffFFFFFF]|cff4CFF00 "
                   << player->GetName() << "|cffFFFFFF has left the game.";
            }
            ChatHandler(nullptr).SendGlobalSysMessage(ss.str().c_str());
        }
    }

    void OnPlayerLevelChanged(Player* player, uint8 oldLevel) override
    {
        if (!sConfigMgr->GetOption<bool>(DCCustomLogin::Config::ENABLE, true))
            return;

        bool debug = sConfigMgr->GetOption<bool>(DCCustomLogin::Config::DEBUG, false);
        DCCustomLogin::LearnSpells::GrantClassSpellsOnLevelUp(player, oldLevel, debug);

        uint32 mountLevel = sConfigMgr->GetOption<uint32>(DCCustomLogin::Config::MOUNT_MIN_LEVEL, 10);
        if (oldLevel < mountLevel && player->GetLevel() >= mountLevel)
            DCCustomLogin::GrantMount(player, debug);

        uint32 dualSpecLevel = sConfigMgr->GetOption<uint32>(DCCustomLogin::Config::DUALSPEC_LEVEL, 10);
        if (oldLevel < dualSpecLevel && player->GetLevel() >= dualSpecLevel)
            DCCustomLogin::GrantDualSpec(player, debug);
    }
};

// =============================================================================
// Script Loader
// =============================================================================

void AddSC_dc_firststart()
{
    new DCCustomLogin_PlayerScript();
}
