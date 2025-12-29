# Client Quality of Life Improvements Evaluation

## Document Purpose
Focus on practical QoL features adaptable via AIO addon framework, popular addon integrations, and TSWoW development tooling that could benefit Dark Chaos without interfering with existing implementations.

**Note:** Transmog Collection and Great Vault + UI are already implemented in Dark Chaos.

---

## 1. Popular WotLK Addon Features to Integrate via AIO

### Priority Matrix

| Feature | Source Addon | Implementation | Player Value | Effort |
|---------|--------------|----------------|--------------|--------|
| Auto Sell Junk | Leatrix Plus | AIO/Server | Very High | Low |
| Auto Repair | Leatrix Plus | AIO/Server | Very High | Low |
| Faster Auto Loot | Leatrix Plus | AIO | High | Low |
| Mail Open All | Postal | AIO | High | Medium |
| Bag Merge View | Bagnon | AIO | High | High |
| Quest Auto-Accept | Leatrix Plus | AIO | Medium | Low |
| Cooldown Text | OmniCC | AIO | High | Low |
| One-Click Mail Collect | Postal | Server-side | Very High | Low |

---

## 2. Leatrix Plus Feature Adaptations

### 2.1 Auto Sell Junk (Server-Side)
**Source:** Leatrix Plus automation module

**Implementation via Eluna:**
```lua
-- Auto sell junk when opening vendor
local function OnGossipHello(event, player, object)
    local vendorEntry = object:GetEntry()
    
    -- Check if this is a vendor
    if not object:IsVendor() then return end
    
    local junkSold = 0
    local goldEarned = 0
    
    -- Iterate player bags
    for bag = 0, 4 do
        for slot = 0, 35 do
            local item = player:GetItemByPos(bag, slot)
            if item and item:GetQuality() == 0 then -- Poor quality (gray)
                local sellPrice = item:GetSellPrice() * item:GetCount()
                goldEarned = goldEarned + sellPrice
                junkSold = junkSold + 1
                player:RemoveItem(item:GetEntry(), item:GetCount())
            end
        end
    end
    
    if junkSold > 0 then
        player:ModifyMoney(goldEarned)
        player:SendBroadcastMessage(string.format(
            "|cff00ff00Sold %d junk items for %s|r",
            junkSold, GetCoinTextureString(goldEarned)
        ))
    end
end

RegisterPlayerEvent(PLAYER_EVENT_ON_SEND_VENDOR_LIST, OnGossipHello)
```

**AIO Toggle UI:**
```lua
-- Client-side toggle
local frame = CreateFrame("Frame", "DCAutoSellToggle", UIParent)
frame.checkbox = CreateFrame("CheckButton", nil, frame, "UICheckButtonTemplate")
frame.checkbox:SetPoint("CENTER", 0, 0)
frame.checkbox.text = frame.checkbox:CreateFontString(nil, "OVERLAY", "GameFontNormal")
frame.checkbox.text:SetPoint("LEFT", frame.checkbox, "RIGHT", 5, 0)
frame.checkbox.text:SetText("Auto Sell Junk")

frame.checkbox:SetScript("OnClick", function(self)
    AIO.Handle("DCSettings", "SetAutoSellJunk", self:GetChecked())
end)
```

### 2.2 Auto Repair
**Source:** Leatrix Plus automation module

```lua
-- Server handler for auto repair
local function OnVendorOpened(event, player, vendor)
    if not vendor:CanRepairItems() then return end
    
    local playerSetting = GetPlayerSetting(player, "autoRepair")
    if not playerSetting then return end
    
    local repairCost = player:GetRepairAllCost()
    if repairCost <= 0 then return end
    
    local useGuildBank = GetPlayerSetting(player, "useGuildRepair")
    local repaired = false
    
    if useGuildBank and player:IsInGuild() then
        local guildGold = GetGuildBankMoney(player:GetGuildId())
        if guildGold >= repairCost then
            -- Guild bank repair
            player:DurabilityRepairAll(true, 0, true)
            repaired = true
            player:SendBroadcastMessage("|cff00ff00Repaired using guild bank|r")
        end
    end
    
    if not repaired and player:GetCoinage() >= repairCost then
        player:DurabilityRepairAll(false, 0, false)
        player:SendBroadcastMessage(string.format(
            "|cff00ff00Repaired for %s|r", GetCoinTextureString(repairCost)
        ))
    end
end
```

### 2.3 Faster Auto Loot
**AIO Implementation:**
```lua
-- Client-side enhanced loot speed
local frame = CreateFrame("Frame")
frame:RegisterEvent("LOOT_OPENED")

local function FastLoot()
    if GetCVarBool("autoLootDefault") ~= IsModifiedClick("AUTOLOOTTOGGLE") then
        local numLoot = GetNumLootItems()
        if numLoot > 0 then
            for i = numLoot, 1, -1 do
                LootSlot(i)
            end
        end
    end
end

frame:SetScript("OnEvent", function(self, event)
    if event == "LOOT_OPENED" then
        FastLoot()
    end
end)
```

### 2.4 Quest Auto-Accept/Turn-In
```lua
-- Auto accept quests from specific NPCs or all
local function OnQuestOffered(event, player, questId)
    local autoAccept = GetPlayerSetting(player, "autoAcceptQuests")
    if not autoAccept then return end
    
    -- Check if it's a daily/weekly or regular quest
    local questInfo = GetQuestTemplate(questId)
    if questInfo.IsDaily or questInfo.IsWeekly then
        player:AcceptQuest(questId)
    elseif GetPlayerSetting(player, "autoAcceptAll") then
        player:AcceptQuest(questId)
    end
end

-- Auto turn-in completed quests
local function OnQuestComplete(event, player, npc, quest)
    local autoTurnIn = GetPlayerSetting(player, "autoTurnInQuests")
    if not autoTurnIn then return end
    
    -- Auto-select reward if only one option or gold only
    local numChoices = quest:GetRewardChoiceItemCount()
    if numChoices <= 1 then
        player:CompleteQuest(quest:GetEntry())
    end
end
```

---

## 3. Postal (Mail) Features

### 3.1 One-Click Collect All Mail
**Server-Side Implementation:**
```lua
-- Command to collect all mail at once
local function CollectAllMail(player)
    local mailCount = player:GetMailCount()
    if mailCount == 0 then
        player:SendBroadcastMessage("|cffff0000No mail to collect|r")
        return
    end
    
    local collected = 0
    local gold = 0
    local items = {}
    
    for i = 1, mailCount do
        local mail = player:GetMail(i)
        if mail then
            -- Collect money
            gold = gold + mail.money
            
            -- Collect items
            for slot = 1, MAIL_MAX_ITEMS do
                local itemEntry = mail:GetItemBySlot(slot)
                if itemEntry then
                    local success = player:AddItem(itemEntry.entry, itemEntry.count)
                    if success then
                        items[itemEntry.entry] = (items[itemEntry.entry] or 0) + itemEntry.count
                    end
                end
            end
            
            -- Mark for deletion if empty
            if not mail:HasItems() and mail.money == 0 then
                player:DeleteMail(i)
            end
            
            collected = collected + 1
        end
    end
    
    player:ModifyMoney(gold)
    player:SendBroadcastMessage(string.format(
        "|cff00ff00Collected %d mails: %s and %d items|r",
        collected, GetCoinTextureString(gold), #items
    ))
end

-- Register as .collectmail command
RegisterPlayerCommand("collectmail", CollectAllMail)
```

### 3.2 AIO Mail UI Enhancement
```lua
-- Enhanced mail frame with "Collect All" button
local mailFrame = AIO.CreateFrame("Frame", "DCEnhancedMail", MailFrame)
mailFrame:SetSize(100, 30)
mailFrame:SetPoint("TOPRIGHT", MailFrame, "TOPRIGHT", -10, -30)

local collectAllBtn = CreateFrame("Button", nil, mailFrame, "UIPanelButtonTemplate")
collectAllBtn:SetSize(90, 25)
collectAllBtn:SetPoint("CENTER")
collectAllBtn:SetText("Collect All")
collectAllBtn:SetScript("OnClick", function()
    AIO.Handle("DCMail", "CollectAll")
end)

-- Visual feedback on mail count
local countText = mailFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
countText:SetPoint("BOTTOM", collectAllBtn, "TOP", 0, 5)

local function UpdateMailCount()
    local count = GetInboxNumItems()
    countText:SetText(string.format("%d mails", count))
end

mailFrame:RegisterEvent("MAIL_INBOX_UPDATE")
mailFrame:SetScript("OnEvent", UpdateMailCount)
```

---

## 4. OmniCC-Style Cooldown Text

### AIO Implementation
```lua
-- Add cooldown text overlay to action buttons
local function AddCooldownText(button)
    if button.cooldownText then return end
    
    local text = button:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    text:SetPoint("CENTER", button, "CENTER", 0, 0)
    text:SetTextColor(1, 1, 0) -- Yellow
    button.cooldownText = text
    
    local function UpdateCooldown()
        local start, duration, enabled = GetActionCooldown(button.action)
        if enabled == 1 and duration > 0 then
            local remaining = start + duration - GetTime()
            if remaining > 0 then
                if remaining > 60 then
                    text:SetText(string.format("%dm", math.ceil(remaining / 60)))
                elseif remaining > 1 then
                    text:SetText(string.format("%d", math.ceil(remaining)))
                else
                    text:SetText(string.format("%.1f", remaining))
                    text:SetTextColor(1, 0, 0) -- Red for < 1s
                end
                text:Show()
            else
                text:Hide()
                text:SetTextColor(1, 1, 0)
            end
        else
            text:Hide()
        end
    end
    
    button:HookScript("OnUpdate", UpdateCooldown)
end

-- Apply to all action buttons
for i = 1, 12 do
    AddCooldownText(_G["ActionButton" .. i])
    AddCooldownText(_G["MultiBarBottomLeftButton" .. i])
    AddCooldownText(_G["MultiBarBottomRightButton" .. i])
    AddCooldownText(_G["MultiBarRightButton" .. i])
    AddCooldownText(_G["MultiBarLeftButton" .. i])
end
```

---

## 5. TSWoW Development Tooling Adaptations

### What Can Be Adapted Without Core Changes

TSWoW uses TrinityCore, not AzerothCore. Direct code adoption is **not recommended**. However, the following development patterns/tooling concepts can improve Dark Chaos workflow:

### 5.1 TypeScript-to-Lua for Addons
**TSWoW Concept:** Write addons in TypeScript, transpile to Lua

**Adaptation for Dark Chaos:**
```json
// package.json for addon development
{
  "name": "dc-addon-dev",
  "scripts": {
    "build": "tstl",
    "watch": "tstl --watch",
    "deploy": "tstl && xcopy /Y build\\*.lua ..\\Client\\Interface\\AddOns\\DarkChaos\\"
  },
  "devDependencies": {
    "typescript": "^5.0.0",
    "typescript-to-lua": "^1.20.0",
    "@wartoshika/wow-declarations": "^0.2.6",
    "lua-types": "^2.13.0"
  }
}
```

```json
// tsconfig.json for addon TypeScript
{
  "compilerOptions": {
    "target": "esnext",
    "lib": ["esnext", "dom"],
    "moduleResolution": "node",
    "outDir": "./build",
    "rootDir": "./src",
    "strict": true
  },
  "tstl": {
    "luaTarget": "5.1",
    "noImplicitSelf": true
  }
}
```

**Benefits:**
- Type safety for addon development
- IntelliSense/autocomplete in VSCode
- Catch errors at compile time
- Easier refactoring

**Does NOT Interfere:** This is a development workflow improvement, not a core change.

### 5.2 Hot Reload for Eluna Scripts
**TSWoW Concept:** Live script reloading without server restart

**Adaptation for Dark Chaos:**
```lua
-- Hot reload command for GMs
local function ReloadElunaScripts(player)
    if player:GetGMRank() < 3 then return end
    
    -- Reload all Lua scripts
    ReloadEluna()
    
    player:SendBroadcastMessage("|cff00ff00Eluna scripts reloaded|r")
    
    -- Broadcast to online GMs
    for _, gm in pairs(GetPlayersInWorld()) do
        if gm:GetGMRank() >= 2 then
            gm:SendBroadcastMessage(string.format(
                "|cffff9900[GM] %s reloaded Eluna scripts|r",
                player:GetName()
            ))
        end
    end
end

RegisterPlayerCommand("reloadeluna", ReloadElunaScripts, 3)
```

### 5.3 Module System Pattern
**TSWoW Concept:** Modular script organization

**Adaptation for Dark Chaos:**
```
Custom/Eluna scripts/
├── modules/
│   ├── qol/
│   │   ├── auto_sell.lua
│   │   ├── auto_repair.lua
│   │   └── fast_loot.lua
│   ├── mythic_plus/
│   │   ├── affixes.lua
│   │   ├── keystone.lua
│   │   └── rewards.lua
│   └── seasonal/
│       ├── season_data.lua
│       └── rewards.lua
├── shared/
│   ├── player_settings.lua
│   ├── db_helpers.lua
│   └── aio_helpers.lua
└── main.lua  -- Loads all modules
```

**main.lua:**
```lua
-- Module loader for Dark Chaos
local MODULES = {
    "shared/player_settings",
    "shared/db_helpers",
    "shared/aio_helpers",
    "modules/qol/auto_sell",
    "modules/qol/auto_repair",
    "modules/qol/fast_loot",
    "modules/mythic_plus/affixes",
    "modules/mythic_plus/keystone",
    "modules/mythic_plus/rewards",
}

for _, module in ipairs(MODULES) do
    local success, err = pcall(require, module)
    if not success then
        print("[DC] Failed to load module: " .. module)
        print("[DC] Error: " .. tostring(err))
    else
        print("[DC] Loaded: " .. module)
    end
end
```

**Does NOT Interfere:** This is organizational, not changing any core behavior.

### 5.4 Build Script for Deployment
**Concept:** Automated sync of changes to server

**PowerShell Script:**
```powershell
# deploy-scripts.ps1
param(
    [string]$ServerPath = "\\server\wowcore\lua_scripts",
    [switch]$Watch
)

$LocalPath = ".\Custom\Eluna scripts\"

function Deploy {
    Write-Host "Deploying Eluna scripts..." -ForegroundColor Cyan
    Copy-Item -Path "$LocalPath\*" -Destination $ServerPath -Recurse -Force
    Write-Host "Deployed successfully!" -ForegroundColor Green
    
    # Optionally trigger reload via RCON/database flag
}

if ($Watch) {
    $watcher = New-Object System.IO.FileSystemWatcher
    $watcher.Path = $LocalPath
    $watcher.Filter = "*.lua"
    $watcher.IncludeSubdirectories = $true
    $watcher.EnableRaisingEvents = $true
    
    Register-ObjectEvent $watcher "Changed" -Action { Deploy }
    
    Write-Host "Watching for changes..." -ForegroundColor Yellow
    while ($true) { Start-Sleep 1 }
} else {
    Deploy
}
```

---

## 6. Ascension Bronzebeard-Only Features

### 6.1 Bronzebeard Overview
Bronzebeard is Ascension's **non-classless** realm - traditional WoW classes without Mystic Enchants or Soulforging.

### Relevant Bronzebeard Features

| Feature | Description | Dark Chaos Relevance |
|---------|-------------|---------------------|
| **Hardcore Mode** | Permadeath option | Could add as challenge mode |
| **Ironman Mode** | No trading/AH, self-found only | Niche appeal |
| **Fresh Economy** | Periodic resets | Already have Seasonal |
| **Dual Spec** | Two talent specs | Already in WotLK |
| **Heirloom System** | XP boost gear | Already have custom heirlooms |
| **World PvP Events** | Scheduled PvP zones | Could enhance existing |

### 6.2 Hardcore Mode (Bronzebeard Style)
```sql
-- Hardcore character flag
ALTER TABLE characters ADD COLUMN hardcore_mode TINYINT DEFAULT 0;
ALTER TABLE characters ADD COLUMN hardcore_deaths INT DEFAULT 0;
ALTER TABLE characters ADD COLUMN hardcore_highest_level INT DEFAULT 1;

-- Hardcore leaderboard
CREATE TABLE hardcore_leaderboard (
    guid INT PRIMARY KEY,
    name VARCHAR(50),
    race TINYINT,
    class TINYINT,
    highest_level INT,
    time_played INT,
    death_cause VARCHAR(100),
    death_zone VARCHAR(100),
    death_date DATETIME
);
```

```lua
-- Hardcore death handler
local function OnHardcoreDeath(event, player, killer)
    if player:GetDBValue("characters", "hardcore_mode") ~= 1 then return end
    
    local deathZone = player:GetAreaId()
    local killerName = killer and killer:GetName() or "Environment"
    
    -- Log to leaderboard
    CharDBExecute(string.format([[
        INSERT INTO hardcore_leaderboard 
        (guid, name, race, class, highest_level, time_played, death_cause, death_zone, death_date)
        VALUES (%d, '%s', %d, %d, %d, %d, '%s', '%s', NOW())
    ]], player:GetGUID(), player:GetName(), player:GetRace(), player:GetClass(),
        player:GetLevel(), player:GetTotalPlayedTime(), killerName, GetAreaName(deathZone)))
    
    -- Announce death
    SendWorldMessage(string.format(
        "|cffff0000[HARDCORE] %s (Level %d %s) has fallen to %s in %s!|r",
        player:GetName(), player:GetLevel(), GetClassName(player:GetClass()),
        killerName, GetAreaName(deathZone)
    ))
    
    -- Convert to non-hardcore or delete based on setting
    player:SetDBValue("characters", "hardcore_mode", 0)
    player:SendBroadcastMessage("|cffff0000Your hardcore journey has ended.|r")
end

RegisterPlayerEvent(PLAYER_EVENT_ON_DEATH, OnHardcoreDeath)
```

---

## 7. Integrated QoL Settings Panel

### AIO Settings UI
```lua
-- Unified QoL settings panel
local DCSettingsFrame = CreateFrame("Frame", "DCQoLSettings", UIParent)
DCSettingsFrame:SetSize(400, 500)
DCSettingsFrame:SetPoint("CENTER")
DCSettingsFrame:SetBackdrop({
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true, tileSize = 32, edgeSize = 32,
    insets = { left = 11, right = 12, top = 12, bottom = 11 }
})
DCSettingsFrame:EnableMouse(true)
DCSettingsFrame:SetMovable(true)
DCSettingsFrame:RegisterForDrag("LeftButton")
DCSettingsFrame:SetScript("OnDragStart", DCSettingsFrame.StartMoving)
DCSettingsFrame:SetScript("OnDragStop", DCSettingsFrame.StopMovingOrSizing)
DCSettingsFrame:Hide()

-- Title
local title = DCSettingsFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
title:SetPoint("TOP", 0, -15)
title:SetText("Dark Chaos QoL Settings")

-- Category tabs
local categories = {"Automation", "Mail", "UI", "Hardcore"}
local yOffset = -50

local function CreateCheckbox(parent, name, label, setting, y)
    local cb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    cb:SetPoint("TOPLEFT", 20, y)
    cb.text = cb:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    cb.text:SetPoint("LEFT", cb, "RIGHT", 5, 0)
    cb.text:SetText(label)
    cb.setting = setting
    
    cb:SetScript("OnClick", function(self)
        AIO.Handle("DCSettings", "Toggle", self.setting, self:GetChecked())
    end)
    
    return cb
end

-- Automation section
local autoHeader = DCSettingsFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
autoHeader:SetPoint("TOPLEFT", 20, -50)
autoHeader:SetText("|cff00ff00Automation|r")

CreateCheckbox(DCSettingsFrame, "AutoSell", "Auto Sell Junk", "autoSellJunk", -70)
CreateCheckbox(DCSettingsFrame, "AutoRepair", "Auto Repair", "autoRepair", -95)
CreateCheckbox(DCSettingsFrame, "AutoRepairGuild", "  Use Guild Bank", "autoRepairGuild", -120)
CreateCheckbox(DCSettingsFrame, "FastLoot", "Fast Auto Loot", "fastLoot", -145)
CreateCheckbox(DCSettingsFrame, "AutoAcceptQuests", "Auto Accept Quests", "autoAcceptQuests", -170)
CreateCheckbox(DCSettingsFrame, "AutoTurnIn", "Auto Turn-In Quests", "autoTurnIn", -195)

-- UI section
local uiHeader = DCSettingsFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
uiHeader:SetPoint("TOPLEFT", 20, -230)
uiHeader:SetText("|cff00ff00UI Enhancements|r")

CreateCheckbox(DCSettingsFrame, "CooldownText", "Show Cooldown Text", "cooldownText", -250)
CreateCheckbox(DCSettingsFrame, "ItemLevel", "Show Item Level", "showItemLevel", -275)
CreateCheckbox(DCSettingsFrame, "GearScore", "Show GearScore", "showGearScore", -300)

-- Close button
local closeBtn = CreateFrame("Button", nil, DCSettingsFrame, "UIPanelCloseButton")
closeBtn:SetPoint("TOPRIGHT", -5, -5)

-- Slash command to open
SLASH_DCQOL1 = "/dcqol"
SlashCmdList["DCQOL"] = function()
    if DCSettingsFrame:IsShown() then
        DCSettingsFrame:Hide()
    else
        DCSettingsFrame:Show()
    end
end
```

---

## 8. Implementation Priority

### Phase 1: Quick Wins (1-2 weeks)
1. ✅ Auto Sell Junk (server-side)
2. ✅ Auto Repair (server-side)
3. ✅ Faster Auto Loot (AIO)
4. ✅ Cooldown Text (AIO)
5. ✅ QoL Settings Panel (AIO)

### Phase 2: Mail Improvements (2-3 weeks)
1. ✅ Collect All Mail command
2. ✅ Enhanced mail UI
3. ✅ Mail tracking per character

### Phase 3: Development Workflow (ongoing)
1. ✅ TypeScript addon development setup
2. ✅ Module organization pattern
3. ✅ Deployment scripts
4. ✅ Hot reload for GMs

### Phase 4: Challenge Modes (3-4 weeks)
1. ⬜ Hardcore mode opt-in
2. ⬜ Ironman mode
3. ⬜ Leaderboards

---

## 9. Summary

### What to Implement (Does Not Conflict)

| Feature | Type | Conflicts? |
|---------|------|-----------|
| Auto Sell Junk | Server-side Eluna | No |
| Auto Repair | Server-side Eluna | No |
| Fast Loot | AIO Client | No |
| Cooldown Text | AIO Client | No |
| Mail Collect All | Server-side | No |
| Settings Panel | AIO Client | No |
| TypeScript Addon Dev | Dev workflow | No |
| Module Organization | Dev workflow | No |
| Hardcore Mode | Optional feature | No |

### What NOT to Adopt from TSWoW

| Feature | Reason |
|---------|--------|
| Datascripts | Requires TrinityCore, not AC |
| Client Extensions DLL | Different core architecture |
| Map ADT generation | Not compatible with AC tooling |
| Spell/Talent modification | Different DBC handling |

### Existing Dark Chaos Features Preserved

- ✅ Transmog Collection
- ✅ Great Vault + UI
- ✅ Mythic+ System
- ✅ Seasonal System
- ✅ Item Upgrades
- ✅ AIO Framework

These QoL additions **complement** existing systems without replacing or conflicting with them.

---

## References
- Leatrix Plus: https://www.curseforge.com/wow/addons/leatrix-plus
- Postal: https://www.curseforge.com/wow/addons/postal
- OmniCC: https://legacy-wow.com/wotlk-addons/omnicc/
- TSWoW Wiki: https://tswow.github.io/tswow-wiki/
- Ascension Bronzebeard: https://project-ascension.com/
