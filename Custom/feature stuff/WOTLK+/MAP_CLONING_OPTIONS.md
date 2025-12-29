# Map and Zone Cloning Options for Dark Chaos

## Document Purpose
Evaluate technical options for cloning/duplicating existing maps and zones to create additional content for level 255 progression.

---

## 1. Understanding Map Cloning vs Zone Reuse

### Key Distinction
| Approach | Description | Client Patch | Best For |
|----------|-------------|--------------|----------|
| **Zone Reuse** | Use existing unused map areas as-is | None | Quick content |
| **Map Cloning** | Duplicate entire maps with modifications | Required | Major new zones |
| **Instance Cloning** | Copy dungeons to new instance IDs | Minimal | Scaled dungeons |
| **Phased Content** | Same zone, different phases | None | Layered content |

---

## 2. Technical Map Structure (3.3.5a)

### File Types Involved
| File Type | Extension | Purpose | Location |
|-----------|-----------|---------|----------|
| WDT | .wdt | Map tile index | World/Maps/{MapName}/ |
| ADT | .adt | Terrain tiles (64x64 per map) | World/Maps/{MapName}/ |
| WMO | .wmo | World Map Objects (buildings) | World/wmo/ |
| M2 | .m2 | Models (trees, props, creatures) | World/generic/ |
| DBC | .dbc | Database definitions | DBFilesClient/ |

### Key DBCs for Maps
| DBC File | Purpose |
|----------|---------|
| Map.dbc | Map definitions (ID, name, type) |
| AreaTable.dbc | Zone/subzone definitions |
| WorldMapArea.dbc | World map display |
| WorldMapContinent.dbc | Continent map display |
| DungeonMap.dbc | Instance map frames |
| LoadingScreens.dbc | Loading screen assignments |
| LFGDungeons.dbc | Dungeon finder entries |

---

## 3. Cloning Options Analysis

### Option A: Full Map Clone (New Map ID)

**Process:**
```
1. Copy all ADT files to new folder with new map name
2. Copy WDT file with new name
3. Add entry to Map.dbc with new MapID
4. Add entries to AreaTable.dbc for zones
5. Add WorldMapArea/Continent entries
6. Update loading screens
7. Create client MPQ patch with all files
```

**Pros:**
- Complete control over new map
- Can modify terrain, objects, spawns independently
- No interference with original content

**Cons:**
- Large client patch (full map ~100-500MB per continent)
- Significant DBC editing
- Must recreate all spawn data in SQL

**Best For:**
- Creating "alternate dimension" versions of continents
- Major expansions with heavy modifications

**Example Use Case:**
Clone Eastern Kingdoms as "Corrupted Eastern Kingdoms" for level 200-255 with modified terrain textures and new mob spawns.

### Option B: Instance Cloning (Same Map, Different Instance)

**Process:**
```
1. Create new entry in instance_template with same MapID
2. Add new difficulty entries in LFGDungeons.dbc (optional)
3. Create scaled creature_template entries
4. Create scaled loot tables
5. Update InstanceScript for new mechanics
```

**Pros:**
- No client patch required (or minimal)
- Quick to implement
- Can share map with original

**Cons:**
- Same physical layout
- Can't modify terrain/objects
- May cause confusion without clear UI distinction

**Best For:**
- Mythic+ style scaling dungeons (Dark Chaos already uses this!)
- Heroic+/Epic versions of dungeons
- Level-scaled versions for 80-255 progression

**Dark Chaos Advantage:**
Already implemented for Mythic+ system - can extend to ALL dungeons.

### Option C: Map ID Override (Advanced)

**Process:**
```
1. Create duplicate Map.dbc entry with same ADT path
2. Both maps point to same terrain files
3. Different spawn data per MapID in SQL
4. Phasing/teleport logic separates players
```

**Pros:**
- Zero client file duplication
- Different spawns per "version"
- Smaller patches

**Cons:**
- Complex implementation
- Potential client issues with duplicate map references
- Limited to spawn/object differences

**Best For:**
- "Past" and "Present" versions of zones
- Seasonal event variations
- PvP vs PvE versions

### Option D: Phased Zones (No Cloning)

**Process:**
```
1. Use phasing system in existing zones
2. Different phase = different creatures/objects
3. Phase based on level/quest/achievement
```

**Pros:**
- No client patches
- Already works in WotLK
- Seamless transitions

**Cons:**
- Same terrain/buildings
- Phase system limitations
- Players in different phases can't see each other

**Best For:**
- Progressive zone content
- Story-based zone changes
- Level-tiered content in same area

---

## 4. Implementation Complexity Matrix

| Method | Server Work | Client Patch | Time Estimate | Dark Chaos Feasibility |
|--------|-------------|--------------|---------------|------------------------|
| Full Map Clone | High | Large (100MB+) | 2-4 weeks | Medium - for major content |
| Instance Clone | Medium | None/Minimal | 1-2 days | **High - already proven** |
| Map ID Override | High | Small (DBCs) | 1-2 weeks | Medium |
| Phased Zones | Low | None | 2-3 days | **High - native support** |

---

## 5. Recommended Cloning Strategies for Level 255

### Strategy 1: Dungeon Scaling Pipeline (Highest Priority)
**Already implemented via Mythic+, extend to:**

| Original Dungeon | Scaled Version | Level Range |
|------------------|----------------|-------------|
| Deadmines | Deadmines M+ | 80-100 |
| Scarlet Monastery | SM M+ Tiers | 100-130 |
| Stratholme | Stratholme M+ | 130-160 |
| Blackrock Depths | BRD M+ | 160-190 |
| Blackrock Spire | BRS M+ | 190-220 |
| Dire Maul | DM M+ | 220-255 |

**Implementation:**
```sql
-- Scale creature templates by tier
INSERT INTO creature_template_scaling 
SELECT entry, tier * 1.25 as health_mod, tier * 1.15 as damage_mod
FROM mythic_plus_tiers;
```

### Strategy 2: Zone Reuse with Phasing (Medium Priority)

**Existing Unused Zones (No Clone Needed):**
- Emerald Dream (partially accessible)
- Programmers' Isle
- Designer Island
- QA/GM Islands

**Phase-Based Level Scaling:**
```
Zone: Wintergrasp
- Phase 1 (Level 1-80): Normal WotLK content
- Phase 2 (Level 80-130): Scaled mobs, new quests
- Phase 3 (Level 130-180): Elite versions, world bosses
- Phase 4 (Level 180-255): Mythic world content
```

### Strategy 3: Selective Map Clones (Lower Priority)

**Best Candidates for Full Clones:**

| Original | Clone Purpose | Justification |
|----------|--------------|---------------|
| Outland | "Shattered Outland" | Good layout, iconic |
| Northrend | "Frozen Wastes" | Large content area |
| Eastern Kingdoms | "Corrupted EK" | Familiar but twisted |

**Clone Modification Ideas:**
- Different skybox (apocalyptic theme)
- Recolored terrain textures
- New WMO placements (ruins, portals)
- Different creature spawns

---

## 6. Technical Implementation Guide

### 6.1 Creating a Dungeon Clone (Instance Method)

**Step 1: Database Setup**
```sql
-- Add new instance template
INSERT INTO instance_template (map, parent, script, allowMount)
SELECT map, parent, 'instance_deadmines_mythic', 0
FROM instance_template WHERE map = 36;  -- Deadmines

-- Create difficulty scaling table
CREATE TABLE IF NOT EXISTS dungeon_scaling (
    instance_id INT,
    tier INT,
    health_multiplier FLOAT,
    damage_multiplier FLOAT,
    loot_tier INT
);
```

**Step 2: Creature Scaling**
```sql
-- Create scaled creature templates
INSERT INTO creature_template (entry, name, minlevel, maxlevel, ...)
SELECT entry + 1000000, CONCAT(name, ' [Mythic]'), 
       minlevel * tier_scale, maxlevel * tier_scale, ...
FROM creature_template 
WHERE entry IN (SELECT creature_entry FROM dungeon_creatures WHERE map = 36);
```

**Step 3: Loot Scaling**
```sql
-- Scale loot tables
INSERT INTO creature_loot_template (Entry, Item, ...)
SELECT Entry + 1000000, scaled_item_id, ...
FROM creature_loot_template
WHERE Entry IN (SELECT entry FROM scaled_creatures);
```

### 6.2 Creating a Full Map Clone

**Step 1: File Preparation**
```powershell
# Clone map files
$sourceMap = "World/Maps/Kalimdor"
$destMap = "World/Maps/KalimdorCorrupted"

# Copy all ADT/WDT files
Copy-Item "$sourceMap/*" -Destination $destMap -Recurse
Rename-Item "$destMap/Kalimdor.wdt" "KalimdorCorrupted.wdt"
```

**Step 2: DBC Modifications**
```
Map.dbc:
  - Add new MapID (e.g., 2001)
  - Set Directory = "KalimdorCorrupted"
  - Set MapName_lang = "Corrupted Kalimdor"

AreaTable.dbc:
  - Clone zone entries with new AreaIDs
  - Update ParentAreaID references

WorldMapArea.dbc:
  - Add entries for world map display
```

**Step 3: MPQ Packaging**
```powershell
# Create patch MPQ
$mpq = New-MPQArchive "patch-x.mpq"
$mpq.Add("World/Maps/KalimdorCorrupted/*")
$mpq.Add("DBFilesClient/Map.dbc")
$mpq.Add("DBFilesClient/AreaTable.dbc")
$mpq.Save()
```

### 6.3 Phased Zone Implementation

**Step 1: Phase Definitions**
```sql
-- Define phases for a zone
INSERT INTO phase_definitions (phase_id, zone_id, min_level, max_level, name)
VALUES 
(10001, 4395, 80, 130, 'Dalaran Tier 1'),
(10002, 4395, 130, 180, 'Dalaran Tier 2'),
(10003, 4395, 180, 255, 'Dalaran Tier 3');
```

**Step 2: Creature Phase Assignment**
```sql
-- Assign creatures to phases
UPDATE creature SET phaseMask = 
    CASE 
        WHEN creature_level <= 80 THEN 1
        WHEN creature_level <= 130 THEN 2
        WHEN creature_level <= 180 THEN 4
        ELSE 8
    END
WHERE map = 571 AND zone = 4395;
```

**Step 3: Player Phase Assignment (Eluna)**
```lua
local function OnLogin(event, player)
    local level = player:GetLevel()
    local zone = player:GetZoneId()
    
    if zone == 4395 then  -- Dalaran
        if level <= 80 then
            player:SetPhaseMask(1, true)
        elseif level <= 130 then
            player:SetPhaseMask(2, true)
        elseif level <= 180 then
            player:SetPhaseMask(4, true)
        else
            player:SetPhaseMask(8, true)
        end
    end
end
RegisterPlayerEvent(3, OnLogin)
```

---

## 7. Tools for Map Cloning

### Essential Tools
| Tool | Purpose | Source |
|------|---------|--------|
| Noggit | Terrain editing, ADT modification | github.com/noggit/noggit3 |
| WoW Model Viewer | Model extraction/preview | wowmodelviewer.net |
| MPQ Editor | MPQ archive creation/editing | github.com/Ladikl/MPQEditor |
| DBC Editor | DBC file editing | various forks available |
| Spell Editor | DBC spell modifications | github.com/stoneharry/Spell-Editor |
| MySQL Workbench | Database management | mysql.com |

### Workflow Example (Dungeon Modification)
```
1. Extract original dungeon ADTs with MPQ Editor
2. Load in Noggit for terrain modifications
3. Export modified ADTs
4. Update DBCs with DBC Editor
5. Package into patch MPQ
6. Test on development client
7. Deploy to production
```

---

## 8. Dark Chaos Specific Recommendations

### Immediate Implementation (No Client Patches)
1. **Extend Mythic+ to all classic dungeons** - Already have system
2. **Phase-based scaling in unused zones** - Wintergrasp, Crystalsong
3. **Instance clones of raids** - Naxxramas Mythic, Ulduar Mythic

### Medium Term (Minor Client Patches)
1. **DBC patches for new dungeon entries** - Better UI integration
2. **Loading screen customizations** - Thematic consistency
3. **World map additions** - Show scaled zones

### Long Term (Major Client Patches)
1. **Full continent clone** - "Corrupted Outland" for 200-255
2. **Custom dungeon maps** - Modified layouts
3. **New world bosses zones** - Cloned arenas

---

## 9. Conclusion

### Best Path Forward for Dark Chaos

**Priority 1: Instance Cloning (90% of new content)**
- Already proven with Mythic+ system
- No client patches required
- Quick to implement
- Extend to all 80+ dungeons/raids

**Priority 2: Phased Zones (9% of new content)**
- Use for open-world progression
- Level-tiered content
- No client patches

**Priority 3: Full Map Clones (1% of new content)**
- Reserve for major content expansions
- "Alternate dimension" themes
- Significant client patch required

### Content Volume Estimate

Using primarily instance cloning and phasing:
| Content Type | Count | Level Coverage |
|--------------|-------|----------------|
| Scaled Dungeons | 40+ | 80-255 |
| Scaled Raids | 15+ | 100-255 |
| Phased Zones | 10+ | 80-255 |
| Custom Zones (existing) | 5 | 1-160 |

**Total: 60+ zones/dungeons** without major client patches!

---

## References
- WoWDev Wiki ADT: https://wowdev.wiki/ADT
- WoWDev Wiki Map: https://wowdev.wiki/Map
- Noggit Documentation: github.com/noggit/noggit3
- AzerothCore Instance System: azerothcore.org/wiki
