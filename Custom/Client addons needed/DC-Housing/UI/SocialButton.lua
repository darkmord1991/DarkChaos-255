-- DC-Housing: a "Decorations" button attached to the Guild tab of the
-- standard social window (FriendsFrame). Only shown while the Guild tab
-- (tab 3 in 3.3.5a) is selected, anchored just outside the right edge so
-- it never overlaps the roster or the guild control buttons.
local DC = DCHousing
local L = DCHousingLocale

local GUILD_TAB = 3
local button

local function UpdateVisibility()
    if not button or not FriendsFrame then
        return
    end
    if FriendsFrame:IsShown() and FriendsFrame.selectedTab == GUILD_TAB then
        button:Show()
    else
        button:Hide()
    end
end

local function CreateButton()
    if button or not FriendsFrame then
        return
    end

    button = CreateFrame("Button", "DCHousingSocialButton", FriendsFrame,
        "UIPanelButtonTemplate")
    button:SetWidth(120)
    button:SetHeight(24)
    button:SetText("|cffFFCC00DC|r Decorations")
    -- Side tab sticking out the right edge of the social window.
    button:SetPoint("TOPLEFT", FriendsFrame, "TOPRIGHT", -4, -36)
    button:SetScript("OnClick", function()
        if DC.Catalog then
            DC.Catalog:Toggle()
        end
    end)
    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine("Guild House Decorations")
        GameTooltip:AddLine(
            "Browse, preview and place decorations in your guild house.",
            1, 1, 1, true)
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", GameTooltip_Hide)

    -- Track tab switches + window show.
    FriendsFrame:HookScript("OnShow", UpdateVisibility)
    if type(FriendsFrameTab_OnClick) == "function" then
        hooksecurefunc("FriendsFrameTab_OnClick", UpdateVisibility)
    end
    UpdateVisibility()
end

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent", CreateButton)
