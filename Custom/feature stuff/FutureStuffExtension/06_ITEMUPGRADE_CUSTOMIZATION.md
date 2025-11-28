# Item Upgrade Stat Customization System

**Priority:** A-Tier  
**Effort:** High (3 weeks)  
**Impact:** High  
**Target System:** `src/server/scripts/DC/ItemUpgrades/`

---

## Current State Analysis

### From ItemUpgradeManager.h
```cpp
struct ItemUpgradeState
{
    float stat_multiplier;  // 1.0 = base, higher = bonus
    // Fixed multiplier scaling only
};

static const float STAT_MULTIPLIER_MAX_HEIRLOOM = 1.35f;  // 35% max bonus
```

### Gaps Identified
- Fixed linear stat increases
- No stat type selection
- No specialization paths
- No hybrid stat options
- No diminishing returns system

---

## Proposed Customization System

### Upgrade Paths
| Path | Focus | Stat Bonus | Trade-off |
|------|-------|------------|-----------|
| **Power** | Primary Stat | +50% Primary | -10% Stamina |
| **Survival** | Stamina + Armor | +40% Stamina, +20% Armor | -15% Primary |
| **Versatile** | Balanced | +25% All Stats | No trade-off |
| **Specialized** | Secondary Stats | +60% chosen secondary | -20% other secondary |

### Stat Selection
Players choose 1-2 secondary stats to prioritize:
- Critical Strike
- Haste
- Hit Rating
- Expertise
- Armor Penetration
- Spell Power (casters)

---

## Database Schema

```sql
-- Upgrade path definitions
CREATE TABLE dc_upgrade_paths (
    path_id TINYINT UNSIGNED PRIMARY KEY,
    path_name VARCHAR(50) NOT NULL,
    path_description TEXT,
    primary_bonus_pct FLOAT DEFAULT 0,
    stamina_bonus_pct FLOAT DEFAULT 0,
    armor_bonus_pct FLOAT DEFAULT 0,
    secondary_bonus_pct FLOAT DEFAULT 0,
    primary_penalty_pct FLOAT DEFAULT 0,
    stamina_penalty_pct FLOAT DEFAULT 0,
    secondary_penalty_pct FLOAT DEFAULT 0
);

-- Player item customizations
CREATE TABLE dc_item_upgrade_customization (
    item_guid INT UNSIGNED NOT NULL,
    player_guid INT UNSIGNED NOT NULL,
    path_id TINYINT UNSIGNED NOT NULL,
    priority_stat_1 TINYINT UNSIGNED DEFAULT 0,  -- StatType enum
    priority_stat_2 TINYINT UNSIGNED DEFAULT 0,
    custom_name VARCHAR(50),  -- Optional renamed item
    socket_1 TINYINT UNSIGNED DEFAULT 0,  -- Bonus socket type
    socket_2 TINYINT UNSIGNED DEFAULT 0,
    enchant_slot INT UNSIGNED DEFAULT 0,  -- Extra enchant
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    modified_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (item_guid),
    FOREIGN KEY (path_id) REFERENCES dc_upgrade_paths(path_id)
);

-- Stat type definitions for priority selection
CREATE TABLE dc_upgrade_stat_types (
    stat_type_id TINYINT UNSIGNED PRIMARY KEY,
    stat_name VARCHAR(30) NOT NULL,
    stat_display VARCHAR(50) NOT NULL,
    allowed_for_paths VARCHAR(50)  -- comma-separated path_ids
);

-- Insert base paths
INSERT INTO dc_upgrade_paths VALUES
(1, 'Power', 'Maximize damage/healing output', 50, 0, 0, 0, 0, 10, 0),
(2, 'Survival', 'Maximize survivability', 0, 40, 20, 0, 15, 0, 0),
(3, 'Versatile', 'Balanced stat growth', 25, 25, 10, 25, 0, 0, 0),
(4, 'Specialized', 'Focus on secondary stats', 0, 0, 0, 60, 0, 0, 20);

-- Insert stat types
INSERT INTO dc_upgrade_stat_types VALUES
(1, 'CRIT', 'Critical Strike', '1,3,4'),
(2, 'HASTE', 'Haste', '1,3,4'),
(3, 'HIT', 'Hit Rating', '1,4'),
(4, 'EXPERTISE', 'Expertise', '1,4'),
(5, 'ARMOR_PEN', 'Armor Penetration', '1,4'),
(6, 'SPELL_POWER', 'Spell Power', '1,3'),
(7, 'DEFENSE', 'Defense Rating', '2'),
(8, 'DODGE', 'Dodge', '2'),
(9, 'PARRY', 'Parry', '2'),
(10, 'RESILIENCE', 'Resilience', '3');
```

---

## Implementation

### Stat Modifier Structure
```cpp
struct ItemStatModifier
{
    uint8 pathId;
    StatType priorityStat1;
    StatType priorityStat2;
    
    // Calculated modifiers
    float primaryMod;
    float staminaMod;
    float armorMod;
    std::unordered_map<StatType, float> secondaryMods;
    
    void Calculate(const UpgradePath& path, uint8 upgradeLevel);
};

void ItemStatModifier::Calculate(const UpgradePath& path, uint8 upgradeLevel)
{
    // Scale bonuses by upgrade level (linear to max at level 80)
    float levelScale = static_cast<float>(upgradeLevel) / 80.0f;
    
    // Apply path bonuses
    primaryMod = 1.0f + (path.primaryBonusPct / 100.0f * levelScale);
    staminaMod = 1.0f + (path.staminaBonusPct / 100.0f * levelScale);
    armorMod = 1.0f + (path.armorBonusPct / 100.0f * levelScale);
    
    // Apply penalties
    primaryMod -= (path.primaryPenaltyPct / 100.0f * levelScale);
    staminaMod -= (path.staminaPenaltyPct / 100.0f * levelScale);
    
    // Priority secondary stats
    float secondaryBonus = path.secondaryBonusPct / 100.0f * levelScale;
    if (priorityStat1 != STAT_NONE)
        secondaryMods[priorityStat1] = 1.0f + secondaryBonus;
    if (priorityStat2 != STAT_NONE)
        secondaryMods[priorityStat2] = 1.0f + (secondaryBonus * 0.6f);  // Second priority gets 60%
    
    // Non-priority secondaries get penalty if Specialized path
    if (path.pathId == PATH_SPECIALIZED && path.secondaryPenaltyPct > 0)
    {
        float penalty = path.secondaryPenaltyPct / 100.0f * levelScale;
        for (uint8 stat = STAT_CRIT; stat <= STAT_RESILIENCE; ++stat)
        {
            StatType st = static_cast<StatType>(stat);
            if (st != priorityStat1 && st != priorityStat2)
                secondaryMods[st] = 1.0f - penalty;
        }
    }
}
```

### Customization Manager
```cpp
class ItemCustomizationManager
{
public:
    static ItemCustomizationManager* instance();

    // Customization operations
    bool SetItemPath(uint32 itemGuid, uint32 playerGuid, uint8 pathId);
    bool SetPriorityStats(uint32 itemGuid, StatType stat1, StatType stat2);
    bool RenameItem(uint32 itemGuid, const std::string& newName);
    
    // Queries
    ItemCustomization* GetCustomization(uint32 itemGuid);
    ItemStatModifier CalculateModifiers(uint32 itemGuid, uint8 upgradeLevel);
    std::vector<UpgradePath> GetAvailablePaths(uint32 itemId);
    std::vector<StatType> GetAvailableStats(uint8 pathId, uint8 playerClass);
    
    // Stat application
    void ApplyCustomStats(Player* player, Item* item);
    void RemoveCustomStats(Player* player, Item* item);
    void RecalculateAllStats(Player* player);
    
    // Validation
    bool CanSelectPath(uint32 itemGuid, uint8 pathId);
    bool CanSelectStat(uint8 pathId, StatType stat);
    bool IsValidCustomization(const ItemCustomization& custom);
    
    // Persistence
    void LoadCustomizations(uint32 playerGuid);
    void SaveCustomization(uint32 itemGuid);
    void DeleteCustomization(uint32 itemGuid);

private:
    ItemCustomizationManager();
    
    std::unordered_map<uint32, ItemCustomization> _customizations;
    std::unordered_map<uint8, UpgradePath> _paths;
    std::unordered_map<uint8, std::vector<StatType>> _pathStats;
};

#define sItemCustom ItemCustomizationManager::instance()
```

### Stat Application Hook
```cpp
// Hook into ItemUpgradeStatApplication.cpp
void ApplyCustomizedStats(Player* player, Item* item)
{
    uint32 itemGuid = item->GetGUID().GetCounter();
    
    // Get base upgrade state
    auto* upgradeState = DarkChaos::ItemUpgrade::GetUpgradeManager()->GetItemUpgradeState(itemGuid);
    if (!upgradeState)
        return;
    
    // Get customization
    auto* custom = sItemCustom->GetCustomization(itemGuid);
    if (!custom)
    {
        // No customization, apply default multiplier
        ApplyDefaultStatMultiplier(player, item, upgradeState->stat_multiplier);
        return;
    }
    
    // Calculate custom modifiers
    ItemStatModifier mods = sItemCustom->CalculateModifiers(itemGuid, upgradeState->upgrade_level);
    
    // Apply to each stat
    for (uint8 i = 0; i < MAX_ITEM_PROTO_STATS; ++i)
    {
        int32 baseStat = item->GetTemplate()->ItemStat[i].ItemStatValue;
        ItemModType statType = item->GetTemplate()->ItemStat[i].ItemStatType;
        
        if (baseStat == 0)
            continue;
        
        float modifier = GetModifierForStatType(mods, statType);
        int32 bonusStat = static_cast<int32>(baseStat * (modifier - 1.0f));
        
        player->ApplyItemStatMod(item->GetSlot(), statType, bonusStat, true);
    }
    
    // Apply primary stat modifier
    if (mods.primaryMod != 1.0f)
    {
        StatType primaryStat = GetPrimaryStatForClass(player->getClass());
        int32 basePrimary = GetItemPrimaryStat(item, primaryStat);
        int32 bonusPrimary = static_cast<int32>(basePrimary * (mods.primaryMod - 1.0f));
        player->ApplyStat(primaryStat, bonusPrimary, true);
    }
    
    // Apply stamina modifier
    if (mods.staminaMod != 1.0f)
    {
        int32 baseStamina = GetItemStatValue(item, ITEM_MOD_STAMINA);
        int32 bonusStamina = static_cast<int32>(baseStamina * (mods.staminaMod - 1.0f));
        player->ApplyStat(STAT_STAMINA, bonusStamina, true);
    }
    
    // Apply armor modifier
    if (mods.armorMod != 1.0f)
    {
        int32 baseArmor = item->GetTemplate()->Armor;
        int32 bonusArmor = static_cast<int32>(baseArmor * (mods.armorMod - 1.0f));
        player->ApplyArmorMod(bonusArmor, true);
    }
}
```

---

## Customization NPC Interface

### NPC Gossip
```cpp
class npc_item_customizer : public CreatureScript
{
public:
    npc_item_customizer() : CreatureScript("npc_item_customizer") { }

    bool OnGossipHello(Player* player, Creature* creature) override
    {
        AddGossipItemFor(player, GOSSIP_ICON_CHAT, "Customize an upgraded item", 
                         GOSSIP_SENDER_MAIN, ACTION_SELECT_ITEM);
        AddGossipItemFor(player, GOSSIP_ICON_CHAT, "View my customizations",
                         GOSSIP_SENDER_MAIN, ACTION_VIEW_CUSTOMS);
        AddGossipItemFor(player, GOSSIP_ICON_CHAT, "Reset a customization",
                         GOSSIP_SENDER_MAIN, ACTION_RESET_CUSTOM);
        SendGossipMenuFor(player, NPC_TEXT_CUSTOMIZER_HELLO, creature);
        return true;
    }

    bool OnGossipSelect(Player* player, Creature* creature, uint32 sender, uint32 action) override
    {
        ClearGossipMenuFor(player);
        
        switch (action)
        {
            case ACTION_SELECT_ITEM:
                ShowUpgradedItems(player, creature);
                break;
            case ACTION_SELECT_PATH:
                ShowPathOptions(player, creature);
                break;
            case ACTION_SELECT_STATS:
                ShowStatOptions(player, creature);
                break;
            // ... etc
        }
        
        return true;
    }

private:
    void ShowUpgradedItems(Player* player, Creature* creature)
    {
        // Show all equipped items that are upgraded
        for (uint8 slot = EQUIPMENT_SLOT_START; slot < EQUIPMENT_SLOT_END; ++slot)
        {
            Item* item = player->GetItemByPos(INVENTORY_SLOT_BAG_0, slot);
            if (!item)
                continue;
            
            auto* upgrade = DarkChaos::ItemUpgrade::GetUpgradeManager()->GetItemUpgradeState(item->GetGUID().GetCounter());
            if (!upgrade || upgrade->upgrade_level == 0)
                continue;
            
            std::string itemName = item->GetTemplate()->Name1;
            std::string slotName = GetSlotName(slot);
            
            std::ostringstream text;
            text << "[" << slotName << "] " << itemName << " (+" << static_cast<int>(upgrade->upgrade_level) << ")";
            
            AddGossipItemFor(player, GOSSIP_ICON_GEAR, text.str(),
                             GOSSIP_SENDER_MAIN + slot, ACTION_CUSTOMIZE_ITEM);
        }
        
        SendGossipMenuFor(player, NPC_TEXT_SELECT_ITEM, creature);
    }

    void ShowPathOptions(Player* player, Creature* creature)
    {
        auto paths = sItemCustom->GetAvailablePaths(_selectedItemId);
        
        for (const auto& path : paths)
        {
            std::ostringstream text;
            text << "|cFF";
            text << GetPathColor(path.pathId);
            text << path.pathName << "|r - " << path.pathDescription;
            
            AddGossipItemFor(player, GOSSIP_ICON_TRAINER, text.str(),
                             GOSSIP_SENDER_MAIN, ACTION_SELECT_PATH + path.pathId);
        }
        
        SendGossipMenuFor(player, NPC_TEXT_SELECT_PATH, creature);
    }
};
```

---

## AIO Addon Customization UI

```lua
-- ItemCustomizer.lua
local CustomizerFrame = AIO.AddAddon()

function CustomizerFrame:Init()
    self.frame = CreateFrame("Frame", "DCItemCustomizer", UIParent)
    self.frame:SetSize(500, 450)
    self.frame:SetPoint("CENTER")
    
    -- Item display
    self:CreateItemDisplay()
    
    -- Path selection
    self:CreatePathButtons()
    
    -- Stat priority
    self:CreateStatDropdowns()
    
    -- Preview
    self:CreateStatPreview()
    
    -- Apply button
    self:CreateApplyButton()
end

function CustomizerFrame:CreatePathButtons()
    local paths = {
        {id = 1, name = "Power", color = {1, 0.2, 0.2}, icon = "Ability_Warrior_Rampage"},
        {id = 2, name = "Survival", color = {0.2, 1, 0.2}, icon = "Spell_Holy_BlessedLife"},
        {id = 3, name = "Versatile", color = {0.2, 0.6, 1}, icon = "Spell_Holy_DivineProtection"},
        {id = 4, name = "Specialized", color = {1, 0.8, 0.2}, icon = "Ability_Mage_ArcanePotency"},
    }
    
    self.pathButtons = {}
    for i, path in ipairs(paths) do
        local btn = CreateFrame("Button", nil, self.frame, "UIPanelButtonTemplate")
        btn:SetSize(100, 80)
        btn:SetPoint("TOPLEFT", 20 + (i-1) * 115, -100)
        
        btn.icon = btn:CreateTexture(nil, "ARTWORK")
        btn.icon:SetSize(40, 40)
        btn.icon:SetPoint("TOP", 0, -5)
        btn.icon:SetTexture("Interface\\Icons\\" .. path.icon)
        
        btn.text = btn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        btn.text:SetPoint("BOTTOM", 0, 10)
        btn.text:SetText(path.name)
        btn.text:SetTextColor(unpack(path.color))
        
        btn:SetScript("OnClick", function()
            self:SelectPath(path.id)
        end)
        
        self.pathButtons[i] = btn
    end
end

function CustomizerFrame:CreateStatDropdowns()
    self.statDropdown1 = CreateFrame("Frame", "DCStatDropdown1", self.frame, "UIDropDownMenuTemplate")
    self.statDropdown1:SetPoint("TOPLEFT", 20, -220)
    UIDropDownMenu_SetWidth(self.statDropdown1, 150)
    UIDropDownMenu_SetText(self.statDropdown1, "Priority Stat 1")
    
    self.statDropdown2 = CreateFrame("Frame", "DCStatDropdown2", self.frame, "UIDropDownMenuTemplate")
    self.statDropdown2:SetPoint("TOPLEFT", 200, -220)
    UIDropDownMenu_SetWidth(self.statDropdown2, 150)
    UIDropDownMenu_SetText(self.statDropdown2, "Priority Stat 2")
end

function CustomizerFrame:CreateStatPreview()
    self.previewFrame = CreateFrame("Frame", nil, self.frame)
    self.previewFrame:SetSize(200, 150)
    self.previewFrame:SetPoint("BOTTOMLEFT", 20, 60)
    
    self.previewFrame.title = self.previewFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    self.previewFrame.title:SetPoint("TOP")
    self.previewFrame.title:SetText("Stat Preview")
    
    self.previewLines = {}
    for i = 1, 6 do
        local line = self.previewFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        line:SetPoint("TOPLEFT", 10, -20 - (i-1) * 18)
        self.previewLines[i] = line
    end
end

function CustomizerFrame:UpdatePreview()
    local data = self:CalculatePreviewStats()
    
    self.previewLines[1]:SetText("Primary: " .. FormatStatChange(data.primary))
    self.previewLines[2]:SetText("Stamina: " .. FormatStatChange(data.stamina))
    self.previewLines[3]:SetText("Armor: " .. FormatStatChange(data.armor))
    self.previewLines[4]:SetText(data.stat1Name .. ": " .. FormatStatChange(data.stat1))
    self.previewLines[5]:SetText(data.stat2Name .. ": " .. FormatStatChange(data.stat2))
end

function FormatStatChange(change)
    if change > 0 then
        return "|cFF00FF00+" .. change .. "%|r"
    elseif change < 0 then
        return "|cFFFF0000" .. change .. "%|r"
    else
        return "|cFFFFFFFF+0%|r"
    end
end
```

---

## Commands

| Command | Description |
|---------|-------------|
| `.upgrade customize <slot>` | Open customization for equipped item |
| `.upgrade path <slot> <pathId>` | Set upgrade path |
| `.upgrade stats <slot> <stat1> <stat2>` | Set priority stats |
| `.upgrade preview <slot>` | Preview current customization |
| `.upgrade reset <slot>` | Reset customization to default |

---

## Timeline

| Phase | Duration | Tasks |
|-------|----------|-------|
| Schema | 1 day | Database tables |
| Modifiers | 4 days | Stat modifier calculation |
| Application | 4 days | Hook into stat application |
| NPC | 3 days | Customization NPC |
| UI | 4 days | AIO addon interface |
| Commands | 1 day | GM/player commands |
| Testing | 4 days | Balance and validation |
| **Total** | **~3 weeks** | |

---

## Future Enhancements

1. **Path Switching** - Allow changing paths (with cost)
2. **Legendary Paths** - Unique paths for artifact items
3. **Class-Specific Paths** - Tank/Healer/DPS specialized
4. **Path Mastery** - Bonus effects at high upgrade levels
5. **Dual Path** - Combine two paths at reduced effectiveness
