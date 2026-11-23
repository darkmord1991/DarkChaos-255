-- ============================================================
-- DC-QoS: In-game bug report (/dcbug)
-- ============================================================
-- A small dialog that sends a bug report to the server over the DC addon
-- protocol (module BUGR). The server (src/server/scripts/DC/LabTools/
-- dc_bug_report.cpp) checks it, rate limits per account and queues it; a
-- separate relay turns queued reports into GitHub issues. Nothing here talks
-- to GitHub, and no account name, IP address or character name is sent: the
-- server adds the map and position itself.
--
-- Sent along with the text: client build and DC fingerprint, locale, zone
-- text, the version of each loaded addon and, when ticked, the newest Lua
-- errors BugGrabber recorded this session.
-- ============================================================

local BugReport = {}
_G.DCQoSBugReport = BugReport

local MODULE = "BUGR"
local CMSG_SUBMIT = 0x01
local SMSG_RESULT = 0x10

local MAX_TITLE = 120
local MAX_BODY = 2000
local MAX_PAYLOAD = 6000          -- encoded JSON; ~25 protocol chunks
local MAX_ADDONS = 48
local MAX_ERRORS = 5
local MAX_ERROR_TEXT = 600
local QUEUE_LIMIT = 24            -- wait while the protocol queue holds more than this
local RESPONSE_TIMEOUT = 20

local CATEGORIES = {
    { key = "bug", label = "General bug" },
    { key = "quest", label = "Quest" },
    { key = "item", label = "Item" },
    { key = "creature", label = "NPC / creature" },
    { key = "spell", label = "Spell / class" },
    { key = "ui", label = "Interface / addon" },
    { key = "other", label = "Other" },
}

local frame                       -- the dialog, created on first open
local pending                     -- { sentAt } while a report is in flight
local categoryIndex = 1

local function Protocol()
    return rawget(_G, "DCAddonProtocol")
end

local function Print(msg)
    if DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage("|cffffcc00[DC Bug Report]|r " .. tostring(msg))
    end
end

local function Trim(text)
    return (string.gsub(text or "", "^%s+", ""):gsub("%s+$", ""))
end

local function Cut(text, limit)
    if type(text) ~= "string" then
        return nil
    end
    if #text > limit then
        return string.sub(text, 1, limit)
    end
    return text
end

-- ------------------------------------------------------------
-- What goes into a report
-- ------------------------------------------------------------

function BugReport.CollectClient()
    local DC = Protocol()
    local version, build = "?", "?"
    if GetBuildInfo then
        version, build = GetBuildInfo()
    end
    local client = {
        build = tostring(version) .. " (" .. tostring(build) .. ")",
        locale = GetLocale and GetLocale() or nil,
        zoneText = Cut(GetRealZoneText and GetRealZoneText() or nil, 96),
        subZoneText = Cut(GetSubZoneText and GetSubZoneText() or nil, 96),
    }
    if DC then
        local ok, fingerprint = pcall(DC.GetNativeExtensionBuildFingerprint, DC)
        if ok and type(fingerprint) == "string" then
            client.fingerprint = Cut(fingerprint, 96)
        end
        local okCaps, caps = pcall(DC.GetNativeExtensionCapabilities, DC)
        if okCaps and tonumber(caps) then
            client.caps = tostring(caps)
        end
    end
    return client
end

-- Loaded addons with their versions, DC ones first.
function BugReport.CollectAddons()
    local dc, others = {}, {}
    if not GetNumAddOns then
        return dc
    end
    for i = 1, GetNumAddOns() do
        local name = GetAddOnInfo(i)
        if name and (not IsAddOnLoaded or IsAddOnLoaded(i)) then
            local entry = { n = Cut(name, 48), v = Cut(GetAddOnMetadata and GetAddOnMetadata(i, "Version") or nil, 48) }
            if string.find(name, "^DC") then
                dc[#dc + 1] = entry
            else
                others[#others + 1] = entry
            end
        end
    end
    for _, entry in ipairs(others) do
        if #dc >= MAX_ADDONS then
            break
        end
        dc[#dc + 1] = entry
    end
    while #dc > MAX_ADDONS do
        table.remove(dc)
    end
    return dc
end

-- The newest BugGrabber errors of the current session.
function BugReport.CollectErrors()
    local list = {}
    local grabber = rawget(_G, "BugGrabber")
    if type(grabber) ~= "table" or type(grabber.GetDB) ~= "function" then
        return list
    end
    local ok, db = pcall(grabber.GetDB, grabber)
    if not ok or type(db) ~= "table" then
        return list
    end
    local session = type(grabber.GetSessionId) == "function" and grabber:GetSessionId() or nil
    for i = #db, 1, -1 do
        if #list >= MAX_ERRORS then
            break
        end
        local err = db[i]
        if type(err) == "table" and (session == nil or err.session == session) then
            local message = err.message
            if type(message) == "table" then
                message = table.concat(message, "")
            end
            if type(message) == "string" and message ~= "" then
                list[#list + 1] = { m = Cut(message, MAX_ERROR_TEXT), c = tonumber(err.counter) }
            end
        end
    end
    return list
end

-- The JSON-ready report table, trimmed until it encodes within MAX_PAYLOAD.
function BugReport.BuildPayload(title, body, category, includeErrors)
    local DC = Protocol()
    local payload = {
        title = Cut(Trim(title), MAX_TITLE),
        body = Cut(Trim(body), MAX_BODY),
        category = category,
        client = BugReport.CollectClient(),
        addons = BugReport.CollectAddons(),
        errors = includeErrors and BugReport.CollectErrors() or {},
    }
    if not DC then
        return payload
    end
    local json = DC:EncodeJSON(payload)
    while type(json) == "string" and #json > MAX_PAYLOAD and (#payload.errors > 0 or #payload.addons > 0) do
        if #payload.errors > 0 then
            table.remove(payload.errors)
        else
            table.remove(payload.addons)
        end
        json = DC:EncodeJSON(payload)
    end
    return payload, json
end

-- ------------------------------------------------------------
-- Sending and the server's answer
-- ------------------------------------------------------------

local function SetStatus(text, r, g, b)
    if frame and frame.status then
        frame.status:SetText(text or "")
        frame.status:SetTextColor(r or 1, g or 0.82, b or 0)
    end
end

local function SetBusy(busy)
    if frame and frame.submit then
        if busy then
            frame.submit:Disable()
        else
            frame.submit:Enable()
        end
    end
end

local function QueueBusy(DC)
    local throttle = DC._throttle
    return type(throttle) == "table" and type(throttle.queue) == "table" and #throttle.queue > QUEUE_LIMIT
end

-- Returns true when the report went out (or is waiting for queue room).
function BugReport.Submit(title, body, category, includeErrors)
    local DC = Protocol()
    if not DC then
        return false, "The DC protocol addon is not loaded."
    end
    if pending then
        return false, "A report is already on its way."
    end
    title, body = Trim(title), Trim(body)
    if #title < 3 then
        return false, "Please enter a title (at least 3 characters)."
    end
    if #body < 10 then
        return false, "Please describe the problem (at least 10 characters)."
    end

    local payload, json = BugReport.BuildPayload(title, body, category, includeErrors)
    if type(json) == "string" and #json > MAX_PAYLOAD then
        return false, "The report is too long. Please shorten the description."
    end

    pending = { sentAt = GetTime and GetTime() or 0, payload = payload, waiting = QueueBusy(DC) }
    if not pending.waiting then
        DC:SendJSON(MODULE, CMSG_SUBMIT, payload)
    end
    return true
end

function BugReport.OnTick()
    if not pending then
        return
    end
    local DC = Protocol()
    local now = GetTime and GetTime() or 0
    if pending.waiting and DC and not QueueBusy(DC) then
        pending.waiting = false
        pending.sentAt = now
        DC:SendJSON(MODULE, CMSG_SUBMIT, pending.payload)
    elseif now - pending.sentAt > RESPONSE_TIMEOUT then
        pending = nil
        SetBusy(false)
        SetStatus("No answer from the server. Please try again later.", 1, 0.3, 0.3)
    end
end

function BugReport.OnResult(data)
    pending = nil
    SetBusy(false)
    if type(data) ~= "table" then
        return
    end
    if data.ok then
        local text = "Thank you! Your report was queued (" .. tostring(data.id or "?") .. ")."
        Print(text)
        SetStatus(text, 0.3, 1, 0.3)
        if frame then
            frame.titleBox:SetText("")
            frame.bodyBox:SetText("")
        end
    else
        local text = tostring(data.error or "The report was not accepted.")
        Print(text)
        SetStatus(text, 1, 0.3, 0.3)
    end
end

function BugReport.OnError(_, errorMsg)
    if not pending then
        return
    end
    pending = nil
    SetBusy(false)
    SetStatus("Bug reports are not available: " .. tostring(errorMsg or "server error"), 1, 0.3, 0.3)
end

-- ------------------------------------------------------------
-- Dialog
-- ------------------------------------------------------------

local function CategoryLabel()
    return "Category: " .. CATEGORIES[categoryIndex].label
end

local function CreateDialog()
    local f = CreateFrame("Frame", "DCQoSBugReportFrame", UIParent)
    f:SetWidth(440)
    f:SetHeight(380)
    f:SetPoint("CENTER")
    f:SetFrameStrata("DIALOG")
    f:SetClampedToScreen(true)
    f:EnableMouse(true)
    f:SetMovable(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", function(self) self:StartMoving() end)
    f:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
    f:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 },
    })
    f:Hide()
    if UISpecialFrames then
        table.insert(UISpecialFrames, "DCQoSBugReportFrame")
    end

    local header = f:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    header:SetPoint("TOP", 0, -18)
    header:SetText("Report a Bug")

    local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -6, -6)

    local titleLabel = f:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    titleLabel:SetPoint("TOPLEFT", 24, -50)
    titleLabel:SetText("Title")

    local titleBox = CreateFrame("EditBox", "DCQoSBugReportTitle", f, "InputBoxTemplate")
    titleBox:SetWidth(380)
    titleBox:SetHeight(20)
    titleBox:SetPoint("TOPLEFT", 30, -64)
    titleBox:SetAutoFocus(false)
    titleBox:SetMaxLetters(MAX_TITLE)
    f.titleBox = titleBox

    local category = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    category:SetWidth(220)
    category:SetHeight(22)
    category:SetPoint("TOPLEFT", 24, -92)
    category:SetText(CategoryLabel())
    category:SetScript("OnClick", function(self)
        categoryIndex = categoryIndex % #CATEGORIES + 1
        self:SetText(CategoryLabel())
    end)
    f.category = category

    local bodyLabel = f:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    bodyLabel:SetPoint("TOPLEFT", 24, -124)
    bodyLabel:SetText("What happened, and how can we see it again?")

    local scroll = CreateFrame("ScrollFrame", "DCQoSBugReportScroll", f, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 26, -140)
    scroll:SetWidth(370)
    scroll:SetHeight(150)

    local bodyBox = CreateFrame("EditBox", "DCQoSBugReportBody", scroll)
    bodyBox:SetMultiLine(true)
    bodyBox:SetAutoFocus(false)
    bodyBox:SetFontObject(ChatFontNormal)
    bodyBox:SetWidth(360)
    bodyBox:SetHeight(150)
    bodyBox:SetMaxLetters(MAX_BODY)
    bodyBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    scroll:SetScrollChild(bodyBox)
    f.bodyBox = bodyBox

    local errors = CreateFrame("CheckButton", "DCQoSBugReportErrors", f, "UICheckButtonTemplate")
    errors:SetPoint("TOPLEFT", 20, -298)
    errors:SetChecked(true)
    local errorsText = _G["DCQoSBugReportErrorsText"]
    if errorsText then
        errorsText:SetText("Attach this session's Lua errors (BugSack)")
    end
    f.errors = errors

    local status = f:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    status:SetPoint("BOTTOMLEFT", 24, 48)
    status:SetPoint("RIGHT", f, "RIGHT", -24, 0)
    status:SetJustifyH("LEFT")
    f.status = status

    local submit = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    submit:SetWidth(110)
    submit:SetHeight(22)
    submit:SetPoint("BOTTOMRIGHT", -138, 18)
    submit:SetText("Send report")
    submit:SetScript("OnClick", function()
        local ok, err = BugReport.Submit(titleBox:GetText(), bodyBox:GetText(), CATEGORIES[categoryIndex].key,
            errors:GetChecked() and true or false)
        if ok then
            SetBusy(true)
            SetStatus("Sending...", 1, 0.82, 0)
        else
            SetStatus(err, 1, 0.3, 0.3)
        end
    end)
    f.submit = submit

    local cancel = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    cancel:SetWidth(110)
    cancel:SetHeight(22)
    cancel:SetPoint("BOTTOMRIGHT", -24, 18)
    cancel:SetText("Close")
    cancel:SetScript("OnClick", function() f:Hide() end)

    return f
end

function BugReport.Open(title)
    if not frame then
        frame = CreateDialog()
    end
    if type(title) == "string" and title ~= "" then
        frame.titleBox:SetText(Cut(title, MAX_TITLE))
    end
    SetStatus("")
    frame:Show()
end

-- ------------------------------------------------------------
-- Wiring
-- ------------------------------------------------------------

-- Drives the queue wait and the answer timeout even while the dialog is closed.
local ticker = CreateFrame("Frame")
ticker:Show()
ticker:SetScript("OnUpdate", function()
    if pending then
        BugReport.OnTick()
    end
end)

do
    local DC = Protocol()
    if DC and type(DC.RegisterJSONHandler) == "function" then
        DC:RegisterJSONHandler(MODULE, SMSG_RESULT, BugReport.OnResult)
    end
    if DC and type(DC.RegisterErrorHandler) == "function" then
        DC:RegisterErrorHandler(MODULE, BugReport.OnError)
    end
end

SLASH_DCQOSBUGREPORT1 = "/dcbug"
SLASH_DCQOSBUGREPORT2 = "/dcbugreport"
SlashCmdList["DCQOSBUGREPORT"] = function(msg)
    BugReport.Open(Trim(msg))
end
