--[[
    DC-UI-Lib (Embedded in DC-AddonProtocol)
    Standard UI Library for DarkChaos Addons
]]

local libName = "DC-UI-Lib"
DC_UI = DC_UI or {}

-- Colors
DC_UI.Colors = {
    Background = {0.1, 0.1, 0.1, 0.95},
    Header = {0.05, 0.05, 0.05, 1.0},
    Border = {0.4, 0.4, 0.4, 1.0},
    Accent = {1.0, 0.8, 0.0, 1.0}, -- Gold
    Text = {1.0, 1.0, 1.0, 1.0},
    TextSecondary = {0.7, 0.7, 0.7, 1.0},
}

-- Match DC-Leaderboards UI style across DC addons
local BG_FELLEATHER = "Interface\\AddOns\\DC-AddonProtocol\\Textures\\Backgrounds\\FelLeather_512.tga"
local BG_TINT_ALPHA = 0.60

-- ============================================================================
-- Helper: Set Backdrop
-- ============================================================================
function DC_UI:SkinFrame(frame)
    if not frame then return end

    frame:SetBackdrop({
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 }
    })
    frame:SetBackdropColor(0, 0, 0, 0)

    if not frame.__dcLeaderboardsStyle then
        frame.__dcLeaderboardsStyle = true

        local bg = frame:CreateTexture(nil, "BACKGROUND", nil, 0)
        bg:SetAllPoints()
        bg:SetTexture(BG_FELLEATHER)
        if bg.SetHorizTile then bg:SetHorizTile(false) end
        if bg.SetVertTile then bg:SetVertTile(false) end

        local tint = frame:CreateTexture(nil, "BACKGROUND", nil, 1)
        tint:SetAllPoints()
        tint:SetTexture(0, 0, 0, BG_TINT_ALPHA)

        frame.__dcBg = bg
        frame.__dcTint = tint
    end
end

-- ============================================================================
-- Component: Main Window
-- ============================================================================
function DC_UI:CreateWindow(name, width, height, titleText)
    local f = CreateFrame("Frame", name, UIParent)
    f:SetSize(width, height)
    f:SetPoint("CENTER")
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    f:SetFrameStrata("HIGH")
    
    self:SkinFrame(f)
    
    -- Header
    local header = CreateFrame("Frame", nil, f)
    header:SetHeight(24)
    header:SetPoint("TOPLEFT", 1, -1)
    header:SetPoint("TOPRIGHT", -1, -1)
    
    header:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        tile = false, tileSize = 0, edgeSize = 0,
        insets = { left = 0, right = 0, top = 0, bottom = 0 }
    })
    local hc = self.Colors.Header
    header:SetBackdropColor(hc[1], hc[2], hc[3], hc[4])
    
    -- Logo
    local logo = header:CreateTexture(nil, "OVERLAY")
    logo:SetSize(16, 16)
    logo:SetPoint("LEFT", 5, 0)
    logo:SetTexture("Interface\\AddOns\\DC-AddonProtocol\\Media\\Logo.tga")
    f.Logo = logo

    -- Title
    local title = header:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("LEFT", logo, "RIGHT", 5, 0)
    title:SetText(titleText or "DarkChaos Window")
    title:SetTextColor(self.Colors.Accent[1], self.Colors.Accent[2], self.Colors.Accent[3])
    f.Title = title
    
    -- Close Button
    local close = CreateFrame("Button", nil, header)
    close:SetSize(20, 20)
    close:SetPoint("RIGHT", -2, 0)
    close:SetNormalTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Up")
    close:SetPushedTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Down")
    close:SetHighlightTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Highlight")
    close:SetScript("OnClick", function() f:Hide() end)
    f.CloseButton = close
    
    return f
end

-- ============================================================================
-- Component: Button
-- ============================================================================
function DC_UI:CreateButton(parent, width, height, text)
    local btn = CreateFrame("Button", nil, parent)
    btn:SetSize(width, height)
    
    -- Custom Backdrop
    btn:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        tile = false, tileSize = 0, edgeSize = 1,
        insets = { left = 0, right = 0, top = 0, bottom = 0 }
    })
    
    local function SetState(state)
        if state == "Normal" then
            btn:SetBackdropColor(0.2, 0.2, 0.2, 1)
            btn:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)
        elseif state == "Hover" then
            btn:SetBackdropColor(0.3, 0.3, 0.3, 1)
            local ac = DC_UI.Colors.Accent
            btn:SetBackdropBorderColor(ac[1], ac[2], ac[3], 1)
        elseif state == "Pushed" then
            btn:SetBackdropColor(0.1, 0.1, 0.1, 1)
            btn:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)
        end
    end
    
    SetState("Normal")
    
    btn:SetScript("OnEnter", function() SetState("Hover") end)
    btn:SetScript("OnLeave", function() SetState("Normal") end)
    btn:SetScript("OnMouseDown", function() SetState("Pushed") end)
    btn:SetScript("OnMouseUp", function() SetState("Hover") end)
    
    -- Text
    local fs = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    fs:SetPoint("CENTER")
    fs:SetText(text or "Button")
    btn:SetFontString(fs)
    
    return btn
end

-- ============================================================================
-- Component: ScrollFrame
-- ============================================================================
function DC_UI:CreateScrollFrame(parent)
    local scrollFrame = CreateFrame("ScrollFrame", nil, parent, "UIPanelScrollFrameTemplate")
    
    -- Skin the scrollbar (basic tinting for now)
    local scrollBar = _G[scrollFrame:GetName() .. "ScrollBar"]
    if scrollBar then
        -- Hide standard textures if we had custom ones, for now just leave default
    end
    
    local content = CreateFrame("Frame", nil, scrollFrame)
    content:SetSize(parent:GetWidth() - 25, parent:GetHeight())
    scrollFrame:SetScrollChild(content)
    
    return scrollFrame, content
end
