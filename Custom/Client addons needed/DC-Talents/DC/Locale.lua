--[[
	DC-Talents - strings of the DC layer (the vendored retail files use retail global strings,
	generated into Data/RetailData.lua).
]]

local _, ns = ...
setfenv(1, ns.env)

ns.L = {
	ADDON_TITLE = "Talents",
	TAB_GLYPHS = "Glyphs",
	GLYPHS_LOCKED = "Glyphs become available at level %d.",
	TAB_PET = "Pet",
	PET_TITLE = "Pet Talents",
	PET_APPLY = "Apply Changes",
	PET_UNDO = "Undo",
	PET_POINTS_FORMAT = "%d pet talent points available",
	PET_NO_PET = "Summon a pet to see its talents.",

	GLYPHS_APPLY = "Apply Loadout Glyphs",
	GLYPHS_LOADOUT_STATUS = "Loadout %s: %d glyph(s) differ",
	GLYPHS_LOADOUT_MATCH = "Loadout %s: glyphs match",
	GLYPHS_NO_LOADOUT = "Select a loadout to compare its glyphs.",
	GLYPHS_DIFFER_NOTICE = "%d glyph(s) differ from loadout %s - open the Glyphs tab to apply them.",
	GLYPH_MISSING = "Missing in your bags: %s",
	GLYPH_UNKNOWN = "Glyph spell %d is not known to this client.",

	TALENT_POINTS_AVAILABLE = "TALENT POINTS AVAILABLE",
	TREE_POINTS_FORMAT = "%d",
	GATE_TOOLTIP_FORMAT = "Requires %d more points spent in %s",
	NEW_LOADOUT = "New Loadout",

	TOOLTIP_RANK_FORMAT = "Rank %d/%d",
	TOOLTIP_NEXT_RANK = "Next rank:",
	TOOLTIP_STAGED = "Pending change: rank %d/%d (click Apply Changes)",
	TOOLTIP_STAGED_REMOVED = "Pending change: will be unlearned (click Apply Changes)",

	ERR_REMOVE_NEEDS_SERVER = "Removing learned talents needs the Dark Chaos server module; only additions can be applied.",
	ERR_COMMIT_PARTIAL = "Some talents could not be learned.",
	ERR_SERVER_TIMEOUT = "The server did not answer the talent change.",
	ERR_IN_COMBAT = "You can't change talents in combat.",
	ERR_DEAD = "You can't change talents while dead.",
	ERR_LOADOUT_MISSING = "That loadout no longer exists.",
	ERR_LOADOUT_NOT_APPLICABLE = "That loadout needs more talent points than you have, or skips a requirement.",
	ERR_TOO_MANY_LOADOUTS = "You have too many loadouts for this class.",

	SPEC_DUAL_HINT = "Learn Dual Talent Specialization from your class trainer to use a second talent group.",
	SPEC_VIEW_BUTTON = "View",

	MENU_EDIT = "Edit Loadout",
	MENU_OVERWRITE = "Save Current Build Here",
	MENU_DUPLICATE = "Duplicate",
	MENU_EXPORT_STRING = "Copy Loadout String",
	MENU_EXPORT_WOWHEAD = "Copy Wowhead Link",
	MENU_SEND = "Send to Player...",
	MENU_DELETE = "Delete",
	MENU_FAVORITE = "Favorite",

	COPY_DIALOG_TITLE = "Press Ctrl+C to copy",

	SLASH_HELP = "/talents - open the talent window; /talents spec | glyphs | classic | scale <0.5-1|auto> | replace | server | debug.",
	SETTING_REPLACE = "Use the Dark Chaos talent window for the talent key and micro button",
}
