local DCBREAKINGNEWS_GLUE_VERSION = "dc-breakingnews-glue-2026-05-09-r1"

local DCBreakingNewsState = {
    appliedRevision = 0,
}

local DCBREAKINGNEWS_FRAME_WIDTH = 430
local DCBREAKINGNEWS_FRAME_HEIGHT = 240

function DCBreakingNews_GetGluePackageVersion()
    return DCBREAKINGNEWS_GLUE_VERSION
end

local function DCBreakingNews_HasClientApi()
    return type(HasBreakingNews) == "function"
        and type(GetBreakingNewsBody) == "function"
        and type(GetBreakingNewsRevision) == "function"
end

local function DCBreakingNews_CoerceNativeBoolean(value)
    local valueType = type(value)

    if valueType == "boolean" then
        return value
    end

    if valueType == "number" then
        return value ~= 0
    end

    if valueType == "string" then
        local lowered = string.lower(value)
        if lowered == "0" or lowered == "false" or lowered == "no" or lowered == "" then
            return false
        end

        if lowered == "1" or lowered == "true" or lowered == "yes" then
            return true
        end
    end

    return value and true or false
end

local function DCBreakingNews_GetParentFrame()
    if CharacterSelect then
        return CharacterSelect
    end

    if GlueParent then
        return GlueParent
    end

    return UIParent
end

local function DCBreakingNews_IsCharacterSelectShown()
    local currentScreen = type(GetCurrentGlueScreenName) == "function"
        and GetCurrentGlueScreenName()
        or nil
    local pendingScreen = type(GetPendingGlueScreenName) == "function"
        and GetPendingGlueScreenName()
        or nil

    if currentScreen == "charselect" or pendingScreen == "charselect" then
        return true
    end

    return CharacterSelect
        and CharacterSelect.IsShown
        and CharacterSelect:IsShown()
end

local function DCBreakingNews_GetScreenDetail()
    local currentScreen = type(GetCurrentGlueScreenName) == "function"
        and GetCurrentGlueScreenName()
        or "nil"
    local pendingScreen = type(GetPendingGlueScreenName) == "function"
        and GetPendingGlueScreenName()
        or "nil"

    return "current=" .. tostring(currentScreen)
        .. " pending=" .. tostring(pendingScreen)
end

local function DCBreakingNews_BuildFallbackText(body)
    if not body or body == "" then
        return nil
    end

    body = string.gsub(body, "\r\n", "\n")
    body = string.gsub(body, "\r", "\n")
    body = string.gsub(body, "<[bB][rR]%s*/?>", "\n")
    body = string.gsub(body, "</[pP]>", "\n\n")
    body = string.gsub(body, "<[pP][^>]*>", "")
    body = string.gsub(body, "</[hH][1-6]>", "\n")
    body = string.gsub(body, "<[hH][1-6][^>]*>", "")
    body = string.gsub(body, "</[lL][iI]>", "\n")
    body = string.gsub(body, "<[lL][iI][^>]*>", "* ")
    body = string.gsub(body, "<[^>]+>", "")
    body = string.gsub(body, "\n%s*\n%s*\n+", "\n\n")
    body = string.gsub(body, "^%s+", "")
    body = string.gsub(body, "%s+$", "")
    return body
end

local function DCBreakingNews_NormalizeBody(format, body)
    if not body or body == "" then
        return nil
    end

    if format == "plain" then
        body = string.gsub(body, "\r\n", "\n")
        body = string.gsub(body, "\r", "\n")
        return body
    end

    return DCBreakingNews_BuildFallbackText(body)
end

local function DCBreakingNews_EnsureFrame()
    if DCBreakingNewsFrame then
        return DCBreakingNewsFrame
    end

    local frame = CreateFrame("Frame", "DCBreakingNewsFrame",
        DCBreakingNews_GetParentFrame())
    frame:SetWidth(DCBREAKINGNEWS_FRAME_WIDTH)
    frame:SetHeight(DCBREAKINGNEWS_FRAME_HEIGHT)
    frame:SetToplevel(true)
    frame:SetFrameStrata("FULLSCREEN_DIALOG")
    if frame.SetClampedToScreen then
        frame:SetClampedToScreen(true)
    end
    frame:Hide()

    if frame.SetBackdrop then
        frame:SetBackdrop({
            bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
            edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
            tile = true,
            tileSize = 16,
            edgeSize = 16,
            insets = {
                left = 5,
                right = 5,
                top = 5,
                bottom = 5,
            },
        })
        frame:SetBackdropColor(0.02, 0.02, 0.02, 0.9)
    end

    local title = frame:CreateFontString(nil, "OVERLAY",
        "GameFontHighlightLarge")
    title:SetPoint("TOPLEFT", frame, "TOPLEFT", 18, -18)
    title:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -34, -18)
    title:SetJustifyH("LEFT")

    local body = frame:CreateFontString(nil, "OVERLAY",
        "GameFontHighlight")
    body:SetPoint("TOPLEFT", frame, "TOPLEFT", 18, -48)
    body:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -18, 18)
    body:SetJustifyH("LEFT")
    body:SetJustifyV("TOP")
    if body.SetNonSpaceWrap then
        body:SetNonSpaceWrap(true)
    end

    local closeButton = CreateFrame("Button", nil, frame)
    closeButton:SetWidth(20)
    closeButton:SetHeight(20)
    closeButton:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -10, -10)

    local closeText = closeButton:CreateFontString(nil, "OVERLAY",
        "GameFontNormal")
    closeText:SetPoint("CENTER", closeButton, "CENTER", 0, 0)
    closeText:SetText("x")

    closeButton:SetScript("OnClick", function()
        frame:Hide()
    end)

    frame.titleText = title
    frame.bodyText = body

    return frame
end

local function DCBreakingNews_ShowFrame(title, body)
    local frame = DCBreakingNews_EnsureFrame()
    local parent = DCBreakingNews_GetParentFrame()

    if frame.GetParent and frame:GetParent() ~= parent then
        frame:SetParent(parent)
    end

    frame:ClearAllPoints()
    frame:SetPoint("TOPLEFT", parent, "TOPLEFT", 48, -120)
    frame.titleText:SetText(title)
    frame.bodyText:SetText(body)
    frame:Show()
end

local function DCBreakingNews_ReportApplied(revision)
    if type(DCBreakingNews_NotifyGlueApplied) == "function" then
        DCBreakingNews_NotifyGlueApplied(revision or 0)
    end
end

local function DCBreakingNews_ReportHidden(reason)
    if type(DCBreakingNews_NotifyGlueHidden) == "function" then
        DCBreakingNews_NotifyGlueHidden(reason or "hidden")
    end
end

local function DCBreakingNews_ReportError(detail)
    if type(DCBreakingNews_NotifyGlueError) == "function" then
        DCBreakingNews_NotifyGlueError(detail or "glue-error")
    end
end

local function DCBreakingNews_HideFrame(reason)
    if DCBreakingNewsFrame and DCBreakingNewsFrame.Hide then
        DCBreakingNewsFrame:Hide()
    end

    DCBreakingNews_ReportHidden(reason)
end

local function DCBreakingNews_ApplyCurrent()
    local hasPayload = DCBreakingNews_HasClientApi()
        and DCBreakingNews_CoerceNativeBoolean(HasBreakingNews())
    if not hasPayload then
        DCBreakingNews_HideFrame("payload-missing")
        return
    end

    local revision = tonumber(GetBreakingNewsRevision and GetBreakingNewsRevision()) or 0
    if revision ~= 0 and DCBreakingNewsState.appliedRevision == revision then
        return
    end

    local title = "Breaking News"
    if type(GetBreakingNewsTitle) == "function" then
        local value = GetBreakingNewsTitle()
        if value and value ~= "" then
            title = value
        end
    end

    local format = type(GetBreakingNewsFormat) == "function"
        and GetBreakingNewsFormat()
        or "simplehtml"
    local body = DCBreakingNews_NormalizeBody(format, GetBreakingNewsBody())
    if not body then
        DCBreakingNews_HideFrame("body-missing format=" .. tostring(format))
        return
    end

    DCBreakingNews_ShowFrame(title, body)
    DCBreakingNews_ReportApplied(revision)

    if revision ~= 0 then
        DCBreakingNewsState.appliedRevision = revision
    end
end

local function DCBreakingNews_TryApplyCurrent()
    local ok, err = pcall(DCBreakingNews_ApplyCurrent)
    if not ok then
        DCBreakingNews_ReportError(tostring(err))
    end
end

function DCBreakingNews_OnPayloadUpdated(revision, reason)
    if not DCBreakingNews_IsCharacterSelectShown() then
        return
    end

    if not revision or revision == 0 then
        DCBreakingNews_HideFrame(reason or "payload-cleared")
        return
    end

    DCBreakingNews_TryApplyCurrent()
end

if type(SetGlueScreen) == "function" then
    local DCBreakingNews_OriginalSetGlueScreen = SetGlueScreen

    SetGlueScreen = function(name)
        DCBreakingNews_OriginalSetGlueScreen(name)

        if name == "charselect" then
            DCBreakingNews_TryApplyCurrent()
        else
            DCBreakingNews_HideFrame("screen=" .. tostring(name))
        end
    end
end

if type(DCBreakingNews_NotifyGlueLoaded) == "function" then
    DCBreakingNews_NotifyGlueLoaded(DCBREAKINGNEWS_GLUE_VERSION)
end