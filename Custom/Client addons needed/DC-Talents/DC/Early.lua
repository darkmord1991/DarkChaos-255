--[[
	DC-Talents - globals the vendored retail files read WHILE LOADING.

	Anything a retail file touches at file scope (table constructors, constants) must exist before
	that file runs, so these load ahead of the vendored code. Behavioural overrides that only matter
	when frames are built live in DC/Overrides.lua.
]]

local _, ns = ...
setfenv(1, ns.env)

local G = ns.realG

-- Blizzard_ClassSpecializationsFrame builds SPEC_STAT_STRINGS keyed by these at load.
LE_UNIT_STAT_STRENGTH = LE_UNIT_STAT_STRENGTH or 1
LE_UNIT_STAT_AGILITY = LE_UNIT_STAT_AGILITY or 2
LE_UNIT_STAT_STAMINA = LE_UNIT_STAT_STAMINA or 3
LE_UNIT_STAT_INTELLECT = LE_UNIT_STAT_INTELLECT or 4
LE_UNIT_STAT_SPIRIT = LE_UNIT_STAT_SPIRIT or 5

ACTION_BUTTON_SHOW_GRID_REASON_SPELLCOLLECTION = ACTION_BUTTON_SHOW_GRID_REASON_SPELLCOLLECTION or 4

-- Retail shows the empty action slots while the window is open. On 3.3.5 that sets attributes on
-- secure action buttons, which is blocked in combat; the stock client shows them on drag anyway.
local function Nop() end
MultiActionBar_ShowAllGrids = Nop
MultiActionBar_HideAllGrids = Nop

-- The talent window and its loadout dialogs are built on first open (DC/Frame.lua), like retail's
-- load-on-demand Blizzard_PlayerSpells: players who never open it never pay for it.
for _, name in ipairs({ "PlayerSpellsFrame", "ClassTalentLoadoutImportDialog", "ClassTalentLoadoutEditDialog", "ClassTalentLoadoutCreateDialog" }) do
	ns.XML.Defer(name)
end

-- Blizzard_GroupFinder/LFGList.lua (not ported).
local LFGStringFromEnum = {
	[Enum.LFGRole.Tank] = "TANK",
	[Enum.LFGRole.Healer] = "HEALER",
	[Enum.LFGRole.Damage] = "DAMAGER",
}

function GetLFGStringFromEnum(role)
	local stringName = LFGStringFromEnum[role]
	return stringName and (G[stringName] or stringName) or ""
end

-- Role icon atlases (TextureUtil) mapped onto the stock 3.3.5 small round role icons: the sheet
-- GetTexCoordsForRoleSmallCircle and LFGFrame.lua's |T| icons use (64 x 64; UI-LFG-ICON-ROLES is the
-- 256 x 256 sheet of the big icons and shows half-icons with these coordinates).
local ROLE_SHEET = "Interface\\LFGFrame\\UI-LFG-ICON-PORTRAITROLES"
local RoleCoords = {
	Tank = { 0, 19 / 64, 22 / 64, 41 / 64 },
	Healer = { 20 / 64, 39 / 64, 1 / 64, 20 / 64 },
	DPS = { 20 / 64, 39 / 64, 22 / 64, 41 / 64 },
	Leader = { 0, 19 / 64, 1 / 64, 20 / 64 },
}
for role, coords in pairs(RoleCoords) do
	for _, suffix in ipairs({ "", "-Micro", "-Disabled", "-Micro-GroupFinder" }) do
		ns.Atlas.Register("UI-LFG-RoleIcon-" .. role .. suffix, ROLE_SHEET, 16, 16, coords[1], coords[2], coords[3], coords[4])
	end
end

-- Retail sound kits used by the port -> 3.3.5 sound names.
local SoundNames = {
	UI_CLASS_TALENT_OPEN_WINDOW = "TalentScreenOpen",
	UI_CLASS_TALENT_CLOSE_WINDOW = "TalentScreenClose",
	UI_CLASS_TALENT_TAB = "igCharacterInfoTab",
	UI_CLASS_TALENT_NODE_SPEND = "igMainMenuOptionCheckBoxOn",
	UI_CLASS_TALENT_NODE_SPEND_MAJOR = "igMainMenuOptionCheckBoxOn",
	UI_CLASS_TALENT_NODE_REFUND = "igMainMenuOptionCheckBoxOff",
	UI_CLASS_TALENT_APPLY_CHANGES = "LevelUp",
	UI_CLASS_TALENT_APPLY_COMPLETE = "igQuestListComplete",
	UI_CLASS_TALENT_SPEC_ACTIVATE = "igMainMenuOptionCheckBoxOn",
	IG_MAINMENU_OPTION_CHECKBOX_ON = "igMainMenuOptionCheckBoxOn",
	IG_MAINMENU_OPTION_CHECKBOX_OFF = "igMainMenuOptionCheckBoxOff",
}
for key, soundName in pairs(SoundNames) do
	local soundKitID = SOUNDKIT[key]
	if soundKitID then
		RegisterSoundKitName(soundKitID, soundName)
	else
		SOUNDKIT[key] = soundName
	end
end
