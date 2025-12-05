--[[
    DC-Welcome Localization
    Centralized strings for easy translation/customization
    
    Author: DarkChaos-255
    Date: January 2025
]]

local addonName = "DC-Welcome"
DCWelcome = DCWelcome or {}
local L = {}
DCWelcome.L = L

-- =============================================================================
-- General Strings
-- =============================================================================

L["ADDON_NAME"] = "DC-Welcome"
L["WELCOME_TITLE"] = "Welcome to DarkChaos-255!"
L["WELCOME_SUBTITLE"] = "Your adventure begins here"

-- =============================================================================
-- Tab Names
-- =============================================================================

L["TAB_WHATS_NEW"] = "What's New"
L["TAB_GETTING_STARTED"] = "Getting Started"
L["TAB_FEATURES"] = "Server Features"
L["TAB_ADDONS"] = "Addons"
L["TAB_PROGRESS"] = "Progress"
L["TAB_FAQ"] = "FAQ"
L["TAB_LINKS"] = "Community"

-- =============================================================================
-- Progress Panel Content
-- =============================================================================

L["PROGRESS_TITLE"] = "Your Progress"
L["PROGRESS_SUBTITLE"] = "Track your progression across all DarkChaos systems"
L["PROGRESS_MYTHIC_RATING"] = "M+ Rating"
L["PROGRESS_PRESTIGE"] = "Prestige"
L["PROGRESS_SEASON_RANK"] = "Season Rank"
L["PROGRESS_ACHIEVEMENTS"] = "Achievements"
L["PROGRESS_WEEKLY_VAULT"] = "Weekly Vault"
L["PROGRESS_SEASON_POINTS"] = "Season Points"
L["PROGRESS_PRESTIGE_XP"] = "Prestige XP"
L["PROGRESS_KEYS_WEEK"] = "M+ Keys This Week"
L["PROGRESS_LOADING"] = "Loading..."
L["PROGRESS_REFRESH"] = "Refresh"

-- =============================================================================
-- What's New Content
-- =============================================================================

L["WHATS_NEW_HEADER"] = "Season %d is LIVE!"
L["WHATS_NEW_INTRO"] = "Welcome to DarkChaos-255, a custom WotLK 3.3.5a server with unique features!"

L["WHATS_NEW_FEATURES"] = {
    "|cff00ff00Mythic+ Dungeons|r - Challenge yourself with scaling difficulty!",
    "|cffff8000Prestige System|r - Reset and earn permanent bonuses!",
    "|cff00ccffHotspots|r - Dynamic world events with bonus rewards!",
    "|cffa335eeItem Upgrades|r - Enhance your gear beyond normal limits!",
    "|cfffff000Seasonal Content|r - New rewards and challenges each season!",
}

-- =============================================================================
-- Getting Started Content
-- =============================================================================

L["GETTING_STARTED_HEADER"] = "New Player Guide"

L["GETTING_STARTED_STEPS"] = {
    {
        title = "|cffffd700Step 1: Explore Your Starter Rewards|r",
        text = "You've received starter gear and gold to help you begin. Check your bags and equip your new items!",
    },
    {
        title = "|cffffd700Step 2: Learn the Basics|r",
        text = "Level up to 80 to unlock end-game content. Use /help for a list of helpful commands.",
    },
    {
        title = "|cffffd700Step 3: Unlock Custom Features|r",
        text = "At level 10, Hotspots become available. At level 80, you'll unlock Mythic+ dungeons and the Prestige system.",
    },
    {
        title = "|cffffd700Step 4: Join the Community|r",
        text = "Join our Discord to chat with other players, get help, and stay updated on server news!",
    },
}

-- =============================================================================
-- Server Features Content (from README.md)
-- =============================================================================

L["FEATURES_HEADER"] = "DarkChaos-255 Features"

L["FEATURE_MYTHIC"] = {
    name = "|cffff8000Mythic+ Dungeons|r",
    icon = "Interface\\Icons\\Achievement_challengemode_gold",
    desc = "Retail-inspired endgame dungeon difficulty scaling with keystones, affixes, and leaderboards.",
    unlock = "Unlocks at level 80",
}

L["FEATURE_PRESTIGE"] = {
    name = "|cffa335eePrestige System|r",
    icon = "Interface\\Icons\\Achievement_level_80",
    desc = "Reset your character to level 1 for permanent account-wide bonuses. Each prestige grants +5% XP, gold find, and more!",
    unlock = "Unlocks at level 80",
}

L["FEATURE_HOTSPOTS"] = {
    name = "|cff00ccffDynamic Hotspots|r",
    icon = "Interface\\Icons\\INV_Misc_Map01",
    desc = "World zones that rotate with bonus XP, drop rates, and special events. Check /hotspot for active zones!",
    unlock = "Unlocks at level 10",
}

L["FEATURE_UPGRADE"] = {
    name = "|cff0070ddItem Upgrades|r",
    icon = "Interface\\Icons\\INV_Enchant_VoidSphere",
    desc = "Enhance your equipment beyond normal item levels using upgrade tokens from M+ and raids.",
    unlock = "Unlocks at level 80",
}

L["FEATURE_SEASONS"] = {
    name = "|cfffff000Seasonal Content|r",
    icon = "Interface\\Icons\\Achievement_General",
    desc = "Competitive seasons with time-limited challenges, leaderboards, and exclusive rewards!",
    unlock = "Available for all players",
}

L["FEATURE_AOE_LOOT"] = {
    name = "|cff00ff00AOE Looting|r",
    icon = "Interface\\Icons\\INV_Misc_Bag_09",
    desc = "Loot multiple corpses at once with smart filtering, auto-skinning, and quality options.",
    unlock = "Available immediately",
}

L["FEATURE_HLBG"] = {
    name = "|cffff0000Hinterland Battleground|r",
    icon = "Interface\\Icons\\Achievement_bg_winAB",
    desc = "Open-world PvP zone with objective-based gameplay, auto raid groups, and seasonal support.",
    unlock = "Unlocks at level 80",
}

L["FEATURE_CHALLENGE"] = {
    name = "|cffff6600Challenge Modes|r",
    icon = "Interface\\Icons\\Spell_Shadow_DeathScream",
    desc = "Hardcore, Semi-Hardcore, Iron Man, and Self-Crafted modes for ultimate difficulty!",
    unlock = "Available at character creation",
}

L["FEATURE_DUNGEON_QUESTS"] = {
    name = "|cff00ff99Dungeon Quest System|r",
    icon = "Interface\\Icons\\INV_Scroll_03",
    desc = "Daily and weekly dungeon objectives with token rewards and personal quest NPCs!",
    unlock = "Unlocks at level 80",
}

L["FEATURE_VAULT"] = {
    name = "|cffa335eeItem Vault|r",
    icon = "Interface\\Icons\\INV_Misc_Bag_CoreFelcloth",
    desc = "Weekly reward caches based on your M+ and raid activity. More runs = more choices!",
    unlock = "Unlocks at level 80",
}

-- =============================================================================
-- FAQ Content
-- =============================================================================

L["FAQ_HEADER"] = "Frequently Asked Questions"

L["FAQ_ENTRIES"] = {
    -- Server FAQ entries (matches .faq command topics)
    {
        question = "How do I get buffs?",
        answer = "Use .buff to get some buffs anywhere you are!",
        category = "general",
    },
    {
        question = "How do I navigate the world?",
        answer = "You can use a mobile teleporter with your pet or use the ones standing around everywhere. Use the teleporters to navigate to the correct leveling zone location.",
        category = "general",
    },
    {
        question = "What is the current max level?",
        answer = "The current Max Level is set to 80! It will be extended to the next progression step soon.",
        category = "general",
    },
    {
        question = "What custom dungeons are available?",
        answer = "We have custom dungeons: The Nexus (Lv100), The Oculus (Lv100), Gundrak (Lv130), AhnCahet (Lv130), Auchenai Crypts (Lv160), Mana Tombs (Lv160), Sethekk Halls (Lv160), Shadow Labyrinth (Lv160). More to come!",
        category = "systems",
    },
    {
        question = "What is the Hinterland Battleground?",
        answer = "The Hinterland Battleground is an open battlefield for the current set maxlevel, with special scripts, quests, events and more! Access via teleporters!",
        category = "systems",
    },
    {
        question = "How do I get Tier 11 gear?",
        answer = "For T11 you need 2500 tokens for each Tier 11 item.",
        category = "systems",
    },
    {
        question = "How do I get Tier 12 gear?",
        answer = "For T12 you need 7500 tokens for each Tier 12 item.",
        category = "systems",
    },
    {
        question = "How do I get a keystone?",
        answer = "Complete any level 80 heroic dungeon to receive your first keystone. Higher keystones come from completing M+ runs within the timer.",
        category = "mythicplus",
    },
    {
        question = "What is the Prestige system?",
        answer = "At level 80, you can 'prestige' to reset to level 1 with permanent bonuses. Each prestige grants +5% XP, gold find, and unlocks rewards.",
        category = "prestige",
    },
    {
        question = "How do Hotspots work?",
        answer = "Hotspots are zones with active bonuses. Use /hotspot or check DC-Hotspot addon to see current zones. Bonuses include +XP, +drops, and rare spawns.",
        category = "systems",
    },
    {
        question = "How do I upgrade items?",
        answer = "Visit the Upgrade NPC in Dalaran with upgrade tokens. Tokens drop from M+ runs and raids. Higher content = better tokens.",
        category = "systems",
    },
    {
        question = "Where is the source code?",
        answer = "The sourcecode and full changelog can be found at https://github.com/darkmord1991/DarkChaos-255",
        category = "community",
    },
    {
        question = "How do I join the Discord?",
        answer = "Use /discord in-game or visit: discord.gg/pNddMEMbb2",
        category = "community",
    },
}

-- =============================================================================
-- Community/Links Content
-- =============================================================================

L["LINKS_HEADER"] = "Join Our Community"
L["LINKS_INTRO"] = "Connect with other players and stay updated!"

L["LINK_DISCORD"] = {
    name = "Discord",
    icon = "Interface\\Icons\\INV_Misc_Book_04",
    url = "discord.gg/pNddMEMbb2",
    desc = "Chat with players, get help, and join events!",
}

L["LINK_WEBSITE"] = {
    name = "Website",
    icon = "Interface\\Icons\\INV_Misc_Note_01",
    url = "darkchaos255.com",
    desc = "News, guides, and account management.",
}

L["LINK_WIKI"] = {
    name = "Wiki",
    icon = "Interface\\Icons\\INV_Misc_Book_09",
    url = "wiki.darkchaos255.com",
    desc = "Detailed guides for all custom features.",
}

L["LINK_DONATE"] = {
    name = "Support Us",
    icon = "Interface\\Icons\\INV_Misc_Coin_01",
    url = "darkchaos255.com/donate",
    desc = "Help keep the server running!",
}

-- =============================================================================
-- Buttons & Actions
-- =============================================================================

L["BTN_CLOSE"] = "Close"
L["BTN_DONT_SHOW"] = "Don't show again"
L["BTN_OPEN_SETTINGS"] = "Open Settings"
L["BTN_COPY_LINK"] = "Click to copy link"
L["BTN_NEXT"] = "Next"
L["BTN_PREV"] = "Previous"

-- =============================================================================
-- Messages
-- =============================================================================

L["MSG_LINK_COPIED"] = "Link copied to chat! Press Ctrl+C to copy."
L["MSG_WELCOME_DISMISSED"] = "Welcome screen hidden. Use /welcome to show again."
L["MSG_FIRST_LOGIN"] = "|cff00ff00Welcome to DarkChaos-255!|r Type |cfffff000/welcome|r anytime to see this screen again."

-- =============================================================================
-- Tooltips
-- =============================================================================

L["TIP_CLOSE"] = "Close this window"
L["TIP_DONT_SHOW"] = "Don't show this automatically on login"
L["TIP_TAB"] = "Click to view %s"
