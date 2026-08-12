-- =====================================================================
--  DC Portrait Capture -- a DEV TOOL, not player-facing content.
--
--  Twelve Dark Chaos bosses are original creations (Timbermaw Hold's six
--  non-Ursoc encounters, all five of Crescent Grove, and Erennius), so no
--  client anywhere ships Encounter Journal art for them -- unlike the Castle
--  Nathria set, which is a straight extract from retail.
--
--  This addon renders each of their creature display ids full-screen against
--  black, using the client's OWN portrait camera so the head framing comes out
--  the way Blizzard's portraits do, and takes one screenshot per boss. The
--  companion script turns those screenshots into the two BLPs the journal
--  wants:
--
--      make-portraits.py   ->  UI-EJ-BOSS-<Name>.blp        (128x64 banner)
--                              Portrait_model_<display>.blp (64x64 portrait)
--
--  USAGE
--      /dcp show 1        preview one entry and check the framing
--      /dcp start         capture the whole queue (screenshots land in
--                         <WoW>\Screenshots)
--      /dcp list          print the queue
--
--  The capture frame is a centred SQUARE whose side is CAPTURE_FRACTION of the
--  screen HEIGHT. Both the frame and the screenshot scale with the screen, so
--  that fraction is all make-portraits.py needs to crop the render back out --
--  no UI-scale or resolution maths on either side. Keep the two constants in
--  step if you change it.
-- =====================================================================

local CAPTURE_FRACTION = 0.8      -- must match CAPTURE_FRACTION in make-portraits.py
local DEFAULT_DELAY    = 1.5      -- seconds to let a model stream in before the shot
local SETTLE_DELAY     = 0.6      -- seconds after the shot before moving on

-- ORDER MATTERS: make-portraits.py pairs the N newest screenshots, oldest
-- first, against this list. Keep the two in the same order.
local QUEUE = {
    -- Timbermaw Hold (map 819)
    { name = "GatewardenMorthak",     display = 503739, boss = "Gatewarden Mor'thak" },
    { name = "TheSunderedChieftain",  display = 503737, boss = "The Sundered Chieftain" },
    { name = "DenMotherUrsara",       display = 23773,  boss = "Den Mother Ursara" },
    { name = "XanthirTheDefiler",     display = 503743, boss = "Xanthir the Defiler" },
    { name = "TheNightmareGivenRoot", display = 503770, boss = "The Nightmare Given Root" },
    { name = "Ursol",                 display = 503735, boss = "Ursol" },
    -- Crescent Grove (map 823)
    { name = "KeeperRanathos",        display = 503751, boss = "Keeper Ranathos" },
    { name = "GrovetenderEngryss",    display = 503737, boss = "Grovetender Engryss" },
    { name = "HighPriestessAlathea",  display = 503753, boss = "High Priestess A'lathea" },
    { name = "FenektisTheDeceiver",   display = 503747, boss = "Fenektis the Deceiver" },
    { name = "MasterRaxxieth",        display = 503755, boss = "Master Raxxieth" },
    -- Emerald Sanctum (map 824)
    { name = "Erennius",              display = 503765, boss = "Erennius" },
}

DCPortraitCaptureDB = DCPortraitCaptureDB or {}

local function Say(fmt, ...)
    DEFAULT_CHAT_FRAME:AddMessage("|cff66bbffDCP|r " .. string.format(fmt, ...))
end

-- --- tiny self-contained scheduler ------------------------------------
-- This addon must run standalone on a bare 3.3.5 client, so it does not assume
-- C_Timer exists (DC-Journal ships a polyfill, but that is a different addon).
local timers = {}
local ticker = CreateFrame("Frame")
ticker:SetScript("OnUpdate", function(_, elapsed)
    for i = #timers, 1, -1 do
        local t = timers[i]
        t.left = t.left - elapsed
        if t.left <= 0 then
            table.remove(timers, i)
            t.fn()
        end
    end
end)

local function After(delay, fn)
    timers[#timers + 1] = { left = delay, fn = fn }
end

-- --- the capture stage ------------------------------------------------
local stage = CreateFrame("Frame", "DCPortraitCaptureStage", UIParent)
stage:SetFrameStrata("FULLSCREEN_DIALOG")
stage:SetAllPoints(UIParent)
stage:Hide()

-- Solid black behind the model: it hides the rest of the UI from the shot and
-- gives make-portraits.py a clean, unambiguous background to key out.
local bg = stage:CreateTexture(nil, "BACKGROUND")
bg:SetAllPoints(stage)
bg:SetTexture(0, 0, 0, 1)

local model = CreateFrame("PlayerModel", "DCPortraitCaptureModel", stage)
model:SetFrameLevel(stage:GetFrameLevel() + 5)
model:SetPoint("CENTER", UIParent, "CENTER", 0, 0)

local label = stage:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
label:SetPoint("TOP", stage, "TOP", 0, -40)

local function SizeStage()
    local side = math.floor(GetScreenHeight() * CAPTURE_FRACTION)
    model:SetWidth(side)
    model:SetHeight(side)
end

local function Render(entry, showLabel)
    SizeStage()
    stage:Show()

    if model.ClearModel then pcall(model.ClearModel, model) end
    local ok = pcall(model.SetCreature, model, entry.display)
    if not ok then
        Say("|cffff5555could not load display %d (%s)|r", entry.display, entry.boss)
    end
    -- SetCamera(0) is the head close-up on this client -- the same framing
    -- Blizzard's Portrait_model_*.blp files use.
    pcall(model.SetCamera, model, 0)
    pcall(model.SetPosition, model, 0, 0, 0)
    pcall(model.SetFacing, model, 0)

    label:SetText(showLabel and (entry.boss .. "  (display " .. entry.display .. ")") or "")
end

-- --- the run ----------------------------------------------------------
local running, savedFormat = false, nil

local function Finish(aborted)
    running = false
    stage:Hide()
    label:SetText("")
    if savedFormat then
        SetCVar("screenshotFormat", savedFormat)
        savedFormat = nil
    end

    if aborted then
        Say("stopped.")
        return
    end

    DCPortraitCaptureDB.lastRun = {}
    for i, e in ipairs(QUEUE) do
        DCPortraitCaptureDB.lastRun[i] = e.name .. ":" .. e.display
    end

    Say("done -- %d shots in your Screenshots folder.", #QUEUE)
    Say("now run:  python make-portraits.py --count %d", #QUEUE)
end

local function Step(index)
    if not running then return end
    if index > #QUEUE then
        Finish(false)
        return
    end

    local entry = QUEUE[index]
    Say("[%d/%d] %s", index, #QUEUE, entry.boss)
    -- No label during a capture run: it would be burned into the screenshot.
    Render(entry, false)

    After(DEFAULT_DELAY, function()
        if not running then return end
        Screenshot()
        After(SETTLE_DELAY, function() Step(index + 1) end)
    end)
end

-- --- slash commands ---------------------------------------------------
SLASH_DCPORTRAIT1 = "/dcp"
SLASH_DCPORTRAIT2 = "/dcportrait"
SlashCmdList["DCPORTRAIT"] = function(msg)
    local cmd, arg = string.match(msg or "", "^(%S*)%s*(.*)$")
    cmd = string.lower(cmd or "")

    if cmd == "list" or cmd == "" then
        Say("%d entries queued:", #QUEUE)
        for i, e in ipairs(QUEUE) do
            Say("  %2d. %-26s display %d", i, e.boss, e.display)
        end
        Say("/dcp show <n> to preview, /dcp start to capture")

    elseif cmd == "show" then
        local i = tonumber(arg)
        local entry = i and QUEUE[i]
        if not entry then
            Say("usage: /dcp show <1-%d>", #QUEUE)
            return
        end
        Render(entry, true)
        Say("showing %s -- /dcp hide when done", entry.boss)

    elseif cmd == "hide" then
        stage:Hide()
        label:SetText("")

    elseif cmd == "start" then
        if running then
            Say("already running -- /dcp stop to abort")
            return
        end
        running = true
        savedFormat = GetCVar("screenshotFormat")
        -- TGA is lossless; JPEG artefacts survive into the BLP.
        SetCVar("screenshotFormat", "tga")
        Say("capturing %d portraits, ~%.1fs each. Do not move the camera.",
            #QUEUE, DEFAULT_DELAY + SETTLE_DELAY)
        Step(1)

    elseif cmd == "stop" then
        if not running then
            Say("not running")
            return
        end
        Finish(true)

    else
        Say("commands: list | show <n> | hide | start | stop")
    end
end

Say("loaded -- /dcp list")
