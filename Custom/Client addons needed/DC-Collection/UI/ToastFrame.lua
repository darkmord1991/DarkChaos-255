--[[
    DC-Collection UI/ToastFrame.lua
    ================================

    Toast notification system for collection updates.
    Similar to achievement toast or loot roll notifications.

    Author: DarkChaos-255
    Version: 1.0.0
]]

local DC = DCCollection
local L = DC and DC.L or {}

local ToastFrame = {}
DC.ToastFrame = ToastFrame

-- ============================================================================
-- CONSTANTS
-- ============================================================================

local TOAST_WIDTH = 280
local TOAST_HEIGHT = 60
local TOAST_DURATION = 5
local TOAST_FADE_OUT = 1
local MAX_TOASTS = 3

-- ============================================================================
-- TOAST QUEUE
-- ============================================================================

local toastQueue = {}
local activeToasts = {}

-- ============================================================================
-- CREATE TOAST FRAME
-- ============================================================================

local function CreateSingleToast(index)
    local frame = CreateFrame("Frame", "DCToastFrame" .. index, UIParent)
    frame:SetSize(TOAST_WIDTH, TOAST_HEIGHT)
    frame:SetPoint("TOP", UIParent, "TOP", 0, -100 - (index - 1) * (TOAST_HEIGHT + 10))
    frame:SetFrameStrata("DIALOG")
    frame:EnableMouse(true)
    frame:Hide()

    -- Background
    frame.bg = frame:CreateTexture(nil, "BACKGROUND")
    frame.bg:SetAllPoints()
    frame.bg:SetTexture(0, 0, 0, 0.85)

    -- Border
    frame.border = frame:CreateTexture(nil, "BORDER")
    frame.border:SetPoint("TOPLEFT", -2, 2)
    frame.border:SetPoint("BOTTOMRIGHT", 2, -2)
    frame.border:SetTexture(0.3, 0.3, 0.3, 1)

    -- Left glow bar (colored by type)
    frame.glowBar = frame:CreateTexture(nil, "ARTWORK")
    frame.glowBar:SetSize(4, TOAST_HEIGHT - 8)
    frame.glowBar:SetPoint("LEFT", frame, "LEFT", 4, 0)
    frame.glowBar:SetTexture(0.2, 0.8, 0.2, 1)

    -- Icon
    frame.icon = frame:CreateTexture(nil, "ARTWORK")
    frame.icon:SetSize(40, 40)
    frame.icon:SetPoint("LEFT", frame.glowBar, "RIGHT", 8, 0)
    frame.icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")

    -- Title
    frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    frame.title:SetPoint("TOPLEFT", frame.icon, "TOPRIGHT", 8, -3)
    frame.title:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -8, -3)
    frame.title:SetJustifyH("LEFT")
    frame.title:SetTextColor(0.6, 0.6, 0.6)

    -- Item name
    frame.itemName = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    frame.itemName:SetPoint("TOPLEFT", frame.title, "BOTTOMLEFT", 0, -2)
    frame.itemName:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -8, 0)
    frame.itemName:SetJustifyH("LEFT")
    frame.itemName:SetWordWrap(false)

    -- Subtitle (optional)
    frame.subtitle = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    frame.subtitle:SetPoint("TOPLEFT", frame.itemName, "BOTTOMLEFT", 0, -2)
    frame.subtitle:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -8, 0)
    frame.subtitle:SetJustifyH("LEFT")
    frame.subtitle:SetTextColor(0.5, 0.5, 0.5)

    -- Click to dismiss
    frame:SetScript("OnMouseDown", function(self)
        ToastFrame:DismissToast(self)
    end)

    return frame
end

-- ============================================================================
-- TOAST POOL
-- ============================================================================

local toastPool = {}

local function GetToastFrame()
    for _, toast in ipairs(toastPool) do
        if not toast.active then
            return toast
        end
    end

    if #toastPool < MAX_TOASTS then
        local newToast = CreateSingleToast(#toastPool + 1)
        table.insert(toastPool, newToast)
        return newToast
    end

    return nil
end

-- ============================================================================
-- SHOW TOAST
-- ============================================================================

local typeColors = {
    mounts     = { r = 0.4, g = 0.8, b = 0.4 },
    pets       = { r = 0.5, g = 0.5, b = 1.0 },
    titles     = { r = 1.0, g = 0.8, b = 0.2 },
    heirlooms  = { r = 0.9, g = 0.8, b = 0.5 },
    transmog   = { r = 0.6, g = 0.2, b = 0.8 },
    achievements = { r = 1.0, g = 0.9, b = 0.3 },
    wishlist   = { r = 1.0, g = 0.5, b = 0.0 },
    default    = { r = 0.3, g = 0.3, b = 0.3 },
}

local typeIcons = {
    mounts     = "Interface\\Icons\\Ability_Mount_RidingHorse",
    pets       = "Interface\\Icons\\INV_Box_PetCarrier_01",
    titles     = "Interface\\Icons\\INV_Scroll_11",
    heirlooms  = "Interface\\Icons\\INV_Misc_Rune_01",
    transmog   = "Interface\\Icons\\INV_Misc_Desecrated_ClothHelm",
    achievements = "Interface\\Icons\\Achievement_General",
    wishlist   = "Interface\\Icons\\INV_Misc_Map02",
}

local typeTitles = {
    mounts     = "New Mount Collected!",
    pets       = "New Pet Collected!",
    titles     = "New Title Earned!",
    heirlooms  = "New Heirloom Collected!",
    transmog   = "New Appearance Collected!",
    achievements = "Achievement Progress!",
    wishlist   = "Wishlist Alert!",
}

function ToastFrame:QueueToast(collType, itemName, icon, subtitle)
    table.insert(toastQueue, {
        collType = collType,
        itemName = itemName,
        icon = icon,
        subtitle = subtitle,
    })

    self:ProcessQueue()
end

function ToastFrame:ProcessQueue()
    if #toastQueue == 0 then
        return
    end

    local toast = GetToastFrame()
    if not toast then
        -- Try again after a short delay
        C_Timer.After(0.5, function() ToastFrame:ProcessQueue() end)
        return
    end

    local data = table.remove(toastQueue, 1)
    self:ShowSingleToast(toast, data)
end

function ToastFrame:ShowSingleToast(toast, data)
    local collType = data.collType or "default"
    local color = typeColors[collType] or typeColors.default

    -- Set glow bar color
    toast.glowBar:SetTexture(color.r, color.g, color.b, 1)

    -- Set icon
    toast.icon:SetTexture(data.icon or typeIcons[collType] or "Interface\\Icons\\INV_Misc_QuestionMark")

    -- Set title
    toast.title:SetText(typeTitles[collType] or "Collection Update")

    -- Set item name with rarity color
    toast.itemName:SetText(data.itemName or "Unknown")
    toast.itemName:SetTextColor(color.r, color.g, color.b)

    -- Set subtitle
    if data.subtitle then
        toast.subtitle:SetText(data.subtitle)
        toast.subtitle:Show()
    else
        toast.subtitle:Hide()
    end

    -- Show and animate
    toast:SetAlpha(0)
    toast:Show()
    toast.active = true

    -- Fade in
    UIFrameFadeIn(toast, 0.3, 0, 1)

    -- Play sound
    if DC:GetSetting("notificationSound") ~= false then
        PlaySound(8959) -- Or use 888 for achievement sound
    end

    -- Auto dismiss after duration
    toast.dismissTimer = C_Timer.NewTimer(TOAST_DURATION, function()
        ToastFrame:DismissToast(toast)
    end)
end

function ToastFrame:DismissToast(toast)
    if not toast or not toast.active then
        return
    end

    if toast.dismissTimer then
        toast.dismissTimer:Cancel()
        toast.dismissTimer = nil
    end

    -- Fade out
    UIFrameFadeOut(toast, TOAST_FADE_OUT, toast:GetAlpha(), 0)

    C_Timer.After(TOAST_FADE_OUT, function()
        toast:Hide()
        toast.active = false

        -- Reposition remaining toasts
        ToastFrame:RepositionToasts()

        -- Process any queued toasts
        ToastFrame:ProcessQueue()
    end)
end

function ToastFrame:RepositionToasts()
    local yOffset = 0
    for _, toast in ipairs(toastPool) do
        if toast.active and toast:IsShown() then
            toast:ClearAllPoints()
            toast:SetPoint("TOP", UIParent, "TOP", 0, -100 - yOffset)
            yOffset = yOffset + TOAST_HEIGHT + 10
        end
    end
end

-- ============================================================================
-- PUBLIC API
-- ============================================================================

function DC:ShowToast(collType, itemName, icon, subtitle)
    if not self:GetSetting("showNewItemToast") then
        -- Fallback to chat message
        local typeStr = L["TAB_" .. string.upper(collType)] or collType
        self:Print(string.format("|cff00ff00New %s:|r %s", typeStr, itemName))
        return
    end

    ToastFrame:QueueToast(collType, itemName, icon, subtitle)
end

-- ============================================================================
-- INITIALIZATION
-- ============================================================================

-- Create initial toast pool
for i = 1, MAX_TOASTS do
    local toast = CreateSingleToast(i)
    toast.active = false
    table.insert(toastPool, toast)
end
