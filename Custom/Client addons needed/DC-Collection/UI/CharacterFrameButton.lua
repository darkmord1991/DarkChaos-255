--[[
    DC-Collection UI/CharacterFrameButton.lua
    ==========================================
    
    Adds a button to CharacterFrame to open DC-Collection
    Positioned to avoid collision with DC-ItemUpgrade buttons
]]

local DC = DCCollection
if not DC then return end

local BUTTON_SIZE = 32
local BUTTON_OFFSET_Y = -169  -- Below DC-ItemUpgrade buttons at -95 and -132

local function CreateCharacterFrameButton()
    if not CharacterFrame then
        return
    end

    -- Don't create if already exists
    if _G["DC_Collection_CharFrameButton"] then
        return
    end

    local button = CreateFrame("Button", "DC_Collection_CharFrameButton", CharacterFrame)
    button:SetSize(BUTTON_SIZE, BUTTON_SIZE)
    button:SetPoint("TOPRIGHT", CharacterFrame, "TOPRIGHT", 0, BUTTON_OFFSET_Y)

    -- Icon
    local icon = button:CreateTexture(nil, "BACKGROUND")
    icon:SetSize(28, 28)
    icon:SetPoint("CENTER")
    icon:SetTexture("Interface\\AddOns\\DC-Collection\\Textures\\Icons\\Collection_64.tga")
    button.icon = icon

    -- Border
    local border = button:CreateTexture(nil, "OVERLAY")
    border:SetSize(64, 64)
    border:SetPoint("CENTER")
    border:SetTexture("Interface\\Buttons\\UI-Quickslot2")
    button.border = border

    -- Highlight
    local highlight = button:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetAllPoints()
    highlight:SetTexture("Interface\\Buttons\\ButtonHilight-Square")
    highlight:SetBlendMode("ADD")

    -- Click handler
    button:SetScript("OnClick", function(self)
        -- Prefer the canonical API.
        if type(DC.ToggleMainFrame) == "function" then
            DC:ToggleMainFrame()
            return
        end

        if DC.MainFrame and DC.MainFrame:IsShown() then
            DC.MainFrame:Hide()
        else
            if type(DC.ShowMainFrame) == "function" then
                DC:ShowMainFrame()
            elseif type(DC.ShowMainUI) == "function" then
                -- Backward/forward-compat alias.
                DC:ShowMainUI()
            end
        end
    end)

    -- Tooltip
    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Collection", 1, 1, 1)
        GameTooltip:AddLine("Open your account-wide collection", 0.8, 0.8, 0.8, true)
        GameTooltip:AddLine(" ", 1, 1, 1)
        GameTooltip:AddLine("|cff00ff00Click|r to toggle", 0.7, 0.7, 0.7)
        GameTooltip:Show()
    end)

    button:SetScript("OnLeave", function(self)
        GameTooltip:Hide()
    end)

    DC.CharacterFrameButton = button
end

-- Create button on PLAYER_LOGIN
local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_LOGIN")
frame:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_LOGIN" then
        CreateCharacterFrameButton()
    end
end)
