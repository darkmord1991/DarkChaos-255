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

local addonNameGlobal = ...
local ADDON_PATH = "Interface\\AddOns\\" .. (addonNameGlobal or "DC-Collection") .. "\\"
local BG_FELLEATHER = ADDON_PATH .. "Textures\\Backgrounds\\FelLeather_512.tga"

-- ============================================================================
-- FRAME CREATION
-- ============================================================================

local function Clamp(v, minV, maxV)
    if v < minV then return minV end
    if v > maxV then return maxV end
    return v
end

local function HasAchievementApi()
    return type(GetCategoryList) == "function"
        and type(GetCategoryNumAchievements) == "function"
        and type(GetAchievementInfo) == "function"
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

    -- Left: Categories
    local categoryPanel = CreateFrame("Frame", nil, frame)
    categoryPanel:SetPoint("TOPLEFT", frame, "TOPLEFT", 10, -10)
    categoryPanel:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 10, 10)
    categoryPanel:SetWidth(CATEGORY_WIDTH + SCROLL_BAR_WIDTH)
    frame.categoryPanel = categoryPanel

    -- Use standard DC background
    categoryPanel.bg = categoryPanel:CreateTexture(nil, "BACKGROUND")
    categoryPanel.bg:SetAllPoints()
    categoryPanel.bg:SetTexture(BG_FELLEATHER)
    categoryPanel.bg:SetVertexColor(1, 1, 1, 0.8)
    
    local categoryTint = categoryPanel:CreateTexture(nil, "BORDER")
    categoryTint:SetAllPoints()
    categoryTint:SetTexture(0, 0, 0, 0.4)

    local catTitle = categoryPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    catTitle:SetPoint("TOPLEFT", categoryPanel, "TOPLEFT", 8, -8)
    catTitle:SetText("Categories")
    frame.categoryTitle = catTitle

    local categoryScroll = CreateFrame("ScrollFrame", "DCAchievementsCategoryScroll", categoryPanel, "UIPanelScrollFrameTemplate")
    categoryScroll:SetPoint("TOPLEFT", catTitle, "BOTTOMLEFT", -4, -6)
    categoryScroll:SetPoint("BOTTOMRIGHT", categoryPanel, "BOTTOMRIGHT", -26, 6)
    frame.categoryScroll = categoryScroll

    local categoryChild = CreateFrame("Frame", nil, categoryScroll)
    categoryChild:SetSize(CATEGORY_WIDTH, 1)
    categoryScroll:SetScrollChild(categoryChild)
    frame.categoryChild = categoryChild

    -- Right: Achievement list
    local achievementPanel = CreateFrame("Frame", nil, frame)
    achievementPanel:SetPoint("TOPLEFT", categoryPanel, "TOPRIGHT", 10, 0)
    achievementPanel:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -10, 10)
    frame.achievementPanel = achievementPanel

    -- Use standard DC background
    achievementPanel.bg = achievementPanel:CreateTexture(nil, "BACKGROUND")
    achievementPanel.bg:SetAllPoints()
    achievementPanel.bg:SetTexture(BG_FELLEATHER)
    achievementPanel.bg:SetVertexColor(1, 1, 1, 0.8)
    
    local achievementTint = achievementPanel:CreateTexture(nil, "BORDER")
    achievementTint:SetAllPoints()
    achievementTint:SetTexture(0, 0, 0, 0.4)

    local achTitle = achievementPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    achTitle:SetPoint("TOPLEFT", achievementPanel, "TOPLEFT", 8, -8)
    achTitle:SetText("Achievements")
    frame.achievementTitle = achTitle

    local achievementScroll = CreateFrame("ScrollFrame", "DCAchievementsListScroll", achievementPanel, "UIPanelScrollFrameTemplate")
    achievementScroll:SetPoint("TOPLEFT", achTitle, "BOTTOMLEFT", -4, -6)
    achievementScroll:SetPoint("BOTTOMRIGHT", achievementPanel, "BOTTOMRIGHT", -26, 6)
    frame.achievementList = achievementScroll

    local achievementChild = CreateFrame("Frame", nil, achievementScroll)
    achievementChild:SetSize(achievementPanel:GetWidth() - SCROLL_BAR_WIDTH, 1)
    achievementScroll:SetScrollChild(achievementChild)
    frame.achievementChild = achievementChild

    local apiNotice = achievementPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    apiNotice:SetPoint("CENTER", achievementPanel, "CENTER", 0, 0)
    apiNotice:SetText("Achievement data is not available on this client.")
    apiNotice:SetTextColor(0.8, 0.8, 0.8)
    apiNotice:Hide()
    frame.apiNotice = apiNotice

    self.frame = frame
    return frame
end

-- ============================================================================
-- CATEGORY LIST
-- ============================================================================

-- Store expanded state
AchievementsUI.expandedCategories = AchievementsUI.expandedCategories or {}

local function BuildCategoryTree(categories)
    local tree = {}
    local catMap = {}
    
    -- First pass: create nodes
    for _, catId in ipairs(categories) do
        local name, parentId = "", -1
        if type(GetCategoryInfo) == "function" then
            name, parentId = GetCategoryInfo(catId)
        end
        catMap[catId] = {
            id = catId,
            name = name or tostring(catId),
            parentId = parentId,
            children = {}
        }
    end
    
    -- Second pass: build tree
    for _, node in pairs(catMap) do
        if node.parentId and node.parentId ~= -1 and catMap[node.parentId] then
            table.insert(catMap[node.parentId].children, node)
        else
            table.insert(tree, node)
        end
    end
    
    return tree, catMap
end

local function CreateCategoryButton(parent, node, indent, frame)
    local btnHeight = 24
    local hasChildren = #node.children > 0
    
    local btn = CreateFrame("Button", nil, parent)
    btn:SetSize(CATEGORY_WIDTH - indent, btnHeight)
    btn.categoryId = node.id
    
    -- Expand/collapse icon for parent categories
    if hasChildren then
        btn.expandIcon = btn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        btn.expandIcon:SetPoint("LEFT", btn, "LEFT", indent, 0)
        btn.expandIcon:SetText(frame.expandedCategories[node.id] and "-" or "+")
        btn.expandIcon:SetTextColor(0.8, 0.8, 0.8)
    end
    
    -- Category text
    btn.text = btn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    btn.text:SetPoint("LEFT", btn, "LEFT", indent + (hasChildren and 15 or 5), 0)
    btn.text:SetText(node.name)
    
    -- Highlight
    btn:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
    
    -- Selection visual
    if frame.selectedCategory == node.id then
        btn.text:SetTextColor(1, 1, 0)
        local sel = btn:CreateTexture(nil, "BACKGROUND")
        sel:SetAllPoints()
        sel:SetTexture("Interface\\QuestFrame\\UI-QuestLogTitleHighlight")
        sel:SetVertexColor(0.8, 0.8, 0, 0.5)
    else
        btn.text:SetTextColor(1, 0.82, 0)
    end
    
    btn:SetScript("OnClick", function()
        if hasChildren then
            -- Toggle expand/collapse
            frame.expandedCategories[node.id] = not frame.expandedCategories[node.id]
            frame:UpdateCategories()
        else
            -- Select leaf category and show achievements
            frame.selectedCategory = node.id
            frame:UpdateCategories()
            frame:UpdateAchievements(node.id)
        end
    end)
    
    return btn, btnHeight
end

local function RenderCategoryTree(parent, tree, frame, yOffset, indent)
    yOffset = yOffset or 0
    indent = indent or 0
    
    for _, node in ipairs(tree) do
        local btn, height = CreateCategoryButton(parent, node, indent, frame)
        btn:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, -yOffset)
        yOffset = yOffset + height
        
        -- Render children if expanded
        if #node.children > 0 and frame.expandedCategories[node.id] then
            yOffset = RenderCategoryTree(parent, node.children, frame, yOffset, indent + 15)
        end
    end
    
    return yOffset
end

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
    
    -- Remove duplicates and add Dark Chaos category if missing
    local seen = {}
    local uniqueCategories = {}
    local hasDarkChaos = false
    
    for i, catId in ipairs(categories) do
        if not seen[catId] then
            seen[catId] = true
            table.insert(uniqueCategories, catId)
            
            -- Check if this is Dark Chaos category
            local name = ""
            if type(GetCategoryInfo) == "function" then
                name = GetCategoryInfo(catId)
            end
            if name and (name:find("Dark") or name:find("Chaos")) then
                hasDarkChaos = true
            end
        end
    end
    
    categories = uniqueCategories
    
    -- If no categories found, show a message
    if #categories == 0 then
        local msg = child:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        msg:SetPoint("CENTER", child, "CENTER", 0, 0)
        msg:SetText("No achievement categories found.\nAchievement data may not be loaded yet.")
        child:SetHeight(100)
        return
    end
    
    -- Build tree structure
    local tree, catMap = BuildCategoryTree(categories)
    
    -- Render tree
    local totalHeight = RenderCategoryTree(child, tree, self, 0, 0)
    child:SetHeight(math.max(totalHeight, 100))
    
    -- Select first leaf category if none selected
    if not self.selectedCategory and categories[1] then
        -- Find first leaf category (no children)
        local function FindFirstLeaf(nodes)
            for _, node in ipairs(nodes) do
                if #node.children == 0 then
                    return node.id
                else
                    local leafId = FindFirstLeaf(node.children)
                    if leafId then return leafId end
                end
            end
            return nil
        end
        
        local firstLeaf = FindFirstLeaf(tree)
        if firstLeaf then
            self.selectedCategory = firstLeaf
            self:UpdateAchievements(firstLeaf)
        end
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

    if type(GetCategoryNumAchievements) ~= "function" or type(GetAchievementInfo) ~= "function" then
        if self.frame.apiNotice then
            self.frame.apiNotice:Show()
        end
        child:SetHeight(100)
        return
    end

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
    if self.frame and self.frame:IsShown() then
        self:UpdateCategories()
    end
end

function AchievementsUI:Show()
    if not self.frame then return end

    self.frame:Show()

    if self.frame.apiNotice then
        if not HasAchievementApi() then
            self.frame.apiNotice:Show()
        else
            self.frame.apiNotice:Hide()
        end
    end

    if HasAchievementApi() then
        self:UpdateCategories()
    end
end

function AchievementsUI:Hide()
    if self.frame then
        self.frame:Hide()
    end
end
