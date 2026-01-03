# AoE Loot System Extensions

**Priority:** B-Tier  
**Effort:** Low-Medium (1 week)  
**Impact:** Medium  
**Target System:** `src/server/scripts/DC/AOELoot/`

---

## Current System Analysis

Based on `ac_aoeloot.cpp` (550+ lines):
- Full AoE loot collection system
- Configuration-driven settings
- Gold tracking and leaderboard
- Anti-exploit measures
- GM commands for management

---

## Proposed Extensions

### 1. Smart Loot Filtering

Player-configurable loot filters to auto-sell or auto-ignore items.

```sql
-- Loot filter definitions
CREATE TABLE dc_aoeloot_filters (
    player_guid INT UNSIGNED NOT NULL,
    filter_type ENUM('ignore', 'auto_sell', 'auto_mail', 'highlight') NOT NULL,
    item_quality TINYINT UNSIGNED DEFAULT 255,  -- 255 = any
    item_class TINYINT UNSIGNED DEFAULT 255,
    item_subclass TINYINT UNSIGNED DEFAULT 255,
    item_id INT UNSIGNED DEFAULT 0,  -- 0 = all matching
    min_value_copper INT UNSIGNED DEFAULT 0,
    max_value_copper INT UNSIGNED DEFAULT 0,  -- 0 = no max
    enabled BOOLEAN DEFAULT TRUE,
    priority TINYINT UNSIGNED DEFAULT 50,
    PRIMARY KEY (player_guid, filter_type, item_quality, item_class, item_subclass, item_id)
);

-- Filter presets for quick setup
CREATE TABLE dc_aoeloot_filter_presets (
    preset_id INT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
    preset_name VARCHAR(50) NOT NULL,
    preset_description TEXT,
    filter_data TEXT NOT NULL  -- JSON array of filter rules
);
```

```cpp
enum LootFilterAction
{
    FILTER_NONE = 0,
    FILTER_IGNORE = 1,      // Don't pick up
    FILTER_AUTO_SELL = 2,   // Pick up and auto-sell
    FILTER_AUTO_MAIL = 3,   // Send to alt/mailbox
    FILTER_HIGHLIGHT = 4    // Special notification
};

class LootFilterManager
{
public:
    static LootFilterManager* instance();

    LootFilterAction GetFilterAction(ObjectGuid::LowType playerGuid, const ItemTemplate* item)
    {
        if (!item)
            return FILTER_NONE;
        
        auto filters = GetPlayerFilters(playerGuid);
        if (filters.empty())
            return FILTER_NONE;
        
        // Sort by priority (higher first)
        std::sort(filters.begin(), filters.end(), 
            [](const auto& a, const auto& b) { return a.priority > b.priority; });
        
        for (const auto& filter : filters)
        {
            if (!filter.enabled)
                continue;
            
            bool matches = true;
            
            // Check item ID first (most specific)
            if (filter.itemId != 0 && filter.itemId != item->ItemId)
                matches = false;
            
            // Check quality
            if (filter.itemQuality != 255 && filter.itemQuality != item->Quality)
                matches = false;
            
            // Check class/subclass
            if (filter.itemClass != 255 && filter.itemClass != item->Class)
                matches = false;
            if (filter.itemSubclass != 255 && filter.itemSubclass != item->SubClass)
                matches = false;
            
            // Check value range
            if (filter.minValue > 0 && item->SellPrice < filter.minValue)
                matches = false;
            if (filter.maxValue > 0 && item->SellPrice > filter.maxValue)
                matches = false;
            
            if (matches)
                return filter.filterType;
        }
        
        return FILTER_NONE;
    }
    
    void ApplyPreset(ObjectGuid::LowType playerGuid, uint32 presetId)
    {
        auto preset = GetPreset(presetId);
        if (!preset)
            return;
        
        // Clear existing filters
        CharacterDatabase.Execute(
            "DELETE FROM dc_aoeloot_filters WHERE player_guid = {}",
            playerGuid);
        
        // Apply preset filters
        auto filters = nlohmann::json::parse(preset->filterData);
        for (const auto& f : filters)
        {
            CharacterDatabase.Execute(
                "INSERT INTO dc_aoeloot_filters VALUES ({}, '{}', {}, {}, {}, {}, {}, {}, 1, {})",
                playerGuid,
                f["type"].get<std::string>(),
                f.value("quality", 255),
                f.value("class", 255),
                f.value("subclass", 255),
                f.value("item_id", 0),
                f.value("min_value", 0),
                f.value("max_value", 0),
                f.value("priority", 50));
        }
        
        // Reload cache
        ReloadPlayerFilters(playerGuid);
    }

private:
    std::unordered_map<uint32, std::vector<LootFilter>> _playerFilters;
};
```

#### Default Presets
```sql
INSERT INTO dc_aoeloot_filter_presets (preset_name, preset_description, filter_data) VALUES
('Vendor Trash', 'Auto-sell gray items', '[{"type":"auto_sell","quality":0}]'),
('No Whites', 'Ignore white items', '[{"type":"ignore","quality":1}]'),
('Valuable Only', 'Only loot items worth 1g+', '[{"type":"ignore","max_value":10000}]'),
('Cloth Collector', 'Highlight cloth drops', '[{"type":"highlight","class":7}]'),
('Gem Hunter', 'Highlight gems and jewelcrafting', '[{"type":"highlight","class":3}]');
```

---

### 2. Loot Statistics & Analytics

Detailed tracking of loot collection patterns.

```sql
CREATE TABLE dc_aoeloot_statistics (
    player_guid INT UNSIGNED NOT NULL,
    stat_date DATE NOT NULL,
    total_items_looted INT UNSIGNED DEFAULT 0,
    total_gold_looted BIGINT UNSIGNED DEFAULT 0,
    items_auto_sold INT UNSIGNED DEFAULT 0,
    gold_from_auto_sell BIGINT UNSIGNED DEFAULT 0,
    rarest_item_looted INT UNSIGNED DEFAULT 0,
    rare_count INT UNSIGNED DEFAULT 0,
    epic_count INT UNSIGNED DEFAULT 0,
    legendary_count INT UNSIGNED DEFAULT 0,
    PRIMARY KEY (player_guid, stat_date)
);

CREATE TABLE dc_aoeloot_item_log (
    log_id BIGINT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
    player_guid INT UNSIGNED NOT NULL,
    item_id INT UNSIGNED NOT NULL,
    item_count INT UNSIGNED NOT NULL,
    creature_entry INT UNSIGNED DEFAULT 0,
    map_id INT UNSIGNED NOT NULL,
    zone_id INT UNSIGNED NOT NULL,
    looted_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    was_auto_sold BOOLEAN DEFAULT FALSE,
    KEY idx_player_date (player_guid, looted_at),
    KEY idx_item (item_id)
);
```

```cpp
void AOELootManager::LogLoot(Player* player, Item* item, Creature* source)
{
    ObjectGuid::LowType guid = player->GetGUID().GetCounter();
    const ItemTemplate* proto = item->GetTemplate();
    
    // Insert item log
    CharacterDatabase.Execute(
        "INSERT INTO dc_aoeloot_item_log "
        "(player_guid, item_id, item_count, creature_entry, map_id, zone_id) "
        "VALUES ({}, {}, {}, {}, {}, {})",
        guid, proto->ItemId, item->GetCount(),
        source ? source->GetEntry() : 0,
        player->GetMapId(), player->GetZoneId());
    
    // Update daily statistics
    CharacterDatabase.Execute(
        "INSERT INTO dc_aoeloot_statistics "
        "(player_guid, stat_date, total_items_looted) "
        "VALUES ({}, CURDATE(), 1) "
        "ON DUPLICATE KEY UPDATE total_items_looted = total_items_looted + 1",
        guid);
    
    // Track quality counts
    if (proto->Quality >= ITEM_QUALITY_RARE)
    {
        std::string column;
        switch (proto->Quality)
        {
            case ITEM_QUALITY_RARE: column = "rare_count"; break;
            case ITEM_QUALITY_EPIC: column = "epic_count"; break;
            case ITEM_QUALITY_LEGENDARY: column = "legendary_count"; break;
            default: break;
        }
        
        if (!column.empty())
        {
            CharacterDatabase.Execute(
                "UPDATE dc_aoeloot_statistics SET {} = {} + 1 "
                "WHERE player_guid = {} AND stat_date = CURDATE()",
                column, column, guid);
        }
    }
}

struct PlayerLootStats
{
    uint64 totalItemsLooted;
    uint64 totalGoldLooted;
    uint64 goldFromAutoSell;
    uint32 rareCount;
    uint32 epicCount;
    uint32 legendaryCount;
    std::string favoriteZone;
    uint32 mostLootedItem;
};

PlayerLootStats AOELootManager::GetPlayerStats(ObjectGuid::LowType playerGuid, 
    const std::string& period)
{
    std::string whereClause;
    if (period == "daily")
        whereClause = "AND stat_date = CURDATE()";
    else if (period == "weekly")
        whereClause = "AND stat_date >= DATE_SUB(CURDATE(), INTERVAL 7 DAY)";
    else if (period == "monthly")
        whereClause = "AND stat_date >= DATE_SUB(CURDATE(), INTERVAL 30 DAY)";
    
    auto result = CharacterDatabase.Query(
        "SELECT "
        "  SUM(total_items_looted), SUM(total_gold_looted), "
        "  SUM(gold_from_auto_sell), SUM(rare_count), "
        "  SUM(epic_count), SUM(legendary_count) "
        "FROM dc_aoeloot_statistics "
        "WHERE player_guid = {} {}",
        playerGuid, whereClause);
    
    PlayerLootStats stats = {};
    if (result)
    {
        Field* fields = result->Fetch();
        stats.totalItemsLooted = fields[0].Get<uint64>();
        stats.totalGoldLooted = fields[1].Get<uint64>();
        stats.goldFromAutoSell = fields[2].Get<uint64>();
        stats.rareCount = fields[3].Get<uint32>();
        stats.epicCount = fields[4].Get<uint32>();
        stats.legendaryCount = fields[5].Get<uint32>();
    }
    
    return stats;
}
```

---

### 3. Group Loot Distribution

Enhanced loot sharing for groups.

```sql
CREATE TABLE dc_aoeloot_group_settings (
    group_leader_guid INT UNSIGNED PRIMARY KEY,
    loot_mode ENUM('ffa', 'round_robin', 'need_greed', 'master') DEFAULT 'ffa',
    auto_distribute BOOLEAN DEFAULT TRUE,
    quality_threshold TINYINT UNSIGNED DEFAULT 2,  -- Green+ for special rules
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

```cpp
enum GroupLootMode
{
    GROUP_LOOT_FFA = 0,          // Everyone gets their own
    GROUP_LOOT_ROUND_ROBIN = 1,  // Takes turns
    GROUP_LOOT_NEED_GREED = 2,   // Roll for quality items
    GROUP_LOOT_MASTER = 3        // Leader distributes
};

class GroupLootDistributor
{
public:
    void DistributeLoot(Group* group, std::vector<Item*>& loot, Creature* source)
    {
        auto settings = GetGroupSettings(group->GetLeaderGUID().GetCounter());
        
        switch (settings.lootMode)
        {
            case GROUP_LOOT_FFA:
                // Each member gets own loot - handled by default AoE loot
                break;
                
            case GROUP_LOOT_ROUND_ROBIN:
                DistributeRoundRobin(group, loot);
                break;
                
            case GROUP_LOOT_NEED_GREED:
                DistributeNeedGreed(group, loot, settings.qualityThreshold);
                break;
                
            case GROUP_LOOT_MASTER:
                SendToMaster(group, loot);
                break;
        }
    }
    
private:
    void DistributeRoundRobin(Group* group, std::vector<Item*>& loot)
    {
        size_t memberIdx = 0;
        auto members = GetGroupMembers(group);
        
        for (auto* item : loot)
        {
            if (members.empty())
                break;
            
            Player* recipient = members[memberIdx % members.size()];
            GiveItemToPlayer(recipient, item);
            memberIdx++;
        }
    }
    
    void DistributeNeedGreed(Group* group, std::vector<Item*>& loot, uint8 threshold)
    {
        for (auto* item : loot)
        {
            if (item->GetTemplate()->Quality >= threshold)
            {
                // Start roll for this item
                StartRoll(group, item);
            }
            else
            {
                // Low quality - distribute normally
                GiveItemToNearestMember(group, item);
            }
        }
    }
    
    void StartRoll(Group* group, Item* item)
    {
        // Send roll request to all group members
        for (auto* member : GetGroupMembers(group))
        {
            SendRollRequest(member, item);
        }
        
        // Store pending roll
        _pendingRolls[item->GetGUID()] = {
            .item = item,
            .group = group,
            .rolls = {},
            .expiresAt = GameTime::GetGameTime().count() + 30
        };
    }
};
```

---

### 4. Loot Notifications Enhancement

Richer loot notifications with sounds and visual effects.

```cpp
struct LootNotification
{
    uint32 itemId;
    uint32 count;
    bool isRare;
    bool isUpgrade;
    uint32 goldValue;
    std::string specialMessage;
};

void AOELootManager::SendEnhancedNotification(Player* player, 
    const std::vector<LootNotification>& notifications)
{
    nlohmann::json data;
    data["type"] = "loot_collected";
    data["items"] = nlohmann::json::array();
    
    uint32 totalValue = 0;
    bool hasRare = false;
    bool hasUpgrade = false;
    
    for (const auto& notif : notifications)
    {
        nlohmann::json item;
        item["id"] = notif.itemId;
        item["count"] = notif.count;
        item["is_rare"] = notif.isRare;
        item["is_upgrade"] = notif.isUpgrade;
        item["value"] = notif.goldValue;
        
        if (!notif.specialMessage.empty())
            item["message"] = notif.specialMessage;
        
        data["items"].push_back(item);
        
        totalValue += notif.goldValue;
        hasRare |= notif.isRare;
        hasUpgrade |= notif.isUpgrade;
    }
    
    data["total_value"] = totalValue;
    data["total_items"] = notifications.size();
    
    // Determine notification tier
    std::string tier = "normal";
    if (hasUpgrade)
        tier = "upgrade";
    else if (hasRare)
        tier = "rare";
    else if (totalValue > 100000)  // 10g+
        tier = "valuable";
    
    data["tier"] = tier;
    
    // Send to addon
    SendAddonPacket(player, "DC_AOELOOT", data.dump());
}
```

#### Addon Display
```lua
-- AOELootNotifications.lua
local NotifFrame = AIO.AddAddon()

function NotifFrame:Init()
    self.frame = CreateFrame("Frame", "DCLootNotif", UIParent)
    self.frame:SetSize(300, 200)
    self.frame:SetPoint("BOTTOMRIGHT", -50, 200)
    
    self.notifications = {}
    self.pool = {}
    
    -- Create notification pool
    for i = 1, 10 do
        local notif = self:CreateNotification()
        notif:Hide()
        table.insert(self.pool, notif)
    end
end

function NotifFrame:CreateNotification()
    local notif = CreateFrame("Frame", nil, self.frame)
    notif:SetSize(280, 30)
    
    notif.icon = notif:CreateTexture(nil, "ARTWORK")
    notif.icon:SetSize(24, 24)
    notif.icon:SetPoint("LEFT", 3, 0)
    
    notif.text = notif:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    notif.text:SetPoint("LEFT", notif.icon, "RIGHT", 5, 0)
    
    notif.value = notif:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    notif.value:SetPoint("RIGHT", -5, 0)
    notif.value:SetTextColor(1, 0.82, 0)
    
    notif.glow = notif:CreateTexture(nil, "BACKGROUND")
    notif.glow:SetAllPoints()
    notif.glow:SetTexture("Interface\\Buttons\\UI-Listbox-Highlight2")
    notif.glow:SetAlpha(0)
    
    return notif
end

function NotifFrame:ShowLoot(data)
    -- Get notification from pool
    local notif = table.remove(self.pool, 1)
    if not notif then
        notif = self:CreateNotification()
    end
    
    -- Setup notification
    local itemName, _, quality, _, _, _, _, _, _, itemTexture = GetItemInfo(data.id)
    notif.icon:SetTexture(itemTexture)
    
    local color = ITEM_QUALITY_COLORS[quality] or ITEM_QUALITY_COLORS[1]
    notif.text:SetText(string.format("|c%s%s|r x%d", 
        color.hex, itemName or "Item", data.count))
    
    if data.value > 0 then
        notif.value:SetText(GetCoinTextureString(data.value))
    else
        notif.value:SetText("")
    end
    
    -- Tier-based effects
    if data.tier == "upgrade" then
        notif.glow:SetVertexColor(0, 1, 0)
        notif.glow:SetAlpha(0.3)
        PlaySound("LEVELUP")
    elseif data.tier == "rare" then
        notif.glow:SetVertexColor(0.5, 0.5, 1)
        notif.glow:SetAlpha(0.2)
        PlaySound("RaidWarning")
    else
        notif.glow:SetAlpha(0)
    end
    
    -- Position and animate
    notif:SetPoint("TOP", self.frame, "TOP", 0, -#self.notifications * 35)
    notif:Show()
    
    -- Fade out after delay
    C_Timer.After(5, function()
        UIFrameFadeOut(notif, 0.5, 1, 0)
        C_Timer.After(0.5, function()
            notif:Hide()
            table.insert(self.pool, notif)
            self:RepositionNotifications()
        end)
    end)
    
    table.insert(self.notifications, notif)
end
```

---

### 5. Auto-Sell Integration

Seamless auto-sell of filtered items.

```cpp
class AutoSellManager
{
public:
    uint32 ProcessAutoSell(Player* player, const std::vector<Item*>& items)
    {
        uint32 totalGold = 0;
        std::vector<uint32> soldItems;
        
        for (auto* item : items)
        {
            auto action = sLootFilter->GetFilterAction(
                player->GetGUID().GetCounter(), item->GetTemplate());
            
            if (action != FILTER_AUTO_SELL)
                continue;
            
            uint32 sellPrice = item->GetTemplate()->SellPrice * item->GetCount();
            
            // Add gold to player
            player->ModifyMoney(sellPrice);
            totalGold += sellPrice;
            
            // Track for statistics
            soldItems.push_back(item->GetEntry());
            
            // Destroy item
            player->DestroyItem(item->GetBagSlot(), item->GetSlot(), true);
        }
        
        if (totalGold > 0)
        {
            // Update statistics
            CharacterDatabase.Execute(
                "UPDATE dc_aoeloot_statistics SET "
                "items_auto_sold = items_auto_sold + {}, "
                "gold_from_auto_sell = gold_from_auto_sell + {} "
                "WHERE player_guid = {} AND stat_date = CURDATE()",
                soldItems.size(), totalGold, player->GetGUID().GetCounter());
            
            // Notify player
            player->GetSession()->SendAreaTriggerMessage(
                "|cFFFFD700Auto-sold %zu items for %s|r",
                soldItems.size(), FormatMoney(totalGold).c_str());
        }
        
        return totalGold;
    }
};
```

---

### 6. Loot Radius Configuration

Player-configurable loot radius.

```sql
CREATE TABLE dc_aoeloot_player_settings (
    player_guid INT UNSIGNED PRIMARY KEY,
    loot_radius FLOAT DEFAULT 30.0,
    auto_loot_enabled BOOLEAN DEFAULT TRUE,
    auto_sell_enabled BOOLEAN DEFAULT TRUE,
    notification_style ENUM('minimal', 'standard', 'detailed', 'off') DEFAULT 'standard',
    sound_enabled BOOLEAN DEFAULT TRUE,
    auto_loot_gold BOOLEAN DEFAULT TRUE,
    auto_loot_quest BOOLEAN DEFAULT TRUE
);
```

```cpp
float AOELootManager::GetPlayerLootRadius(ObjectGuid::LowType playerGuid)
{
    auto it = _playerSettings.find(playerGuid);
    if (it != _playerSettings.end())
        return it->second.lootRadius;
    
    // Load from DB
    auto result = CharacterDatabase.Query(
        "SELECT loot_radius FROM dc_aoeloot_player_settings WHERE player_guid = {}",
        playerGuid);
    
    if (result)
        return result->Fetch()[0].Get<float>();
    
    return _defaultRadius;  // Config default
}

bool AOELootManager::SetPlayerLootRadius(ObjectGuid::LowType playerGuid, float radius)
{
    // Clamp to valid range
    float minRadius = sConfigMgr->GetOption<float>("AOELoot.MinRadius", 10.0f);
    float maxRadius = sConfigMgr->GetOption<float>("AOELoot.MaxRadius", 100.0f);
    radius = std::clamp(radius, minRadius, maxRadius);
    
    CharacterDatabase.Execute(
        "INSERT INTO dc_aoeloot_player_settings (player_guid, loot_radius) "
        "VALUES ({}, {}) ON DUPLICATE KEY UPDATE loot_radius = {}",
        playerGuid, radius, radius);
    
    _playerSettings[playerGuid].lootRadius = radius;
    return true;
}
```

---

## GM Commands

```cpp
// .aoeloot filter add <player> <type> <quality> [class] [subclass]
// .aoeloot filter remove <player> <type> <quality>
// .aoeloot filter list <player>
// .aoeloot filter preset <player> <preset_id>
// .aoeloot stats <player> [period]
// .aoeloot radius <player> <radius>
// .aoeloot settings <player>
```

---

## Configuration Options

```ini
# AOE Loot Extended Settings
AOELoot.Extended.EnableFilters = 1
AOELoot.Extended.EnableAutoSell = 1
AOELoot.Extended.EnableStatistics = 1
AOELoot.Extended.MinRadius = 10.0
AOELoot.Extended.MaxRadius = 100.0
AOELoot.Extended.DefaultRadius = 30.0
AOELoot.Extended.StatRetentionDays = 90
AOELoot.Extended.ItemLogRetentionDays = 7
```

---

## Timeline

| Phase | Duration | Tasks |
|-------|----------|-------|
| Filters | 2 days | Filter system, presets |
| Statistics | 2 days | Tracking, queries |
| Group Loot | 2 days | Distribution modes |
| Notifications | 1 day | Enhanced display |
| Auto-Sell | 1 day | Seamless integration |
| Testing | 1 day | Full system test |
| **Total** | **~1.5 weeks** | |

---

## Integration Points

- **ItemUpgrades**: Filter based on upgrade potential
- **Seasons**: Seasonal loot bonuses
- **Hotspots**: Enhanced loot in hotspot zones
- **Prestige**: Prestige affects loot radius cap
