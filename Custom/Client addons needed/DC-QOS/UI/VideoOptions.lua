-- ============================================================
-- DC-QoS: Video Options Pages
-- ============================================================
-- Pages in the game's own Video window, next to Resolution and Effects. A module
-- listed here gets a scrolling page from its CreateSettings, and the window's buttons
-- reach it through VideoOptionsOkay, VideoOptionsCancel, VideoOptionsDefault and
-- VideoOptionsRefresh. IsAvailable keeps a page off a client that lacks what it needs.

local addon = DCQOS

local PAGES = { "GraphicsPlus", "PostProcessing" }

-- What VideoOptionsFramePanelContainer's 413 leaves beside the insets and the scroll bar
local CONTENT_WIDTH = 378
local SLIDER_WIDTH = 165
local COLUMNS = { 12, 201 }

local function CleanValue(info, value)
    if value >= info.max then
        return info.max
    end

    local stepped = info.min + math.floor((value - info.min) / info.step + 0.5) * info.step
    return tonumber(string.format("%.2f", stepped))
end

-- info: key, label, min, max, step, format. Moving the slider calls onChanged with the
-- value on its step. ShowStored puts a stored value on it without calling back, so
-- that opening a page cannot round a value that was set from the console.
function addon:CreateVideoSlider(parent, column, y, info, onChanged)
    local slider = self:CreateSlider(parent, "DCQoSVideo_" .. info.key)
    slider:SetPoint("TOPLEFT", COLUMNS[column], y)
    slider:SetWidth(SLIDER_WIDTH)
    slider:SetMinMaxValues(info.min, info.max)
    slider:SetValueStep(info.step)
    slider.Text:SetFontObject("GameFontNormalSmall")
    slider.Low:SetText(info.format(info.min))
    slider.High:SetText(info.format(info.max))
    -- The label carries the value; CreateSlider's line would round 0.7 up to 1
    slider.Value:Hide()

    local function ShowValue(value)
        slider.Text:SetText(info.label .. ": " .. info.format(value))
    end

    function slider:ShowStored(value)
        self.dcqosQuiet = true
        self:SetValue(value)
        self.dcqosQuiet = false
        ShowValue(value)
    end

    slider:SetScript("OnValueChanged", function(self, value)
        if self.dcqosQuiet then return end
        local clean = CleanValue(info, value)
        ShowValue(clean)
        onChanged(clean)
    end)

    return slider
end

function addon:CreateVideoCheckbox(parent, y, key, label, onClick)
    local name = "DCQoSVideo_" .. key
    local box = CreateFrame("CheckButton", name, parent, "OptionsSmallCheckButtonTemplate")
    box:SetPoint("TOPLEFT", COLUMNS[1], y)
    _G[name .. "Text"]:SetText(label)
    box:SetScript("OnClick", function(self)
        PlaySound(self:GetChecked() and "igMainMenuOptionCheckBoxOn" or "igMainMenuOptionCheckBoxOff")
        onClick(self:GetChecked() and true or false)
    end)
    return box
end

function addon:CreateVideoHeader(parent, y, text)
    local header = parent:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    header:SetPoint("TOPLEFT", COLUMNS[1], y)
    header:SetText(text)
    return header
end

function addon:CreateVideoNote(parent, y, text)
    local note = parent:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    note:SetPoint("TOPLEFT", COLUMNS[1], y)
    note:SetPoint("RIGHT", parent, "RIGHT", -12, 0)
    note:SetJustifyH("LEFT")
    note:SetText(text)
    return note
end

function addon:CreateVideoPageTitle(parent, title, text)
    local titleText = parent:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    titleText:SetPoint("TOPLEFT", COLUMNS[1], -12)
    titleText:SetText(title)
    return self:CreateVideoNote(parent, -34, text)
end

function addon:SetVideoControlEnabled(control, enabled)
    control:EnableMouse(enabled)
    control:SetAlpha(enabled and 1 or 0.5)
end

local function CreatePage(moduleName, module)
    local name = "DCQoSVideoPage" .. moduleName
    local page = CreateFrame("Frame", name, VideoOptionsFramePanelContainer)
    page:Hide()
    page.name = module.displayName

    local scroll = CreateFrame("ScrollFrame", name .. "Scroll", page, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", page, "TOPLEFT", 6, -6)
    scroll:SetPoint("BOTTOMRIGHT", page, "BOTTOMRIGHT", -29, 6)
    scroll.scrollBarHideable = true

    local content = CreateFrame("Frame", nil, scroll)
    content:SetPoint("TOPLEFT", scroll, "TOPLEFT", 0, 0)
    content:SetSize(CONTENT_WIDTH, 1)
    scroll:SetScrollChild(content)
    page.content = content

    content:SetHeight(-module.CreateSettings(content))

    page.okay = module.VideoOptionsOkay
    page.cancel = module.VideoOptionsCancel
    page.default = module.VideoOptionsDefault
    page.refresh = module.VideoOptionsRefresh

    OptionsFrame_AddCategory(VideoOptionsFrame, page)
    return page
end

function addon:CreateVideoOptionsPages()
    if self.videoOptionsPages then return end
    self.videoOptionsPages = {}

    for _, moduleName in ipairs(PAGES) do
        local module = self.modules[moduleName]
        if module and (not module.IsAvailable or module.IsAvailable()) then
            local ok, page = pcall(CreatePage, moduleName, module)
            if ok then
                self.videoOptionsPages[moduleName] = page
            else
                self:Print("Video options: " .. moduleName .. " failed to build: " .. tostring(page), true)
            end
        end
    end
end

function addon:OpenVideoOptionsPage(moduleName)
    local page = self.videoOptionsPages and self.videoOptionsPages[moduleName]
    if page then
        OptionsFrame_OpenToCategory(VideoOptionsFrame, page.name)
    else
        VideoOptionsFrame:Show()
    end
end
