# Heirloom System: Separate Primary & Secondary Stat Upgrades - Feasibility Analysis

**Date:** November 16, 2025  
**Status:** FEASIBILITY ANALYSIS  
**Recommendation:** ✅ HIGHLY FEASIBLE - Multiple proven implementation paths available

---

## Executive Summary

**YES - Separate primary and secondary stat upgrades are fully feasible** in your AzerothCore codebase. Your existing infrastructure already supports this through multiple proven mechanisms.

### Key Findings:

1. **Primary Stats (STR/AGI/INT/STA/SPI)**: Auto-scale with character level using existing **heirloom scaling system** (`heirloom_scaling_255.cpp`)
2. **Secondary Stats (Crit/Haste/Mastery/etc)**: Add via **enchantment system** using ItemUpgrade essence upgrades
3. **Client Recognition**: ✅ Fully supported - client automatically recognizes both methods
4. **No New Systems Needed**: Leverage existing heirloom + enchantment infrastructure

---

## The Proposed Design

### Option 1: "Heirloom Feature" (Primary Stats) + "Item Upgrade Tier" (Secondary Stats)

**Rename "Tier Upgrade" → "Enhancement Level" or "Essence Level"**

```
Heirloom Flamefury Blade (Level 1)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
+25 Strength     ← Scales with character level (heirloom)
+20 Stamina      ← Scales with character level (heirloom)
+15 Critical Strike ← Added via Enhancement Level 5
+10 Haste        ← Added via Enhancement Level 5
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Enhancement Level: 5/15 (⭐⭐⭐⭐⭐○○○○○○○○○○)
Upgrade cost: 281 Artifact Essence
```

**Key Terminology:**
- ❌ "Tier Upgrade" → Too confusing with TIER_RAID, TIER_MYTHIC, etc.
- ✅ "Enhancement Level" → Clear, non-conflicting
- ✅ "Essence Level" → Thematic with essence currency
- ✅ "Artifact Power Level" → Thematic for artifact-tier items

---

## Technical Implementation: Three Proven Methods

### Method A: Heirloom Scaling + Enchantments (RECOMMENDED ⭐)

**How It Works:**

1. **Primary Stats** → Handled by `heirloom_scaling_255.cpp` (already exists)
   - Uses `ScalingStatDistribution` and `ScalingStatValue` from item_template
   - Auto-scales STR/AGI/INT/STA/SPI with player level (1-255)
   - Client automatically recognizes via DBC system
   - **NO C++ CHANGES NEEDED** - already working!

2. **Secondary Stats** → Added via temporary enchantments
   - Uses `TEMP_ENCHANTMENT_SLOT` (enchantment slot already exists)
   - Enchant ID formula: `300003 + (tier × 100) + level`
   - Example: Enhancement Level 8 = Enchant ID 80008
   - Client displays as green bonus stats ("+15 Critical Strike")
   - Already proven working in your ItemUpgrade system

**Client Recognition:**
- ✅ Primary stats: Client reads `ITEM_FIELD_ENCHANTMENT` + `ScalingStatValue`
- ✅ Secondary stats: Client reads `PLAYER_VISIBLE_ITEM_1_ENCHANTMENT` field
- ✅ Tooltips: Both display correctly (white for primary, green for secondary)
- ✅ Character sheet: Both update player stats in real-time

**Advantages:**
- ✅ Uses existing proven systems (heirloom_scaling_255.cpp already works)
- ✅ Client automatically recognizes both stat types
- ✅ Minimal C++ changes (only enchantment application logic)
- ✅ Clear visual distinction (primary=white, secondary=green text)
- ✅ Database-friendly (no template modifications)

**Implementation Steps:**

```cpp
// File: src/server/scripts/DC/ItemUpgrades/ItemUpgradeStatApplication.cpp

void ApplyHeirloomEnhancement(Player* player, Item* item, uint8 enhancement_level)
{
    if (!player || !item)
        return;

    // Check if this is a heirloom item
    ItemTemplate const* proto = item->GetTemplate();
    if (proto->Quality != ITEM_QUALITY_HEIRLOOM)
        return;

    // Primary stats already handled by heirloom_scaling_255.cpp
    // We only need to apply secondary stat enchantment

    // Remove old enchantment if exists
    if (item->GetEnchantmentId(TEMP_ENCHANTMENT_SLOT))
    {
        player->ApplyEnchantment(item, TEMP_ENCHANTMENT_SLOT, false);
        item->ClearEnchantment(TEMP_ENCHANTMENT_SLOT);
    }

    // Apply new enchantment based on enhancement level
    uint32 enchant_id = 300003 + enhancement_level; // 300004-80015
    item->SetEnchantment(TEMP_ENCHANTMENT_SLOT, enchant_id, 0, 0);
    player->ApplyEnchantment(item, TEMP_ENCHANTMENT_SLOT, true);

    // Force stat update
    player->UpdateAllStats();
}
```

**Database Setup:**

```sql
-- Heirloom items already have ScalingStatDistribution set
-- Example from your current SQL:
INSERT INTO item_template (entry, class, subclass, name, displayid, Quality, 
    Flags, BuyCount, BuyPrice, SellPrice, InventoryType, AllowableClass, AllowableRace,
    ItemLevel, RequiredLevel, RequiredSkill, RequiredSkillRank,
    maxcount, stackable, ContainerSlots, StatsCount,
    stat_type1, stat_value1, -- PRIMARY STATS (handled by heirloom system)
    stat_type2, stat_value2, -- SET TO 0 (no secondary stats in template)
    ScalingStatDistribution, ScalingStatValue, -- KEY: These enable heirloom scaling
    -- ... rest of fields
) VALUES (
    300332, 2, 8, 'Heirloom Flamefury Blade', 45001, 7, -- Quality 7 = HEIRLOOM
    524288, 1, 0, 0, 13, -1, -1,
    1, 1, 0, 0, 1, 1, 0, 1,
    4, 25, -- stat_type1=STR(4), stat_value1=25 (BASE - will be scaled by heirloom)
    0, 0,  -- NO SECONDARY STATS in template
    1, 100, -- ScalingStatDistribution + ScalingStatValue (enables heirloom)
    -- ...
);

-- Enhancement enchantments (secondary stats only)
INSERT INTO spell_item_enchantment_template (ench, chance, description) VALUES
-- Level 0: 1.05x multiplier (5% bonus)
(300003, 100, 'Enhancement Level 0 (+5% Secondary Stats)'),
-- Level 1: 1.075x multiplier (7.5% bonus)
(300004, 100, 'Enhancement Level 1 (+7.5% Secondary Stats)'),
-- Level 5: 1.15x multiplier (15% bonus)
(80005, 100, 'Enhancement Level 5 (+15% Secondary Stats)'),
-- Level 10: 1.275x multiplier (27.5% bonus)
(80010, 100, 'Enhancement Level 10 (+27.5% Secondary Stats)'),
-- Level 15: 1.35x multiplier (35% bonus)
(80015, 100, 'Enhancement Level 15 (+35% Secondary Stats)');

-- Enhancement costs (essence-based progression)
-- Use a NEW name: dc_heirloom_enhancement_costs (not "tier", not "upgrade")
CREATE TABLE IF NOT EXISTS dc_heirloom_enhancement_costs (
    enhancement_level TINYINT UNSIGNED NOT NULL,
    essence_cost INT UNSIGNED NOT NULL,
    stat_multiplier FLOAT NOT NULL,
    PRIMARY KEY (enhancement_level)
);

-- Populate enhancement costs (1.05x → 1.35x over 15 levels)
INSERT INTO dc_heirloom_enhancement_costs 
(enhancement_level, essence_cost, stat_multiplier) VALUES
(0, 0, 1.05),      -- Starting bonus: 5%
(1, 75, 1.075),    -- Level 1: 75 essence, +7.5%
(2, 83, 1.10),     -- Level 2: 83 essence, +10%
(3, 91, 1.125),    -- Level 3: 91 essence, +12.5%
(4, 100, 1.15),    -- ...escalating costs
(5, 110, 1.175),
-- ... continue to level 15
(15, 281, 1.35);   -- Max level: 35% bonus to secondary stats
```

**Key Files to Modify:**

1. ✅ **Already Working:** `src/server/scripts/DC/heirloom_scaling_255.cpp`
   - Handles primary stat scaling (STR/AGI/INT/STA/SPI)
   - Hooks into `OnPlayerCustomScalingStatValueBefore` and `OnPlayerCustomScalingStatValue`
   - Scales stats from level 1-255 automatically
   - **NO MODIFICATIONS NEEDED** - this already works!

2. 🔨 **Needs Creation:** `src/server/scripts/DC/ItemUpgrades/ItemUpgradeHeirloomEnhancement.cpp`
   - New file to handle enhancement (secondary stat) application
   - Apply/remove enchantments when enhancement level changes
   - Hook into equip/unequip events

3. 🔨 **Needs Modification:** `src/server/scripts/DC/ItemUpgrades/ItemUpgradeAddonHandler.cpp`
   - Add handling for heirloom items specifically
   - Send enhancement level (not "tier") to addon
   - Message format: `HEIRLOOM_ENHANCE|item_guid|enhancement_level|max_level|stat_multiplier`

4. 🔨 **Needs Modification:** `Custom/Client addons needed/DC-ItemUpgrade/DarkChaos_ItemUpgrade_Retail.lua`
   - Add special UI section for heirlooms: "Enhancement Level" instead of "Upgrade Level"
   - Display: "Primary stats scale with your level (Heirloom)"
   - Display: "Secondary stats: +15% (Enhancement Level 5/15)"

---

### Method B: Dual Enchantment Slots (Alternative)

**How It Works:**

1. **Primary Stats** → Use `PERM_ENCHANTMENT_SLOT` (enchantment slot 0)
   - Apply enchant with formula based on player level
   - Enchant ID: `90000 + playerLevel` (e.g., 90080 for level 80)
   - Grants STR/AGI/INT/STA/SPI based on level

2. **Secondary Stats** → Use `TEMP_ENCHANTMENT_SLOT` (enchantment slot 1)
   - Apply enchant with formula based on enhancement level
   - Enchant ID: `300003 + enhancement_level` (e.g., 80005 for level 5)
   - Grants Crit/Haste/Mastery based on enhancement level

**Client Recognition:**
- ✅ Client reads both `PLAYER_VISIBLE_ITEM_1_ENCHANTMENT` offset 0 and 1
- ✅ Both slots display in tooltip
- ✅ Both slots update character stats

**Advantages:**
- ✅ Complete control over both stat types
- ✅ Clear separation of concerns
- ✅ Easy to update independently

**Disadvantages:**
- ⚠️ Requires 2 enchantment entries per level (more database entries)
- ⚠️ Primary stat enchant needs to update on level-up (more C++ logic)
- ⚠️ Less "clean" than reusing existing heirloom system

---

### Method C: Custom Item Fields (Advanced)

**How It Works:**

1. Add custom fields to `item_instance` table
2. Store primary_stat_level and secondary_stat_level separately
3. Calculate stats dynamically on equip

**Client Recognition:**
- ⚠️ Requires packet manipulation (custom SMSG_ITEM_QUERY_SINGLE_RESPONSE)
- ⚠️ Client won't auto-recognize without custom patch
- ⚠️ More complex implementation

**Recommendation:** ❌ NOT RECOMMENDED - too complex for what you need

---

## Client Recognition: How It Works

### Primary Stat Recognition (Heirloom System)

**Server → Client Flow:**

```
1. Player equips heirloom item
   ↓
2. Server calls _ApplyItemBonuses() (Player.cpp line 6693)
   ↓
3. Checks for ScalingStatDistribution (line 6698)
   ↓
4. Calls OnPlayerCustomScalingStatValueBefore hook
   ↓
5. heirloom_scaling_255.cpp calculates scaled stats (line 40-107)
   ↓
6. Server applies stats via HandleStatModifier()
   ↓
7. Server sends SMSG_UPDATE_OBJECT with new UNIT_FIELD_STAT values
   ↓
8. Client updates character sheet display
```

**Key Fields Updated:**
- `UNIT_FIELD_STAT0` (Strength)
- `UNIT_FIELD_STAT1` (Agility)
- `UNIT_FIELD_STAT2` (Stamina)
- `UNIT_FIELD_STAT3` (Intellect)
- `UNIT_FIELD_STAT4` (Spirit)

### Secondary Stat Recognition (Enchantment System)

**Server → Client Flow:**

```
1. Player upgrades heirloom enhancement level
   ↓
2. Server calls ApplyEnchantment() (PlayerStorage.cpp line 4304)
   ↓
3. Server sets enchant via SetEnchantment() (Item.cpp line 922)
   ↓
4. Updates ITEM_FIELD_ENCHANTMENT_1_1 with enchant ID
   ↓
5. Updates PLAYER_VISIBLE_ITEM_1_ENCHANTMENT for visibility (line 4672)
   ↓
6. Client queries enchant data from spell_item_enchantment_template
   ↓
7. Applies stat bonuses (Crit/Haste/etc) via enchant effects
   ↓
8. Client updates tooltip and character sheet
```

**Key Fields Updated:**
- `ITEM_FIELD_ENCHANTMENT_1_1` (enchant ID stored on item)
- `PLAYER_VISIBLE_ITEM_1_ENCHANTMENT` (visible to client for tooltip)
- Rating fields: `PLAYER_FIELD_COMBAT_RATING_1` (Crit), etc.

### Visual Display in Client

**Character Sheet:**
```
Strength: 125 (100 + 25)  ← Primary (heirloom scaling)
  +25 from Heirloom Scaling

Critical Strike Rating: 45 (30 + 15)  ← Secondary (enchantment)
  +15 from Enhancement Level 5
```

**Tooltip:**
```
Heirloom Flamefury Blade
━━━━━━━━━━━━━━━━━━━━━━━━
+25 Strength          (white text - from item_template)
+20 Stamina           (white text - from item_template)
+15 Critical Strike   (green text - from enchantment)
+10 Haste Rating      (green text - from enchantment)
━━━━━━━━━━━━━━━━━━━━━━━━
Enhancement Level: 5/15
Upgrade for more secondary stats
```

---

## Naming Recommendations

**Avoid "Tier" Terminology** - It conflicts with existing TIER_RAID, TIER_MYTHIC in your ItemUpgradeManager.h

### Recommended Names:

1. **"Enhancement Level"** ⭐ BEST
   - Clear and descriptive
   - No conflicts with existing systems
   - Natural progression feel
   - Example: "Enhancement Level 5/15"

2. **"Essence Level"** ⭐ GOOD
   - Ties directly to currency (Artifact Essence)
   - Thematic for artifact-tier items
   - Example: "Essence Level 5/15"

3. **"Artifact Power Level"**
   - Very thematic
   - Clear connection to artifact system
   - Example: "Artifact Power Level 5/15"

4. **"Empowerment Level"**
   - Fantasy-appropriate
   - Distinct from other systems
   - Example: "Empowerment Level 5/15"

### Database Table Names:

```sql
-- OLD (confusing with TIER_RAID enum)
dc_item_upgrade_costs  ❌

-- NEW (clear and non-conflicting)
dc_heirloom_enhancement_costs  ✅
dc_heirloom_essence_levels     ✅
dc_artifact_power_levels       ✅
```

---

## Implementation Recommendation

### ⭐ Recommended Path: Method A (Heirloom + Enchantment)

**Why This Is Best:**

1. ✅ **Minimal Changes** - Heirloom scaling already works perfectly
2. ✅ **Proven Systems** - Both heirloom and enchantment systems battle-tested
3. ✅ **Client Native** - No client patches needed
4. ✅ **Clear Separation** - Primary (white) vs Secondary (green) visually distinct
5. ✅ **Database Friendly** - No template modifications
6. ✅ **Easy to Maintain** - Leverage existing infrastructure

**What Needs to Be Done:**

1. **SQL Updates:**
   - ✅ Already done: Remove secondary stats from item_template (stat_type2/3 = 0)
   - 🔨 Create new table: `dc_heirloom_enhancement_costs` (rename from tier)
   - 🔨 Create enchantment entries: 16 enchants for levels 0-15

2. **C++ Code:**
   - ✅ Already working: `heirloom_scaling_255.cpp` (primary stats)
   - 🔨 Create new: `ItemUpgradeHeirloomEnhancement.cpp` (secondary stats via enchants)
   - 🔨 Modify: `ItemUpgradeAddonHandler.cpp` (send enhancement data, not "tier")

3. **Lua Addon:**
   - 🔨 Add UI section for heirlooms: "Enhancement Level" display
   - 🔨 Update tooltip generation: Show "Primary stats scale with level"
   - 🔨 Update upgrade preview: Show secondary stat gains only

**Estimated Development Time:**
- SQL: 2 hours (table + enchant entries)
- C++: 8-12 hours (enhancement application + hooks)
- Lua: 4-6 hours (UI updates + tooltip changes)
- Testing: 4-6 hours
- **Total: 18-26 hours** (2-3 days of focused work)

---

## Testing Checklist

Once implemented, verify the following:

### Primary Stat Testing (Heirloom System)

- [ ] Create level 1 character, equip heirloom
- [ ] Verify STR/AGI/INT/STA/SPI show base values
- [ ] Level to 10, verify primary stats increase automatically
- [ ] Level to 80, verify primary stats continue scaling
- [ ] Level to 255, verify primary stats reach max scaling
- [ ] Check character sheet displays correct values
- [ ] Check tooltip displays correct primary stats (white text)

### Secondary Stat Testing (Enhancement System)

- [ ] Create heirloom at Enhancement Level 0
- [ ] Verify NO secondary stats initially
- [ ] Upgrade to Enhancement Level 1
- [ ] Verify Crit/Haste/etc appear (green text in tooltip)
- [ ] Upgrade to Enhancement Level 5
- [ ] Verify secondary stats increase (multiplier 1.175x)
- [ ] Upgrade to Enhancement Level 15 (max)
- [ ] Verify secondary stats reach 1.35x multiplier
- [ ] Unequip item, verify enchantment removed
- [ ] Re-equip, verify enchantment reapplied

### Integration Testing

- [ ] Equip heirloom at level 1, verify primary stats only
- [ ] Upgrade to Enhancement Level 5, verify secondary stats added
- [ ] Level to 80, verify primary stats increase but secondary stats unchanged
- [ ] Upgrade to Enhancement Level 10, verify secondary stats increase
- [ ] Trade heirloom to alt, verify stats apply correctly
- [ ] Test with all 9 weapon types + 24 armor pieces

---

## FAQ

### Q: Will this work with existing heirlooms?

**A:** Yes! Your `heirloom_scaling_255.cpp` already handles primary stat scaling perfectly. You just need to add the enchantment layer for secondary stats.

### Q: What if a player logs out with a heirloom equipped?

**A:** Enchantments persist in the database (`character_item_instance` table). On login, the server will re-apply the enchantment automatically via `AddEnchantmentDurations()`.

### Q: Can players see the enhancement level in trade window?

**A:** Yes! The enchantment is stored in `PLAYER_VISIBLE_ITEM_1_ENCHANTMENT` which is visible in trade/inspect/tooltips.

### Q: What happens if a player removes the enchantment manually?

**A:** Add a check in `HandleCancelTempEnchantmentOpcode` to prevent removal of enhancement enchants (IDs 300003-80015).

### Q: Will this conflict with other enchantments (weapon oils, etc)?

**A:** No - heirlooms use `TEMP_ENCHANTMENT_SLOT` which is separate from weapon enchants (`PERM_ENCHANTMENT_SLOT`). Both can coexist.

### Q: How does this scale computationally?

**A:** Extremely well. Primary stat scaling happens once per level-up. Secondary stat application happens once per equip. Both use O(1) lookups.

---

## Conclusion

**✅ VERDICT: Highly Feasible - Recommended for Production**

Your codebase has ALL the infrastructure needed to implement separate primary/secondary stat upgrades:

1. ✅ **Heirloom system** (`heirloom_scaling_255.cpp`) handles primary stats
2. ✅ **Enchantment system** (`ApplyEnchantment()`) handles secondary stats
3. ✅ **Client recognition** fully supported for both methods
4. ✅ **Existing database** structure supports enhancement tracking
5. ✅ **Proven implementations** already working in your ItemUpgrade system

**Next Steps:**

1. Decide on naming: "Enhancement Level", "Essence Level", or "Artifact Power"
2. Create SQL migration for `dc_heirloom_enhancement_costs` table
3. Implement `ItemUpgradeHeirloomEnhancement.cpp` for enchantment application
4. Update addon UI to display enhancement level
5. Test thoroughly with all heirloom types

**Recommended Timeline:**
- Week 1: SQL + C++ implementation
- Week 2: Addon UI updates
- Week 3: Testing + bug fixes
- **Total: 3 weeks to production-ready**

---

**Author:** GitHub Copilot  
**Analysis Date:** November 16, 2025  
**Codebase Version:** AzerothCore 3.3.5a with DarkChaos modifications
