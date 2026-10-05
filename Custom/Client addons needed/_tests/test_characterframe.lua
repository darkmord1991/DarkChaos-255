-- DC-CharacterFrame: loads the real addon files against a stubbed stock
-- CharacterFrame and drives login, tab switching, the outfit dropdown sync,
-- the stats pane, the titles / equipment-set / upgrade panes and the retired
-- legacy buttons. wowsim resolves unknown widget methods to no-ops, so this
-- pins logic and data flow, not the client API surface.
dofile("wowsim.lua")
_G.unpack = _G.unpack or table.unpack   -- 3.3.5 client global; Lua 5.4 moved it
local ROOT = os.getenv("DC_ADDON_ROOT") or [[K:\Dark-Chaos\DarkChaos-255-Master\Custom\Client addons needed\]]
local ADDON = ROOT .. [[DC-CharacterFrame\]]
local pass, fail = 0, 0
local function ok(c, m) if c then pass = pass + 1; print("  PASS " .. m) else fail = fail + 1; print("  FAIL " .. m) end end

-- ---------------------------------------------------------------------------
-- Simulator extensions
-- ---------------------------------------------------------------------------
local Methods = getmetatable(CreateFrame("Frame")).__index
local TexMethods = getmetatable(CreateFrame("Frame"):CreateTexture()).__index
function Methods:GetName() return self._name end
function Methods:SetID(id) self._id = id end
function Methods:GetID() return self._id or 0 end
function Methods:SetFrameLevel(l) self._level = l end
function Methods:GetFrameLevel() return self._level or 1 end
function Methods:SetWidth(w) self._w = w end
function Methods:SetHeight(h) self._h = h end
function Methods:GetWidth() return self._w or 300 end
function Methods:GetHeight() return self._h or 100 end
function Methods:SetPoint(...) self._point = { ... } end
function Methods:HookScript(k, fn)
    local prev = self._scripts[k]
    self._scripts[k] = function(...) if prev then prev(...) end; fn(...) end
end
function Methods:GetEffectiveScale() return 1 end
function TexMethods:SetFormattedText(fmt, ...) self._text = string.format(fmt, ...) end
function TexMethods:GetTexture() return self._tex and self._tex[1] end

local simCreateFrame = CreateFrame
_G.CreateFrame = function(ftype, name, parent, tmpl)
    local f = simCreateFrame(ftype, name, parent, tmpl)
    f._shown = true
    f._name = name
    if name then _G[name] = f end
    if tmpl == "StatFrameTemplate" and name then
        _G[name .. "Label"] = f:CreateFontString()
        local stat = simCreateFrame("Frame", name .. "Stat", f)
        stat._shown = true
        stat._name = name .. "Stat"
        _G[name .. "Stat"] = stat
        _G[name .. "StatText"] = stat:CreateFontString()
    elseif (tmpl == "UIPanelScrollFrameTemplate" or tmpl == "FauxScrollFrameTemplate") and name then
        local bar = simCreateFrame("Slider", name .. "ScrollBar", f)
        bar._name = name .. "ScrollBar"
        _G[name .. "ScrollBar"] = bar
    end
    return f
end

_G.hooksecurefunc = function(a, b, c)
    if type(a) == "table" then
        local orig = a[b]
        a[b] = function(...) orig(...); c(...) end
    else
        local orig = _G[a]
        _G[a] = function(...) orig(...); b(...) end
    end
end

-- ---------------------------------------------------------------------------
-- Stock globals
-- ---------------------------------------------------------------------------
_G.UIParent = CreateFrame("Frame", "UIParent")
_G.GameTooltip = CreateFrame("GameTooltip", "GameTooltip")
for _, n in ipairs({ "GameFontNormal", "GameFontHighlight", "GameFontNormalSmall", "GameFontHighlightSmall",
                     "GameFontNormalLarge", "NumberFontNormalSmall" }) do
    _G[n] = { GetFont = function() return "font", 16, "" end }
end
_G.GetCursorPosition = function() return 0, 0 end
_G.PlaySound = function() end
_G.UpdateUIPanelPositions = function() end
_G.UIPanelWindows = { CharacterFrame = { area = "left", pushable = 3 } }
_G.FramePositionDelegate = { UpdateUIPanelPositions = function() end }
function Methods:GetLeft() return self._left or 0 end
function Methods:GetTop() return self._top or 0 end
_G.GameFontDisableSmall = { GetFont = function() return "font", 10, "" end }
_G.SetPortraitTexture = function() end
_G.strtrim = function(s) return (s:gsub("^%s+", ""):gsub("%s+$", "")) end
_G.UnitLevel = function() return 80 end
_G.UnitRace = function() return "Night Elf", "NightElf" end
_G.UnitClass = function() return "Warrior", "WARRIOR" end
_G.UnitFactionGroup = function() return "Alliance", "Alliance" end
_G.GetGuildInfo = function() return "Dark Chaos", "Member" end
_G.RAID_CLASS_COLORS = { WARRIOR = { r = 0.78, g = 0.61, b = 0.43 } }
_G.PLAYER_LEVEL = "Level %s %s %s"
_G.GUILD_TITLE_TEMPLATE = "%s of %s"
_G.STAT_FORMAT = "%s:"
for _, n in ipairs({ "RED_FONT_COLOR_CODE", "GREEN_FONT_COLOR_CODE", "HIGHLIGHT_FONT_COLOR_CODE", "GRAY_FONT_COLOR_CODE",
                     "NORMAL_FONT_COLOR_CODE" }) do _G[n] = "|cffffffff" end
_G.FONT_COLOR_CODE_CLOSE = "|r"
_G.PAPERDOLLFRAME_TOOLTIP_FORMAT = "%s"
_G.RESISTANCE_TOOLTIP_SUBTEXT = "%s %d %s"
for i = 2, 6 do _G["SPELL_SCHOOL" .. i .. "_CAP"] = "School" .. i; _G["RESISTANCE" .. i .. "_NAME"] = "Res" .. i; _G["RESISTANCE_TYPE" .. i] = "type" .. i end
_G.RESISTANCE_NONE, _G.RESISTANCE_POOR, _G.RESISTANCE_FAIR, _G.RESISTANCE_GOOD, _G.RESISTANCE_VERYGOOD, _G.RESISTANCE_EXCELLENT = "n", "p", "f", "g", "v", "e"
_G.PLAYER_TITLE_NONE = "None"
_G.EQUIPSET_EQUIP, _G.SAVE, _G.DELETE, _G.ACCEPT, _G.CANCEL, _G.EQUIPMENT_MANAGER = "Equip", "Save", "Delete", "Accept", "Cancel", "Equipment Manager"
_G.MAX_EQUIPMENT_SETS_PER_PLAYER = 10
_G.ITEM_QUALITY_COLORS = { [4] = { r = 0.64, g = 0.21, b = 0.93, hex = "|cffa335ee" } }
_G.UnitHasRelicSlot = function() return false end
_G.UnitResistance = function() return 0, 10, 5, 0 end
_G.GetCombatRating = function(cr) return cr * 10 end
_G.GetCombatRatingBonus = function(cr) return (cr == 6) and 7.5 or 2.5 end   -- melee hit 7.5%
_G.GetDodgeChance = function() return 10 end
_G.GetParryChance = function() return 5 end
_G.GetShieldBlock = function() return 1234 end
_G.GetUnitSpeed = function() return 7 * 1.6 end
_G.UnitHasMana = function() return true end
_G.GetManaRegen = function() return 10, 4 end
_G.NOT_APPLICABLE = "N/A"

local SLOT_IDS = {
    HeadSlot = 1, NeckSlot = 2, ShoulderSlot = 3, ShirtSlot = 4, ChestSlot = 5, WaistSlot = 6, LegsSlot = 7, FeetSlot = 8,
    WristSlot = 9, HandsSlot = 10, Finger0Slot = 11, Finger1Slot = 12, Trinket0Slot = 13, Trinket1Slot = 14,
    BackSlot = 15, MainHandSlot = 16, SecondaryHandSlot = 17, RangedSlot = 18, TabardSlot = 19, AmmoSlot = 0,
}
_G.GetInventorySlotInfo = function(key) return SLOT_IDS[key], "Interface\\Paperdoll\\" .. key end
local ammoEquipped = false
_G.GetInventoryItemLink = function(_, id)
    if id == 0 then return ammoEquipped and "item:2000" or nil end
    if id == 4 or id == 17 or id == 19 then return nil end   -- shirt, off hand, tabard empty
    return "|Hitem:" .. (1000 + id) .. ":0|h[Item " .. id .. "]|h"
end
_G.GetInventoryItemTexture = function(_, id)
    if id == 0 then return ammoEquipped and "ammo" or nil end
    if id == 4 or id == 17 or id == 19 then return nil end
    return "Interface\\Icons\\Item" .. id
end
_G.GetInventoryItemQuality = function() return 4 end
_G.GetInventoryItemID = function(_, id) return 1000 + id end
_G.GetItemInfo = function(link)
    local id = tonumber(string.match(link, "item:(%d+)")) or 0
    local loc = (id == 1016) and "INVTYPE_2HWEAPON" or "INVTYPE_HEAD"
    return "Item " .. id, link, 4, 200, 80, "Armor", "Plate", 1, loc, "Interface\\Icons\\Item"
end

-- Titles
_G.GetNumTitles = function() return 3 end
_G.IsTitleKnown = function(i) return (i <= 2) and 1 or 0 end
_G.GetTitleName = function(i) return "Title" .. i end
_G.GetCurrentTitle = function() return 2 end
local setTitle
_G.SetCurrentTitle = function(id) setTitle = id end

-- Equipment sets
local equipped, savedSet
_G.GetNumEquipmentSets = function() return 2 end
_G.GetEquipmentSetInfo = function(i) return "Set" .. i, "Interface\\Icons\\Set" .. i end
_G.GetEquipmentSetInfoByName = function(n) return (n == "Set1" or n == "Set2") and n or nil end
_G.EquipmentManager_EquipSet = function(n) equipped = n end
_G.SaveEquipmentSet = function(n) savedSet = n end

-- Popups, dropdown, scrolling
_G.StaticPopupDialogs = {}
local shownPopups = {}
_G.StaticPopup_Show = function(which, a1, a2, data)
    table.insert(shownPopups, { which = which, a1 = a1, data = data })
    local dialog = CreateFrame("Frame", "StaticPopup1")
    dialog.data = data
    _G["StaticPopup1EditBox"] = CreateFrame("EditBox", "StaticPopup1EditBox", dialog)
    return dialog
end
local menuButtons = {}
_G.UIDropDownMenu_CreateInfo = function() return {} end
_G.UIDropDownMenu_AddButton = function(info, level) table.insert(menuButtons, { info = info, level = level }) end
_G.UIDropDownMenu_Initialize = function(frame, fn) frame._init = fn end
_G.UIDropDownMenu_SetWidth = function() end
_G.UIDropDownMenu_SetText = function(frame, text) frame._ddtext = text end
_G.FauxScrollFrame_Update = function() end
_G.FauxScrollFrame_GetOffset = function() return 0 end
_G.FauxScrollFrame_OnVerticalScroll = function() end
_G.ScrollFrameTemplate_OnMouseWheel = function() end

-- Stock character frame
_G.CharacterFrame = CreateFrame("Frame", "CharacterFrame", UIParent)
CharacterFrame._level = 5
_G.PaperDollFrame = CreateFrame("Frame", "PaperDollFrame", CharacterFrame)
PaperDollFrame._level = 6
_G.ReputationFrame = CreateFrame("Frame", "ReputationFrame", CharacterFrame)
ReputationFrame:Hide()
_G.CharacterFramePortrait = CharacterFrame:CreateTexture()
_G.CharacterNameFrame = CreateFrame("Frame", "CharacterNameFrame", CharacterFrame)
_G.CharacterNameText = CharacterNameFrame:CreateFontString()
_G.CharacterFrameCloseButton = CreateFrame("Button", "CharacterFrameCloseButton", CharacterFrame)
_G.CharacterFrameTab1 = CreateFrame("Button", "CharacterFrameTab1", CharacterFrame)
_G.CharacterLevelText = PaperDollFrame:CreateFontString()
_G.CharacterGuildText = PaperDollFrame:CreateFontString()
_G.CharacterModelFrame = CreateFrame("PlayerModel", "CharacterModelFrame", PaperDollFrame)
_G.CharacterModelFrameRotateLeftButton = CreateFrame("Button", "CharacterModelFrameRotateLeftButton", CharacterModelFrame)
_G.CharacterModelFrameRotateRightButton = CreateFrame("Button", "CharacterModelFrameRotateRightButton", CharacterModelFrame)
for key, id in pairs(SLOT_IDS) do
    local b = CreateFrame("Button", "Character" .. key, PaperDollFrame)
    b:SetID(id)
end
_G.CharacterAttributesFrame = CreateFrame("Frame", "CharacterAttributesFrame", PaperDollFrame)
_G.GearManagerDialog = CreateFrame("Frame", "GearManagerDialog", PaperDollFrame)

_G.CharacterFrame_ShowSubFrame = function(name)
    for _, n in ipairs({ "PaperDollFrame", "ReputationFrame" }) do
        if n == name then _G[n]:Show() else _G[n]:Hide() end
    end
end
_G.PaperDollFrame_SetLevel = function() end
_G.PaperDollFrame_UpdateStats = function() end
_G.PaperDollItemSlotButton_Update = function() end
_G.PaperDollStatTooltip = function() end
for _, n in ipairs({ "CharacterDamageFrame_OnEnter", "CharacterRangedDamageFrame_OnEnter",
                     "CharacterSpellBonusDamage_OnEnter", "CharacterSpellCritChance_OnEnter" }) do
    _G[n] = function() end
end
local setterCalls = {}
for _, n in ipairs({ "SetStat", "SetArmor", "SetDamage", "SetAttackSpeed", "SetAttackPower", "SetRating",
                     "SetMeleeCritChance", "SetExpertise", "SetRangedDamage", "SetRangedAttackSpeed",
                     "SetRangedAttackPower", "SetRangedCritChance", "SetSpellBonusDamage", "SetSpellBonusHealing",
                     "SetSpellCritChance", "SetSpellHaste", "SetManaRegen", "SetSpellPenetration", "SetDefense",
                     "SetDodge", "SetParry", "SetBlock", "SetResilience" }) do
    _G["PaperDollFrame_" .. n] = function(frame)
        setterCalls[n] = (setterCalls[n] or 0) + 1
        _G[frame:GetName() .. "Label"]:SetText(n)
        _G[frame:GetName() .. "StatText"]:SetText("1")
    end
end

-- Legacy buttons that must be retired.
for _, n in ipairs({ "DC_ItemUpgrade_CharFrameButton", "DC_ItemUpgrade_HeirloomButton", "DC_Collection_CharFrameButton" }) do
    CreateFrame("Button", n, CharacterFrame)
end

-- DC-ItemUpgrade stub
local toggled, selectedSlot = {}, nil
_G.DarkChaos_ItemUpgrade = {
    BAG_EQUIPPED = 255,
    IsHeirloomItemId = function(id) return id == 1002 end,
    ToggleUpgradeFrame = function(mode) table.insert(toggled, mode); return true end,
}
_G.DarkChaos_ItemUpgradeFrame = CreateFrame("Frame", "DarkChaos_ItemUpgradeFrame")
DarkChaos_ItemUpgradeFrame:Hide()
_G.DarkChaos_ItemUpgrade_GetCachedDataForLocation = function(bag, slot)
    if bag == 255 and slot == 0 then
        return { currentUpgrade = 3, maxUpgrade = 10, upgradedItemLevel = 220, baseItemLevel = 200, tier = 1 }
    end
end
_G.DarkChaos_ItemUpgrade_SelectItemBySlot = function(bag, slot) selectedSlot = { bag, slot } end
_G.DarkChaos_ItemUpgrade_HandleJsonItemInfo = function() end

-- DC-Collection stub
local requests, loaded, savedOutfits, deleted = {}, {}, {}, {}
local DC = { db = {}, transmogState = {} }
_G.DCCollection = DC
function DC:IsProtocolReady() return true end
function DC:OnMsg_SavedOutfits() end
function DC:HandleTransmogState() end
function DC:RequestTransmogState() DC.stateRequested = true end
function DC:ShowMainFrame() DC.mainShown = true end
function DC:SelectTab(tab) DC.tab = tab end
DC.Protocol = {
    RequestSavedOutfitsPage = function(_, offset, limit) table.insert(requests, { offset, limit }) end,
    SaveOutfit = function(_, id, name, icon, slots) table.insert(savedOutfits, { id = id, name = name }) end,
    DeleteOutfit = function(_, id) table.insert(deleted, id) end,
}
DC.Wardrobe = {
    EQUIPMENT_SLOTS = { { key = "HeadSlot" }, { key = "ChestSlot" }, { key = "MainHandSlot" } },
    LoadOutfit = function(_, outfit) table.insert(loaded, outfit.name) end,
    SaveCurrentOutfit = function(_, name, id) table.insert(savedOutfits, { id = id or 0, name = name, current = true }) end,
}

-- ---------------------------------------------------------------------------
-- Load the addon and log in
-- ---------------------------------------------------------------------------
local before = frameCount
for _, f in ipairs({ "Core.lua", "Chrome.lua", "Stats.lua", "Sidebar.lua", "Outfits.lua", "Upgrades.lua" }) do
    dofile(ADDON .. f)
end
local DCCF = DCCharacterFrame
ok(DCCF and #DCCF.sidebars == 4, "four sidebar panes registered (stats, titles, sets, upgrades)")

-- Fire PLAYER_LOGIN on the addon's event frame. wowsim keeps its frame list in
-- an upvalue of advance(); the Core event frame is the only unnamed, parentless
-- frame with an OnEvent script.
local fired = 0
local eventFrames = {}
local i = 1
while true do
    local n, v = debug.getupvalue(_G.advance, i)
    if not n then break end
    if n == "frames" then eventFrames = v end
    i = i + 1
end
for _, f in ipairs(eventFrames) do
    if f._scripts.OnEvent and not f._name and f._parent == nil then
        f._scripts.OnEvent(f, "PLAYER_LOGIN")
        fired = fired + 1
    end
end
ok(fired >= 1, "PLAYER_LOGIN dispatched to the addon event frame")
ok(DCCF.chrome and DCCF.inset and DCCF.insetRight and DCCF.modelBg, "chrome, insets and model backdrop built")
ok(DCCF.mode == "retail" and CharacterFrame._w == DCCF.RETAIL_WIDTH and CharacterFrame._h == 424, "paperdoll tab uses the retail geometry")
ok(CharacterFramePortrait._shown == false, "stock portrait hidden behind the chrome ring")
ok(CharacterLevelText._text and CharacterLevelText._text:find("Night Elf") and CharacterLevelText._text:find("Warrior"),
    "level line shows race and class-coloured class: " .. tostring(CharacterLevelText._text))
ok(CharacterGuildText._text == "Member of Dark Chaos", "guild line rendered")
ok(CharacterLevelText._point and CharacterLevelText._point[3] == "TOPLEFT" and CharacterLevelText._point[4] == 168,
    "header centred over the left inset, clear of the sidebar tabs")

-- Legacy buttons
local retired = true
for _, n in ipairs({ "DC_ItemUpgrade_CharFrameButton", "DC_ItemUpgrade_HeirloomButton", "DC_Collection_CharFrameButton" }) do
    _G[n]:Show()
    if _G[n]._shown ~= false then retired = false end
end
ok(retired, "legacy item-upgrade / collection buttons are hidden and stay hidden after Show()")

-- Weapon row / ammo
ok(CharacterAmmoSlot._shown == false and CharacterMainHandSlot._point[4] == 104, "no ammo: ammo slot hidden, weapon row centred (x=104)")
ammoEquipped = true
DCCF:UpdateWeaponRow()
ok(CharacterAmmoSlot._shown == true and CharacterMainHandSlot._point[4] == 83, "ammo equipped: slot shown, weapon row shifts left (x=83)")
ammoEquipped = false
DCCF:UpdateWeaponRow()

-- Tab switching
CharacterFrame_ShowSubFrame("ReputationFrame")
ok(DCCF.mode == "stock" and CharacterFrame._w == 384 and CharacterFrame._h == 512 and CharacterFramePortrait._shown == true,
    "reputation tab restores the stock 384x512 frame and portrait")
CharacterFrame_ShowSubFrame("PaperDollFrame")
ok(DCCF.mode == "retail" and CharacterFrame._w == DCCF.RETAIL_WIDTH, "back to the character tab restores retail geometry")

-- Stats pane
local pane = DCCF.statsPane
ok(pane and tostring(pane.ilvlValue._text) == "201", "average item level rounds to 201 (got " .. tostring(pane and pane.ilvlValue._text) .. ")")
-- A character saved under the old per-class defaults (rogue: ranged/spell/resist
-- collapsed) is migrated to "everything expanded" once.
DCCF.db.collapsedStats = { spell = true, ranged = true, resist = true }
DCCF.db.statsLayoutVersion = nil
DCCF:LayoutStats()
local c = DCCF.db.collapsedStats
ok(next(c) == nil and DCCF.db.statsLayoutVersion == 2, "old class-default collapse state is cleared: every category starts expanded")
local function CategoryRows(key)
    for _, entry in ipairs(pane.categories) do if entry.def.key == key then return entry end end
end
local allShown = true
for _, key in ipairs({ "attributes", "melee", "ranged", "spell", "defense", "resist" }) do
    for _, r in ipairs(CategoryRows(key).rows) do if r._shown ~= true then allShown = false end end
end
ok(allShown, "rows of every category (incl. ranged, spell, resistances) are shown")
setterCalls = {}
DCCF:UpdateStats()
ok(setterCalls.SetStat == 5 and setterCalls.SetDamage == 1 and setterCalls.SetRangedDamage == 1 and setterCalls.SetSpellHaste == 1,
    "every expanded category runs its stat setters (base, melee, ranged, spell)")
local resistRow = CategoryRows("resist").rows[1]
ok(_G[resistRow:GetName() .. "StatText"]._text ~= nil and _G[resistRow:GetName() .. "Label"]._text == "School2:",
    "resistance rows carry a label and a value")
local function RowByKind(entry, kind, arg)
    for _, r in ipairs(entry.rows) do if r.statKind == kind and (arg == nil or r.statArg == arg) then return r end end
end
local melee = CategoryRows("melee")
local hitRow = RowByKind(melee, "hit", "MELEE")
ok(_G[hitRow:GetName() .. "StatText"]._text == "7.50%" and hitRow.tooltip2:find("Hit Rating: 60")
    and hitRow.tooltip2:find("vs. boss %(%+3%): 0.50%%"), "melee hit row shows the percentage with rating and boss miss chance in the tooltip")
ok(_G[RowByKind(melee, "arp"):GetName() .. "StatText"]._text == "2.50%", "armor penetration row shows the percentage")
ok(_G[RowByKind(melee, "hastepct"):GetName() .. "StatText"]._text == "2.50%", "melee haste row shows the percentage")
local defense = CategoryRows("defense")
ok(_G[RowByKind(defense, "avoidance"):GetName() .. "StatText"]._text == "20.00%", "avoidance = dodge + parry + 5% base miss")
ok(tostring(_G[RowByKind(defense, "blockvalue"):GetName() .. "StatText"]._text) == "1234", "block value row reads GetShieldBlock")
ok(_G[RowByKind(CategoryRows("attributes"), "movespeed"):GetName() .. "StatText"]._text == "160%", "movement speed row shows 160%")
local spellHdr = CategoryRows("spell").header
spellHdr._scripts.OnClick(spellHdr)
ok(DCCF.db.collapsedStats.spell == true and CategoryRows("spell").rows[1]._shown == false, "clicking a header collapses the category and saves it")
setterCalls = {}
DCCF:UpdateStats()
ok(not setterCalls.SetSpellHaste, "a collapsed category skips its setters")
spellHdr._scripts.OnClick(spellHdr)
ok(DCCF.db.collapsedStats.spell == nil and CategoryRows("spell").rows[1]._shown == true, "clicking again expands it")
DCCF:UpdateStats()
ok((setterCalls.SetSpellHaste or 0) >= 1, "re-expanded spell category updates its rows")
local castRow = RowByKind(CategoryRows("spell"), "manaregencasting")
ok(tostring(_G[castRow:GetName() .. "StatText"]._text) == "20" and castRow.tooltip2:find("50 mana per 5 seconds while not casting"),
    "regen-while-casting row shows casting MP5 with the not-casting value in the tooltip")
-- 16 equipped items (off hand empty): upgraded head 220 + 15 x 200, plus the 2H main hand counted twice
local avg = DCCF:GetAverageItemLevel()
ok(math.abs(avg - ((220 + 15 * 200 + 200) / 17)) < 0.01, "average item level uses the upgraded level from the DC-ItemUpgrade cache and counts a 2H twice")

-- Slot badges
DCCF:UpdateAllSlotOverlays()
ok(CharacterHeadSlot.dccfLevel and tostring(CharacterHeadSlot.dccfLevel._text) == "220" and CharacterHeadSlot.dccfLevel._shown ~= false,
    "head slot badge shows upgraded item level 220")
ok(CharacterShirtSlot.dccfLevel and CharacterShirtSlot.dccfLevel._shown == false, "shirt slot carries no item level badge")
ok(CharacterHeadSlot.dccfQuality._shown ~= false, "epic item shows a quality border")

-- Titles pane
DCCF:SelectSidebar(2)
local titles = DCCF.titlesPane
ok(#titles.titles == 3 and titles.titles[1].name == "None" and titles.selected == 2, "titles: None + 2 known titles, current title selected")
ok(titles.rows[3].Check._shown == true and titles.rows[2].Check._shown == false, "check mark only on the selected title row (Title2 sorts third)")
titles.rows[3]._scripts.OnClick(titles.rows[3])
ok(setTitle == titles.rows[3].titleId, "clicking a title row sets it")

-- Equipment sets pane
DCCF.setsPane._h = 325   -- anchored pane; the sim has no layout engine
DCCF:SelectSidebar(3)
local sets = DCCF.setsPane
local setRows = sets.setsList.rows
ok(setRows[1].setName == "Set1" and setRows[2].setName == "Set2" and setRows[3]._shown == false, "equipment sets listed")
ok(sets.setsList._h == 88 and sets.emptySets._shown == false, "sets list sized to its two rows, no empty notice")
ok(sets.EquipButton._enabled == false, "equip disabled with no selection")
setRows[2]._scripts.OnClick(setRows[2])
ok(sets.selectedName == "Set2" and setRows[2].Check._shown == true, "clicking a set selects it")
sets.EquipButton._scripts.OnClick(sets.EquipButton)
ok(equipped == "Set2", "Equip button equips the selected set")
setRows[2].Delete._scripts.OnClick(setRows[2].Delete)
ok(shownPopups[#shownPopups].which == "CONFIRM_DELETE_EQUIPMENT_SET" and shownPopups[#shownPopups].a1 == "Set2", "delete asks the stock confirmation")
ok(sets.outfitList.rows[1]._shown == false and sets.emptyOutfits._text == "Loading outfits...", "outfits section waits for the server list")

-- Moving the frame
local handle = DCCF.dragHandle
ok(handle and handle._scripts.OnDragStart and handle._scripts.OnDragStop, "title bar drag handle built")
CharacterFrame._left, CharacterFrame._top = 300, 700
handle._scripts.OnDragStop(handle)
ok(DCCF.db.position and DCCF.db.position.left == 300 and DCCF.db.position.top == 700, "dragging remembers the frame position")
CharacterFrame._point = nil
FramePositionDelegate.UpdateUIPanelPositions()
ok(CharacterFrame._point and CharacterFrame._point[1] == "TOPLEFT" and CharacterFrame._point[4] == 300 and CharacterFrame._point[5] == 700,
    "UI panel re-layout puts the frame back where it was dragged")
handle._scripts.OnMouseUp(handle, "RightButton")
ok(DCCF.db.position == nil, "right-click on the title bar resets the position")
ok(UIPanelWindows.CharacterFrame.xoffset == 16, "retail mode offsets the panel so the portrait ring stays on screen")
CharacterFrame_ShowSubFrame("ReputationFrame")
ok(UIPanelWindows.CharacterFrame.xoffset == 0, "stock tabs use the stock panel offset")
CharacterFrame_ShowSubFrame("PaperDollFrame")

-- Upgrades pane
DCCF:SelectSidebar(4)
local up = DCCF.upgradesPane
ok(up.rows[1].slotId == 1 and up.rows[1].Progress._text:find("3/10") and tostring(up.rows[1].Level._text) == "220", "head row shows 3/10 upgrades and level 220")
ok(up.rows[2].isHeirloom == true and up.rows[2].Progress._text:find("HL"), "neck (heirloom id) flagged as heirloom")
up.rows[2]._scripts.OnClick(up.rows[2])
ok(toggled[#toggled] == "HEIRLOOM" and selectedSlot and selectedSlot[1] == 255 and selectedSlot[2] == 2,
    "clicking the heirloom row opens the heirloom window on slot 2")
up.rows[1]._scripts.OnClick(up.rows[1])
ok(toggled[#toggled] == "STANDARD" and selectedSlot[2] == 1, "clicking a normal row opens the standard window on that slot")

-- Outfits
ok(#requests >= 1 and requests[1][1] == 0 and requests[1][2] == 50, "opening the panel requests the full outfit list (offset 0, limit 50)")
ok(DC.stateRequested, "transmog state requested when unknown")
DC.db.outfits = {
    { id = 7, name = "Zeta", icon = "Interface/Icons/A", slots = { HeadSlot = 111, ChestSlot = 222 } },
    { id = 3, name = "Alpha", icon = "Interface/Icons/B", items = '{"HeadSlot":333}', slots = '{"HeadSlot":333}' },
}
DC.db.outfitsOffset, DC.db.outfitsLimit, DC.db.outfitsTotal = 0, 50, 2
DC:OnMsg_SavedOutfits({})
local O = DCCF.Outfits
ok(#O.list == 2 and O.list[1].name == "Alpha" and O.list[2].name == "Zeta", "outfits merged and sorted by name")
ok(O.byId[3].slots.HeadSlot == 333, "string-encoded slot payload parsed")
ok(O.loaded and not O.fetching, "listing complete after one page")
ok(DCCF.outfitDropDown._ddtext:find("No Outfit"), "no transmog applied -> dropdown shows No Outfit")
DCCF:SelectSidebar(3)
local outfitRows = sets.outfitList.rows
ok(outfitRows[1].Text._text == "Alpha" and outfitRows[2].Text._text == "Zeta" and outfitRows[3]._shown == false
    and sets.emptyOutfits._shown == false, "equipment manager pane lists the saved outfits")
outfitRows[2]._scripts.OnClick(outfitRows[2])
ok(loaded[#loaded] == "Zeta", "clicking an outfit row applies it")
DCCF.db.selectedOutfitId = 0   -- back to "nothing selected" for the checks below
DCCF:RefreshOutfits()
outfitRows[1].Delete._scripts.OnClick(outfitRows[1].Delete)
ok(shownPopups[#shownPopups].which == "DCCF_OUTFIT_DELETE" and shownPopups[#shownPopups].data == 3, "outfit row delete asks for confirmation")
sets.NewOutfitButton._scripts.OnClick(sets.NewOutfitButton)
ok(shownPopups[#shownPopups].which == "DCCF_OUTFIT_NAME", "+ button opens the new-outfit prompt")
ok(DCCF.outfitSaveButton._enabled == false, "save disabled without a selection")

DC.transmogState = { ["0"] = 111, ["4"] = 222 }   -- head (eq 0) + chest (eq 4) = Zeta
DC:HandleTransmogState({})
ok(DCCF.outfitDropDown._ddtext == "Zeta" and DCCF.db.selectedOutfitId == 7, "current look auto-selects the matching outfit")
ok(outfitRows[2].Check._shown == true and outfitRows[1].Check._shown == false, "equipment manager pane ticks the worn outfit")
ok(DCCF.outfitSaveButton._enabled == false, "matching look: nothing to save")
DC.transmogState = { ["0"] = 111, ["4"] = 999 }
DC:HandleTransmogState({})
ok(DCCF.outfitDropDown._ddtext:find("Zeta") and DCCF.outfitDropDown._ddtext:find("%*"), "drifted look marks the selected outfit as modified")
ok(DCCF.outfitSaveButton._enabled == true, "modified look enables Save")
DCCF.outfitSaveButton._scripts.OnClick(DCCF.outfitSaveButton)
ok(savedOutfits[#savedOutfits].name == "Zeta" and savedOutfits[#savedOutfits].id == 7, "Save overwrites the selected outfit through the wardrobe")

menuButtons = {}
DCCF.outfitDropDown._init(DCCF.outfitDropDown, 1)
ok(#menuButtons == 4 and menuButtons[1].info.text == "Alpha" and menuButtons[2].info.text == "Zeta"
    and menuButtons[3].info.text:find("New Outfit") and menuButtons[4].info.text == "Open Wardrobe",
    "level-1 menu: outfits, New Outfit..., Open Wardrobe")
ok(menuButtons[2].info.hasArrow == 1 and menuButtons[2].info.icon == "Interface/Icons/A", "outfit entries carry icon and submenu arrow")
menuButtons[1].info.func()
ok(loaded[#loaded] == "Alpha" and DCCF.db.selectedOutfitId == 3, "clicking an outfit applies it via the wardrobe loader and selects it")
menuButtons = {}
_G.UIDROPDOWNMENU_MENU_VALUE = 3
DCCF.outfitDropDown._init(DCCF.outfitDropDown, 2)
ok(#menuButtons == 5 and menuButtons[1].info.isTitle == 1 and menuButtons[5].info.text:find("Delete"), "level-2 menu: title, apply, overwrite, rename, delete")
menuButtons[5].info.func()
ok(shownPopups[#shownPopups].which == "DCCF_OUTFIT_DELETE" and shownPopups[#shownPopups].data == 3, "delete asks for confirmation with the outfit id")
StaticPopupDialogs["DCCF_OUTFIT_DELETE"].OnAccept({ data = 3 })
ok(deleted[1] == 3 and O.byId[3] == nil and DCCF.db.selectedOutfitId == 0, "confirmed delete removes the outfit and clears the selection")
menuButtons = {}
DCCF.outfitDropDown._init(DCCF.outfitDropDown, 1)
menuButtons[2].info.func()   -- New Outfit...
local dlg = shownPopups[#shownPopups]
ok(dlg.which == "DCCF_OUTFIT_NAME", "New Outfit opens the name popup")
StaticPopup1EditBox._text = " Raid Look "
StaticPopupDialogs["DCCF_OUTFIT_NAME"].OnAccept({ GetName = function() return "StaticPopup1" end, data = dlg.data })
ok(savedOutfits[#savedOutfits].name == "Raid Look" and savedOutfits[#savedOutfits].current and O.pendingSelectName == "Raid Look",
    "naming saves the current look and remembers it for selection")
menuButtons = {}
DCCF.outfitDropDown._init(DCCF.outfitDropDown, 1)
menuButtons[#menuButtons].info.func()
ok(DC.mainShown and DC.tab == "wardrobe", "Open Wardrobe opens the collection on the wardrobe tab")

print(string.format("RESULT %d passed, %d failed", pass, fail))
os.exit(fail == 0 and 0 or 1)
