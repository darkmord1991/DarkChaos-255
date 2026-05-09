local DCBreakingNewsState = {
    elapsed = 0,
    appliedRevision = 0,
}

local function DCBreakingNews_HasClientApi()
    return type(HasBreakingNews) == "function"
        and type(GetBreakingNewsBody) == "function"
        and type(GetBreakingNewsRevision) == "function"
end

local function DCBreakingNews_IsCharacterSelectShown()
    return CharacterSelect
        and CharacterSelect.IsShown
        and CharacterSelect:IsShown()
end

local function DCBreakingNews_NormalizeBody(format, body)
    if not body or body == "" then
        return nil
    end

    if format == "plain" then
        body = string.gsub(body, "\r\n", "\n")
        body = string.gsub(body, "\n", "<br/>")
    end

    return body
end

local function DCBreakingNews_ApplyCurrent()
    if not DCBreakingNews_HasClientApi() or not HasBreakingNews() then
        return
    end

    if not (ServerAlertFrame and ServerAlertTitle and ServerAlertText) then
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
        return
    end

    if CharacterSelect
        and ServerAlertFrame.GetParent
        and ServerAlertFrame:GetParent() ~= CharacterSelect then
        ServerAlertFrame:SetParent(CharacterSelect)
    end

    ServerAlertTitle:SetText(title)
    ServerAlertText:SetText(body)
    ServerAlertFrame:Show()

    if revision ~= 0 then
        DCBreakingNewsState.appliedRevision = revision
    end
end

function DCBreakingNews_OnUpdate(self, elapsed)
    DCBreakingNewsState.elapsed = DCBreakingNewsState.elapsed + elapsed
    if DCBreakingNewsState.elapsed < 0.25 then
        return
    end

    DCBreakingNewsState.elapsed = 0

    if not DCBreakingNews_IsCharacterSelectShown() then
        return
    end

    DCBreakingNews_ApplyCurrent()
end