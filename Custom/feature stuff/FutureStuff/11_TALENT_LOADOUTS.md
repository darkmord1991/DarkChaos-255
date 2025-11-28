# Talent Loadouts System

**Priority:** S2 - High Priority  
**Effort:** Low (1 week)  
**Impact:** High  
**Base:** Custom Eluna/C++ with character_talents

---

## Overview

A Talent Loadouts system allows players to save and quickly swap between different talent configurations. Essential for funservers where players need different specs for PvE (M+, Raids) and PvP (HLBG, Arenas).

---

## Why It Fits DarkChaos-255

### Quality of Life
- Fast spec swapping for M+ → PvP → Raid
- No reagent costs
- One-click respec
- Saves time, increases engagement

### Funserver Context
- PvP and PvE both important
- Multiple content types need different specs
- Alt-friendly feature
- Expected in modern WoW

### Synergies
| System | Integration |
|--------|-------------|
| **Mythic+** | PvE spec for dungeons |
| **HLBG** | PvP spec for battleground |
| **Seasonal** | Seasonal talent experiments |
| **Dual Spec** | Enhances existing dual spec |

---

## Feature Highlights

### Core Features

1. **Multiple Loadouts**
   - Save 5+ talent configurations
   - Name each loadout
   - Quick-swap hotkey
   - Per-spec loadouts

2. **Glyph Integration**
   - Include glyphs in loadouts
   - Swap glyphs with talents
   - Save glyph configurations

3. **Gear Integration (Optional)**
   - Link gear sets to loadouts
   - Auto-equip on swap
   - Equipment manager integration

4. **Smart Restrictions**
   - Only swap out of combat
   - Cooldown between swaps
   - Rested area requirement (optional)

---

## Technical Implementation

### Database Schema

```sql
-- Saved talent loadouts
CREATE TABLE dc_talent_loadouts (
    loadout_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    player_guid INT UNSIGNED,
    loadout_name VARCHAR(50),
    loadout_order INT DEFAULT 0,
    spec_index TINYINT DEFAULT 0,  -- 0 = primary, 1 = secondary
    
    -- Talent points (format: "talent_id:rank,talent_id:rank,...")
    talents_tree1 TEXT,
    talents_tree2 TEXT,
    talents_tree3 TEXT,
    
    -- Glyphs
    glyph_major1 INT UNSIGNED DEFAULT 0,
    glyph_major2 INT UNSIGNED DEFAULT 0,
    glyph_major3 INT UNSIGNED DEFAULT 0,
    glyph_minor1 INT UNSIGNED DEFAULT 0,
    glyph_minor2 INT UNSIGNED DEFAULT 0,
    glyph_minor3 INT UNSIGNED DEFAULT 0,
    
    -- Optional: linked gear set
    linked_equipment_set VARCHAR(50) NULL,
    
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    last_used TIMESTAMP NULL,
    
    INDEX idx_player (player_guid),
    INDEX idx_spec (player_guid, spec_index)
);

-- Quick access for loadout slots (optional)
CREATE TABLE dc_talent_loadout_slots (
    player_guid INT UNSIGNED,
    slot_index TINYINT,  -- 1-5
    loadout_id INT UNSIGNED,
    PRIMARY KEY (player_guid, slot_index),
    FOREIGN KEY (loadout_id) REFERENCES dc_talent_loadouts(loadout_id) ON DELETE SET NULL
);
```

### Eluna Implementation

```lua
-- Talent Loadout Manager
local TalentLoadouts = {}
TalentLoadouts.PlayerLoadouts = {}  -- Cache
TalentLoadouts.SWAP_COOLDOWN = 30   -- Seconds between swaps
TalentLoadouts.MAX_LOADOUTS = 10

-- Load loadouts for player
function TalentLoadouts.LoadForPlayer(player)
    local guid = player:GetGUIDLow()
    TalentLoadouts.PlayerLoadouts[guid] = {}
    
    local query = CharDBQuery([[
        SELECT loadout_id, loadout_name, spec_index,
               talents_tree1, talents_tree2, talents_tree3,
               glyph_major1, glyph_major2, glyph_major3,
               glyph_minor1, glyph_minor2, glyph_minor3,
               linked_equipment_set
        FROM dc_talent_loadouts
        WHERE player_guid = ]] .. guid .. [[ ORDER BY loadout_order
    ]])
    
    if query then
        repeat
            table.insert(TalentLoadouts.PlayerLoadouts[guid], {
                id = query:GetUInt32(0),
                name = query:GetString(1),
                specIndex = query:GetUInt8(2),
                talents = {
                    query:GetString(3),
                    query:GetString(4),
                    query:GetString(5)
                },
                glyphs = {
                    major = {query:GetUInt32(6), query:GetUInt32(7), query:GetUInt32(8)},
                    minor = {query:GetUInt32(9), query:GetUInt32(10), query:GetUInt32(11)}
                },
                equipmentSet = query:GetString(12)
            })
        until not query:NextRow()
    end
end

-- Save current talents as loadout
function TalentLoadouts.SaveLoadout(player, loadoutName)
    local guid = player:GetGUIDLow()
    local loadouts = TalentLoadouts.PlayerLoadouts[guid] or {}
    
    if #loadouts >= TalentLoadouts.MAX_LOADOUTS then
        player:SendBroadcastMessage("|cffff0000Maximum loadouts reached (" .. 
            TalentLoadouts.MAX_LOADOUTS .. ").|r")
        return false
    end
    
    -- Get current talents
    local talents = TalentLoadouts.GetCurrentTalents(player)
    local glyphs = TalentLoadouts.GetCurrentGlyphs(player)
    local specIndex = player:GetActiveSpec()
    
    -- Save to database
    CharDBExecute(string.format([[
        INSERT INTO dc_talent_loadouts 
        (player_guid, loadout_name, spec_index, 
         talents_tree1, talents_tree2, talents_tree3,
         glyph_major1, glyph_major2, glyph_major3,
         glyph_minor1, glyph_minor2, glyph_minor3,
         loadout_order)
        VALUES (%d, '%s', %d, '%s', '%s', '%s', %d, %d, %d, %d, %d, %d, %d)
    ]], guid, loadoutName, specIndex,
        talents[1], talents[2], talents[3],
        glyphs.major[1], glyphs.major[2], glyphs.major[3],
        glyphs.minor[1], glyphs.minor[2], glyphs.minor[3],
        #loadouts + 1
    ))
    
    TalentLoadouts.LoadForPlayer(player)
    player:SendBroadcastMessage("|cff00ff00Talent loadout '" .. loadoutName .. "' saved!|r")
    return true
end

-- Get current talents as serialized string
function TalentLoadouts.GetCurrentTalents(player)
    local talents = {"", "", ""}
    
    for tree = 1, 3 do
        local talentData = {}
        -- WotLK has variable talents per tree, iterate through known talent IDs
        for talentId = 1, 100 do  -- Approximate max
            local rank = player:GetTalentRank(talentId, tree)
            if rank and rank > 0 then
                table.insert(talentData, talentId .. ":" .. rank)
            end
        end
        talents[tree] = table.concat(talentData, ",")
    end
    
    return talents
end

-- Get current glyphs
function TalentLoadouts.GetCurrentGlyphs(player)
    return {
        major = {
            player:GetGlyph(0) or 0,
            player:GetGlyph(1) or 0,
            player:GetGlyph(2) or 0
        },
        minor = {
            player:GetGlyph(3) or 0,
            player:GetGlyph(4) or 0,
            player:GetGlyph(5) or 0
        }
    }
end

-- Apply loadout
function TalentLoadouts.ApplyLoadout(player, loadoutId)
    local guid = player:GetGUIDLow()
    local loadouts = TalentLoadouts.PlayerLoadouts[guid]
    
    if not loadouts then
        TalentLoadouts.LoadForPlayer(player)
        loadouts = TalentLoadouts.PlayerLoadouts[guid]
    end
    
    -- Find loadout
    local loadout = nil
    for _, l in ipairs(loadouts) do
        if l.id == loadoutId then
            loadout = l
            break
        end
    end
    
    if not loadout then
        player:SendBroadcastMessage("|cffff0000Loadout not found.|r")
        return false
    end
    
    -- Check combat
    if player:IsInCombat() then
        player:SendBroadcastMessage("|cffff0000Cannot swap talents in combat.|r")
        return false
    end
    
    -- Check cooldown
    local lastSwap = player:GetData("last_talent_swap") or 0
    if os.time() - lastSwap < TalentLoadouts.SWAP_COOLDOWN then
        local remaining = TalentLoadouts.SWAP_COOLDOWN - (os.time() - lastSwap)
        player:SendBroadcastMessage("|cffff0000Talent swap on cooldown: " .. remaining .. "s|r")
        return false
    end
    
    -- Check if need to switch spec first
    if loadout.specIndex ~= player:GetActiveSpec() then
        player:ActivateTalentSpec(loadout.specIndex)
        -- Wait for spec swap, then apply talents
        player:RegisterEvent(function()
            TalentLoadouts.ApplyTalentsAndGlyphs(player, loadout)
        end, 1000, 1)
    else
        TalentLoadouts.ApplyTalentsAndGlyphs(player, loadout)
    end
    
    return true
end

-- Apply talents and glyphs from loadout
function TalentLoadouts.ApplyTalentsAndGlyphs(player, loadout)
    -- Reset talents first
    player:ResetTalents(true)  -- true = no cost
    
    -- Apply talents
    for tree = 1, 3 do
        local talentString = loadout.talents[tree]
        if talentString and talentString ~= "" then
            for pair in string.gmatch(talentString, "([^,]+)") do
                local talentId, rank = pair:match("(%d+):(%d+)")
                if talentId and rank then
                    for i = 1, tonumber(rank) do
                        player:LearnTalent(tonumber(talentId))
                    end
                end
            end
        end
    end
    
    -- Apply glyphs
    for i, glyphId in ipairs(loadout.glyphs.major) do
        if glyphId > 0 then
            player:SetGlyph(i - 1, glyphId)  -- 0-indexed
        end
    end
    for i, glyphId in ipairs(loadout.glyphs.minor) do
        if glyphId > 0 then
            player:SetGlyph(i + 2, glyphId)  -- Minors start at slot 3
        end
    end
    
    -- Apply equipment set if linked
    if loadout.equipmentSet and loadout.equipmentSet ~= "" then
        player:SendBroadcastMessage("|cff888888Equipping set: " .. loadout.equipmentSet .. "|r")
        -- Would need C++ support or addon to actually equip
    end
    
    -- Set cooldown
    player:SetData("last_talent_swap", os.time())
    
    -- Update last used
    CharDBExecute("UPDATE dc_talent_loadouts SET last_used = NOW() WHERE loadout_id = " .. loadout.id)
    
    player:SendBroadcastMessage("|cff00ff00Loadout '" .. loadout.name .. "' applied!|r")
end

-- Slash commands
local function HandleLoadoutCommand(player, command, args)
    if command ~= "loadout" and command ~= "talents" and command ~= "spec" then
        return true
    end
    
    local subCmd, param = args:match("(%S+)%s*(.*)")
    subCmd = subCmd or args
    
    if subCmd == "save" then
        local name = param ~= "" and param or "Loadout " .. os.date("%H:%M")
        TalentLoadouts.SaveLoadout(player, name)
        
    elseif subCmd == "load" or subCmd == "apply" then
        local loadoutId = tonumber(param)
        if loadoutId then
            TalentLoadouts.ApplyLoadout(player, loadoutId)
        else
            -- Try by name
            local guid = player:GetGUIDLow()
            local loadouts = TalentLoadouts.PlayerLoadouts[guid] or {}
            for _, l in ipairs(loadouts) do
                if l.name:lower() == param:lower() then
                    TalentLoadouts.ApplyLoadout(player, l.id)
                    return false
                end
            end
            player:SendBroadcastMessage("Usage: .loadout load <id or name>")
        end
        
    elseif subCmd == "list" then
        local loadouts = TalentLoadouts.PlayerLoadouts[player:GetGUIDLow()] or {}
        player:SendBroadcastMessage("|cff00ff00=== Your Loadouts ===|r")
        for _, l in ipairs(loadouts) do
            local specName = l.specIndex == 0 and "Primary" or "Secondary"
            player:SendBroadcastMessage(string.format("  [%d] %s (%s)", l.id, l.name, specName))
        end
        if #loadouts == 0 then
            player:SendBroadcastMessage("  No loadouts saved. Use .loadout save <name>")
        end
        
    elseif subCmd == "delete" then
        local loadoutId = tonumber(param)
        if loadoutId then
            CharDBExecute("DELETE FROM dc_talent_loadouts WHERE loadout_id = " .. loadoutId .. 
                " AND player_guid = " .. player:GetGUIDLow())
            TalentLoadouts.LoadForPlayer(player)
            player:SendBroadcastMessage("|cffff0000Loadout deleted.|r")
        else
            player:SendBroadcastMessage("Usage: .loadout delete <id>")
        end
        
    elseif subCmd == "rename" then
        local id, newName = param:match("(%d+)%s+(.+)")
        if id and newName then
            CharDBExecute(string.format(
                "UPDATE dc_talent_loadouts SET loadout_name = '%s' WHERE loadout_id = %s AND player_guid = %d",
                newName, id, player:GetGUIDLow()))
            TalentLoadouts.LoadForPlayer(player)
            player:SendBroadcastMessage("|cff00ff00Loadout renamed to '" .. newName .. "'|r")
        else
            player:SendBroadcastMessage("Usage: .loadout rename <id> <newname>")
        end
        
    else
        player:SendBroadcastMessage("Usage: .loadout save|load|list|delete|rename")
        player:SendBroadcastMessage("  .loadout save <name> - Save current talents")
        player:SendBroadcastMessage("  .loadout load <id> - Apply loadout")
        player:SendBroadcastMessage("  .loadout list - Show saved loadouts")
    end
    
    return false
end
RegisterPlayerEvent(42, HandleLoadoutCommand)

-- Load on login
local function OnLogin(event, player)
    TalentLoadouts.LoadForPlayer(player)
end
RegisterPlayerEvent(3, OnLogin)
```

### Client Addon (Optional)

```lua
-- DC-Loadouts addon
local LoadoutFrame = CreateFrame("Frame", "DCLoadouts", UIParent)
LoadoutFrame:SetSize(200, 300)
LoadoutFrame:SetPoint("CENTER")
LoadoutFrame:Hide()

-- Buttons for each loadout
local buttons = {}

function LoadoutFrame:RefreshLoadouts(loadouts)
    -- Clear existing
    for _, btn in ipairs(buttons) do
        btn:Hide()
    end
    
    -- Create buttons
    for i, loadout in ipairs(loadouts) do
        local btn = buttons[i] or CreateFrame("Button", nil, LoadoutFrame, "UIPanelButtonTemplate")
        btn:SetSize(180, 25)
        btn:SetPoint("TOP", 0, -30 - (i * 30))
        btn:SetText(loadout.name)
        btn:SetScript("OnClick", function()
            SendChatMessage(".loadout load " .. loadout.id, "SAY")
        end)
        btn:Show()
        buttons[i] = btn
    end
end

-- AIO message handler
AIO.AddAddonMessage("DC-Loadouts", function(player, action, data)
    if action == "UPDATE" then
        LoadoutFrame:RefreshLoadouts(data.loadouts)
    end
end)

-- Toggle command
SLASH_LOADOUT1 = "/loadout"
SlashCmdList["LOADOUT"] = function(msg)
    if msg == "" then
        if LoadoutFrame:IsShown() then
            LoadoutFrame:Hide()
        else
            LoadoutFrame:Show()
        end
    else
        SendChatMessage(".loadout " .. msg, "SAY")
    end
end
```

---

## Commands Reference

| Command | Description |
|---------|-------------|
| `.loadout save <name>` | Save current talents |
| `.loadout load <id>` | Apply loadout by ID |
| `.loadout load <name>` | Apply loadout by name |
| `.loadout list` | Show all loadouts |
| `.loadout delete <id>` | Delete loadout |
| `.loadout rename <id> <name>` | Rename loadout |

---

## Implementation Phases

### Phase 1 (Days 1-3): Core System
- [ ] Database schema
- [ ] Save/load functionality
- [ ] Talent serialization
- [ ] Basic commands

### Phase 2 (Days 4-5): Glyphs & Polish
- [ ] Glyph integration
- [ ] Cooldown handling
- [ ] Combat restrictions
- [ ] Spec awareness

### Phase 3 (Days 6-7): Enhancement
- [ ] Equipment set linking (optional)
- [ ] Client addon
- [ ] Quick-swap hotkeys

---

## Integration Ideas

### With Mythic+
```lua
-- Auto-suggest PvE loadout when entering M+
local function OnEnterMythicPlus(player, keystoneLevel)
    local pveLoadout = TalentLoadouts.FindByTag(player, "pve")
    if pveLoadout then
        player:SendBroadcastMessage("Tip: Type .loadout load " .. pveLoadout.id .. 
            " for your PvE spec!")
    end
end
```

### With HLBG
```lua
-- Auto-suggest PvP loadout when queuing
local function OnQueueHLBG(player)
    local pvpLoadout = TalentLoadouts.FindByTag(player, "pvp")
    if pvpLoadout then
        player:SendBroadcastMessage("Tip: Type .loadout load " .. pvpLoadout.id .. 
            " for your PvP spec!")
    end
end
```

---

## Success Metrics

- Loadouts saved per player
- Swap frequency
- Time saved (vs manual respec)
- Player satisfaction

---

## Risks & Mitigations

| Risk | Mitigation |
|------|------------|
| Exploit in combat | Strict combat check |
| Spam swapping | Cooldown between swaps |
| Talent sync issues | Verify after apply |
| Glyph costs | Free glyph application in loadouts |

---

**Recommendation:** This is a must-have QoL feature for any serious funserver. Implementation is straightforward with Eluna. Start with basic save/load, add glyphs in phase 2. Consider making first 3 loadouts free, additional slots unlockable.
