/*
 * Copyright (C) 2016+ AzerothCore <www.azerothcore.org>
 * Released under GNU AGPL v3 License
 *
 * DarkChaos-255 Achievement System
 * 
 * Features:
 * - Automatic achievement progression tracking
 * - Custom zone exploration
 * - Custom dungeon completion
 * - Hinterlands BG statistics
 * - Prestige level achievements
 * - Collection tracking
 * - Challenge mode achievements
 * - Level milestone achievements
 */

#include "ScriptMgr.h"
#include "Player.h"
#include "Config.h"
#include "Chat.h"
#include "AchievementMgr.h"
#include "Map.h"
#include "Battleground.h"
#include "DatabaseEnv.h"
#include "WorldSessionMgr.h"
#include "SpellMgr.h"
#include "SpellInfo.h"

// Achievement IDs
enum DCAchievements
{
    // Zone Exploration
    ACHIEVEMENT_EXPLORE_AZSHARA_CRATER      = 10001,
    ACHIEVEMENT_AZSHARA_CRATER_QUESTS       = 10002,
    ACHIEVEMENT_EXPLORE_HYJAL               = 10003,
    ACHIEVEMENT_HYJAL_QUESTS                = 10004,
    
    // Hinterlands BG
    ACHIEVEMENT_HINTERLANDS_NOVICE          = 10200,
    ACHIEVEMENT_HINTERLANDS_VICTOR          = 10201,
    ACHIEVEMENT_HINTERLANDS_HERO            = 10202,
    ACHIEVEMENT_FLAG_RUNNER                 = 10203,
    ACHIEVEMENT_FLAG_MASTER                 = 10204,
    ACHIEVEMENT_HINTERLANDS_DEFENDER        = 10205,
    
    // Prestige
    ACHIEVEMENT_PRESTIGE_1                  = 10300,
    ACHIEVEMENT_PRESTIGE_2                  = 10301,
    ACHIEVEMENT_PRESTIGE_3                  = 10302,
    ACHIEVEMENT_PRESTIGE_4                  = 10303,
    ACHIEVEMENT_PRESTIGE_5                  = 10304,
    ACHIEVEMENT_PRESTIGE_6                  = 10305,
    ACHIEVEMENT_PRESTIGE_7                  = 10306,
    ACHIEVEMENT_PRESTIGE_8                  = 10307,
    ACHIEVEMENT_PRESTIGE_9                  = 10308,
    ACHIEVEMENT_PRESTIGE_10                 = 10309,
    
    // Collections
    ACHIEVEMENT_MOUNT_COLLECTOR             = 10400,
    ACHIEVEMENT_MOUNT_MASTER                = 10401,
    ACHIEVEMENT_PET_COLLECTOR               = 10402,
    ACHIEVEMENT_PET_MASTER                  = 10403,
    ACHIEVEMENT_TITLE_COLLECTOR             = 10404,
    ACHIEVEMENT_THE_TITLED                  = 10405,
    
    // Server Firsts
    ACHIEVEMENT_FIRST_255                   = 10500,
    ACHIEVEMENT_FIRST_PRESTIGE              = 10501,
    
    // Challenge Modes
    ACHIEVEMENT_HARDCORE_SURVIVOR           = 10600,
    ACHIEVEMENT_HARDCORE_LEGEND             = 10601,
    ACHIEVEMENT_IRON_MAN                    = 10602,
    ACHIEVEMENT_IRON_LEGEND                 = 10603,
    ACHIEVEMENT_SELF_SUFFICIENT             = 10604,
    
    // Level Milestones
    ACHIEVEMENT_LEVEL_100                   = 10700,
    ACHIEVEMENT_LEVEL_150                   = 10701,
    ACHIEVEMENT_LEVEL_200                   = 10702,
    ACHIEVEMENT_LEVEL_255                   = 10703,
};

// Custom achievement criteria types
enum DCAchievementCriteriaTypes
{
    DC_CRITERIA_TYPE_HINTERLANDS_MATCHES    = 1,
    DC_CRITERIA_TYPE_HINTERLANDS_WINS       = 2,
    DC_CRITERIA_TYPE_FLAGS_CAPTURED         = 3,
    DC_CRITERIA_TYPE_BASE_DEFENSES          = 4,
    DC_CRITERIA_TYPE_CUSTOM_QUESTS          = 5,
};

class DCAchievementSystem : public PlayerScript
{
public:
    DCAchievementSystem() : PlayerScript("DCAchievementSystem") { }

    // Level achievements
    void OnPlayerLevelChanged(Player* player, uint8 oldLevel) override
    {
        uint8 newLevel = player->GetLevel();
        
        ChatHandler(player->GetSession()).PSendSysMessage("|cFFFFD700DEBUG LEVEL: {} -> {}|r", oldLevel, newLevel);
        
        // Level milestone achievements
        if (newLevel >= 100 && oldLevel < 100)
        {
            ChatHandler(player->GetSession()).PSendSysMessage("DEBUG: Checking Level 100 achievement");
            CompleteAchievement(player, ACHIEVEMENT_LEVEL_100);
        }
            
        if (newLevel >= 150 && oldLevel < 150)
        {
            ChatHandler(player->GetSession()).PSendSysMessage("DEBUG: Checking Level 150 achievement");
            CompleteAchievement(player, ACHIEVEMENT_LEVEL_150);
        }
            
        if (newLevel >= 200 && oldLevel < 200)
        {
            ChatHandler(player->GetSession()).PSendSysMessage("DEBUG: Checking Level 200 achievement");
            CompleteAchievement(player, ACHIEVEMENT_LEVEL_200);
        }
            
        if (newLevel >= 255 && oldLevel < 255)
        {
            ChatHandler(player->GetSession()).PSendSysMessage("DEBUG: Checking Level 255 achievement");
            CompleteAchievement(player, ACHIEVEMENT_LEVEL_255);
            
            // Check for server first
            if (IsServerFirst("first_255"))
            {
                ChatHandler(player->GetSession()).PSendSysMessage("DEBUG: First 255! Granting achievement");
                CompleteAchievement(player, ACHIEVEMENT_FIRST_255);
                AnnounceServerFirst(player, "First to Level 255");
            }
        }
        
        // Challenge mode achievements
        if (player->GetPlayerSetting("mod-challenge-modes", 0).value) // Hardcore
        {
            if (newLevel >= 60)
                CompleteAchievement(player, ACHIEVEMENT_HARDCORE_SURVIVOR);
            if (newLevel >= 255)
                CompleteAchievement(player, ACHIEVEMENT_HARDCORE_LEGEND);
        }
        
        if (player->GetPlayerSetting("mod-challenge-modes", 7).value) // Iron Man
        {
            if (newLevel >= 60)
                CompleteAchievement(player, ACHIEVEMENT_IRON_MAN);
            if (newLevel >= 255)
                CompleteAchievement(player, ACHIEVEMENT_IRON_LEGEND);
        }
        
        if (player->GetPlayerSetting("mod-challenge-modes", 2).value) // Self-Crafted
        {
            if (newLevel >= 60)
                CompleteAchievement(player, ACHIEVEMENT_SELF_SUFFICIENT);
        }
    }

    // Quest achievements
    void OnPlayerCompleteQuest(Player* /*player*/, Quest const* /*quest*/) override
    {
        // TODO: Track custom quest completions
        // You would need to query how many custom quests the player has completed
    }

    // Area exploration
    void OnPlayerUpdateZone(Player* /*player*/, uint32 newZone, uint32 /*newArea*/) override
    {
        // Azshara Crater
        if (newZone == 268)
        {
            // Check if player has explored all areas (would need to track subareas)
            // CompleteAchievement(player, ACHIEVEMENT_EXPLORE_AZSHARA_CRATER);
        }
        
        // Hyjal
        if (newZone == 616)
        {
            // Check if player has explored all areas
            // CompleteAchievement(player, ACHIEVEMENT_EXPLORE_HYJAL);
        }
    }

private:
    void CompleteAchievement(Player* player, uint32 achievementId)
    {
        AchievementEntry const* achievement = sAchievementStore.LookupEntry(achievementId);
        if (achievement && !player->HasAchieved(achievementId))
        {
            player->CompletedAchievement(achievement);
        }
    }
    
    bool IsServerFirst(std::string const& category)
    {
        QueryResult result = CharacterDatabase.Query(
            "SELECT COUNT(*) FROM dc_server_firsts WHERE category = '{}'", category
        );
        
        if (!result)
            return true;
            
        Field* fields = result->Fetch();
        return fields[0].Get<uint64>() == 0;
    }
    
    void RecordServerFirst(Player* player, std::string const& category)
    {
        CharacterDatabase.Execute(
            "INSERT INTO dc_server_firsts (category, player_guid, player_name, achievement_time) VALUES ('{}', {}, '{}', UNIX_TIMESTAMP())",
            category, player->GetGUID().GetCounter(), player->GetName()
        );
    }
    
    void AnnounceServerFirst(Player* player, std::string const& achievement)
    {
        std::string announcement = Acore::StringFormat(
            "|cFFFFD700[Server First!]|r Player {} has achieved: {}!",
            player->GetName(), achievement
        );
        sWorldSessionMgr->SendServerMessage(SERVER_MSG_STRING, announcement);
    }
};

// Prestige achievement tracker
class DCAchievementPrestige : public PlayerScript
{
public:
    DCAchievementPrestige() : PlayerScript("DCAchievementPrestige") { }

    void OnPlayerLogin(Player* player) override
    {
        ChatHandler(player->GetSession()).PSendSysMessage("|cFFFFD700=== PRESTIGE ACHIEVEMENTS DEBUG ===|r");
        
        // Check prestige level and grant achievements
        QueryResult result = CharacterDatabase.Query(
            "SELECT prestige_level FROM dc_character_prestige WHERE guid = {}",
            player->GetGUID().GetCounter()
        );
        
        if (!result)
        {
            ChatHandler(player->GetSession()).PSendSysMessage("DEBUG: No prestige data found in database");
            return;
        }
            
        Field* fields = result->Fetch();
        uint32 prestigeLevel = fields[0].Get<uint32>();
        ChatHandler(player->GetSession()).PSendSysMessage("DEBUG: Found prestige level in DB: {}", prestigeLevel);
        
        // Grant all prestige achievements up to current level
        for (uint32 i = 1; i <= prestigeLevel && i <= 10; ++i)
        {
            uint32 achievementId = ACHIEVEMENT_PRESTIGE_1 + (i - 1);
            AchievementEntry const* achievement = sAchievementStore.LookupEntry(achievementId);
            
            if (achievement)
            {
                ChatHandler(player->GetSession()).PSendSysMessage("DEBUG: Checking prestige achievement {} (ID: {})", i, achievementId);
                
                if (!player->HasAchieved(achievementId))
                {
                    player->CompletedAchievement(achievement);
                    ChatHandler(player->GetSession()).PSendSysMessage("|cFF00FF00Granted prestige achievement {}|r", achievementId);
                }
                else
                {
                    ChatHandler(player->GetSession()).PSendSysMessage("DEBUG: Already has prestige achievement {}", achievementId);
                }
            }
            else
            {
                ChatHandler(player->GetSession()).PSendSysMessage("|cFFFF0000ERROR: Achievement {} not found in store|r", achievementId);
            }
        }
        
        // Check for server first prestige
        if (prestigeLevel >= 1)
        {
            QueryResult firstResult = CharacterDatabase.Query(
                "SELECT COUNT(*) FROM dc_server_firsts WHERE category = 'first_prestige'"
            );
            
            if (!firstResult || firstResult->Fetch()[0].Get<uint32>() == 0)
            {
                AchievementEntry const* achievement = sAchievementStore.LookupEntry(ACHIEVEMENT_FIRST_PRESTIGE);
                if (achievement)
                {
                    player->CompletedAchievement(achievement);
                    ChatHandler(player->GetSession()).PSendSysMessage("|cFF00FF00Granted FIRST PRESTIGE achievement!|r");
                    
                    CharacterDatabase.Execute(
                        "INSERT INTO dc_server_firsts (category, player_guid, player_name, achievement_time) VALUES ('first_prestige', {}, '{}', UNIX_TIMESTAMP())",
                        player->GetGUID().GetCounter(), player->GetName()
                    );
                    
                    std::string announcement = Acore::StringFormat(
                        "|cFFFFD700[Server First!]|r Player {} is the first to achieve Prestige!",
                        player->GetName()
                    );
                    sWorldSessionMgr->SendServerMessage(SERVER_MSG_STRING, announcement);
                }
            }
        }
    }
};

// Collection achievement tracker
class DCAchievementCollections : public PlayerScript
{
public:
    DCAchievementCollections() : PlayerScript("DCAchievementCollections") { }

    void OnPlayerLogin(Player* player) override
    {
        ChatHandler(player->GetSession()).PSendSysMessage("|cFFFFD700=== COLLECTION ACHIEVEMENTS DEBUG ===|r");
        
        // Check mount count
        uint32 mountCount = GetMountCount(player);
        ChatHandler(player->GetSession()).PSendSysMessage("DEBUG: Player has {} mounts", mountCount);
        if (mountCount >= 50)
        {
            CompleteAchievement(player, ACHIEVEMENT_MOUNT_COLLECTOR);
            ChatHandler(player->GetSession()).PSendSysMessage("|cFF00FF00Mount Collector achievement check (50+ mounts)|r");
        }
        if (mountCount >= 100)
        {
            CompleteAchievement(player, ACHIEVEMENT_MOUNT_MASTER);
            ChatHandler(player->GetSession()).PSendSysMessage("|cFF00FF00Mount Master achievement check (100+ mounts)|r");
        }
            
        // Check pet count
        uint32 petCount = GetPetCount(player);
        ChatHandler(player->GetSession()).PSendSysMessage("DEBUG: Player has {} pets", petCount);
        if (petCount >= 50)
        {
            CompleteAchievement(player, ACHIEVEMENT_PET_COLLECTOR);
            ChatHandler(player->GetSession()).PSendSysMessage("|cFF00FF00Pet Collector achievement check (50+ pets)|r");
        }
        if (petCount >= 100)
        {
            CompleteAchievement(player, ACHIEVEMENT_PET_MASTER);
            ChatHandler(player->GetSession()).PSendSysMessage("|cFF00FF00Pet Master achievement check (100+ pets)|r");
        }
            
        // Check title count
        uint32 titleCount = GetTitleCount(player);
        ChatHandler(player->GetSession()).PSendSysMessage("DEBUG: Player has {} titles", titleCount);
        if (titleCount >= 25)
        {
            CompleteAchievement(player, ACHIEVEMENT_TITLE_COLLECTOR);
            ChatHandler(player->GetSession()).PSendSysMessage("|cFF00FF00Title Collector achievement check (25+ titles)|r");
        }
        if (titleCount >= 50)
        {
            CompleteAchievement(player, ACHIEVEMENT_THE_TITLED);
            ChatHandler(player->GetSession()).PSendSysMessage("|cFF00FF00The Titled achievement check (50+ titles)|r");
        }
        
        ChatHandler(player->GetSession()).PSendSysMessage("|cFFFFD700=== END COLLECTION DEBUG ===|r");
    }

private:
    uint32 GetMountCount(Player* player)
    {
        // Count learned mount spells (Effect 6 = SPELL_EFFECT_APPLY_AURA with mount aura)
        uint32 count = 0;
        PlayerSpellMap const& spells = player->GetSpellMap();
        for (auto const& spell : spells)
        {
            if (spell.second->State == PLAYERSPELL_REMOVED)
                continue;
                
            SpellInfo const* spellInfo = sSpellMgr->GetSpellInfo(spell.first);
            if (!spellInfo)
                continue;
                
            // Check if it's a mount spell (has mount aura effect)
            for (uint8 i = 0; i < MAX_SPELL_EFFECTS; ++i)
            {
                if (spellInfo->Effects[i].Effect == SPELL_EFFECT_APPLY_AURA &&
                    (spellInfo->Effects[i].ApplyAuraName == SPELL_AURA_MOUNTED ||
                     spellInfo->Effects[i].ApplyAuraName == SPELL_AURA_MOD_INCREASE_MOUNTED_FLIGHT_SPEED))
                {
                    count++;
                    break;
                }
            }
        }
        return count;
    }
    
    uint32 GetPetCount(Player* player)
    {
        QueryResult result = CharacterDatabase.Query(
            "SELECT COUNT(*) FROM character_pet WHERE owner = {}",
            player->GetGUID().GetCounter()
        );
        
        if (!result)
            return 0;
            
        return result->Fetch()[0].Get<uint64>();
    }
    
    uint32 GetTitleCount(Player* player)
    {
        // Count number of titles player has earned
        uint32 count = 0;
        for (uint32 i = 0; i < 200; ++i) // Adjust max title ID as needed
        {
            CharTitlesEntry const* titleEntry = sCharTitlesStore.LookupEntry(i);
            if (titleEntry && player->HasTitle(titleEntry))
                count++;
        }
        return count;
    }
    
    void CompleteAchievement(Player* player, uint32 achievementId)
    {
        AchievementEntry const* achievement = sAchievementStore.LookupEntry(achievementId);
        if (achievement && !player->HasAchieved(achievementId))
        {
            player->CompletedAchievement(achievement);
        }
    }
};

// Debug command to check achievements
class DCDebugAchievementCommand : public CommandScript
{
public:
    DCDebugAchievementCommand() : CommandScript("dc_debug_achievement") { }

    Acore::ChatCommands::ChatCommandTable GetCommands() const override
    {
        static Acore::ChatCommands::ChatCommandTable commandTable =
        {
            { "checkachievements", HandleCheckAchievements, SEC_ADMINISTRATOR, "Check if achievements are in store" },
        };
        return commandTable;
    }

    static bool HandleCheckAchievements(ChatHandler* handler, char const* args)
    {
        handler->PSendSysMessage("|cFFFFD700=== ACHIEVEMENT STORE DEBUG ===|r");
        
        uint32 prestige1 = 10300;
        AchievementEntry const* ach = sAchievementStore.LookupEntry(prestige1);
        
        if (!ach)
        {
            handler->PSendSysMessage("|cFFFF0000ERROR: Achievement {} not found in store!|r", prestige1);
        }
        else
        {
            handler->PSendSysMessage("|cFF00FF00Found Achievement {}: {}", prestige1, ach->name);
            handler->PSendSysMessage("Category: {} | Points: {} | Flags: {}", ach->category, ach->points, ach->flags);
        }
        
        // Check category
        AchievementCategoryEntry const* cat = sAchievementCategoryStore.LookupEntry(10004);
        if (!cat)
        {
            handler->PSendSysMessage("|cFFFF0000ERROR: Category 10004 not found in store!|r");
        }
        else
        {
            handler->PSendSysMessage("|cFF00FF00Found Category 10004: {}", cat->name);
        }
        
        // Check a few prestige achievements
        for (uint32 i = 10300; i <= 10306; ++i)
        {
            AchievementEntry const* achievement = sAchievementStore.LookupEntry(i);
            if (achievement)
            {
                handler->PSendSysMessage("  {} - {}", i, achievement->name);
            }
            else
            {
                handler->PSendSysMessage("|cFFFF0000  {} - NOT FOUND|r", i);
            }
        }
        
        handler->PSendSysMessage("|cFFFFD700=== END ACHIEVEMENT STORE DEBUG ===|r");
        return true;
    }
};

void AddSC_dc_achievements()
{
    new DCAchievementSystem();
    new DCAchievementPrestige();
    new DCAchievementCollections();
    new DCDebugAchievementCommand();
}
