-- ============================================================
-- DC-QoS: Shared Shell / Widgets / Notifications / Accessibility
-- ============================================================

local addon = DCQOS
if not addon then return end

local math_floor = math.floor
local strfind = string.find
local strgsub = string.gsub
local strlower = string.lower

addon.settingsKeywords = addon.settingsKeywords or {}
addon.scalableFrames = addon.scalableFrames or {}

addon:MergeModuleDefaults({
    experience = {
        enabled = true,
    },
    editMode = {
        enabled = true,
        showToolbar = true,
        autoUnlockFrames = true,
        autoEnableKeybinds = true,
        showGridWhileEditing = true,
        useNavigationPreview = true,
    },
    notifications = {
        enabled = true,
        duration = 3.5,
        maxVisible = 3,
        scale = 1.0,
        chatFallback = true,
    },
    accessibility = {
        enabled = true,
        fontScale = 1.0,
        tooltipScale = 1.0,
        highContrast = false,
        cleanerTooltips = true,
        questTextContrast = true,
        largerQuestText = true,
    },
})

local DEFAULT_KEYWORDS = {
    Experience = { "settings", "search", "widgets", "toast", "notifications", "accessibility", "edit mode", "toolbar" },
    Automation = { "auto repair", "auto sell", "loot", "cinematics", "quests", "gossip" },
    Interface = { "camera", "world map", "gryphons", "buff frame", "quest levels" },
    Chat = { "chat", "timestamps", "urls", "channels", "copy", "class colors" },
    Tooltips = { "tooltip", "item id", "npc id", "spell id", "item level", "upgrade info" },
    DruidFix = { "druid", "fix", "icons", "stats" },
    NameplatesPlus = { "nameplates", "threat", "cast bar", "debuffs", "npc icons" },
    CombatLog = { "combat", "damage meter", "healing", "segments", "death recap", "threat" },
    GTFO = { "damage alerts", "danger", "audio", "flash", "ground effects" },
    Bags = { "bags", "inventory", "bank", "search", "sort", "junk", "onebag" },
    BagEnhancements = { "bags", "inventory", "bank", "search", "sort", "junk", "onebag" },
    VendorPlus = { "vendor", "sell junk", "repair", "reagents", "junk list" },
    ItemScore = { "item score", "pawn", "upgrade", "spec weights" },
    FrameMover = { "edit mode", "move frames", "grid", "snap", "layout" },
    ActionBars = { "action bars", "bar layout", "buttons", "custom bars" },
    Keybinds = { "bindings", "hover bind", "keys", "quick bind" },
    Minimap = { "minimap", "tracking", "buttons", "calendar", "zoom" },
    Navigation = { "navigation", "waypoint", "supertrack", "quest follow", "marker" },
    SocialEnhancements = { "social", "friends", "guild", "who", "auto invite" },
    Mail = { "mail", "collect all", "mailbox" },
    Profiles = { "profiles", "export", "import", "settings profile" },
    TalentManager = { "talents", "templates", "glyphs", "inspect", "builds" },
    ExtendedStats = { "stats", "character", "ratings", "avoidance" },
    WeakAuras = { "weakauras", "auras", "options" },
}

for moduleName, keywords in pairs(DEFAULT_KEYWORDS) do
    addon.settingsKeywords[moduleName] = addon.settingsKeywords[moduleName] or keywords
end

function addon:RegisterSettingsKeywords(moduleName, keywords)
    if not moduleName or type(keywords) ~= "table" then return end
    self.settingsKeywords[moduleName] = keywords
end

function addon:GetSettingsKeywords(moduleName)
    return self.settingsKeywords[moduleName] or {}
end

function addon:NormalizeSearchText(text)
    text = tostring(text or "")
    text = strlower(text)
    text = strgsub(text, "[%c]+", " ")
    text = strgsub(text, "^%s+", "")
    text = strgsub(text, "%s+$", "")
    text = strgsub(text, "%s+", " ")
    return text
end

function addon:SearchMatches(moduleName, query, extraText)
    local normalizedQuery = self:NormalizeSearchText(query)
    if normalizedQuery == "" then
        return true
    end

    local parts = {
        self:NormalizeSearchText(moduleName),
        self:NormalizeSearchText(extraText),
    }

    if self.dashboardDisplayNames and self.dashboardDisplayNames[moduleName] then
        table.insert(parts, self:NormalizeSearchText(self.dashboardDisplayNames[moduleName]))
    end

    for _, keyword in ipairs(self:GetSettingsKeywords(moduleName)) do
        table.insert(parts, self:NormalizeSearchText(keyword))
    end

    local haystack = table.concat(parts, " ")
    for token in string.gmatch(normalizedQuery, "%S+") do
        if not strfind(haystack, token, 1, true) then
            return false
        end
    end

    return true
end

function addon:RegisterScalableFrame(frame)
    if not frame then return end
    self.scalableFrames[frame] = true
end

function addon:ApplyFontScaleToFrame(frame)
    if not frame then return end

    local accessibility = self.settings and self.settings.accessibility or self.defaults.accessibility or {}
    local scale = 1.0
    if accessibility.enabled ~= false then
        scale = tonumber(accessibility.fontScale) or 1.0
    end

    local function ApplyToObject(object, depth)
        if not object or depth > 5 then return end

        if object.GetObjectType and object:GetObjectType() == "FontString" and object.GetFont and object.SetFont then
            local font, size, flags = object:GetFont()
            if font and size then
                if not object.__dcqosOriginalFont then
                    object.__dcqosOriginalFont = { font = font, size = size, flags = flags }
                end

                local original = object.__dcqosOriginalFont
                object:SetFont(original.font, math.max(8, original.size * scale), original.flags)
            end
        end

        if object.GetRegions then
            for _, region in ipairs({ object:GetRegions() }) do
                ApplyToObject(region, depth + 1)
            end
        end

        if object.GetChildren then
            for _, child in ipairs({ object:GetChildren() }) do
                ApplyToObject(child, depth + 1)
            end
        end
    end

    ApplyToObject(frame, 0)
end

local questReadabilityPanels = {
    "QuestFrameDetailPanel",
    "QuestFrameProgressPanel",
    "QuestFrameRewardPanel",
    "QuestLogDetailFrame",
    "GreetingFrame",
}

local questReadabilityText = {
    "QuestInfoTitleHeader",
    "QuestInfoDescriptionText",
    "QuestInfoObjectivesText",
    "QuestInfoRewardText",
    "QuestProgressText",
    "QuestRewardText",
    "GreetingText",
}

local function ApplyQuestReadability()
    local accessibility = addon.settings and addon.settings.accessibility or {}
    local enableContrast = accessibility.enabled ~= false and accessibility.questTextContrast
    local largerText = accessibility.enabled ~= false and accessibility.largerQuestText
    local baseScale = tonumber(accessibility.fontScale) or 1.0
    local textScale = largerText and (baseScale * 1.10) or baseScale

    for _, name in ipairs(questReadabilityPanels) do
        local panel = _G[name]
        if panel then
            if not panel.__dcqosQuestShade then
                local shade = panel:CreateTexture(nil, "BACKGROUND")
                shade:SetAllPoints(panel)
                shade:SetTexture(0, 0, 0, 0.01)
                panel.__dcqosQuestShade = shade
            end

            panel.__dcqosQuestShade:SetTexture(0, 0, 0, enableContrast and 0.24 or 0.01)
        end
    end

    for _, name in ipairs(questReadabilityText) do
        local text = _G[name]
        if text and text.GetFont and text.SetFont then
            local font, size, flags = text:GetFont()
            if font and size then
                if not text.__dcqosQuestOriginalFont then
                    text.__dcqosQuestOriginalFont = { font = font, size = size, flags = flags }
                end

                local original = text.__dcqosQuestOriginalFont
                text:SetFont(original.font, math.max(10, original.size * textScale), original.flags)
            end

            if text.SetTextColor then
                if enableContrast then
                    text:SetTextColor(1.0, 0.96, 0.86)
                else
                    text:SetTextColor(1.0, 0.82, 0.0)
                end
            end
        end
    end
end

function addon:ApplyAccessibility()
    for frame in pairs(self.scalableFrames or {}) do
        if frame then
            self:ApplyFontScaleToFrame(frame)
        end
    end

    if self.settingsPanel then
        self:ApplyFontScaleToFrame(self.settingsPanel)
    end

    ApplyQuestReadability()
end

function addon:StyleActionButton(button)
    if not button or button.__dcqosStyledButton then return button end
    button.__dcqosStyledButton = true

    local bg = button:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(button)
    bg:SetTexture("Interface\\Buttons\\WHITE8x8")
    bg:SetVertexColor(0.08, 0.08, 0.08, 0.88)
    button.__dcqosBg = bg

    local border = button:CreateTexture(nil, "BORDER")
    border:SetPoint("TOPLEFT", button, "TOPLEFT", -1, 1)
    border:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 1, -1)
    border:SetTexture("Interface\\Buttons\\WHITE8x8")
    border:SetVertexColor(0.28, 0.28, 0.28, 1)
    button.__dcqosBorder = border

    button:HookScript("OnEnter", function(self)
        if self.__dcqosBg then
            self.__dcqosBg:SetVertexColor(0.12, 0.18, 0.20, 0.95)
        end
        if self.__dcqosBorder then
            self.__dcqosBorder:SetVertexColor(0.86, 0.74, 0.25, 1)
        end
    end)

    button:HookScript("OnLeave", function(self)
        if self.__dcqosBg then
            self.__dcqosBg:SetVertexColor(0.08, 0.08, 0.08, 0.88)
        end
        if self.__dcqosBorder then
            self.__dcqosBorder:SetVertexColor(0.28, 0.28, 0.28, 1)
        end
    end)

    return button
end

function addon:CreateActionButton(parent, text, width, height)
    local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    button:SetSize(width or 120, height or 22)
    button:SetText(text or "")
    self:StyleActionButton(button)
    return button
end

function addon:SkinSearchBox(editBox, placeholderText)
    if not editBox or editBox.__dcqosSearchSkinned then return editBox end
    editBox.__dcqosSearchSkinned = true

    editBox:SetTextInsets(8, 8, 0, 0)

    local shade = editBox:CreateTexture(nil, "BACKGROUND")
    shade:SetAllPoints(editBox)
    shade:SetTexture("Interface\\Buttons\\WHITE8x8")
    shade:SetVertexColor(0.05, 0.05, 0.05, 0.82)

    local border = editBox:CreateTexture(nil, "BORDER")
    border:SetPoint("TOPLEFT", editBox, "TOPLEFT", -1, 1)
    border:SetPoint("BOTTOMRIGHT", editBox, "BOTTOMRIGHT", 1, -1)
    border:SetTexture("Interface\\Buttons\\WHITE8x8")
    border:SetVertexColor(0.28, 0.28, 0.28, 1)

    local placeholder = editBox:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    placeholder:SetPoint("LEFT", editBox, "LEFT", 8, 0)
    placeholder:SetJustifyH("LEFT")
    placeholder:SetText(placeholderText or "Search")

    local function RefreshPlaceholder()
        if editBox:GetText() and editBox:GetText() ~= "" then
            placeholder:Hide()
        else
            placeholder:Show()
        end
    end

    editBox:HookScript("OnEditFocusGained", function()
        border:SetVertexColor(0.86, 0.74, 0.25, 1)
        RefreshPlaceholder()
    end)
    editBox:HookScript("OnEditFocusLost", function()
        border:SetVertexColor(0.28, 0.28, 0.28, 1)
        RefreshPlaceholder()
    end)
    editBox:HookScript("OnTextChanged", RefreshPlaceholder)
    RefreshPlaceholder()

    return editBox
end

function addon:CreateSearchBox(parent, name, placeholderText, width)
    local editBox = CreateFrame("EditBox", name, parent, "InputBoxTemplate")
    editBox:SetSize(width or 220, 20)
    editBox:SetAutoFocus(false)
    self:SkinSearchBox(editBox, placeholderText or "Search")
    return editBox
end

function addon:CreateSectionHeader(parent, text)
    local header = parent:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    header:SetText(text or "")
    header:SetTextColor(1, 0.82, 0)
    return header
end

local toastContainer
local toastPool = {}
local activeToasts = {}

local TOAST_COLORS = {
    info = { title = "Notice", color = { 0.35, 0.72, 1.0 }, bg = { 0.04, 0.08, 0.12, 0.92 } },
    success = { title = "Success", color = { 0.36, 0.92, 0.48 }, bg = { 0.04, 0.12, 0.06, 0.92 } },
    warning = { title = "Warning", color = { 1.0, 0.82, 0.25 }, bg = { 0.12, 0.08, 0.03, 0.94 } },
    error = { title = "Error", color = { 1.0, 0.38, 0.32 }, bg = { 0.12, 0.04, 0.04, 0.96 } },
}

local function EnsureToastContainer()
    if toastContainer then return end

    toastContainer = CreateFrame("Frame", "DCQOSToastContainer", UIParent)
    toastContainer:SetPoint("TOP", UIParent, "TOP", 0, -120)
    toastContainer:SetSize(360, 220)
    toastContainer:SetFrameStrata("DIALOG")
    toastContainer:SetClampedToScreen(true)

    addon:RegisterScalableFrame(toastContainer)
end

local function RelayoutToasts()
    if not toastContainer then return end

    local notifications = addon.settings and addon.settings.notifications or addon.defaults.notifications
    local maxVisible = math.max(1, math_floor((tonumber(notifications.maxVisible) or 3) + 0.5))
    local scale = tonumber(notifications.scale) or 1.0
    local offsetY = 0

    toastContainer:SetScale(scale)

    for index, toast in ipairs(activeToasts) do
        if index <= maxVisible then
            toast:ClearAllPoints()
            toast:SetPoint("TOP", toastContainer, "TOP", 0, -offsetY)
            toast:Show()
            offsetY = offsetY + toast:GetHeight() + 8
        else
            toast:Hide()
        end
    end
end

local function ReleaseToast(toast)
    if not toast then return end

    for index, active in ipairs(activeToasts) do
        if active == toast then
            table.remove(activeToasts, index)
            break
        end
    end

    toast:SetScript("OnUpdate", nil)
    toast:Hide()
    table.insert(toastPool, toast)
    RelayoutToasts()
end

local function AcquireToast()
    EnsureToastContainer()

    local toast = table.remove(toastPool)
    if toast then
        return toast
    end

    toast = CreateFrame("Frame", nil, toastContainer)
    toast:SetSize(320, 46)
    toast:SetFrameStrata("DIALOG")
    toast:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true,
        tileSize = 16,
        edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })

    toast.bar = toast:CreateTexture(nil, "ARTWORK")
    toast.bar:SetPoint("TOPLEFT", 4, -4)
    toast.bar:SetPoint("BOTTOMLEFT", 4, 4)
    toast.bar:SetWidth(5)
    toast.bar:SetTexture("Interface\\Buttons\\WHITE8x8")

    toast.title = toast:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    toast.title:SetPoint("TOPLEFT", toast.bar, "TOPRIGHT", 8, -6)
    toast.title:SetPoint("RIGHT", toast, "RIGHT", -10, 0)
    toast.title:SetJustifyH("LEFT")

    toast.message = toast:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    toast.message:SetPoint("TOPLEFT", toast.title, "BOTTOMLEFT", 0, -3)
    toast.message:SetPoint("RIGHT", toast, "RIGHT", -10, 0)
    toast.message:SetJustifyH("LEFT")
    toast.message:SetSpacing(2)

    toast.close = CreateFrame("Button", nil, toast, "UIPanelCloseButton")
    toast.close:SetPoint("TOPRIGHT", 2, 2)
    toast.close:SetScript("OnClick", function()
        ReleaseToast(toast)
    end)

    addon:RegisterScalableFrame(toast)
    return toast
end

function addon:ShowToast(message, level, opts)
    local notifications = self.settings and self.settings.notifications or self.defaults.notifications
    if notifications.enabled == false then return end

    local toast = AcquireToast()
    local style = TOAST_COLORS[level or "info"] or TOAST_COLORS.info
    local duration = tonumber((opts and opts.duration) or notifications.duration) or 3.5

    toast:SetBackdropColor(style.bg[1], style.bg[2], style.bg[3], style.bg[4])
    toast:SetBackdropBorderColor(style.color[1], style.color[2], style.color[3], 1)
    toast.bar:SetVertexColor(style.color[1], style.color[2], style.color[3], 1)

    toast.title:SetText((opts and opts.title) or style.title)
    toast.title:SetTextColor(style.color[1], style.color[2], style.color[3])
    toast.message:SetText(tostring(message or ""))
    toast.message:SetTextColor(1, 1, 1)
    toast.expiresAt = (GetTime() or 0) + duration

    toast:SetScript("OnUpdate", function(self)
        if (GetTime() or 0) >= (self.expiresAt or 0) then
            ReleaseToast(self)
        end
    end)

    table.insert(activeToasts, 1, toast)
    RelayoutToasts()
end

function addon:Notify(message, level, opts)
    opts = opts or {}

    if opts.showToast ~= false then
        self:ShowToast(message, level, opts)
    end

    local notifications = self.settings and self.settings.notifications or self.defaults.notifications
    if opts.chatFallback ~= false and notifications.chatFallback ~= false then
        self:Print(message, true)
    elseif opts.forceChat then
        self:Print(message, true)
    end
end

function addon:OpenSettingsModule(moduleName)
    if not self.settingsPanel then
        self:CreateSettingsPanel()
    end

    InterfaceOptionsFrame_OpenToCategory("DC-QoS")
    InterfaceOptionsFrame_OpenToCategory("DC-QoS")

    if moduleName and self.ShowModule then
        self:ShowModule(moduleName)
    end
end

function addon:EnterEditMode()
    if self.settings and self.settings.editMode and self.settings.editMode.enabled == false then
        self:Notify("Edit mode is disabled in Experience settings.", "warning")
        return false
    end

    local frameMover = self.modules and self.modules.FrameMover
    if not frameMover or not frameMover.EnableEditorMode then
        self:Notify("Frame mover is not available.", "error")
        return false
    end

    self._editModePreviousKeybindState = self.keybindMode
    self._editModeWasUnlocked = self.settings.frameMover and self.settings.frameMover.unlocked == true
    self._editModePreviousGridState = self.settings.frameMover and self.settings.frameMover.showGrid == true

    if self.settings.editMode.autoUnlockFrames and frameMover.UnlockFrames then
        frameMover:UnlockFrames()
    end

    if self.settings.editMode.autoEnableKeybinds then
        self:SetKeybindMode(true, true)
    end

    if self.settings.editMode.showGridWhileEditing then
        self.settings.frameMover.showGrid = true
    end

    frameMover:EnableEditorMode()
    if frameMover.RefreshEditorOverlay then
        frameMover:RefreshEditorOverlay()
    end

    self:Notify("Edit mode enabled.", "success", { chatFallback = false })
    return true
end

function addon:ExitEditMode()
    local frameMover = self.modules and self.modules.FrameMover
    if not frameMover or not frameMover.DisableEditorMode then
        return false
    end

    frameMover:DisableEditorMode()
    if frameMover.LockFrames and self.settings.editMode.autoUnlockFrames and not self._editModeWasUnlocked then
        frameMover:LockFrames()
    end

    if self.settings.frameMover then
        self.settings.frameMover.showGrid = self._editModePreviousGridState == true
        if frameMover.UpdateGridOverlay then
            frameMover:UpdateGridOverlay()
        end
    end

    if self.settings.editMode.autoEnableKeybinds then
        self:SetKeybindMode(self._editModePreviousKeybindState or false, true)
    end

    if frameMover.RefreshEditorOverlay then
        frameMover:RefreshEditorOverlay()
    end

    self:Notify("Edit mode disabled.", "info", { chatFallback = false })
    return true
end

function addon:ToggleEditMode()
    local frameMover = self.modules and self.modules.FrameMover
    if frameMover and self.settings and self.settings.frameMover and self.settings.frameMover.editorMode then
        return self:ExitEditMode()
    end

    return self:EnterEditMode()
end

addon:RegisterEvent("PLAYER_LOGIN", function()
    addon:DelayedCall(1.2, function()
        addon:ApplyAccessibility()
    end)
end)

addon:RegisterEvent("SETTING_CHANGED", function(path)
    if not path then return end

    if strfind(path, "accessibility.", 1, true) or strfind(path, "notifications.", 1, true) then
        addon:ApplyAccessibility()
        RelayoutToasts()
    end
end)