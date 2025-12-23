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

function AchievementsUI:Create(parent)
    if self.frame then
        return self.frame
    end

    -- Create container frame (to be embedded in MainFrame content)
    local frame = CreateFrame("Frame", "DCAchievementsFrame", parent)
    frame:SetAllPoints(parent)
    frame:Hide()

    -- Background
    frame.bg = frame:CreateTexture(nil, "BACKGROUND")
    frame.bg:SetAllPoints()
    frame.bg:SetTexture(0, 0, 0, 0.3)

    -- 1. Categories (Left Side)
    local categoryList = CreateFrame("ScrollFrame", "DCAchievementsCategoryList", frame, "UIPanelScrollFrameTemplate")
    categoryList:SetPoint("TOPLEFT", frame, "TOPLEFT", 5, -5)
    categoryList:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 5, 5)
    categoryList:SetWidth(CATEGORY_WIDTH)
    
    -- Category List Background
    categoryList.bg = categoryList:CreateTexture(nil, "BACKGROUND")
    categoryList.bg:SetAllPoints()
    categoryList.bg:SetTexture(0, 0, 0, 0.5)

    local categoryChild = CreateFrame("Frame", nil, categoryList)
    categoryChild:SetSize(CATEGORY_WIDTH, 1)
    categoryList:SetScrollChild(categoryChild)
    
    frame.categoryList = categoryList
    frame.categoryChild = categoryChild

    -- 2. Achievements (Right Side)
    local achievementList = CreateFrame("ScrollFrame", "DCAchievementsList", frame, "UIPanelScrollFrameTemplate")
    achievementList:SetPoint("TOPLEFT", categoryList, "TOPRIGHT", 5, 0)
    achievementList:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -25, 5)
    
    -- Achievement List Background
    achievementList.bg = achievementList:CreateTexture(nil, "BACKGROUND")
    achievementList.bg:SetAllPoints()
    achievementList.bg:SetTexture(0, 0, 0, 0.2)

    local achievementChild = CreateFrame("Frame", nil, achievementList)
    achievementChild:SetSize(achievementList:GetWidth(), 1)
    achievementList:SetScrollChild(achievementChild)

    frame.achievementList = achievementList
    frame.achievementChild = achievementChild

    self.frame = frame
    return frame
end

-- ============================================================================
-- CATEGORY LIST
-- ============================================================================

function AchievementsUI:UpdateCategories()
    if not self.frame then return end
    
    local child = self.frame.categoryChild
    -- Clear existing
    for _, c in ipairs({child:GetChildren()}) do
        c:Hide()
        c:SetParent(nil)
    end

    -- Get Categories
    -- In 3.3.5a, GetAchievementCategoryList() returns a list of category IDs
    local categories = (GetAchievementCategoryList and GetAchievementCategoryList()) or {}
    
    local btnHeight = 24
    local yOffset = 0

    for i, catId in ipairs(categories) do
        local name, parentId = GetAchievementCategory(catId)
        
        local btn = CreateFrame("Button", nil, child)
        btn:SetSize(CATEGORY_WIDTH, btnHeight)
        btn:SetPoint("TOPLEFT", child, "TOPLEFT", 0, -yOffset)
        
        -- Text
        btn.text = btn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        btn.text:SetPoint("LEFT", btn, "LEFT", 10, 0)
        btn.text:SetText(name)
        
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
    if not self.frame or not categoryId then return end
    
    local child = self.frame.achievementChild
    -- Clear existing
    for _, c in ipairs({child:GetChildren()}) do
        c:Hide()
        c:SetParent(nil)
    end

    -- Get Achievements in Category
    -- GetAchievementCategory(categoryId) returns name, parentId
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
    if self.selectedCategory then
        self:UpdateAchievements(self.selectedCategory)
    end
end

function AchievementsUI:Show()
    if not self.frame then return end
    self.frame:Show()
    
    -- Request data if needed
    if DC.RequestAchievements then
        DC:RequestAchievements()
    end
    
    self:UpdateCategories()
end

function AchievementsUI:Hide()
    if not self.frame then return end
    self.frame:Hide()
end
