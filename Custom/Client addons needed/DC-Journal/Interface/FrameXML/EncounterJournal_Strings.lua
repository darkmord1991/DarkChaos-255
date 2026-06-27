-- Dark Chaos content-tab labels (Open World world bosses / Mythic+)
DCEJ_OPENWORLD_TAB = DCEJ_OPENWORLD_TAB or "Open World"
DCEJ_MYTHICPLUS_TAB = DCEJ_MYTHICPLUS_TAB or "Mythic+"

ADVENTURE = ADVENTURE or "Adventure Guide"
ADVENTURE_JOURNAL = ADVENTURE_JOURNAL or "Adventure Guide"
NAVIGATIONBAR_HOME = NAVIGATIONBAR_HOME or "Home"
AJ_SUGGESTED_CONTENT_TAB = AJ_SUGGESTED_CONTENT_TAB or "Suggested"
EJ_RAIDS_TAB = EJ_RAIDS_TAB or "Raids"
RAIDS = RAIDS or "Raids"
INSTANCE = INSTANCE or "Dungeon"
ENCOUNTER = ENCOUNTER or "Encounter"
HEADHUNTING = HEADHUNTING or "Headhunting"
LOOTJOURNAL_ITEM_SETS = LOOTJOURNAL_ITEM_SETS or "Item Sets"
ENCOUNTER_JOURNAL_SHOW_MAP = ENCOUNTER_JOURNAL_SHOW_MAP or "Show Map"
ENCOUNTER_JOURNAL_SHOW_SEARCH_RESULTS = ENCOUNTER_JOURNAL_SHOW_SEARCH_RESULTS or "Show all results"
ENCOUNTER_JOURNAL_SEARCH_RESULTS = ENCOUNTER_JOURNAL_SEARCH_RESULTS or "Search Results: %s (%d)"
ENCOUNTER_JOURNAL_ITEM = ENCOUNTER_JOURNAL_ITEM or "Item"
ENCOUNTER_JOURNAL_ENCOUNTER = ENCOUNTER_JOURNAL_ENCOUNTER or "Encounter"
ENCOUNTER_JOURNAL_INSTANCE = ENCOUNTER_JOURNAL_INSTANCE or "Dungeon"
EJ_FILTER_ALL_CLASS = EJ_FILTER_ALL_CLASS or "All Classes"
EJ_CLASS_FILTER = EJ_CLASS_FILTER or "Class"
CLASS = CLASS or "Class"
FILTER = FILTER or "Filter"
ALL_INVENTORY_SLOTS = ALL_INVENTORY_SLOTS or "All Slots"
MAINMENUBAR_EJ_NEWBIE_TOOLTIP = MAINMENUBAR_EJ_NEWBIE_TOOLTIP or "Information about dungeon and raid bosses, including their abilities and loot."
LOOTJOURNAL_ITEM_CLICK_TO_OPEN_LOOT = LOOTJOURNAL_ITEM_CLICK_TO_OPEN_LOOT or "Click to open the loot."
LOOTJOURNAL_SOURCE_TOOLTIP_HEAD = LOOTJOURNAL_SOURCE_TOOLTIP_HEAD or "Source"
LOOTJOURNAL_PVPICON_TOOLTIP_HEAD = LOOTJOURNAL_PVPICON_TOOLTIP_HEAD or "PvP Set"
LOOTJOURNAL_PVPICON_TOOLTIP = LOOTJOURNAL_PVPICON_TOOLTIP or "A set suitable for player-versus-player combat."
RETURN_TO_DEFAULT = RETURN_TO_DEFAULT or "Return to Defaults"
OVERVIEW = OVERVIEW or "Overview"
ABILITIES = ABILITIES or "Abilities"
LOOT_NOUN = LOOT_NOUN or "Loot"
MODEL = MODEL or "Model"
BOSS_INFO_STRING = BOSS_INFO_STRING or "Boss: %s"
EJ_SET_ITEM_LEVEL = EJ_SET_ITEM_LEVEL or "|cffcc4040[%s]|r Item Level: %d"
SEARCH_LOADING_TEXT = SEARCH_LOADING_TEXT or "Searching..."
SEARCH_PROGRESS_BAR_TEXT = SEARCH_PROGRESS_BAR_TEXT or "Searching"
BINDING_NAME_TOGGLEENCOUNTERJOURNAL = BINDING_NAME_TOGGLEENCOUNTERJOURNAL or ADVENTURE

LOOTJOURNAL_FACTION_NEUTRAL = LOOTJOURNAL_FACTION_NEUTRAL or 0
LOOTJOURNAL_FACTION_ALLIANCE = LOOTJOURNAL_FACTION_ALLIANCE or 1
LOOTJOURNAL_FACTION_HORDE = LOOTJOURNAL_FACTION_HORDE or 2

for i = 0, 12 do
	local key = "ENCOUNTER_JOURNAL_SECTION_FLAG"..i
	_G[key] = _G[key] or ("Flag "..i)
	local descKey = "ENCOUNTER_JOURNAL_SECTION_FLAG_DESCRIPTION"..i
	_G[descKey] = _G[descKey] or ("Flag description "..i)
end

-- Vanilla 3.3.5 has no ITEM_SUB_CLASS_* globals; EJ uses them as GetItemInfo subclass keys.
local function DefItemSubClass(name, enUS)
	if not _G[name] then
		_G[name] = enUS
	end
end

DefItemSubClass("ITEM_SUB_CLASS_2_0", "One-Handed Axes")
DefItemSubClass("ITEM_SUB_CLASS_2_1", "Two-Handed Axes")
DefItemSubClass("ITEM_SUB_CLASS_2_2", "Bows")
DefItemSubClass("ITEM_SUB_CLASS_2_3", "Guns")
DefItemSubClass("ITEM_SUB_CLASS_2_4", "One-Handed Maces")
DefItemSubClass("ITEM_SUB_CLASS_2_5", "Two-Handed Maces")
DefItemSubClass("ITEM_SUB_CLASS_2_6", "Polearms")
DefItemSubClass("ITEM_SUB_CLASS_2_7", "One-Handed Swords")
DefItemSubClass("ITEM_SUB_CLASS_2_8", "Two-Handed Swords")
DefItemSubClass("ITEM_SUB_CLASS_2_10", "Staves")
DefItemSubClass("ITEM_SUB_CLASS_2_13", "Fist Weapons")
DefItemSubClass("ITEM_SUB_CLASS_2_14", "Miscellaneous")
DefItemSubClass("ITEM_SUB_CLASS_2_15", "Daggers")
DefItemSubClass("ITEM_SUB_CLASS_2_18", "Crossbows")
DefItemSubClass("ITEM_SUB_CLASS_2_19", "Wands")

DefItemSubClass("ITEM_SUB_CLASS_4_1", "Cloth")
DefItemSubClass("ITEM_SUB_CLASS_4_2", "Leather")
DefItemSubClass("ITEM_SUB_CLASS_4_3", "Mail")
DefItemSubClass("ITEM_SUB_CLASS_4_4", "Plate")
DefItemSubClass("ITEM_SUB_CLASS_4_5", "Cosmetic")
DefItemSubClass("ITEM_SUB_CLASS_4_6", "Shields")
DefItemSubClass("ITEM_SUB_CLASS_4_7", "Librams")
DefItemSubClass("ITEM_SUB_CLASS_4_8", "Idols")
DefItemSubClass("ITEM_SUB_CLASS_4_9", "Totems")
DefItemSubClass("ITEM_SUB_CLASS_4_10", "Sigils")

DefItemSubClass("ITEM_SUB_CLASS_5_0", "Reagent")
DefItemSubClass("ITEM_SUB_CLASS_7_0", "Trade Goods")
DefItemSubClass("ITEM_SUB_CLASS_7_1", "Parts")
DefItemSubClass("ITEM_SUB_CLASS_7_2", "Explosives")
DefItemSubClass("ITEM_SUB_CLASS_7_3", "Devices")
DefItemSubClass("ITEM_SUB_CLASS_7_4", "Jewelcrafting")
DefItemSubClass("ITEM_SUB_CLASS_7_5", "Cloth")
DefItemSubClass("ITEM_SUB_CLASS_7_6", "Leather")
DefItemSubClass("ITEM_SUB_CLASS_7_7", "Metal & Stone")
DefItemSubClass("ITEM_SUB_CLASS_7_8", "Meat")
DefItemSubClass("ITEM_SUB_CLASS_7_9", "Herb")
DefItemSubClass("ITEM_SUB_CLASS_7_10", "Elemental")
DefItemSubClass("ITEM_SUB_CLASS_7_11", "Other")
DefItemSubClass("ITEM_SUB_CLASS_7_12", "Enchanting")
DefItemSubClass("ITEM_SUB_CLASS_7_13", "Materials")
DefItemSubClass("ITEM_SUB_CLASS_7_14", "Armor Enchantment")
DefItemSubClass("ITEM_SUB_CLASS_7_15", "Weapon Enchantment")

DefItemSubClass("ITEM_SUB_CLASS_9_0", "Book")
DefItemSubClass("ITEM_SUB_CLASS_9_1", "Leatherworking")
DefItemSubClass("ITEM_SUB_CLASS_9_2", "Tailoring")
DefItemSubClass("ITEM_SUB_CLASS_9_3", "Engineering")
DefItemSubClass("ITEM_SUB_CLASS_9_4", "Blacksmithing")
DefItemSubClass("ITEM_SUB_CLASS_9_5", "Cooking")
DefItemSubClass("ITEM_SUB_CLASS_9_6", "Alchemy")
DefItemSubClass("ITEM_SUB_CLASS_9_7", "First Aid")
DefItemSubClass("ITEM_SUB_CLASS_9_8", "Enchanting")
DefItemSubClass("ITEM_SUB_CLASS_9_9", "Fishing")
DefItemSubClass("ITEM_SUB_CLASS_9_10", "Jewelcrafting")
DefItemSubClass("ITEM_SUB_CLASS_9_11", "Inscription")

DefItemSubClass("ITEM_SUB_CLASS_11_3", "Ammo Pouch")
DefItemSubClass("ITEM_SUB_CLASS_12_0", "Quest")
DefItemSubClass("ITEM_SUB_CLASS_13_0", "Key")
DefItemSubClass("ITEM_SUB_CLASS_13_1", "Lockpick")
DefItemSubClass("ITEM_SUB_CLASS_14_0", "Permanent")
DefItemSubClass("ITEM_SUB_CLASS_15_0", "Junk")
DefItemSubClass("ITEM_SUB_CLASS_15_1", "Reagent")
DefItemSubClass("ITEM_SUB_CLASS_15_2", "Companion Pets")
DefItemSubClass("ITEM_SUB_CLASS_15_3", "Holiday")
DefItemSubClass("ITEM_SUB_CLASS_15_4", "Other")
DefItemSubClass("ITEM_SUB_CLASS_15_5", "Mount")

if not GetItemSubClassInfo then
	function GetItemSubClassInfo(classID, subClassID)
		if tonumber(classID) and tonumber(subClassID) then
			return _G[string.format("ITEM_SUB_CLASS_%d_%d", classID, subClassID)]
		end
	end
end

local function DefItemClass(name, enUS)
	if not _G[name] then
		_G[name] = enUS
	end
end

DefItemClass("ITEM_CLASS_0", "Consumable")
DefItemClass("ITEM_CLASS_1", "Container")
DefItemClass("ITEM_CLASS_2", "Weapon")
DefItemClass("ITEM_CLASS_3", "Gem")
DefItemClass("ITEM_CLASS_4", "Armor")
DefItemClass("ITEM_CLASS_5", "Reagent")
DefItemClass("ITEM_CLASS_6", "Projectile")
DefItemClass("ITEM_CLASS_7", "Trade Goods")
DefItemClass("ITEM_CLASS_8", "Generic")
DefItemClass("ITEM_CLASS_9", "Recipe")
DefItemClass("ITEM_CLASS_10", "Money")
DefItemClass("ITEM_CLASS_11", "Quiver")
DefItemClass("ITEM_CLASS_12", "Quest")
DefItemClass("ITEM_CLASS_13", "Key")
DefItemClass("ITEM_CLASS_14", "Permanent")
DefItemClass("ITEM_CLASS_15", "Miscellaneous")
DefItemClass("ITEM_CLASS_16", "Glyph")

DefItemSubClass("ITEM_SUB_CLASS_4_0", "Miscellaneous")
