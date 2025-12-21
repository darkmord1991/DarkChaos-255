# DC-Leaderboards Integration for Collections

**Purpose:** Define how collection statistics integrate with the existing DC-Leaderboards addon  
**Related:** DC-Leaderboards v1.4.0, Collection System Overview

---

## Overview

The DC-Leaderboards addon already provides a full-screen category/subcategory system for competitive rankings. Collection statistics fit naturally as a new category for server-wide collection competition.

---

## Proposed Leaderboard Categories

Add to `LB.Categories` in DC-Leaderboards.lua:

```lua
{
    id = "collections",
    name = "Collections",
    icon = "Interface\\Icons\\INV_Misc_Bag_17",
    color = "ff69b4",  -- Hot pink for collections
    subcats = {
        { id = "coll_total", name = "Total Collected" },
        { id = "coll_mounts", name = "Mounts" },
        { id = "coll_pets", name = "Companion Pets" },
        { id = "coll_transmog", name = "Appearances" },
        { id = "coll_toys", name = "Toys" },
        { id = "coll_titles", name = "Titles" },
        { id = "coll_achieve", name = "Collection Achievements" },
    }
},
```

---

## Database Tables (Server-Side)

All tables use `dc_` prefix for consistency:

```sql
-- Leaderboard cache for collections (updated periodically)
CREATE TABLE IF NOT EXISTS `dc_collection_leaderboard` (
    `account_id` INT UNSIGNED NOT NULL,
    `collection_type` ENUM('total','mount','pet','transmog','toy','title','achieve') NOT NULL,
    `count` INT UNSIGNED NOT NULL DEFAULT 0,
    `percent` DECIMAL(5,2) NOT NULL DEFAULT 0.00,
    `rank` INT UNSIGNED NOT NULL DEFAULT 0,
    `last_updated` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`account_id`, `collection_type`),
    KEY `idx_rank` (`collection_type`, `rank`),
    KEY `idx_count` (`collection_type`, `count` DESC)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='Collection leaderboard rankings';
```

---

## Leaderboard Data Format

### Request (Client → Server)
```json
{
    "op": 1,
    "cat": "collections",
    "subcat": "coll_mounts",
    "page": 1,
    "limit": 25
}
```

### Response (Server → Client)
```json
{
    "op": 16,
    "cat": "collections",
    "subcat": "coll_mounts",
    "total": 487,
    "page": 1,
    "entries": [
        {
            "rank": 1,
            "name": "TopCollector",
            "class": 2,
            "value": 175,
            "extra": "100.0%",
            "guild": "Elite Guild"
        },
        {
            "rank": 2,
            "name": "MountFan",
            "class": 8,
            "value": 168,
            "extra": "96.0%",
            "guild": "Collectors United"
        }
    ]
}
```

---

## Column Display Configuration

Add to DC-Leaderboards column definitions:

```lua
-- Collection-specific column configurations
LB.CollectionColumns = {
    coll_total = {
        { name = "Collected", key = "value", width = 100 },
        { name = "Percent", key = "extra", width = 80 },
    },
    coll_mounts = {
        { name = "Mounts", key = "value", width = 80 },
        { name = "Percent", key = "extra", width = 80 },
        { name = "Favorites", key = "extra2", width = 80 },
    },
    coll_pets = {
        { name = "Pets", key = "value", width = 80 },
        { name = "Percent", key = "extra", width = 80 },
        { name = "Named", key = "extra2", width = 80 },
    },
    coll_transmog = {
        { name = "Appearances", key = "value", width = 100 },
        { name = "Percent", key = "extra", width = 80 },
    },
    coll_toys = {
        { name = "Toys", key = "value", width = 80 },
        { name = "Percent", key = "extra", width = 80 },
    },
    coll_titles = {
        { name = "Titles", key = "value", width = 80 },
        { name = "Percent", key = "extra", width = 80 },
    },
    coll_achieve = {
        { name = "Achievements", key = "value", width = 100 },
        { name = "Points", key = "extra", width = 80 },
    },
}
```

---

## Server Query Examples

### Total Collection Leaderboard
```sql
SELECT 
    a.username AS account_name,
    c.name AS character_name,
    c.class,
    COALESCE(gm.guildid, 0) AS guild_id,
    (
        SELECT COUNT(*) FROM dc_mount_collection WHERE account_id = a.id
    ) + (
        SELECT COUNT(*) FROM dc_pet_collection WHERE account_id = a.id
    ) + (
        SELECT COUNT(*) FROM dc_toy_collection WHERE account_id = a.id
    ) AS total_collected,
    ROUND(
        (
            (SELECT COUNT(*) FROM dc_mount_collection WHERE account_id = a.id) +
            (SELECT COUNT(*) FROM dc_pet_collection WHERE account_id = a.id) +
            (SELECT COUNT(*) FROM dc_toy_collection WHERE account_id = a.id)
        ) * 100.0 / (
            (SELECT COUNT(*) FROM dc_mount_definitions) +
            (SELECT COUNT(*) FROM dc_pet_definitions) +
            (SELECT COUNT(*) FROM dc_toy_definitions)
        ), 1
    ) AS percent_complete
FROM auth.account a
JOIN characters c ON c.account = a.id
LEFT JOIN guild_member gm ON c.guid = gm.guid
WHERE c.guid = (
    SELECT guid FROM characters WHERE account = a.id ORDER BY level DESC LIMIT 1
)
ORDER BY total_collected DESC
LIMIT 25 OFFSET 0;
```

### Mount Collection Leaderboard
```sql
SELECT 
    c.name AS character_name,
    c.class,
    COUNT(mc.spell_id) AS mount_count,
    ROUND(COUNT(mc.spell_id) * 100.0 / (SELECT COUNT(*) FROM dc_mount_definitions), 1) AS percent,
    SUM(mc.is_favorite) AS favorites
FROM dc_mount_collection mc
JOIN characters c ON c.account = mc.account_id 
WHERE c.guid = (
    SELECT guid FROM characters WHERE account = mc.account_id ORDER BY level DESC LIMIT 1
)
GROUP BY mc.account_id
ORDER BY mount_count DESC
LIMIT 25;
```

---

## UI Integration Notes

### Tab Icon Suggestion
Use `Interface\\Icons\\INV_Misc_Bag_17` (collection bag) or create a custom composite icon.

### Color Scheme
- Primary: `#ff69b4` (Hot Pink) - Fun/collection vibe
- Secondary: `#da70d6` (Orchid)
- Accent: `#ffd700` (Gold for achievements)

### Tooltip Enhancement
When hovering a collection entry:
```
Rank #1: TopCollector
────────────────────────
Mounts: 175/175 (100.0%)
 ├─ Ground: 85
 ├─ Flying: 82
 └─ Aquatic: 8
Favorites: 12
Last Mount: Invincible's Reins
```

---

## Implementation Steps

1. **Add category to DC-Leaderboards.lua** (~30 lines)
2. **Add server handler for "collections" category** (Eluna or C++)
3. **Create `dc_collection_leaderboard` cache table**
4. **Add periodic job to update rankings** (every 10 minutes)
5. **Test integration with existing leaderboard UI**

---

## Future Enhancements

- **Weekly/Monthly collection challenges**
- **"Collector of the Week" announcement**
- **Guild collection totals**
- **Collection comparison between players**
- **Collection milestones notifications**

