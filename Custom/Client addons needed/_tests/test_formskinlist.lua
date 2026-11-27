-- Forms tab skin list (DC-Collection/UI/FormFrame.lua).
--
-- Stock FauxScrollFrame_Update hides the scroll frame ITSELF when every item fits
-- (numItems <= numToDisplay). The skin rows used to be children of that scroll frame,
-- so short lists vanished with it: Voidwalker (6 skins) and Succubus (5) showed an
-- empty pane while Metamorphosis (26) and Cat (104) were fine. Visibility here is
-- judged the way the client does, through the whole parent chain.

dofile("wowsim.lua")
local ROOT = [[K:\Dark-Chaos\DarkChaos-255-Master\Custom\Client addons needed\]]
local SRC = os.getenv("DC_FORMFRAME_FILE") or (ROOT .. [[DC-Collection\UI\FormFrame.lua]])

local pass, fail = 0, 0
local function ok(c, m)
    if c then pass = pass + 1; print("  PASS " .. m)
    else fail = fail + 1; print("  FAIL " .. m) end
end

local FrameMethods = getmetatable(CreateFrame("Frame")).__index
function FrameMethods:SetFrameLevel(l) self._level = l end
function FrameMethods:GetFrameLevel() return self._level or 1 end
function FrameMethods:GetHeight() return self._height or 0 end

-- Stock 3.3.5 behaviour (FrameXML/UIPanelTemplates.lua), reduced to the visibility part.
_G.FauxScrollFrame_Update = function(frame, numItems, numToDisplay)
    if numItems > numToDisplay then
        frame:Show()
    else
        frame:Hide()
    end
end
_G.FauxScrollFrame_GetOffset = function() return 0 end
_G.FauxScrollFrame_OnVerticalScroll = function() end
_G.GetCursorPosition = function() return 0, 0 end

local forms = {}
_G.DCCollection = {
    L = {},
    FormModule = {
        GetForm = function(_, id) return forms[id] end,
        GetForms = function() return {} end,
        ResetForm = function() end,
    },
}
dofile(SRC)
local DC = _G.DCCollection
local Forms = DC.Forms

local function skins(n)
    local t = {}
    for i = 1, n do t[i] = { model = 508180 + i, name = "Skin " .. i, unlocked = true } end
    return t
end
forms[251] = { form = 251, name = "Voidwalker", skins = skins(6) }
forms[252] = { form = 252, name = "Succubus", skins = skins(5) }
forms[22] = { form = 22, name = "Metamorphosis", skins = skins(26) }

local function visible(f)
    while f do
        if not f._shown then return false end
        f = f._parent
    end
    return true
end

local host = CreateFrame("Frame")
host:Show()
local frame = Forms:Build(host)
frame:Show()
frame.skinScroll:Show()

local function shownRows()
    local n = 0
    for _, row in ipairs(frame.skinRows) do
        if visible(row) then n = n + 1 end
    end
    return n
end

print("short lists (every row fits)")
Forms.selectedForm = 251
Forms:RefreshSkins()
ok(not frame.skinScroll._shown, "the scroll frame hides itself for 6 skins (stock behaviour)")
ok(shownRows() == 6, "Voidwalker shows all 6 skin rows (got " .. shownRows() .. ")")
Forms.selectedForm = 252
Forms:RefreshSkins()
ok(shownRows() == 5, "Succubus shows all 5 skin rows (got " .. shownRows() .. ")")

print("long list (scrolls)")
Forms.selectedForm = 22
Forms:RefreshSkins()
ok(frame.skinScroll._shown, "the scroll frame shows for 26 skins")
ok(shownRows() == #frame.skinRows and shownRows() > 0, "Metamorphosis fills every row (got " .. shownRows() .. ")")

print("back to a short list")
Forms.selectedForm = 252
Forms:RefreshSkins()
ok(shownRows() == 5, "rows past the 5 skins are hidden again (got " .. shownRows() .. ")")

print("rows sit above the scroll frame")
ok(frame.skinRows[1]:GetFrameLevel() > frame.skinScroll:GetFrameLevel(), "row frame level above the scroll frame")

print(string.format("RESULT: %d passed, %d failed", pass, fail))
if fail > 0 then os.exit(1) end
