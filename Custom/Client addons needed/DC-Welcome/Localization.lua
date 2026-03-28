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
L["WELCOME_SUBTITLE"] = "Your command center for custom progression, addons, and seasonal systems"

-- =============================================================================
-- Tab Names
-- =============================================================================

L["TAB_WHATS_NEW"] = "What's New"
L["TAB_GETTING_STARTED"] = "Getting Started"
L["TAB_FEATURES"] = "Server Features"
L["TAB_ADDONS"] = "Addons"
L["TAB_PROGRESS"] = "Progress"
L["TAB_SEASON"] = "Season"
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
L["WHATS_NEW_INTRO"] = "DarkChaos-255 uses bracketed progression. The live cap is currently level 80, while the long-term progression path continues through later brackets up to 255."

L["WHATS_NEW_FEATURES"] = {
    "|cffffd700Bracketed Progression|r - The live bracket is currently capped at 80, with future brackets planned for 100, 130, 160, 200, and 255.",
    "|cffff8000Mythic+ Suite|r - Keystones, affixes, group finder, Great Vault progress, and leaderboards.",
    "|cffa335eePrestige at 255|r - A later-bracket system planned for the eventual 255 cap, with reset-based long-term progression.",
    "|cff00ccffHotspots + Map Upgrades|r - Rotating bonus zones with world-map pins for hotspots and world content.",
    "|cff00ff00AOE Loot + DC-QOS|r - Faster looting plus tooltip, automation, bag, nameplate, and interface improvements.",
    "|cff00ff99Collections + Info Bar|r - Browse mounts, pets, toys, titles, appearances, and keep key server info visible.",
    "|cffff0000Hinterland Battleground|r - Open-world PvP with queue HUD, live stats, and seasonal tracking.",
    "|cffff66ffSeason Systems|r - Season points, token and essence tracking, reward popups, and leaderboards.",
    "|cffff6600Challenge Modes|r - Hardcore, Iron Man, Self-Crafted, and other special-rule runs via the Challenge Mode Manager.",
    "|cffa335eeUnified Addons Hub|r - Open and configure the full DarkChaos addon stack from one place.",
}

-- =============================================================================
-- Getting Started Content
-- =============================================================================

L["GETTING_STARTED_HEADER"] = "New Player Guide"

L["GETTING_STARTED_STEPS"] = {
    {
        title = "|cffffd700Step 1: Open the Welcome Hub|r",
        text = "Use this addon as your landing page. The Addons tab opens the DarkChaos client tools, while Progress and Season show your live progression data.",
    },
    {
        title = "|cffffd700Step 2: Follow the Level Milestones|r",
        text = "The live bracket currently ends at 80, where Mythic+ opens. Later brackets are planned for 100, 130, 160, 200, and 255, with Prestige reserved for the eventual 255 bracket.",
    },
    {
        title = "|cffffd700Step 3: Enable the Client Tools|r",
        text = "Open DC-Mapupgrades, DC-QOS, DC-Collection, DC-InfoBar, and the Mythic+ suite from the Addons tab so you have the full DarkChaos UI stack available while leveling.",
    },
    {
        title = "|cffffd700Step 4: Keep the Resources Handy|r",
        text = "Use the Community tab for Discord, GitHub, current docs, and issue tracking so you always have the latest setup and feature information.",
    },
}

-- =============================================================================
-- Server Features Content (from README.md)
-- =============================================================================

L["FEATURES_HEADER"] = "DarkChaos-255 Features"

L["FEATURE_MYTHIC"] = {
    name = "|cffff8000Mythic+ Dungeons|r",
    icon = "Interface\\Icons\\Achievement_challengemode_gold",
    desc = "Scaling dungeon content with keystones, affixes, group finder, Great Vault integration, and seasonal leaderboards.",
    unlock = "Unlocks at level 80",
}

L["FEATURE_PRESTIGE"] = {
    name = "|cffa335eePrestige System|r",
    icon = "Interface\\Icons\\Achievement_level_80",
    desc = "A future-bracket system planned for the eventual level 255 cap, where capped characters can reset for permanent stat bonuses and prestige progression.",
    unlock = "Planned for the 255 bracket",
}

L["FEATURE_HOTSPOTS"] = {
    name = "|cff00ccffDynamic Hotspots|r",
    icon = "Interface\\Icons\\INV_Misc_Map01",
    desc = "Rotating bonus zones with world-map support, active markers, and extra world content visibility. Check /hotspot for the current rotation.",
    unlock = "Unlocks at level 10",
}

L["FEATURE_UPGRADE"] = {
    name = "|cff0070ddItem Upgrades|r",
    icon = "Interface\\Icons\\INV_Enchant_VoidSphere",
    desc = "Upgrade current gear and heirlooms using tokens earned through Mythic+, seasonal systems, and other custom progression content.",
    unlock = "Unlocks at level 80",
}

L["FEATURE_SEASONS"] = {
    name = "|cfffff000Seasonal Content|r",
    icon = "Interface\\Icons\\Achievement_General",
    desc = "Season points, token and essence tracking, reward popups, leaderboard competition, and rotating progression goals.",
    unlock = "Available throughout your journey",
}

L["FEATURE_AOE_LOOT"] = {
    name = "|cff00ff00AOE Looting|r",
    icon = "Interface\\Icons\\INV_Misc_Bag_09",
    desc = "Loot nearby corpses in one click with filters, auto-skinning, and DC-AOESettings support for fast farming.",
    unlock = "Available immediately",
}

L["FEATURE_HLBG"] = {
    name = "|cffff0000Hinterland Battleground|r",
    icon = "Interface\\Icons\\Achievement_bg_winAB",
    desc = "Objective-based open-world PvP with queue tools, a dedicated HUD, live stats, and seasonal support.",
    unlock = "Check the current queue requirements",
}

L["FEATURE_CHALLENGE"] = {
    name = "|cffff6600Challenge Modes|r",
    icon = "Interface\\Icons\\Spell_Shadow_DeathScream",
    desc = "Hardcore, Semi-Hardcore, Iron Man, Self-Crafted, and other special-rule runs handled through the Challenge Mode Manager UI.",
    unlock = "Available through the Challenge Mode Manager",
}

L["FEATURE_DUNGEON_QUESTS"] = {
    name = "|cff00ff99Dungeon Quest System|r",
    icon = "Interface\\Icons\\INV_Scroll_03",
    desc = "Supported dungeon runs can include personal objectives, bonus rewards, and extra progression hooks while you push higher tiers.",
    unlock = "Available in supported dungeon content",
}

L["FEATURE_VAULT"] = {
    name = "|cffa335eeItem Vault|r",
    icon = "Interface\\Icons\\INV_Misc_Bag_CoreFelcloth",
    desc = "Weekly reward choices tied to successful Mythic+ activity and tracked directly in the Progress tab.",
    unlock = "Weekly progression feature",
}

-- =============================================================================
-- FAQ Content
-- =============================================================================

L["FAQ_HEADER"] = "Frequently Asked Questions"

-- =============================================================================
-- Community/Links Content
-- =============================================================================

L["LINKS_HEADER"] = "Community & Resources"
L["LINKS_INTRO"] = "Stay connected, check the latest docs, and keep the current project links close at hand."

L["LINK_DISCORD"] = {
    name = "Discord",
    icon = "Interface\\Icons\\INV_Misc_Book_04",
    url = "https://discord.gg/pNddMEMbb2",
    desc = "Chat with players, get help, and join events!",
}

L["LINK_WEBSITE"] = {
    name = "GitHub Repository",
    icon = "Interface\\Icons\\INV_Misc_Note_01",
    url = "https://github.com/darkmord1991/DarkChaos-255",
    desc = "Source code, changelog, and the current project state.",
}

L["LINK_WIKI"] = {
    name = "README / Docs",
    icon = "Interface\\Icons\\INV_Misc_Book_09",
    url = "https://github.com/darkmord1991/DarkChaos-255/blob/master/README.md",
    desc = "Setup notes, feature overview, and addon documentation.",
}

L["LINK_DONATE"] = {
    name = "Issue Tracker",
    icon = "Interface\\Icons\\INV_Misc_Note_05",
    url = "https://github.com/darkmord1991/DarkChaos-255/issues",
    desc = "Report bugs, follow fixes, and review open work.",
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
