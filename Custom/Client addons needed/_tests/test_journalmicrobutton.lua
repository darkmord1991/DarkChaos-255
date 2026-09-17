-- Adventure Journal micro button slot (DC-Journal/.../EncounterJournal_MicroButton.lua).
--
-- The journal button is inserted between Quest Log and Socials. Stock
-- VehicleMenuBar_MoveMicroButtons runs every time the main bar comes back from a
-- vehicle or possess bar and re-anchors Socials straight to Quest Log, which laid
-- Socials over the journal button (the journal "became" Social) and pulled the rest
-- of the bar back by one slot.
dofile("wowsim.lua")
local ROOT = os.getenv("DC_JOURNAL_ROOT") or [[K:\Dark-Chaos\DarkChaos-255-Master\Custom\Client addons needed\]]
local FILE = os.getenv("DC_JOURNAL_MICROBUTTON_FILE")
    or (ROOT .. [[DC-Journal\Interface\FrameXML\EncounterJournal_MicroButton.lua]])
local pass, fail = 0, 0
local function ok(c, m) if c then pass=pass+1; print("  PASS "..m) else fail=fail+1; print("  FAIL "..m) end end

-- Anchors are what this test is about, so record them instead of the no-op stub.
local Methods = getmetatable(CreateFrame("Frame")).__index
function Methods:SetPoint(point, rel, relPoint, x, y) self._point = {point, rel, relPoint, x, y} end
function Methods:ClearAllPoints() self._point = nil end

local simCreateFrame = CreateFrame
_G.hooksecurefunc = function(name, hook)
    local orig = _G[name]
    _G[name] = function(...) orig(...); hook(...) end
end
_G.MicroButtonTooltipText = function(text) return text end
_G.UpdateMicroButtons = function() end
_G.UpdateTalentButton = function() end

local STOCK = {
    "CharacterMicroButton", "SpellbookMicroButton", "TalentMicroButton", "AchievementMicroButton",
    "QuestLogMicroButton", "SocialsMicroButton", "PVPMicroButton", "LFGMicroButton",
    "MainMenuMicroButton", "HelpMicroButton",
}
local ALL = {}
for _, n in ipairs(STOCK) do ALL[#ALL + 1] = n end
ALL[#ALL + 1] = "EncounterJournalMicroButton"

-- Fresh client: stock micro buttons anchored as MainMenuBarMicroButtons.xml has them,
-- plus the stock vehicle mover, then the addon file and PLAYER_LOGIN.
local function boot(skinAtLogin)
    for _, n in ipairs(ALL) do _G[n] = nil end
    _G.EncounterJournalMicroButtonHooked = nil
    _G.MainMenuBarArtFrame = simCreateFrame("Frame")
    _G.VehicleMenuBar = simCreateFrame("Frame")
    _G.VehicleMenuBarArtFrame = simCreateFrame("Frame")

    local created = {}
    _G.CreateFrame = function(ftype, name, parent, tmpl)
        local f = simCreateFrame(ftype, name, parent, tmpl)
        f._shown = true -- the client creates frames shown; wowsim starts them hidden
        if name then _G[name] = f end
        created[#created + 1] = f
        return f
    end

    local prev
    for _, n in ipairs(STOCK) do
        local b = CreateFrame("Button", n, MainMenuBarArtFrame)
        b:Show()
        if prev then b:SetPoint("BOTTOMLEFT", prev, "BOTTOMRIGHT", -3, 0) else b:SetPoint("BOTTOMLEFT", 552, 2) end
        prev = b
    end

    -- FrameXML/VehicleMenuBar.lua (3.3.5a), VehicleMenuBar_MoveMicroButtons.
    local MicroButtons = {}
    for _, n in ipairs(STOCK) do MicroButtons[#MicroButtons + 1] = _G[n] end
    _G.VehicleMenuBar_MoveMicroButtons = function(skinName)
        if not skinName then
            for _, frame in pairs(MicroButtons) do
                frame:SetParent(MainMenuBarArtFrame)
                frame:Show()
            end
            CharacterMicroButton:ClearAllPoints()
            CharacterMicroButton:SetPoint("BOTTOMLEFT", 552, 2)
            SocialsMicroButton:ClearAllPoints()
            SocialsMicroButton:SetPoint("BOTTOMLEFT", QuestLogMicroButton, "BOTTOMRIGHT", -3, 0)
            UpdateTalentButton()
        else
            for _, frame in pairs(MicroButtons) do
                frame:SetParent(VehicleMenuBarArtFrame)
                frame:Show()
            end
            CharacterMicroButton:ClearAllPoints()
            CharacterMicroButton:SetPoint("BOTTOMLEFT", VehicleMenuBar, "BOTTOMRIGHT", -340, 41)
            SocialsMicroButton:ClearAllPoints()
            SocialsMicroButton:SetPoint("TOPLEFT", CharacterMicroButton, "BOTTOMLEFT", 0, 20)
            UpdateTalentButton()
        end
    end

    if skinAtLogin then
        VehicleMenuBar.currSkin = skinAtLogin
        VehicleMenuBar_MoveMicroButtons(skinAtLogin)
    end

    local first = #created + 1
    dofile(FILE)
    for i = first, #created do
        local f = created[i]
        if f._scripts.OnEvent then f._scripts.OnEvent(f, "PLAYER_LOGIN") end
    end
end

-- Walks the BOTTOMLEFT->BOTTOMRIGHT chain from a button. Returns the row as a string,
-- or nil plus the name of the button that has two buttons sitting in its next slot.
local function row(from)
    local order, cur = {from}, _G[from]
    while true do
        local found = {}
        for _, n in ipairs(ALL) do
            local p = _G[n] and _G[n]._point
            if p and p[1] == "BOTTOMLEFT" and p[2] == cur and p[3] == "BOTTOMRIGHT" then found[#found + 1] = n end
        end
        if #found > 1 then return nil, order[#order] end
        if #found == 0 then return table.concat(order, " ") end
        order[#order + 1] = found[1]
        cur = _G[found[1]]
    end
end

local FLAT = "CharacterMicroButton SpellbookMicroButton TalentMicroButton AchievementMicroButton QuestLogMicroButton "
    .. "EncounterJournalMicroButton SocialsMicroButton PVPMicroButton LFGMicroButton MainMenuMicroButton HelpMicroButton"
local VEHICLE_TOP = "CharacterMicroButton SpellbookMicroButton TalentMicroButton AchievementMicroButton "
    .. "QuestLogMicroButton EncounterJournalMicroButton"
local VEHICLE_BOTTOM = "SocialsMicroButton PVPMicroButton LFGMicroButton MainMenuMicroButton HelpMicroButton"

local function flatOk(label)
    local r, overlap = row("CharacterMicroButton")
    ok(r == FLAT, label .. (overlap and ("  <-- two buttons share the slot after " .. overlap) or ""))
    ok(EncounterJournalMicroButton:GetParent() == MainMenuBarArtFrame and EncounterJournalMicroButton:IsShown(),
        label .. ": journal button is on the main bar and shown")
end

local function vehicleOk(label)
    ok(row("CharacterMicroButton") == VEHICLE_TOP, label .. ": journal button ends the top row")
    local s = SocialsMicroButton._point
    ok(s and s[1] == "TOPLEFT" and s[2] == CharacterMicroButton and row("SocialsMicroButton") == VEHICLE_BOTTOM,
        label .. ": Socials still starts the stacked second row")
    ok(EncounterJournalMicroButton:GetParent() == VehicleMenuBarArtFrame and EncounterJournalMicroButton:IsShown(),
        label .. ": journal button moves onto the vehicle bar")
end

print("== Scenario A: normal login ==")
boot()
flatOk("journal sits between Quest Log and Socials after login")

print("== Scenario B: main bar restored after a vehicle / possess bar (the reported bug) ==")
VehicleMenuBar_MoveMicroButtons()
flatOk("bar order survives VehicleMenuBar_MoveMicroButtons()")

print("== Scenario C: vehicle skin ==")
VehicleMenuBar.currSkin = "Mechanical"
VehicleMenuBar_MoveMicroButtons("Mechanical")
vehicleOk("Mechanical skin")
VehicleMenuBar.currSkin = nil
VehicleMenuBar_MoveMicroButtons()
flatOk("leaving the vehicle restores the flat bar")

print("== Scenario D: login while already on a vehicle ==")
boot("Natural")
vehicleOk("logged in on a Natural skin")
VehicleMenuBar.currSkin = nil
VehicleMenuBar_MoveMicroButtons()
flatOk("leaving the vehicle after that login")

print(string.format("\nRESULT: %d passed, %d failed", pass, fail))
os.exit(fail == 0 and 0 or 1)
