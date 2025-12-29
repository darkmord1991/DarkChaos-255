# Retail Client Features Portable via AIO Addon

## Document Purpose
Evaluate retail WoW client features that can be adapted and ported to Dark Chaos 3.3.5a client using the AIO (Addon Interface Overlay) addon framework and Lua modifications.

---

## 1. AIO Framework Overview

### What is AIO?
AIO (Addon Interface Overlay) enables **server-controlled client addons** that:
- Sync data between server and client in real-time
- Create custom UI frames and elements
- Override or extend default client behavior
- Distribute addons automatically to players (no manual install)

### AIO Technical Capabilities
| Capability | Description |
|------------|-------------|
| **Frame Creation** | Custom windows, buttons, textures |
| **Data Binding** | Server variables → Client display |
| **Event Handling** | Custom events and hooks |
| **UI Modification** | Alter existing UI elements |
| **Combat Log** | Parse and display custom combat info |
| **Tooltips** | Enhanced item/spell tooltips |
| **Chat Integration** | Custom chat channels and messages |

---

## 2. Retail Features Analysis

### Feature Categories

| Category | Retail Examples | AIO Adaptability |
|----------|-----------------|------------------|
| **Reward Systems** | Great Vault, Weekly Cache | ⭐⭐⭐⭐⭐ High |
| **Collection Systems** | Transmog, Mounts, Pets | ⭐⭐⭐⭐ High |
| **Progression UI** | M+ Rating, Renown | ⭐⭐⭐⭐⭐ High |
| **Content Scaling** | Chromie Time, Timewalking | ⭐⭐⭐ Medium |
| **Combat Systems** | Affixes, Mechanics | ⭐⭐⭐⭐ High |
| **Quality of Life** | Adventure Guide, Group Finder | ⭐⭐⭐⭐ High |

---

## 3. High-Priority Retail Features for AIO

### 3.1 Great Vault System

**Retail Feature:**
- Weekly reward cache with 9 possible item choices
- Tracks dungeons, raids, PvP participation
- Players choose 1 reward from available options

**AIO Implementation:**
```lua
-- Great Vault Frame (conceptual)
local GreatVault = CreateFrame("Frame", "DarkChaosVault", UIParent)
GreatVault:SetSize(600, 400)

-- Tier slots
for i = 1, 9 do
    local slot = CreateFrame("Button", "VaultSlot"..i, GreatVault)
    slot:SetScript("OnClick", function()
        -- Request reward from server
        AIO.SendAddonMessage("VaultClaim", i)
    end)
end

-- Server data sync
AIO.RegisterEvent("VAULT_UPDATE", function(data)
    -- data contains: {dungeons=4, raids=2, pvp=1500, rewards={...}}
    UpdateVaultDisplay(data)
end)
```

**Server Side (Eluna):**
```lua
local function CalculateVaultRewards(player)
    local dungeons = GetMythicPlusDungeonCount(player)
    local raids = GetRaidBossKills(player)
    local pvp = GetPvPHonor(player)
    
    local rewards = {}
    if dungeons >= 1 then table.insert(rewards, GenerateDungeonReward(1)) end
    if dungeons >= 4 then table.insert(rewards, GenerateDungeonReward(2)) end
    if dungeons >= 8 then table.insert(rewards, GenerateDungeonReward(3)) end
    -- ... similar for raids and pvp
    
    return rewards
end
```

**Dark Chaos Status:** Mythic+ already exists, Great Vault UI is natural extension!

---

### 3.2 Mythic+ Rating Display

**Retail Feature:**
- Score displayed on character
- Leaderboards and rankings
- Color-coded difficulty indicators

**AIO Implementation:**
```lua
-- M+ Score Display on Character Frame
local ScoreFrame = CreateFrame("Frame", "MythicScoreFrame", PaperDollFrame)
ScoreFrame:SetPoint("BOTTOMLEFT", CharacterNameFrame, "TOPLEFT", 0, 5)

local ScoreText = ScoreFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
ScoreText:SetText("|cff00ff00M+ Score: 2450|r")

-- Color by score tier
local function GetScoreColor(score)
    if score >= 3000 then return "|cffff8000" -- Legendary (orange)
    elseif score >= 2500 then return "|cffa335ee" -- Epic (purple)
    elseif score >= 2000 then return "|cff0070dd" -- Rare (blue)
    elseif score >= 1500 then return "|cff1eff00" -- Uncommon (green)
    else return "|cffffffff" -- Common (white)
    end
end

-- Update from server
AIO.RegisterEvent("MYTHIC_SCORE_UPDATE", function(score)
    local color = GetScoreColor(score)
    ScoreText:SetText(color.."M+ Score: "..score.."|r")
end)
```

**Dark Chaos Status:** Already has Mythic+ - just needs UI polish!

---

### 3.3 Transmog/Wardrobe Collection

**Retail Feature:**
- Account-wide appearance collection
- Preview appearances before applying
- Sets tracking and completion

**AIO Implementation:**
```lua
-- Wardrobe Collection Frame
local Wardrobe = CreateFrame("Frame", "DCWardrobe", UIParent)
Wardrobe:SetSize(700, 500)

-- Category tabs
local categories = {"Head", "Shoulder", "Chest", "Hands", "Waist", "Legs", "Feet", "Weapon"}
for i, cat in ipairs(categories) do
    local tab = CreateFrame("Button", "WardrobeTab"..i, Wardrobe)
    tab:SetText(cat)
    tab:SetScript("OnClick", function()
        AIO.SendAddonMessage("WardrobeCategory", cat)
    end)
end

-- Appearance grid (8x6 = 48 items per page)
local grid = {}
for i = 1, 48 do
    grid[i] = CreateFrame("Button", "WardrobeSlot"..i, Wardrobe)
    grid[i]:SetSize(50, 50)
    grid[i]:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        ShowAppearanceTooltip(self.appearanceId)
    end)
    grid[i]:SetScript("OnClick", function(self)
        PreviewAppearance(self.appearanceId)
    end)
end

-- Preview model
local PreviewModel = CreateFrame("DressUpModel", "WardrobePreview", Wardrobe)
PreviewModel:SetSize(300, 400)
```

**Server Backend:**
```lua
-- Track collected appearances
CREATE TABLE character_wardrobe (
    guid INT,
    appearance_id INT,
    slot INT,
    collected_date DATETIME,
    PRIMARY KEY (guid, appearance_id)
);

-- Eluna: Check appearance unlock on item acquisition
local function OnLootItem(event, player, item, count)
    local displayId = item:GetDisplayId()
    local slot = GetItemSlot(item:GetEntry())
    
    -- Check if already collected
    if not HasAppearance(player:GetGUID(), displayId) then
        SaveAppearance(player:GetGUID(), displayId, slot)
        player:SendBroadcastMessage("New appearance unlocked!")
        AIO.SendAddonMessage(player, "APPEARANCE_UNLOCKED", displayId)
    end
end
```

**Dark Chaos Status:** Would be new feature - high player value!

---

### 3.4 Adventure Guide / Dungeon Journal

**Retail Feature:**
- Boss encounter information
- Loot tables viewable
- Strategy tips and abilities

**AIO Implementation:**
```lua
-- Dungeon Journal Frame
local Journal = CreateFrame("Frame", "DCDungeonJournal", UIParent)
Journal:SetSize(800, 600)

-- Dungeon list (left panel)
local DungeonList = CreateFrame("ScrollFrame", "JournalDungeonList", Journal)
DungeonList:SetSize(200, 550)

-- Boss info (right panel)
local BossInfo = CreateFrame("Frame", "JournalBossInfo", Journal)
BossInfo:SetSize(580, 400)

-- Boss model
local BossModel = CreateFrame("PlayerModel", "JournalBossModel", BossInfo)
BossModel:SetSize(200, 300)

-- Abilities list
local AbilityList = CreateFrame("ScrollFrame", "JournalAbilities", BossInfo)

-- Loot table
local LootTable = CreateFrame("Frame", "JournalLoot", Journal)
local function CreateLootSlots()
    for i = 1, 20 do
        local slot = CreateFrame("Button", "JournalLootSlot"..i, LootTable)
        slot:SetSize(40, 40)
        slot:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetHyperlink(self.itemLink)
        end)
    end
end

-- Server data request
AIO.RegisterEvent("JOURNAL_DUNGEON_DATA", function(data)
    -- data: {bosses={...}, loot={...}, description="..."}
    PopulateJournal(data)
end)
```

**Server Backend:**
```lua
-- Boss data tables
CREATE TABLE dungeon_journal_bosses (
    boss_id INT PRIMARY KEY,
    dungeon_id INT,
    name VARCHAR(100),
    description TEXT,
    model_id INT,
    abilities TEXT -- JSON array of ability IDs
);

CREATE TABLE dungeon_journal_abilities (
    ability_id INT PRIMARY KEY,
    boss_id INT,
    spell_id INT,
    name VARCHAR(100),
    description TEXT,
    icon_id INT,
    mechanic_type ENUM('Tank', 'Healer', 'DPS', 'Everyone')
);
```

**Dark Chaos Status:** Would significantly help new players with Mythic+!

---

### 3.5 Personal Loot UI / Bonus Roll

**Retail Feature:**
- Personal loot with tradeable window
- Bonus roll for extra loot chances
- Token/currency spending for gear

**AIO Implementation:**
```lua
-- Bonus Roll Frame
local BonusRoll = CreateFrame("Frame", "DCBonusRoll", UIParent)
BonusRoll:SetSize(300, 100)
BonusRoll:SetPoint("TOP", 0, -200)

local RollButton = CreateFrame("Button", "BonusRollButton", BonusRoll, "UIPanelButtonTemplate")
RollButton:SetText("Bonus Roll (25 Valor)")
RollButton:SetScript("OnClick", function()
    AIO.SendAddonMessage("BONUS_ROLL", bossId)
end)

-- Timer bar
local TimerBar = CreateFrame("StatusBar", "BonusRollTimer", BonusRoll)
TimerBar:SetSize(250, 20)
TimerBar:SetMinMaxValues(0, 15)

-- Result display
AIO.RegisterEvent("BONUS_ROLL_RESULT", function(result)
    if result.success then
        ShowLootWon(result.itemId)
    else
        ShowGoldReward(result.gold)
    end
end)
```

**Dark Chaos Status:** Complements Mythic+ loot system nicely!

---

### 3.6 Weekly Quests / Objectives Panel

**Retail Feature:**
- Weekly reset objectives
- Progress tracking
- Reward previews

**AIO Implementation:**
```lua
-- Weekly Objectives Frame
local WeeklyPanel = CreateFrame("Frame", "DCWeeklyObjectives", UIParent)
WeeklyPanel:SetSize(350, 450)

-- Objective rows
local objectives = {
    {name = "Complete 8 Mythic+ Dungeons", type = "dungeon", target = 8},
    {name = "Kill 3 Raid Bosses", type = "raid", target = 3},
    {name = "Earn 1500 PvP Honor", type = "pvp", target = 1500},
    {name = "Complete 25 Daily Quests", type = "quest", target = 25},
}

for i, obj in ipairs(objectives) do
    local row = CreateFrame("Frame", "WeeklyRow"..i, WeeklyPanel)
    row:SetSize(320, 50)
    
    local name = row:CreateFontString(nil, "OVERLAY")
    name:SetText(obj.name)
    
    local progress = CreateFrame("StatusBar", "WeeklyProgress"..i, row)
    progress:SetMinMaxValues(0, obj.target)
    
    local text = progress:CreateFontString(nil, "OVERLAY")
    text:SetText("0/"..obj.target)
end

-- Time until reset display
local ResetTimer = WeeklyPanel:CreateFontString(nil, "OVERLAY")
local function UpdateResetTimer()
    local timeLeft = GetTimeUntilWeeklyReset()
    ResetTimer:SetText("Resets in: "..FormatTime(timeLeft))
end
```

**Dark Chaos Status:** Excellent for retention - drives weekly engagement!

---

## 4. Medium-Priority Retail Features

### 4.1 Talent Loadouts / Dual Spec Enhancement

**Retail Feature:**
- Multiple talent loadout saves
- Quick swap between builds
- Import/export strings

**AIO Approach:**
```lua
-- Loadout manager (extends existing dual spec)
local LoadoutManager = CreateFrame("Frame", "DCLoadoutManager", TalentFrame)

-- Save loadout button
local SaveButton = CreateFrame("Button", "SaveLoadoutBtn", LoadoutManager)
SaveButton:SetScript("OnClick", function()
    local loadout = GetCurrentTalentLoadout()
    local name = GetLoadoutName()
    AIO.SendAddonMessage("SAVE_LOADOUT", {name = name, talents = loadout})
end)

-- Loadout dropdown
local LoadoutDropdown = CreateFrame("Frame", "LoadoutDropdown", LoadoutManager, "UIDropDownMenuTemplate")
UIDropDownMenu_Initialize(LoadoutDropdown, function(self, level)
    local loadouts = GetSavedLoadouts()
    for _, loadout in ipairs(loadouts) do
        local info = UIDropDownMenu_CreateInfo()
        info.text = loadout.name
        info.func = function() ApplyLoadout(loadout.id) end
        UIDropDownMenu_AddButton(info)
    end
end)
```

### 4.2 Group Finder Enhancement

**Retail Feature:**
- Custom group listings
- Filter by key level/rating
- Applicant management

**AIO Approach:**
```lua
-- Enhanced LFG Frame
local EnhancedLFG = CreateFrame("Frame", "DCGroupFinder", UIParent)

-- Create listing
local ListingFrame = CreateFrame("Frame", "LFGListingCreate", EnhancedLFG)
local TitleInput = CreateFrame("EditBox", "LFGTitle", ListingFrame)
local DescInput = CreateFrame("EditBox", "LFGDesc", ListingFrame)
local KeyLevelDropdown = CreateFrame("Frame", "LFGKeyLevel", ListingFrame, "UIDropDownMenuTemplate")

-- Browse listings
local ListingsScroll = CreateFrame("ScrollFrame", "LFGListings", EnhancedLFG)
-- ... rows with: Title, Leader, Key Level, Current Members, Apply button

-- Applicant queue
local ApplicantFrame = CreateFrame("Frame", "LFGApplicants", EnhancedLFG)
-- Shows: Name, Class, iLvl, M+ Score, Accept/Decline buttons
```

### 4.3 Professions UI Modernization

**Retail Feature:**
- Recipe tracking
- Profession knowledge tree
- Quality tiers

**AIO Approach:**
```lua
-- Enhanced profession frame
local ProfessionUI = CreateFrame("Frame", "DCProfessionUI", TradeSkillFrame)

-- Recipe progress tracking
local TrackedRecipes = CreateFrame("Frame", "TrackedRecipes", ProfessionUI)

-- Crafting queue
local CraftQueue = CreateFrame("Frame", "CraftQueue", ProfessionUI)
-- Queue multiple items for crafting

-- Material calculator
local MaterialCalc = CreateFrame("Frame", "MaterialCalculator", ProfessionUI)
-- Input desired quantity, shows total materials needed
```

---

## 5. Quality of Life Features

### 5.1 Loot Spec / Transmog Spec

```lua
-- Quick spec switch for loot
local LootSpecFrame = CreateFrame("Frame", "DCLootSpec", PaperDollFrame)

local specs = {"Current Spec", "Holy", "Protection", "Retribution"}  -- Paladin example
local LootSpecDropdown = CreateFrame("Frame", "LootSpecDropdown", LootSpecFrame, "UIDropDownMenuTemplate")
UIDropDownMenu_Initialize(LootSpecDropdown, function()
    for i, spec in ipairs(specs) do
        local info = UIDropDownMenu_CreateInfo()
        info.text = spec
        info.func = function() 
            AIO.SendAddonMessage("SET_LOOT_SPEC", i)
        end
        UIDropDownMenu_AddButton(info)
    end
end)
```

### 5.2 Quick Keystone Display

```lua
-- Show keystone in bags/character panel
local KeystoneDisplay = CreateFrame("Frame", "DCKeystoneDisplay", PaperDollFrame)
KeystoneDisplay:SetSize(200, 50)

local KeystoneIcon = KeystoneDisplay:CreateTexture(nil, "ARTWORK")
KeystoneIcon:SetSize(40, 40)

local KeystoneText = KeystoneDisplay:CreateFontString(nil, "OVERLAY")
-- "Halls of Lightning +15"

-- Server sync
AIO.RegisterEvent("KEYSTONE_UPDATE", function(dungeon, level)
    KeystoneText:SetText(dungeon.." +"..level)
    KeystoneIcon:SetTexture(GetDungeonIcon(dungeon))
end)
```

### 5.3 Achievement Points Display Enhancement

```lua
-- Enhanced achievement display
local AchievementEnhanced = CreateFrame("Frame", "DCAchievementFrame", AchievementFrame)

-- Category completion bars
local CategoryProgress = CreateFrame("Frame", "AchievementCategoryProgress", AchievementEnhanced)

-- Nearest achievements (closest to completion)
local NearestAchievements = CreateFrame("Frame", "NearestAchievements", AchievementEnhanced)
```

---

## 6. Combat & Mechanics Features

### 6.1 Affix Display (Already Relevant for Mythic+)

```lua
-- Affix display frame in dungeons
local AffixFrame = CreateFrame("Frame", "DCAffixDisplay", UIParent)
AffixFrame:SetSize(200, 100)
AffixFrame:SetPoint("TOPRIGHT", -10, -150)

-- Affix icons with tooltips
local affixes = {}
for i = 1, 4 do
    affixes[i] = CreateFrame("Button", "AffixIcon"..i, AffixFrame)
    affixes[i]:SetSize(40, 40)
    affixes[i]:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:SetText(self.affixName)
        GameTooltip:AddLine(self.affixDesc, 1, 1, 1, true)
        GameTooltip:Show()
    end)
end

-- Active affix warnings
local function ShowAffixWarning(affixId, message)
    UIErrorsFrame:AddMessage(message, 1, 0.5, 0)
end
```

### 6.2 Interrupt Tracker

```lua
-- Party interrupt tracker
local InterruptTracker = CreateFrame("Frame", "DCInterruptTracker", UIParent)
InterruptTracker:SetSize(250, 150)

-- Track party member interrupt CDs
local interruptSpells = {
    [6552] = 10,   -- Pummel
    [2139] = 24,   -- Counterspell
    [1766] = 10,   -- Kick
    -- etc
}

local function UpdateInterruptCD(unit, spellId, cd)
    -- Update display for unit's interrupt cooldown
end

-- Register combat log events
InterruptTracker:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
InterruptTracker:SetScript("OnEvent", function(self, event)
    local _, eventType, _, sourceGUID, _, _, _, destGUID, _, _, _, spellId = CombatLogGetCurrentEventInfo()
    if eventType == "SPELL_CAST_SUCCESS" and interruptSpells[spellId] then
        local unit = GetUnitFromGUID(sourceGUID)
        UpdateInterruptCD(unit, spellId, interruptSpells[spellId])
    end
end)
```

### 6.3 Death Recap

```lua
-- Death recap showing killing blow and damage sources
local DeathRecap = CreateFrame("Frame", "DCDeathRecap", UIParent)
DeathRecap:SetSize(400, 300)

-- Damage entries
local damageLog = {}
local function TrackDamage(timestamp, source, amount, school, spell)
    table.insert(damageLog, {time = timestamp, source = source, amount = amount, school = school, spell = spell})
    -- Keep last 10 seconds
    while #damageLog > 0 and (GetTime() - damageLog[1].time) > 10 do
        table.remove(damageLog, 1)
    end
end

-- Show on death
local function ShowDeathRecap()
    -- Display damageLog in frame
    for i, entry in ipairs(damageLog) do
        -- Create row showing source, spell, damage, school
    end
end

RegisterEvent("PLAYER_DEAD", ShowDeathRecap)
```

---

## 7. Implementation Priority Matrix

| Feature | Player Value | Implementation Effort | AIO Complexity | Priority |
|---------|--------------|----------------------|----------------|----------|
| Great Vault UI | ⭐⭐⭐⭐⭐ | Medium | Medium | **P1** |
| M+ Rating Display | ⭐⭐⭐⭐⭐ | Low | Low | **P1** |
| Affix Display | ⭐⭐⭐⭐⭐ | Low | Low | **P1** |
| Weekly Objectives | ⭐⭐⭐⭐ | Medium | Medium | **P1** |
| Dungeon Journal | ⭐⭐⭐⭐ | High | Medium | **P2** |
| Transmog Wardrobe | ⭐⭐⭐⭐ | High | High | **P2** |
| Group Finder+ | ⭐⭐⭐⭐ | Medium | Medium | **P2** |
| Bonus Roll | ⭐⭐⭐ | Medium | Low | **P2** |
| Talent Loadouts | ⭐⭐⭐ | Medium | Medium | **P3** |
| Interrupt Tracker | ⭐⭐⭐ | Low | Low | **P3** |
| Death Recap | ⭐⭐⭐ | Medium | Medium | **P3** |
| Profession UI+ | ⭐⭐ | High | High | **P4** |

---

## 8. Development Roadmap

### Phase 1: Core Mythic+ Enhancements (Weeks 1-4)
1. M+ Rating display on character frame
2. Affix display in dungeons
3. Great Vault weekly cache UI
4. Weekly objectives panel

### Phase 2: Progression Systems (Weeks 5-8)
1. Dungeon Journal for all M+ dungeons
2. Enhanced Group Finder
3. Bonus Roll system

### Phase 3: Collection Systems (Weeks 9-12)
1. Transmog Wardrobe foundation
2. Appearance collection tracking
3. Set completion UI

### Phase 4: Quality of Life (Weeks 13-16)
1. Talent loadout manager
2. Interrupt tracker
3. Death recap
4. Combat log enhancements

---

## 9. Conclusion

### Best Value Features for Dark Chaos

**Immediate Implementation (Already Have Infrastructure):**
1. ✅ Mythic+ Rating display - Server already tracks, just needs UI
2. ✅ Affix display - Already have affixes, show them better
3. ✅ Great Vault - Natural extension of weekly M+ rewards

**High Value Additions:**
1. 🎯 Dungeon Journal - Help players learn M+ mechanics
2. 🎯 Weekly Objectives - Drive engagement and retention
3. 🎯 Transmog Collection - Long-term collection goal

**AIO Framework Strength:**
Dark Chaos AIO can implement 80%+ of retail convenience features with NO client patch required!

---

## References
- AIO Framework: https://github.com/Rochet2/AIO
- Wowpedia Mythic+: https://wowpedia.fandom.com/wiki/Mythic%2B
- Wowpedia Great Vault: https://wowpedia.fandom.com/wiki/Great_Vault
- Wowpedia Appearances: https://wowpedia.fandom.com/wiki/Appearances
- WoW Lua API: https://wowpedia.fandom.com/wiki/World_of_Warcraft_API
