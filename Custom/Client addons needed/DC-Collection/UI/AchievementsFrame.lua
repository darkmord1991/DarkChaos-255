--[[
    DC-Collection UI/AchievementsFrame.lua
    ======================================

    Retail-style Achievement UI.
    "Small clone" of the Blizzard Achievement Interface.

    Features:
    - Left side: Category list
    - Right side: Achievement list with details
    - Account-wide progress integration

    Author: DarkChaos-255
    Version: 1.0.0
]]

local DC = DCCollection
local L = DC and DC.L or {}

local AchievementsUI = {}
DC.AchievementsUI = AchievementsUI

-- ============================================================================
-- CONSTANTS
-- ============================================================================

local FRAME_WIDTH = 980
local FRAME_HEIGHT = 500
local CATEGORY_WIDTH = 180
local ACHIEVEMENT_HEIGHT = 80
local SCROLL_BAR_WIDTH = 26

-- ============================================================================
-- FRAME CREATION
-- ============================================================================

local function EnsureBlizzardAchievementUI()
    if LoadAddOn then
        pcall(LoadAddOn, "Blizzard_AchievementUI")
    end
    if AchievementFrame_LoadUI then
        pcall(AchievementFrame_LoadUI)
    end
end

local function Clamp(v, minV, maxV)
    if v < minV then return minV end
    if v > maxV then return maxV end
    return v
end

function AchievementsUI:Create(parent)
    if self.frame then
        return self.frame
    end

    -- Create container frame (to be embedded in MainFrame content)
    local frame = CreateFrame("Frame", "DCAchievementsFrame", parent)
    frame:SetAllPoints(parent)
    frame:Hide()

    if type(frame.SetClipsChildren) == "function" then
        frame:SetClipsChildren(true)
    end

    self.frame = frame
    return frame
end

function AchievementsUI:FitEmbeddedAchievementFrame()
    if not self.frame or not AchievementFrame then
        return
    end

    local availW = self.frame:GetWidth() or 0
    local availH = self.frame:GetHeight() or 0

    if availW <= 1 or availH <= 1 then
        return
    end

    -- Base size is the WotLK AchievementFrame footprint.
    local baseW = (AchievementFrame.GetWidth and AchievementFrame:GetWidth()) or FRAME_WIDTH
    local baseH = (AchievementFrame.GetHeight and AchievementFrame:GetHeight()) or FRAME_HEIGHT
    if baseW <= 1 then baseW = FRAME_WIDTH end
    if baseH <= 1 then baseH = FRAME_HEIGHT end

    local scale = math.min(availW / baseW, availH / baseH)
    scale = Clamp(scale, 0.5, 1)

    AchievementFrame:ClearAllPoints()
    AchievementFrame:SetPoint("CENTER", self.frame, "CENTER", 0, 0)
    if type(AchievementFrame.SetScale) == "function" then
        AchievementFrame:SetScale(scale)
    end

    if type(AchievementFrame.SetClampedToScreen) == "function" then
        AchievementFrame:SetClampedToScreen(true)
    end

    if AchievementFrameCloseButton then
        AchievementFrameCloseButton:Hide()
    end
end

-- ============================================================================
-- CATEGORY LIST
-- ============================================================================

function AchievementsUI:UpdateCategories()
    if not self.frame or not self.frame.categoryChild then return end
    
    local child = self.frame.categoryChild
    -- Clear existing
    for _, c in ipairs({child:GetChildren()}) do
        c:Hide()
        c:SetParent(nil)
    end

    -- Get Categories
    -- 3.3.5a clients commonly expose GetCategoryList() (varargs) rather than GetAchievementCategoryList().
    local categories = nil
    if type(GetAchievementCategoryList) == "function" then
        categories = GetAchievementCategoryList()
    end
    if type(categories) ~= "table" then
        if type(GetCategoryList) == "function" then
            local res = GetCategoryList()
            if type(res) == "table" then
                categories = res
            else
                categories = { GetCategoryList() }
            end
        else
            categories = {}
        end
    end
    
    -- If no categories found, show a message
    if #categories == 0 then
        local msg = child:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        msg:SetPoint("CENTER", child, "CENTER", 0, 0)
        msg:SetText("No achievement categories found.\nAchievement data may not be loaded yet.")
        child:SetHeight(100)
        return
    end
    
    local btnHeight = 24
    local yOffset = 0

    for i, catId in ipairs(categories) do
        local name, parentId
        if type(GetCategoryInfo) == "function" then
            name, parentId = GetCategoryInfo(catId)
        else
            name = tostring(catId)
        end
        
        local btn = CreateFrame("Button", nil, child)
        btn:SetSize(CATEGORY_WIDTH, btnHeight)
        btn:SetPoint("TOPLEFT", child, "TOPLEFT", 0, -yOffset)
        
        -- Text
        btn.text = btn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        btn.text:SetPoint("LEFT", btn, "LEFT", 10, 0)
        btn.text:SetText(name or tostring(catId))
        
        -- Highlight
        btn:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
        
        -- Selection
        if self.selectedCategory == catId then
            btn.text:SetTextColor(1, 1, 1)
            local sel = btn:CreateTexture(nil, "BACKGROUND")
            sel:SetAllPoints()
            sel:SetTexture("Interface\\QuestFrame\\UI-QuestLogTitleHighlight")
            sel:SetVertexColor(0.8, 0.8, 0, 0.5)
        else
            btn.text:SetTextColor(1, 0.82, 0)
        end

        btn:SetScript("OnClick", function()
            self.selectedCategory = catId
            self:UpdateCategories() -- Refresh selection
            self:UpdateAchievements(catId)
        end)

        yOffset = yOffset + btnHeight
    end

    child:SetHeight(yOffset)
    
    -- Select first if none selected
    if not self.selectedCategory and categories[1] then
        self.selectedCategory = categories[1]
        self:UpdateAchievements(categories[1])
    end
end

-- ============================================================================
-- ACHIEVEMENT LIST
-- ============================================================================

function AchievementsUI:UpdateAchievements(categoryId)
    if not self.frame or not self.frame.achievementChild or not categoryId then return end
    
    local child = self.frame.achievementChild
    -- Clear existing
    for _, c in ipairs({child:GetChildren()}) do
        c:Hide()
        c:SetParent(nil)
    end

    -- Get Achievements in Category
    -- In WotLK, GetCategoryInfo(categoryId) returns name/parent; achievements are accessed via GetAchievementInfo(categoryId, index).
    -- We need to iterate achievements.
    -- In 3.3.5a, we might need to scan all achievements or use an API if available.
    -- Actually, GetCategoryNumAchievements(categoryId) returns count.
    -- GetAchievementInfo(categoryId, index) gets info by index in category.

    local numAchievements = GetCategoryNumAchievements(categoryId)
    local btnHeight = ACHIEVEMENT_HEIGHT
    local width = self.frame.achievementList:GetWidth()
    local yOffset = 0

    for i = 1, numAchievements do
        local id, name, points, completed, month, day, year, description, flags, icon, rewardText, isGuild, wasEarnedByMe, earnedBy = GetAchievementInfo(categoryId, i)
        
        -- Check account-wide status from DC.achievements
        local accountCompleted = false
        if DC.achievements and DC.achievements[id] then
            accountCompleted = true
        end
        
        local isCompleted = completed or accountCompleted

        local btn = self:CreateAchievementButton(child, width, btnHeight)
        btn:SetPoint("TOPLEFT", child, "TOPLEFT", 0, -yOffset)
        
        -- Populate Data
        btn.name:SetText(name)
        btn.desc:SetText(description)
        btn.icon:SetTexture(icon)
        btn.points:SetText(points)
        
        if isCompleted then
            btn.name:SetTextColor(1, 0.82, 0) -- Gold
            btn.icon:SetDesaturated(false)
            btn.bg:SetTexture(0.2, 0.2, 0.2, 0.8)
            btn.border:SetVertexColor(1, 0.82, 0, 1) -- Gold border
            
            if accountCompleted and not completed then
                btn.status:SetText("Completed (Account)")
                btn.status:SetTextColor(0.5, 0.5, 1)
            else
                btn.status:SetText("Completed")
                btn.status:SetTextColor(0, 1, 0)
            end
        else
            btn.name:SetTextColor(0.6, 0.6, 0.6) -- Grey
            btn.icon:SetDesaturated(true)
            btn.bg:SetTexture(0.1, 0.1, 0.1, 0.8)
            btn.border:SetVertexColor(0.5, 0.5, 0.5, 1) -- Grey border
            btn.status:SetText("")
        end

        -- Reward
        if rewardText and rewardText ~= "" then
            btn.reward:SetText("Reward: " .. rewardText)
            btn.reward:Show()
        else
            btn.reward:Hide()
        end

        yOffset = yOffset + btnHeight + 5
    end

    child:SetHeight(yOffset)
end

function AchievementsUI:CreateAchievementButton(parent, width, height)
    local btn = CreateFrame("Frame", nil, parent)
    btn:SetSize(width, height)
    
    -- Background
    btn.bg = btn:CreateTexture(nil, "BACKGROUND")
    btn.bg:SetAllPoints()
    btn.bg:SetTexture(0.2, 0.2, 0.2, 0.8)
    
    -- Border (Gold/Grey)
    btn.border = btn:CreateTexture(nil, "BORDER")
    btn.border:SetPoint("TOPLEFT", -2, 2)
    btn.border:SetPoint("BOTTOMRIGHT", 2, -2)
    btn.border:SetTexture("Interface\\Tooltips\\UI-Tooltip-Border")
    
    -- Icon
    btn.icon = btn:CreateTexture(nil, "ARTWORK")
    btn.icon:SetSize(50, 50)
    btn.icon:SetPoint("LEFT", btn, "LEFT", 10, 0)
    
    -- Name
    btn.name = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    btn.name:SetPoint("TOPLEFT", btn.icon, "TOPRIGHT", 10, 0)
    btn.name:SetJustifyH("LEFT")
    
    -- Description
    btn.desc = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    btn.desc:SetPoint("TOPLEFT", btn.name, "BOTTOMLEFT", 0, -5)
    btn.desc:SetPoint("RIGHT", btn, "RIGHT", -40, 0)
    btn.desc:SetJustifyH("LEFT")
    btn.desc:SetHeight(24)
    
    -- Points (Shield)
    btn.shield = btn:CreateTexture(nil, "ARTWORK")
    btn.shield:SetSize(24, 24)
    btn.shield:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", -10, 10)
    btn.shield:SetTexture("Interface\\AchievementFrame\\UI-Achievement-Shields")
    btn.shield:SetTexCoord(0, 0.5, 0, 0.5) -- Standard shield
    
    btn.points = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    btn.points:SetPoint("CENTER", btn.shield, "CENTER", 0, 0)
    
    -- Status (Completed/Account)
    btn.status = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    btn.status:SetPoint("TOPRIGHT", btn, "TOPRIGHT", -10, -10)
    
    -- Reward
    btn.reward = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    btn.reward:SetPoint("BOTTOMLEFT", btn.icon, "BOTTOMRIGHT", 10, 5)
    btn.reward:SetTextColor(1, 0.5, 0) -- Orange
    
    return btn
end

function AchievementsUI:Refresh()
    -- Blizzard UI updates itself.
end

function AchievementsUI:Show()
    if not self.frame then return end

    EnsureBlizzardAchievementUI()

    if AchievementFrame then
        if not self._origParent then
            self._origParent = AchievementFrame:GetParent() or UIParent
        end

        AchievementFrame:Hide()
        AchievementFrame:SetParent(self.frame)
        AchievementFrame:ClearAllPoints()
        AchievementFrame:Show()

        -- Keep it fitted even if the main window is resized.
        if not self._fitHooked then
            self._fitHooked = true
            self.frame:SetScript("OnSizeChanged", function()
                AchievementsUI:FitEmbeddedAchievementFrame()
            end)
        end

        self:FitEmbeddedAchievementFrame()
    end

    self.frame:Show()
end

function AchievementsUI:Hide()
    if self.frame then
        self.frame:Hide()
    end

    if AchievementFrame and self._origParent and AchievementFrame:GetParent() == self.frame then
        AchievementFrame:Hide()
        AchievementFrame:SetParent(self._origParent)
        AchievementFrame:ClearAllPoints()
        AchievementFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)

        if type(AchievementFrame.SetScale) == "function" then
            AchievementFrame:SetScale(1)
        end

        if AchievementFrameCloseButton then
            AchievementFrameCloseButton:Show()
        end
    end
end
