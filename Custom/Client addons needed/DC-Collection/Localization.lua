--[[
    DC-Collection Localization
    ==========================
    
    Localization strings for all supported languages.
    
    Author: DarkChaos-255
    Version: 1.0.0
]]

DCCollection = DCCollection or {}
DCCollection.L = DCCollection.L or {}
local L = DCCollection.L

-- Default to English
L.ADDON_NAME = "DC-Collection"
L.ADDON_LOADED = "DC-Collection v%s loaded. Type /dcc for options."

-- Tabs
L.TAB_OVERVIEW = "My Collection"
L.TAB_MOUNTS = "Mounts"
L.TAB_PETS = "Pets"
L.TAB_HEIRLOOMS = "Heirlooms"
L.TAB_TRANSMOG = "Transmog"
L.TAB_WARDROBE = "Wardrobe"
L.TAB_TITLES = "Titles"
L.TAB_SHOP = "Shop"
L.TAB_WISHLIST = "Wishlist"
L.TAB_ACHIEVEMENTS = "Achievements"

-- Filters
L.FILTER_ALL = "All"
L.FILTER_COLLECTED = "Collected"
L.FILTER_NOT_COLLECTED = "Not Collected"
L.FILTER_FAVORITES = "Favorites"
L.FILTER_USABLE = "Usable"

-- Mount types
L.MOUNT_GROUND = "Ground"
L.MOUNT_FLYING = "Flying"
L.MOUNT_AQUATIC = "Aquatic"

-- Factions
L.FACTION_ALL = "All Factions"
L.FACTION_ALLIANCE = "Alliance"
L.FACTION_HORDE = "Horde"

-- Sources
L.SOURCE_UNKNOWN = "Unknown source"
L.SOURCE_DROP = "Drops from %s"
L.SOURCE_VENDOR = "Sold by %s"
L.SOURCE_QUEST = "Quest: %s"
L.SOURCE_ACHIEVEMENT = "Achievement: %s"
L.SOURCE_PROFESSION = "Profession: %s"
L.SOURCE_REPUTATION = "Reputation: %s"
L.SOURCE_PVP = "PvP Reward"
L.SOURCE_PROMOTION = "Promotional"
L.SOURCE_DARKCHAOS = "DarkChaos Exclusive"

-- Rarity
L.RARITY_COMMON = "Common"
L.RARITY_UNCOMMON = "Uncommon"
L.RARITY_RARE = "Rare"
L.RARITY_EPIC = "Epic"
L.RARITY_LEGENDARY = "Legendary"

-- Actions
L.ACTION_SUMMON = "Summon"
L.ACTION_DISMISS = "Dismiss"
L.ACTION_FAVORITE = "Favorite"
L.ACTION_UNFAVORITE = "Unfavorite"
L.ACTION_PREVIEW = "Preview"
L.ACTION_SET_TITLE = "Set Title"
L.ACTION_ADD_WISHLIST = "Add to Wishlist"
L.ACTION_REMOVE_WISHLIST = "Remove from Wishlist"
L.ACTION_SUMMON_HEIRLOOM = "Summon to Bag"

-- Shop
L.SHOP_TITLE = "Collection Shop"
L.SHOP_BUY = "Buy"
L.SHOP_CONFIRM = "Purchase %s for %s?"
L.SHOP_SUCCESS = "Purchased %s!"
L.SHOP_ERROR_CURRENCY = "Not enough currency!"
L.SHOP_ERROR_REQUIREMENT = "Requirements not met: %s"
L.SHOP_ERROR_LIMIT = "Purchase limit reached!"
L.SHOP_ERROR_STOCK = "Out of stock!"
L.SHOP_TOKENS = "Collection Tokens"
L.SHOP_EMBLEMS = "Collector's Emblems"
L.SHOP_REQUIRES = "Requires:"
L.SHOP_REQUIRES_MOUNTS = "%d mounts collected"
L.SHOP_REQUIRES_PETS = "%d pets collected"
L.SHOP_REQUIRES_TOTAL = "%d total collectibles"

-- Currency
L.CURRENCY_TOKENS = "Tokens"
L.CURRENCY_EMBLEMS = "Emblems"

-- Statistics
L.STATS_TOTAL = "Total: %d"
L.STATS_COLLECTED = "Collected: %d / %d"
L.STATS_PROGRESS = "%.1f%% Complete"

-- Bonuses
L.BONUS_MOUNT_SPEED = "Mount Speed Bonus"
L.BONUS_CURRENT = "Current: +%d%%"
L.BONUS_NEXT = "Next: +%d%% at %d mounts"

-- Wishlist
L.WISHLIST_TITLE = "Wishlist"
L.WISHLIST_EMPTY = "Your wishlist is empty."
L.WISHLIST_ADDED = "Added to wishlist: %s"
L.WISHLIST_REMOVED = "Removed from wishlist: %s"
L.WISHLIST_HINT = "Items on your wishlist will notify you when nearby!"

-- Notifications
L.NOTIFY_MOUNT_COLLECTED = "New mount collected: %s!"
L.NOTIFY_PET_COLLECTED = "New pet collected: %s!"
L.NOTIFY_ACHIEVEMENT = "Collection achievement: %s!"
L.NOTIFY_WISHLIST_NEARBY = "Wishlist item nearby: %s!"

-- Errors
L.ERROR_NOT_LOADED = "Collection data not yet loaded."
L.ERROR_SERVER_OFFLINE = "Unable to reach server."
L.ERROR_ALREADY_OWNED = "You already own this item."
L.ERROR_NOT_OWNED = "You don't own this item."
L.ERROR_BAGS_FULL = "Your bags are full!"

-- Heirlooms
L.HEIRLOOM_UPGRADE_LEVEL = "Upgrade Level: %d / %d"
L.HEIRLOOM_ALREADY_HAVE = "You already have this heirloom."
L.HEIRLOOM_SUMMONED = "Heirloom summoned to your bags!"

-- German localization
if GetLocale() == "deDE" then
    L.ADDON_NAME = "DC-Collection"
    L.TAB_OVERVIEW = "Meine Sammlung"
    L.TAB_MOUNTS = "Reittiere"
    L.TAB_PETS = "Begleiter"
    L.TAB_HEIRLOOMS = "Erbstücke"
    L.TAB_TRANSMOG = "Transmogrifikation"
    L.TAB_WARDROBE = "Garderobe"
    L.TAB_TITLES = "Titel"
    L.TAB_SHOP = "Shop"
    L.TAB_WISHLIST = "Wunschliste"
    L.TAB_ACHIEVEMENTS = "Erfolge"
    
    L.FILTER_ALL = "Alle"
    L.FILTER_COLLECTED = "Gesammelt"
    L.FILTER_NOT_COLLECTED = "Nicht gesammelt"
    L.FILTER_FAVORITES = "Favoriten"
    
    L.MOUNT_GROUND = "Boden"
    L.MOUNT_FLYING = "Fliegend"
    L.MOUNT_AQUATIC = "Wasser"
    
    L.ACTION_SUMMON = "Beschwören"
    L.ACTION_FAVORITE = "Favorit"
    L.ACTION_PREVIEW = "Vorschau"
    
    L.SHOP_TITLE = "Sammler-Shop"
    L.SHOP_BUY = "Kaufen"
    L.SHOP_TOKENS = "Sammelmarken"
    L.SHOP_EMBLEMS = "Sammlerembleme"
    
    L.STATS_COLLECTED = "Gesammelt: %d / %d"
    L.STATS_PROGRESS = "%.1f%% Abgeschlossen"
end
